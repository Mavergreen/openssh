#!/bin/sh
# Verifies build/version.sh auto produces <derived-upstream>-mavericks.1 on a repo with no tags,
# and that it reads the derived upstream rather than a hardcoded value.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
sh "$REPO/build/derive-upstream-version.sh" >/dev/null 2>&1
UP="$(cat "$REPO/UPSTREAM_VERSION")"
OUT="$(cd "$REPO" && sh build/version.sh auto)"
echo "$OUT" | grep -q "FULL=${UP}-mavericks\." || { echo "FAIL: version.sh auto did not emit ${UP}-mavericks.N: $OUT" >&2; exit 1; }
echo "ok: $OUT"
