#!/bin/sh
# platform: host-agnostic
# Apply the vendored Apple-restoration patches to an unpacked OpenSSH source tree, drop in
# keychain.{h,m}, and put keychain.o in LIBSSH_OBJS. POSIX /bin/sh; 10.9-safe patch (Apple patch
# 2.0 -- has -F fuzz, no --merge). Sourced with --source-only to expose its functions to tests.
#
# Written to survive new upstreams. A hunk applies when its context still matches, and fuzz can
# forgive only context at a hunk's edges, so the patches never wrap or copy upstream lines that
# churn: an option string is extended by a getopt() macro placed above the loop, never copied; an
# include goes right after includes.h, never among system includes upstream reorders. The one
# Makefile.in change is a single anchored edit, not a hunk carrying the object lists either side.
# A patch that needs fuzz still applies, with a warning: refresh it (regenerate from a patched
# tree) while it still applies, before a hunk is rejected.
#   usage: apply-patches.sh <openssh-src-dir>
set -eu

# $1 = source dir, $2 = patch, $3 = strip level. Fails, naming the patch, on a rejected hunk.
apply_one() {
  name="$(basename "$2")"
  echo ">> applying $name (-p$3)"
  # -F2, patch's own default: fuzz past it would let a hunk with three lines of context apply with
  # none of them matching, at its old line number -- a silent misplacement, not a failure.
  if ! out="$(cd "$1" && patch "-p$3" -F2 < "$2" 2>&1)"; then
    printf '%s\n' "$out"
    echo "::error::$name does not apply to this upstream: a hunk was rejected (above)"
    return 1
  fi
  printf '%s\n' "$out"
  case "$out" in
    *fuzz*) echo "::warning::$name applied only with fuzz: upstream moved around it; refresh it before a hunk is rejected" ;;
  esac
}

# $1 = source dir. keychain.o first in LIBSSH_OBJS, by its one line, or a failure naming it.
add_keychain_object() {
  mk="$1/Makefile.in"
  if ! grep -q '^LIBSSH_OBJS=\${LIBOPENSSH_OBJS} \\$' "$mk"; then
    echo "::error::Makefile.in has no 'LIBSSH_OBJS=\${LIBOPENSSH_OBJS} \\' line to put keychain.o in front of"
    return 1
  fi
  sed 's/^LIBSSH_OBJS=\${LIBOPENSSH_OBJS} \\$/LIBSSH_OBJS=keychain.o ${LIBOPENSSH_OBJS} \\/' "$mk" > "$mk.new"
  mv "$mk.new" "$mk"
  echo ">> keychain.o added to LIBSSH_OBJS"
}

case "${1:-}" in
  --source-only) return 0 2>/dev/null || exit 0 ;;
esac

SRC="${1:?usage: apply-patches.sh <openssh-src-dir>}"
SELF="$(cd "$(dirname "$0")" && pwd)"
P="$SELF/../patches"

cp "$P/keychain.h" "$P/keychain.m" "$SRC/"
for patch in ssh-add-keychain.patch ssh-agent-launchd.patch ssh-askpass-confirm.patch; do
  apply_one "$SRC" "$P/$patch" 0
done
add_keychain_object "$SRC"
echo "patches applied to $SRC"
