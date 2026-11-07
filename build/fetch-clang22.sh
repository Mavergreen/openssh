#!/bin/sh
# platform: host-agnostic
#   usage: fetch-clang22.sh     prints the prefix of the clang22 release components/clang22/version pins, for this
#          host, through shipyard's fetch_clang22.sh: the cross pkg on a modern Mac, the native pkg on 10.9
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/msc.sh"
d="$(sh "$SHIPYARD_SCRIPTS/fetch_clang22.sh" "$REPO_ROOT/components/clang22")"
for b in clang llvm-ar llvm-ranlib llvm-nm; do
  [ -x "$d/bin/$b" ] || { echo "fetch-clang22: $d lacks bin/$b" >&2; exit 1; }
done
echo "$d"
