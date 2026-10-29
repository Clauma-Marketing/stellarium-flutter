"""Capture real app-store screenshot scenes from the live Night Sky Guide web app.

Drives headless Chrome over the DevTools Protocol: boots the deployed web app,
waits for the Stellarium WASM engine, stages each scene through the engine's JS
API (time, view direction, constellation layers, selected star + gold label),
and captures PNGs at exact App Store pixel sizes (logical 430x932 @3x for the
6.7" iPhone canvas).

Usage:
    python capture_scenes.py [--out DIR] [--url URL] [--scene NAME]
"""

import argparse
import base64
import http.client
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import websocket

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT = 9333
APP_URL = "https://star-register-app.web.app"

# Logical viewport; capture is W*SCALE x H*SCALE px (1290x2796 = APP_IPHONE_67)
W, H, SCALE = 430, 932, 3


class CDP:
    def __init__(self, ws_url):
        self.ws = websocket.create_connection(ws_url, timeout=120)
        self.next_id = 0

    def send(self, method, params=None):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    def eval(self, expr, await_promise=False):
        r = self.send("Runtime.evaluate", {
            "expression": expr,
            "awaitPromise": await_promise,
            "returnByValue": True,
        })
        if r.get("exceptionDetails"):
            raise RuntimeError(json.dumps(r["exceptionDetails"])[:500])
        return r.get("result", {}).get("value")

    def wait_for(self, expr, timeout=90, poll=0.5, label=""):
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                if self.eval(expr):
                    return
            except RuntimeError:
                pass
            time.sleep(poll)
        raise TimeoutError(f"waiting for {label or expr}")

    def shot(self, path):
        data = self.send("Page.captureScreenshot", {"format": "png"})["data"]
        Path(path).write_bytes(base64.b64decode(data))
        print(f"  wrote {path}")

    def click(self, x, y):
        for t in ("mousePressed", "mouseReleased"):
            self.send("Input.dispatchMouseEvent", {
                "type": t, "x": x, "y": y, "button": "left", "clickCount": 1,
            })

    def type_text(self, text):
        self.send("Input.insertText", {"text": text})


