#!/bin/sh
# platform: macOS-only -- pkgbuild builds the component, and otool checks the updater's linkage
# Assemble the PRODUCT pkg from the staged /usr/local/mavergreen/openssh tree: shared
# stage_product.sh stages the Sparkle updater .app + LaunchAgent, writes the manifest (with this
# product's --replaces entries and the postinstall hook), and renders the pkgbuild scripts; then
# pkgbuild builds the component and shared set_install_floor.sh -> productbuild stamps the 10.9.5
# install floor, and build-info.sh records what was built. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/versions.sh"                                  # exports SHIPYARD, PREFIX, WORK, OPENSSH_VERSION, LIBRESSL_VERSION, REPO_ROOT
: "${SHIPYARD_SCRIPTS:=$SHIPYARD}"                               # shared scripts dir (CI exports SHIPYARD_SCRIPTS; versions.sh sets SHIPYARD)
FULL="$(cat "$REPO_ROOT/VERSION")"                     # <upstream>-mavericks.N (written by release.yml)
STAGE="${STAGE:-$WORK/staging}"
OUT="${OUT:-$REPO_ROOT/dist}"; mkdir -p "$OUT"

[ -d "$STAGE$PREFIX/bin" ] || { echo "FATAL: no staged payload at $STAGE$PREFIX (run build/build-openssh.sh first)" >&2; exit 1; }

# platform: matches shipyard's mavericks-cross hidden preset's binaryDir formula
#           ($penv{TMPDIR}/mm-build/${sourceDirName}-cross, mavericks-presets.json) -- CMakePresets.json's
#           "cross" preset inherits it and no longer pins its own binaryDir, so this default must agree
#           with what `shipyard-cmake --preset cross` actually configures, not with a path in the tree.
UPD_APP="${UPD_APP:-${TMPDIR:-/tmp}/mm-build/$(basename "$REPO_ROOT")-cross/openssh-updater.app}"
[ -d "$UPD_APP" ] || { echo "FATAL: updater not built at $UPD_APP (shipyard-cmake --preset cross && shipyard-cmake --build \$UPDATER_BUILD_DIR --target openssh-updater)" >&2; exit 1; }
# The updater must NOT link the product it updates.
otool -L "$UPD_APP/Contents/MacOS/openssh-updater" | grep -q '/usr/local/mavergreen/openssh' && { echo "FATAL: updater links the product" >&2; exit 1; } || true

export COPYFILE_DISABLE=1                              # no ._AppleDouble sidecars in the payload
find "$STAGE" -name '._*' -delete 2>/dev/null || true # strip AppleDouble cruft before packaging

SCR="$OUT/pkg-scripts"; rm -rf "$SCR"
set --
while IFS= read -r r; do
  if [ -n "$r" ]; then set -- "$@" --replaces "$r"; fi
done < "$REPO_ROOT/build/system-replaces"
sh "$SHIPYARD_SCRIPTS/stage_product.sh" --stage "$STAGE" --product openssh --name "OpenSSH for Mavericks" \
  --version "$FULL" --updater-app "$UPD_APP" \
  --postinstall-hook "$REPO_ROOT/scripts/postinstall-hook.sh" --scripts-out "$SCR" "$@"

COMP="$OUT/openssh-component.pkg"
pkgbuild --root "$STAGE" --identifier dev.mavergreen.openssh --version "$FULL" \
         --scripts "$SCR" --install-location / "$COMP"

# Product archive with the hard 10.9.5 OS install floor (shared set_install_floor.sh -> productbuild).
PKG="$OUT/OpenSSH-${FULL}.pkg"
sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" \
  --identifier dev.mavergreen.openssh \
  --title "OpenSSH for Mavericks" \
  --component "$COMP" --out "$PKG" \
  --min-os 10.9.5 --host-arch x86_64 --require-scripts
rm -f "$COMP"   # intermediate: only the floored product archive ships

# Record what this variant was built FROM (shared build-info.sh: <outfile> key=value ...).
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$OUT/build-info-product.txt" \
  variant=product prefix="$PREFIX" \
  upstream="$OPENSSH_VERSION" libressl="$LIBRESSL_VERSION" full="$FULL"

echo "built $PKG"
