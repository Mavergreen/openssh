#!/bin/sh
# Assemble the REPLACEMENT pkg: an empty payload (plus the uninstall helper under the prefix) with
# preinstall/postinstall that back up and symlink the system OpenSSH to our /usr/local copies.
# Same version + 10.9.5 floor as the product pkg. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/versions.sh"
: "${SHIPYARD_SCRIPTS:=$SHIPYARD}"
FULL="$(cat "$REPO_ROOT/VERSION")"
OUT="${OUT:-$REPO_ROOT/dist}"; mkdir -p "$OUT"

payload="$WORK/replace-payload"; rm -rf "$payload"
mkdir -p "$payload$PREFIX/libexec"
cp "$SELF/../scripts/uninstall" "$payload$PREFIX/libexec/openssh-mavericks-deactivate"
chmod +x "$payload$PREFIX/libexec/openssh-mavericks-deactivate"

scr="$OUT/replace-scripts"; rm -rf "$scr"; mkdir -p "$scr"
cp "$SELF/../scripts/preinstall" "$scr/preinstall"
cp "$SELF/../scripts/postinstall" "$scr/postinstall"
chmod +x "$scr/preinstall" "$scr/postinstall"

comp="$OUT/openssh-replace-component.pkg"
pkgbuild --root "$payload" --identifier dev.mavergreen.openssh.replace \
  --version "$FULL" --scripts "$scr" --install-location / "$comp"

sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" \
  --identifier dev.mavergreen.openssh.replace \
  --title "Make OpenSSH for Mavericks the system default" \
  --component "$comp" --min-os 10.9.5 \
  --out "$OUT/OpenSSH-System-Replace-${FULL}.pkg"
rm -f "$comp"   # intermediate component (no floor): only the floored product archive ships

sh "$SHIPYARD_SCRIPTS/build-info.sh" "$OUT/build-info-replace.txt" \
  variant=replace upstream="$OPENSSH_VERSION" full="$FULL"

echo "built $OUT/OpenSSH-System-Replace-${FULL}.pkg"
