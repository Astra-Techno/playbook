#!/usr/bin/env bash
set -euo pipefail

# Only run on the disposable macOS GitHub runner. Never echo secret values.
for name in IOS_TEAM_ID IOS_CERTIFICATE_BASE64 IOS_CERTIFICATE_PASSWORD IOS_PROFILE_BASE64 ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_BASE64 APP_PATH BUNDLE_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing required secret or setting: $name"
    exit 1
  fi
done

printf '%s' "$IOS_CERTIFICATE_BASE64" | base64 --decode > "$RUNNER_TEMP/distribution.p12"
printf '%s' "$IOS_PROFILE_BASE64" | base64 --decode > "$RUNNER_TEMP/profile.mobileprovision"
mkdir -p "$RUNNER_TEMP/appstore-keys"
printf '%s' "$ASC_PRIVATE_KEY_BASE64" | base64 --decode > "$RUNNER_TEMP/appstore-keys/AuthKey_${ASC_KEY_ID}.p8"
chmod 600 "$RUNNER_TEMP/distribution.p12" "$RUNNER_TEMP/appstore-keys/"*.p8
security cms -D -i "$RUNNER_TEMP/profile.mobileprovision" > "$RUNNER_TEMP/profile.plist"

python3 scripts/ios/prepare-profile.py

keychain="$RUNNER_TEMP/kocourt-signing.keychain-db"
keychain_password="$(openssl rand -hex 24)"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$RUNNER_TEMP/distribution.p12" -P "$IOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security list-keychains -d user -s "$keychain" login.keychain-db
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security find-identity -v -p codesigning "$keychain"
