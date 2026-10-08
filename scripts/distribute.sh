#!/usr/bin/env bash
# Builds the signed release APK and uploads it to Firebase App Distribution.
# Usage: scripts/distribute.sh "release notes" [testers-group]
# Needs android/key.properties + keystore and `firebase login`.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="1:1064196095812:android:19b03f5e6963ab5ca9e111" # Firebase project gaala-evaluator
NOTES="${1:-}"
TESTER_GROUPS="${2:-}"

[[ -f android/key.properties ]] || { echo "Missing android/key.properties" >&2; exit 1; }

flutter build apk --release
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "$APP_ID" \
  --release-notes "$NOTES" \
  ${TESTER_GROUPS:+--groups "$TESTER_GROUPS"}
