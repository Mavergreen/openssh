#!/bin/sh
# platform: macOS-only -- package-system-replace.sh runs pkgbuild and productbuild
#   usage: sh build/package-replace-pkg.sh   (after build/package-pkg.sh; reads VERSION)
#          The optional System Replace pkg: installing it points the system's OpenSSH paths at
#          this product's tree, on 10.9 only (mavergreen system-replace).
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/versions.sh"
: "${SHIPYARD_SCRIPTS:=$SHIPYARD}"
FULL="$(cat "$REPO_ROOT/VERSION")"
OUT="${OUT:-$REPO_ROOT/dist}"; mkdir -p "$OUT"
sh "$SHIPYARD_SCRIPTS/package-system-replace.sh" --product openssh \
  --title "Make OpenSSH for Mavericks the system default" --version "$FULL" \
  --out "$OUT/OpenSSH-System-Replace-${FULL}.pkg"
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$OUT/build-info-replace.txt" \
  variant=replace upstream="$OPENSSH_VERSION" full="$FULL"
echo "built $OUT/OpenSSH-System-Replace-${FULL}.pkg"
