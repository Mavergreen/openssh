#!/bin/sh
# platform: host-agnostic
# apply-patches.sh: keychain.o goes in front of LIBSSH_OBJS by one anchored line, failing loudly
# if that line is gone; a patch that needs fuzz still applies, with a warning naming it; a patch
# with a rejected hunk fails, naming it.
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/openssh-patches.XXXXXX")"; trap 'rm -rf "$W"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
# POSIX sh's . passes no arguments: a sourced script sees the caller's own, so set them first.
set -- --source-only
. "$R/build/apply-patches.sh"

mkdir -p "$W/mk"
printf 'X=1\nLIBSSH_OBJS=${LIBOPENSSH_OBJS} \\\n\tauthfd.o\n' > "$W/mk/Makefile.in"
add_keychain_object "$W/mk" > /dev/null || fail "add_keychain_object refused a Makefile.in that has the line"
grep -qx 'LIBSSH_OBJS=keychain.o ${LIBOPENSSH_OBJS} \\' "$W/mk/Makefile.in" || fail "keychain.o is not first in LIBSSH_OBJS"
grep -qx '	authfd.o' "$W/mk/Makefile.in" || fail "the rest of Makefile.in changed"

mkdir -p "$W/gone"; printf 'LIBSSH_OBJS= foo.o\n' > "$W/gone/Makefile.in"
if out="$(add_keychain_object "$W/gone" 2>&1)"; then fail "a Makefile.in without the line must fail"; fi
case "$out" in *LIBSSH_OBJS*) ;; *) fail "the refusal should name LIBSSH_OBJS: $out" ;; esac

# A patch made where line 3 read "c"; the tree says "C" there, at the hunk's edge: fuzz.
mkdir -p "$W/a" "$W/b" "$W/fuzzy"
printf '%s\n' a b c d e f g h i j > "$W/a/f.c"
printf '%s\n' a b c d e NEW f g h i j > "$W/b/f.c"
(cd "$W" && diff -u --label f.c --label f.c a/f.c b/f.c > "$W/demo.patch") || true
printf '%s\n' a b C d e f g h i j > "$W/fuzzy/f.c"
out="$(apply_one "$W/fuzzy" "$W/demo.patch" 0)" || fail "a patch that needs only fuzz must still apply"
case "$out" in *"::warning"*demo.patch*fuzz*) ;; *) fail "fuzz must warn, naming the patch: $out" ;; esac
grep -qx NEW "$W/fuzzy/f.c" || fail "the fuzzed hunk was not applied"

mkdir -p "$W/rejected"; printf '%s\n' z y x w v u t s r q > "$W/rejected/f.c"
if out="$(apply_one "$W/rejected" "$W/demo.patch" 0 2>&1)"; then fail "a rejected hunk must fail"; fi
case "$out" in *"::error"*demo.patch*) ;; *) fail "a reject must fail naming the patch: $out" ;; esac

echo "PASS: apply-patches"
