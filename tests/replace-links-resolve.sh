#!/bin/sh
# Standing guard on the replacement pkg: every symlink scripts/postinstall drops into the system
# paths must point at a file our payload actually ships.
#
# The failure this exists to catch is silent by construction. postinstall links
# /usr/libexec/sshd-keygen-wrapper -- which 10.9's ssh.plist names as launchd's Program for
# com.openssh.sshd -- into our prefix, and for a while nothing shipped that file: `ln -sfn`
# creates a dangling symlink happily, pkgbuild packages it happily, and the host ends up with no
# working sshd (10.5p1-mavericks.2 did). Rather than assert one filename, this runs the real
# postinstall against a fake root laid out from the real staging tree and checks that every link
# it creates resolves -- so the next path added to postinstall without a payload fails here too.
#
# Exits 77 (SKIP) before a build, like the other payload tests. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"

STAGE="${STAGE:-$WORK/staging}"
[ -d "$STAGE$PREFIX/bin" ] || { echo "not built ($STAGE) -- skipping"; exit 77; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/replace-links.XXXXXX")"; export ROOT
trap 'rm -rf "$ROOT"' EXIT INT TERM

# Lay the real payload out under the fake root, exactly where the installed pkg puts it.
mkdir -p "$ROOT$PREFIX"
( cd "$STAGE$PREFIX" && tar cf - . ) | ( cd "$ROOT$PREFIX" && tar xf - )

sh "$REPO_ROOT/scripts/postinstall"

links=0
broken=0
for l in $(find "$ROOT" -type l); do
  links=$((links + 1))
  if [ ! -e "$l" ]; then
    broken=$((broken + 1))
    echo "FAIL: ${l#$ROOT} -> $(readlink "$l") is dangling: nothing in the payload ships it" >&2
  fi
done

[ "$links" -gt 0 ] || { echo "FAIL: postinstall created no symlinks at all under $ROOT" >&2; exit 1; }
[ "$broken" -eq 0 ] || {
  echo "FAIL: $broken of $links symlinks from scripts/postinstall resolve to nothing." >&2
  echo "      Every path it links must be shipped under $PREFIX by the build." >&2
  exit 1
}

echo "ok: all $links symlinks from the replacement postinstall resolve into the payload"
