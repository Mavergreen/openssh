#!/bin/sh
# Assemble the PRODUCT pkg from the built /usr/local staging tree: stage the Sparkle updater
# .app + daily-check LaunchAgent (shared stage_updater.sh), pkgbuild the component, stamp the
# 10.9.5 install floor (shared set_install_floor.sh -> productbuild), and record build-info.
# POSIX /bin/sh.
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
UPD_APP="${UPD_APP:-${TMPDIR:-/tmp}/mm-build/$(basename "$REPO_ROOT")-cross/OpenSSHUpdater.app}"
[ -d "$UPD_APP" ] || { echo "FATAL: updater not built at $UPD_APP (shipyard-cmake --preset cross && shipyard-cmake --build \$UPDATER_BUILD_DIR --target OpenSSHUpdater)" >&2; exit 1; }
# The updater must NOT link the product it updates.
otool -L "$UPD_APP/Contents/MacOS/OpenSSHUpdater" | grep -q '/usr/local/.*ssh' && { echo "FATAL: updater links the product" >&2; exit 1; } || true

export COPYFILE_DISABLE=1                              # no ._AppleDouble sidecars in the payload
find "$STAGE" -name '._*' -delete 2>/dev/null || true # strip AppleDouble cruft before packaging

# Stage the updater .app + its daily-check LaunchAgent into the payload, and render the postinstall
# that loads the agent (shared stage_updater.sh: --stage --app --app-dir --agent-label --scripts-out).
SCR="$OUT/pkg-scripts"; rm -rf "$SCR"; mkdir -p "$SCR"
sh "$SHIPYARD_SCRIPTS/stage_updater.sh" \
  --stage "$STAGE" \
  --app "$UPD_APP" \
  --app-dir "/Library/Application Support/Mavergreen" \
  --agent-label "dev.mavergreen.openssh-updatecheck" \
  --scripts-out "$SCR"

# Flat component pkg over the whole payload (/usr/local/... + the updater .app + LaunchAgent),
# with the postinstall that loads the update-check agent.
COMP="$OUT/openssh-component.pkg"
pkgbuild --root "$STAGE" --identifier dev.mavergreen.openssh --version "$FULL" \
         --scripts "$SCR" --install-location / "$COMP"

# Product archive with the hard 10.9.5 OS install floor (shared set_install_floor.sh -> productbuild).
PKG="$OUT/OpenSSH-${FULL}.pkg"
sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" \
  --identifier dev.mavergreen.openssh \
  --title "OpenSSH for Mavericks" \
  --component "$COMP" --out "$PKG" \
  --min-os 10.9.5 --host-arch x86_64
rm -f "$COMP"   # intermediate: only the floored product archive ships

# Record what this variant was built FROM (shared build-info.sh: <outfile> key=value ...).
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$OUT/build-info-product.txt" \
  variant=product prefix="$PREFIX" \
  upstream="$OPENSSH_VERSION" libressl="$LIBRESSL_VERSION" full="$FULL"

echo "built $PKG"