def launch_chrome(profile_dir):
    proc = subprocess.Popen([
        CHROME, "--headless=new", f"--remote-debugging-port={PORT}",
        "--remote-allow-origins=*",
        f"--user-data-dir={profile_dir}", "--hide-scrollbars",
        "--no-first-run", "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env={**os.environ, "TZ": "America/New_York"})
    for _ in range(60):
        try:
            conn = http.client.HTTPConnection("localhost", PORT, timeout=2)
            conn.request("GET", "/json")
            targets = json.loads(conn.getresponse().read())
            page = next(t for t in targets if t["type"] == "page")
            return proc, page["webSocketDebuggerUrl"]
        except Exception:
            time.sleep(0.5)
    proc.kill()
    raise RuntimeError("Chrome debugger did not come up")


# MJD for a given UTC datetime: days since 1858-11-17T00:00
def mjd(y, mo, d, h=0, mi=0):
    import datetime
    epoch = datetime.datetime(1858, 11, 17, tzinfo=datetime.timezone.utc)
    dt = datetime.datetime(y, mo, d, h, mi, tzinfo=datetime.timezone.utc)
    return (dt - epoch).total_seconds() / 86400.0


# A moonless clear August night over New York, ~22:30 EDT (02:30 UTC next day).
NIGHT_MJD = mjd(2026, 8, 16, 2, 30)

SETUP_COMMON = """
(() => {
  const stel = window.stellarium;
  stel.core.selection = null;
  stel.core.observer.utc = %(mjd).6f;
  stel.core.atmosphere.visible = true;
  stel.core.landscapes.visible = true;
  stel.core.milkyway.visible = true;
  stel.core.dsos.visible = true;
  stel.core.stars.visible = true;
  return true;
})()
"""

def scene_common(cdp):
    cdp.eval(SETUP_COMMON % {"mjd": NIGHT_MJD})
    time.sleep(1.0)


def look(cdp, az_deg, alt_deg, fov_deg=None):
    cdp.eval(f"window.stellariumAPI.lookAt({az_deg}, {alt_deg}, 0.5)")
    if fov_deg is not None:
        cdp.eval(
            "window.stellarium.zoomTo(%f * window.stellarium.D2R, 0.5)" % fov_deg)
    time.sleep(2.0)


def set_lines(cdp, lines=True, labels=True, art=False):
    cdp.eval(f"""
    (() => {{
      const c = window.stellarium.core.constellations;
      c.lines_visible = {str(lines).lower()};
      c.labels_visible = {str(labels).lower()};
      c.images_visible = {str(art).lower()};
      return true;
    }})()""")
    time.sleep(1.0)


def select_star(cdp, name, hip=None, label=None):
    found = cdp.eval(f"""
    (() => {{
      const stel = window.stellarium;
      const hip = {json.dumps(hip)};
      const name = {json.dumps(name)};
      let obj = null;
      if (hip) obj = stel.getObjByHip(hip);
      if (!obj) obj = stel.getObj(name) || stel.getObj('NAME ' + name) || stel.getObj('* ' + name);
      if (!obj) return false;
      stel.core.selection = obj;
      stel.pointAndLock(obj, 1.0);
      return true;
    }})()""")
    if not found:
        raise RuntimeError(f"object not found: {name}")
    time.sleep(2.5)
    if label:
        if not hip:
            raise ValueError("label requires a hip number")
        cdp.eval(f"window.stellariumAPI.addPersistentLabel('HIP {hip}', {json.dumps(label)})")
        time.sleep(1.0)


# ---------------------------------------------------------------- scenes ---

def scene_hero(cdp, out):
    """Milky Way over the horizon, no overlays: the pure sky."""
    scene_common(cdp)
    set_lines(cdp, lines=False, labels=False)
    look(cdp, 170, 32, 95)
    time.sleep(1.5)
    cdp.shot(out / "scene-hero.png")


def scene_constellations(cdp, out):
    """Constellation lines + labels around the summer triangle."""
    scene_common(cdp)
    set_lines(cdp, lines=True, labels=True)
    look(cdp, 120, 55, 110)
    set_lines(cdp, lines=True, labels=True)  # Flutter can re-apply settings; win the race
    time.sleep(1.5)
    set_lines(cdp, lines=True, labels=True)
    time.sleep(1.2)
    cdp.shot(out / "scene-constellations.png")


def scene_star(cdp, out):
    """Vega selected with a gold custom label — the 'your star' shot."""
    scene_common(cdp)
    set_lines(cdp, lines=True, labels=False)
    select_star(cdp, "Vega", hip=91262, label="Emma ⭐")
    cdp.eval("window.stellarium.zoomTo(40 * window.stellarium.D2R, 0.8)")
    time.sleep(2.0)
    set_lines(cdp, lines=True, labels=False)
    time.sleep(1.2)
    cdp.shot(out / "scene-star.png")


def scene_planet(cdp, out):
    """Saturn close-up with rings — solar-system shot."""
    scene_common(cdp)
    set_lines(cdp, lines=False, labels=False)
    select_star(cdp, "Saturn")
    cdp.eval("window.stellarium.zoomTo(0.05 * window.stellarium.D2R, 1.2)")
    time.sleep(3.0)
    # Close the star info sheet (its X button) — the naming CTA reads odd for a
    # planet — then re-center Saturn in the freed-up viewport.
    cdp.click(400, 604)
    time.sleep(1.5)
    cdp.eval("""
    (() => {
      const stel = window.stellarium;
      const obj = stel.getObj('Saturn') || stel.getObj('NAME Saturn');
      if (obj) stel.pointAndLock(obj, 0.8);
      return true;
    })()""")
    cdp.eval("window.stellarium.zoomTo(0.015 * window.stellarium.D2R, 0.8)")
    time.sleep(2.5)
    cdp.shot(out / "scene-planet.png")


def scene_dusk(cdp, out):
    """Deep-blue twilight, first stars out — time-travel shot."""
    cdp.eval(SETUP_COMMON % {"mjd": mjd(2026, 8, 16, 1, 0)})  # 21:00 EDT
    time.sleep(1.0)
    set_lines(cdp, lines=False, labels=False)
    look(cdp, 270, 20, 90)
    time.sleep(1.5)
    cdp.shot(out / "scene-dusk.png")


def scene_search(cdp, out):
    """Two captures: the focused search bar with recent searches, then the
    star found via a typed query. The suggestion list is the app's search
    history, seeded into localStorage before page load (see main)."""
    scene_common(cdp)
    set_lines(cdp, lines=True, labels=False)
    look(cdp, 150, 40, 90)
    cdp.click(190, 891)   # focus the (empty) bottom search bar -> history list
    time.sleep(2.0)
    cdp.shot(out / "scene-search.png")

    cdp.type_text("Sirius")
    time.sleep(1.0)
    for t, down in (("rawKeyDown", True), ("keyUp", False)):
        cdp.send("Input.dispatchKeyEvent", {
            "type": t, "key": "Enter", "code": "Enter",
            "windowsVirtualKeyCode": 13, "nativeVirtualKeyCode": 13,
            **({"text": "\r"} if down else {}),
        })
    time.sleep(5.0)       # registry lookup + fly-to animation
    cdp.shot(out / "scene-found.png")


# Selection-free scenes first: the Flutter star-info sheet stays open once a
# selection is made, so hero/dusk/constellations must run before the
# selection-making scenes. The search flow types into the UI, so it runs last.
SCENES = {
    "hero": scene_hero,
    "dusk": scene_dusk,
    "constellations": scene_constellations,
    "star": scene_star,
    "planet": scene_planet,
    "search": scene_search,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(Path(__file__).parent / "captures"))
    ap.add_argument("--url", default=APP_URL)
    ap.add_argument("--scene", action="append", help="subset of scenes to run")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    profile = tempfile.mkdtemp(prefix="nsg-shots-")
    proc, ws_url = launch_chrome(profile)
    try:
        cdp = CDP(ws_url)
        cdp.send("Page.enable")
        cdp.send("Emulation.setDeviceMetricsOverride", {
            "width": W, "height": H, "deviceScaleFactor": SCALE, "mobile": True,
        })
        # Seed search history so the search scene's suggestion list has
        # believable entries (shared_preferences stores JSON-encoded strings).
        history = json.dumps(json.dumps([
            {"query": "Sirius", "searchedAt": "2026-08-20T21:14:00.000"},
            {"query": "9736-58577-3012084", "searchedAt": "2026-08-19T22:41:00.000"},
            {"query": "Andromeda", "searchedAt": "2026-08-18T23:02:00.000"},
        ]))
        cdp.send("Page.addScriptToEvaluateOnNewDocument", {
            "source": f"localStorage.setItem('flutter.search_history', {json.dumps(history)});",
        })
        cdp.send("Page.navigate", {"url": args.url})
        print("waiting for engine...")
        cdp.wait_for("!!(window.stellarium && window.stellariumReady)",
                     timeout=120, label="stellarium engine")
        time.sleep(6)  # let Flutter apply saved settings / initial state

        names = args.scene or list(SCENES)
        for name in names:
            print(f"scene: {name}")
            SCENES[name](cdp, out)
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
