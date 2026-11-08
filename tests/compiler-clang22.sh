#!/bin/sh
# platform: host-agnostic
# spec: the family's "The compiler: clang22 on every host" (mavergreen-conventions) -- OpenSSH and its
#       LibreSSL build with the clang22 release components/clang22/version pins, through
#       build/fetch-clang22.sh, never Apple's /usr/bin/clang or the Command Line Tools' ar and ranlib.
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
bad() { echo "FAIL: $*"; fail=1; }
grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+-mavericks\.[0-9]+' "$R/components/clang22/version" 2>/dev/null \
  || bad "components/clang22/version does not pin a clang-22 release tag"
for f in build/build-openssh.sh build/build-libressl.sh; do
  grep -q 'fetch-clang22\.sh' "$R/$f" || bad "$f does not take its compiler from build/fetch-clang22.sh"
  grep -q '/usr/bin/clang' "$R/$f" && bad "$f still names Apple's /usr/bin/clang"
  grep -q 'fetch_sdk\.sh' "$R/$f" && grep -q 'CFLAGS="-isysroot \$SDK' "$R/$f" \
    || bad "$f does not pass shipyard's pinned SDK by -isysroot (clang22's own SDK link needs python3's setup-sdk)"
  for v in CC AR RANLIB; do
    grep -Eq "(^|[^A-Z_])$v=\"\\\$CLANG22/bin/" "$R/$f" || bad "$f does not set $v from clang22"
  done
done
grep -q 'components/clang22/version' "$R/.github/workflows/repackage-on-ingredient-bump.yml" \
  || bad "a clang22 bump does not cut a repackage (it carries Recaulk's fixes into the binaries)"
[ "$fail" = 0 ] && echo 'PASS: OpenSSH and LibreSSL build with the pinned clang22'
exit "$fail"
