#!/bin/sh
# platform: macOS-only -- drives assert_binary_compatible.sh, which reads Mach-O via otool/lipo
# Standing equivalence gate: every shipped OpenSSH binary must be 10.9-safe (x86_64, minos
# 10.9, no post-10.9 undefined imports/selectors). Delegates to the INSTALLED
# mavericks-shipyard assert_binary_compatible.sh (which takes the binaries positionally and
# hardcodes the x86_64/min-10.9 asserts + the post-10.9 symbol/selector denials -- there is no
# <floor> <arch> argument to pass).
#
# Unlike mavericks-golang (whose Go runtime USES clock_gettime, a 10.12 symbol, and therefore ships
# the macports-legacy-support shim that DEFINES it), OpenSSH -- like Wowfunhappy's native-10.9 build
# -- does not use clock_gettime: configured against the 10.9 SDK it falls back to gettimeofday. So we
# do NOT require _clock_gettime to be defined (no legacy-support shim is linked); the guard just
# proves each shipped binary is x86_64 / min-10.9 with no post-10.9 imports or selectors.
#
# Exits 77 (SKIP) when the staging tree isn't built yet: this test lives in tests/*.sh and the
# shared runner globs those, so in isolation (nothing built) it must SKIP, never fail. The real
# gate is CI running it against the CI-built staging. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF/.." && pwd)"; export REPO_ROOT
# versions.sh honours a pre-set REPO_ROOT (golang's ${REPO_ROOT:=...} idiom), so a test under
# tests/ can source it plainly; it exports WORK, PREFIX, and SHIPYARD.
. "$REPO_ROOT/build/versions.sh"
: "${SHIPYARD:?mavericks-shipyard not found; install it -- see its README}"

STAGE="${STAGE:-$WORK/staging}"
[ -d "$STAGE$PREFIX/bin" ] || { echo "not built ($STAGE) -- skipping"; exit 77; }

# sshd-keygen-wrapper is a shell script rather than Mach-O, so the Mach-O sweep below skips it.
# Assert it is here first: this guard walks the shipped payload, so while it merely SKIPPED the
# one non-Mach-O file, that file could stop being shipped and nothing anywhere went red --
# which is how 10.5p1-mavericks.2 shipped with launchd's sshd Program missing.
WRAPPER="$STAGE$PREFIX/libexec/sshd-keygen-wrapper"
[ -f "$WRAPPER" ] || { echo "FAIL: $WRAPPER is not in the payload; launchd's ssh job needs it" >&2; exit 1; }
[ -x "$WRAPPER" ] || { echo "FAIL: $WRAPPER is not executable; launchd cannot run it" >&2; exit 1; }

# Collect every shipped Mach-O binary.
set --
for b in "$STAGE$PREFIX"/bin/* "$STAGE$PREFIX"/sbin/* "$STAGE$PREFIX"/libexec/*; do
  [ -f "$b" ] || continue
  case "$b" in *sshd-keygen-wrapper) continue;; esac
  file "$b" | grep -q 'Mach-O' || continue
  echo ">> compat-check $b"
  set -- "$@" "$b"
done
[ "$#" -gt 0 ] || { echo "no Mach-O binaries under $STAGE$PREFIX -- skipping"; exit 77; }

sh "$SHIPYARD/assert_binary_compatible.sh" "$@"
echo "ok: all shipped binaries are 10.9-safe"
