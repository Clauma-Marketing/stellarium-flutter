#!/bin/bash
# Build and upload store releases for Night Sky Guide.
#
# Usage:
#   tool/release.sh bump            # increment build number (3.5.8+250 -> 3.5.8+251)
#   tool/release.sh build           # build Android AAB + iOS IPA
#   tool/release.sh upload-ios      # upload IPA to App Store Connect (TestFlight)
#   tool/release.sh upload-android  # upload AAB to Play Console as DRAFT release
#   tool/release.sh all             # bump + build + upload both
#
# Rollout/submission stays manual on purpose: Play "Start rollout" and the
# App Store "Submit for review" are done in the consoles.
#
# Credentials (tool/release.env, gitignored):
#   ASC_KEY_ID / ASC_ISSUER_ID  App Store Connect API key (App Manager role);
#                               .p8 in ~/.appstoreconnect/private_keys/
#   PLAY_JSON                   Play service-account JSON. One-time setup:
#                               Play Console -> Setup -> API access -> link GCP
#                               project; create service account + JSON key in
#                               GCP; invite its email under Users & permissions
#                               with release permission for the app.
set -euo pipefail
cd "$(dirname "$0")/.."

source tool/release.env

IPA="build/ios/ipa/Star Guide.ipa"
AAB="build/app/outputs/bundle/release/app-release.aab"
PACKAGE="com.starregistration.planetarium"

cmd_bump() {
  local line ver build
  line=$(grep -E '^version:' pubspec.yaml)
  ver=${line#version: }; build=${ver#*+}; ver=${ver%+*}
  sed -i '' "s/^version: .*/version: ${ver}+$((build + 1))/" pubspec.yaml
  echo "Bumped: ${ver}+${build} -> ${ver}+$((build + 1))"
}

cmd_build() {
  # flutterw regenerates the stellarium data asset list before building.
  # Fall back to bare flutter if the wrapper's dart shim fails (see
  # tool/flutterw); only safe when assets/stellarium/data/ is unchanged.
  local flutter_cmd="./tool/flutterw"
  "$flutter_cmd" --version >/dev/null 2>&1 || flutter_cmd="flutter"
  "$flutter_cmd" build appbundle --release
  "$flutter_cmd" build ipa --release
}

cmd_upload_ios() {
  [ -f "$IPA" ] || { echo "No IPA at $IPA - run: tool/release.sh build"; exit 1; }
  xcrun altool --upload-app -t ios -f "$IPA" \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "Uploaded. Track processing in App Store Connect -> TestFlight."
}

cmd_upload_android() {
  [ -f "$AAB" ] || { echo "No AAB at $AAB - run: tool/release.sh build"; exit 1; }
  [ -n "${PLAY_JSON:-}" ] && [ -f "$PLAY_JSON" ] || {
    echo "PLAY_JSON not configured in tool/release.env (see header for setup)."
    echo "Manual fallback: drag $AAB into Play Console -> Production -> Create new release."
    exit 1
  }
  command -v fastlane >/dev/null || { echo "fastlane missing: brew install fastlane"; exit 1; }
  fastlane run upload_to_play_store \
      package_name:"$PACKAGE" aab:"$AAB" json_key:"$PLAY_JSON" \
      track:production release_status:draft
  echo "Uploaded as DRAFT to the production track - roll out in Play Console."
}

case "${1:-}" in
  bump)           cmd_bump ;;
  build)          cmd_build ;;
  upload-ios)     cmd_upload_ios ;;
  upload-android) cmd_upload_android ;;
  all)            cmd_bump; cmd_build; cmd_upload_ios; cmd_upload_android ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
