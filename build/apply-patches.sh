#!/bin/sh
# Apply the vendored Apple-restoration patches to an unpacked OpenSSH source tree and drop in
# keychain.{h,m}, then patch Makefile.in to build keychain.o. POSIX /bin/sh; 10.9-safe patch
# (Apple patch 2.0 -- has -F fuzz, no --merge).
# Strip levels are MIXED: the Apple-derived patches are authored with
# bare filenames -> -p0; our Makefile.in.patch is authored with a/ b/ prefixes -> -p1.
#   usage: apply-patches.sh <openssh-src-dir>
set -eu
SRC="${1:?usage: apply-patches.sh <openssh-src-dir>}"
SELF="$(cd "$(dirname "$0")" && pwd)"
P="$SELF/../patches"

cp "$P/keychain.h" "$P/keychain.m" "$SRC/"
# "<patch> <strip>" pairs.
for entry in \
  "ssh-add-keychain.patch 0" \
  "ssh-agent-launchd.patch 0" \
  "ssh-askpass-confirm.patch 0" \
  "Makefile.in.patch 1"; do
  patch=${entry% *}; strip=${entry##* }
  echo ">> applying $patch (-p$strip)"
  ( cd "$SRC" && patch "-p$strip" -F3 < "$P/$patch" )
done
echo "patches applied to $SRC"
