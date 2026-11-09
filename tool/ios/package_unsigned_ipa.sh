#!/usr/bin/env bash
# Package an unsigned iOS build as an .ipa: the app bundle inside Payload/,
# zipped. It installs on no iPhone as it is; a signing tool and the owner's
# Apple Account sign it first (docs/operations.md, iOS builds).
#
#   tool/ios/package_unsigned_ipa.sh app/build/ios/iphoneos/Runner.app out.ipa
set -euo pipefail

app="${1:?usage: package_unsigned_ipa.sh APP_BUNDLE OUTPUT_IPA}"
out="${2:?usage: package_unsigned_ipa.sh APP_BUNDLE OUTPUT_IPA}"
[[ -d "$app" && -f "$app/Info.plist" ]] || {
  echo "::error::$app is not an app bundle (no Info.plist)"
  exit 1
}
case "$out" in
  /*) ;;
  *) out="$PWD/$out" ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/Payload"
cp -R "$app" "$work/Payload/"
rm -f "$out"
# -y keeps symbolic links inside frameworks as links; -X leaves out extra
# file attributes.
(cd "$work" && zip -qryX "$out" Payload)
echo "Packaged $(basename "$app") as $out ($(du -h "$out" | cut -f1))"
