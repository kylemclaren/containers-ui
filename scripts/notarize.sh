#!/usr/bin/env bash
#
# notarize.sh — submit a DMG to Apple's notary service and staple the ticket.
#
# Requires a Developer-ID-signed payload (hardened runtime + secure timestamp);
# an unsigned DMG will be rejected. Credentials come from the environment:
#
#   NOTARY_APPLE_ID   Apple ID email
#   NOTARY_PASSWORD   app-specific password for that Apple ID
#   NOTARY_TEAM_ID    Apple Developer team ID
#
# Usage: scripts/notarize.sh <path/to.dmg>
#
set -euo pipefail

DMG_PATH="${1:?usage: notarize.sh <dmg>}"
: "${NOTARY_APPLE_ID:?set NOTARY_APPLE_ID}"
: "${NOTARY_PASSWORD:?set NOTARY_PASSWORD}"
: "${NOTARY_TEAM_ID:?set NOTARY_TEAM_ID}"

echo "==> Submitting $DMG_PATH to the notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$NOTARY_APPLE_ID" \
  --password "$NOTARY_PASSWORD" \
  --team-id "$NOTARY_TEAM_ID" \
  --wait

echo "==> Stapling ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
echo "==> Notarized and stapled: $DMG_PATH"
