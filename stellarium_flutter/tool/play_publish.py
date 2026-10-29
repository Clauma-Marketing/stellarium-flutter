"""Publish Night Sky Guide assets to Google Play via the Android Publisher API.

One edit transaction: upload the AAB as a DRAFT production release with
localized release notes, create/update the new-language listings, and replace
phone screenshots for every language. Rollout stays manual in Play Console.

Usage:
    play_publish.py [--skip-aab] [--skip-listings] [--skip-shots] [--dry-run]

Requires:
    - service-account JSON at ~/.config/play-publisher.json (invited in Play
      Console with Manage-store-presence + Release permissions)
    - google-auth + requests
"""

import argparse
import json
import re
import sys
import time
from pathlib import Path

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

PKG = "com.starregistration.planetarium"
BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"

HERE = Path(__file__).parent
# Version comes from pubspec ("version: 3.6.1+253") so it can't drift from the AAB
_VERSION = re.search(r"^version:\s*(\S+)\+(\d+)", (HERE.parent / "pubspec.yaml").read_text(), re.M)
VERSION_NAME, VERSION_CODE = _VERSION.group(1), int(_VERSION.group(2))
AAB = HERE.parent / "build/app/outputs/bundle/release/app-release.aab"
SHOTS = HERE / "store_screenshots/out"
META = json.loads((HERE / "store_metadata/play_locales.json").read_text())
ASC_META = json.loads((HERE / "store_metadata/locales.json").read_text())
NOTES = json.loads((HERE / f"store_metadata/notes-{VERSION_NAME}.json").read_text())
KEY = Path.home() / ".config/play-publisher.json"


def session():
    creds = service_account.Credentials.from_service_account_file(
        KEY, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    creds.refresh(Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s


def check(r, what):
    if not r.ok:
        raise SystemExit(f"{what}: HTTP {r.status_code}\n{r.text[:800]}")
    return r.json() if r.text else {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-aab", action="store_true")
    ap.add_argument("--skip-listings", action="store_true")
    ap.add_argument("--skip-shots", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    s = session()
    edit = check(s.post(f"{BASE}/edits", json={}), "create edit")
    eid = edit["id"]
    print(f"edit {eid}")

    if args.dry_run:
        # prove access, then abandon the edit
        check(s.get(f"{BASE}/edits/{eid}/listings"), "list listings")
        s.delete(f"{BASE}/edits/{eid}")
        print("dry-run OK: API access works")
        return

    # 1) AAB -> draft production release with localized notes
    if not args.skip_aab:
        data = AAB.read_bytes()
        print(f"uploading AAB ({len(data) // 1024 // 1024} MB)...")
        r = s.post(f"{UPLOAD}/edits/{eid}/bundles?uploadType=media",
                   headers={"Content-Type": "application/octet-stream"},
                   data=data, timeout=1800)
        bundle = check(r, "upload bundle")
        print(f"  bundle versionCode {bundle['versionCode']}")
        if bundle["versionCode"] != VERSION_CODE:
            raise SystemExit(f"expected versionCode {VERSION_CODE}")
        notes = [{"language": lang, "text": NOTES[key]}
                 for lang, key in META["notesKey"].items()]
        # Keep the track's live/staged releases; only replace an older draft
        current = check(s.get(f"{BASE}/edits/{eid}/tracks/production"), "get track")
        kept = [r for r in current.get("releases", []) if r.get("status") != "draft"]
        check(s.put(f"{BASE}/edits/{eid}/tracks/production", json={
            "track": "production",
            "releases": kept + [{
                "name": f"{VERSION_NAME} ({VERSION_CODE})",
                "versionCodes": [str(VERSION_CODE)],
                "status": "draft",
                "releaseNotes": notes,
            }],
        }), "set production draft")
        print("  production DRAFT release staged")

    # 2) new-language listings (existing languages left untouched)
    if not args.skip_listings:
        for lang, m in META["newListings"].items():
            override = META.get("fullDescriptionOverrides", {}).get(lang)
            full = override or ASC_META["newLocales"][META["ascLocaleForFullDescription"][lang]]["description"]
            check(s.put(f"{BASE}/edits/{eid}/listings/{lang}", json={
                "language": lang,
                "title": m["title"],
                "shortDescription": m["short"],
                "fullDescription": full,
            }), f"listing {lang}")
            print(f"  listing {lang}: '{m['title']}'")

    # 3) phone screenshots for every language: delete-all, then upload 7
    if not args.skip_shots:
        for lang, d in META["screenshotDirs"].items():
            check(s.delete(f"{BASE}/edits/{eid}/listings/{lang}/phoneScreenshots"),
                  f"clear shots {lang}")
            for i in range(1, 8):
                png = (SHOTS / d / f"APP_IPHONE_67_{i}.png").read_bytes()
                for attempt in (1, 2, 3):
                    r = s.post(
                        f"{UPLOAD}/edits/{eid}/listings/{lang}/phoneScreenshots?uploadType=media",
                        headers={"Content-Type": "image/png"}, data=png, timeout=300)
                    if r.ok:
                        break
                    print(f"    retry {attempt} {lang} #{i}: {r.status_code}")
                    time.sleep(3 * attempt)
                check(r, f"shot {lang} #{i}")
            print(f"  screenshots {lang}: 7 uploaded")

    # 4) commit (retry with changesNotSentForReview when Play demands it)
    r = s.post(f"{BASE}/edits/{eid}:commit")
    if not r.ok and "changesNotSentForReview" in r.text:
        r = s.post(f"{BASE}/edits/{eid}:commit?changesNotSentForReview=true")
    check(r, "commit")
    print("COMMITTED")


if __name__ == "__main__":
    sys.exit(main())
