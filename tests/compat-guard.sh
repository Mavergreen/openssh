#!/bin/sh
# Standing equivalence gate: every shipped OpenSSH binary must be 10.9-safe (x86_64, minos
# 10.9, no post-10.9 undefined imports/selectors). Delegates to the INSTALLED
# mavericks-shared-cmake assert_binary_compatible.sh (which takes the binaries positionally and
# hardcodes the x86_64/min-10.9 asserts + the post-10.9 symbol/selector denials -- there is no
# <floor> <arch> argument to pass). Mirrors mavericks-golang/tests/compat-guard.sh, which invokes
#   MAVERICKS_REQUIRE_DEFINED_SYMBOLS='_clock_gettime' sh "$MSC/assert_binary_compatible.sh" "$@"
# so a 10.9-linked binary must DEFINE the legacy-support _clock_gettime shim (else its own
# _clock_gettime import would read as a post-10.9 leak).
#
# Exits 77 (SKIP) when the staging tree isn't built yet: this test lives in tests/*.sh and the
# shared runner globs those, so in isolation (nothing built) it must SKIP, never fail. The real
# gate is CI running it against the CI-built staging. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SELF/.." && pwd)"
# versions.sh anchors its own helpers (msc.sh, derive-upstream-version.sh) on `dirname "$0"`, so it
# must be sourced with $0 resolving to build/ -- do that via a build/-resident stub. Sourcing it
# straight from tests/ would make it look for tests/msc.sh and abort. Capture its exported env
# (WORK, PREFIX, MSC) into this shell.
eval "$(cd "$REPO/build" && sh -c '. ./versions.sh >/dev/null 2>&1 || exit 1
  printf "WORK=%s\nPREFIX=%s\nMSC=%s\n" "$WORK" "$PREFIX" "${MSC:-}"' \
  | sed 's/^/export /')"
: "${MSC:?mavericks-shared-cmake not found; install it -- see its README}"

STAGE="${STAGE:-$WORK/staging}"
[ -d "$STAGE$PREFIX/bin" ] || { echo "not built ($STAGE) -- skipping"; exit 77; }

# Collect every shipped Mach-O binary (sshd-keygen-wrapper is a shell script, not Mach-O).
set --
for b in "$STAGE$PREFIX"/bin/* "$STAGE$PREFIX"/sbin/* "$STAGE$PREFIX"/libexec/*; do
  [ -f "$b" ] || continue
  case "$b" in *sshd-keygen-wrapper) continue;; esac
  file "$b" | grep -q 'Mach-O' || continue
  echo ">> compat-check $b"
  set -- "$@" "$b"
done
[ "$#" -gt 0 ] || { echo "no Mach-O binaries under $STAGE$PREFIX -- skipping"; exit 77; }

MAVERICKS_REQUIRE_DEFINED_SYMBOLS='_clock_gettime' \
  sh "$MSC/assert_binary_compatible.sh" "$@"
echo "ok: all shipped binaries are 10.9-safe"
