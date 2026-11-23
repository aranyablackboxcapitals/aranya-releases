#!/usr/bin/env bash
set -euo pipefail

apk=$1
version=$2
reference=$3
tools=${ANDROID_BUILD_TOOLS:?Set ANDROID_BUILD_TOOLS to the Android build-tools directory}
badging=$("$tools/aapt" dump badging "$apk")
package=$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")
name=$(sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p" <<<"$badging")
code=$(sed -n "s/^package: .*versionCode='\([^']*\)'.*/\1/p" <<<"$badging")
if [[ "$package" != com.aranyacapitals.android || "$name" != "$version" || ! "$code" =~ ^[1-9][0-9]*$ ]] ||
   grep -q '^application-debuggable' <<<"$badging"; then
  echo "Expected a non-debug Aranya APK with versionName $version." >&2
  exit 1
fi

signers() {
  local certs
  certs=$("$tools/apksigner" verify --print-certs "$1")
  sed -n 's/^Signer #[0-9]* certificate SHA-256 digest: //p' <<<"$certs" | sort
}
actual=$(signers "$apk")
expected=$(signers "$reference")
if [[ -z "$actual" || "$actual" != "$expected" ]]; then
  echo "APK signing certificate differs from the current public APK." >&2
  exit 1
fi
previous_badging=$("$tools/aapt" dump badging "$reference")
previous_code=$(sed -n "s/^package: .*versionCode='\([^']*\)'.*/\1/p" <<<"$previous_badging")
if [[ ! "$previous_code" =~ ^[1-9][0-9]*$ ]] ||
   { [[ "${REQUIRE_NEWER:-1}" == 1 ]] && ((code <= previous_code)); }; then
  echo "APK versionCode must be higher than the current public APK's versionCode." >&2
  exit 1
fi
printf 'Verified Aranya %s (versionCode %s).\n' "$version" "$code"
openssl dgst -sha256 "$apk"
