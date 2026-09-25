#!/bin/sh
# platform: host-agnostic
# Verifies build/version.sh auto emits <upstream>-mavericks.N AND that the upstream value is
# read from UPSTREAM_VERSION (not hardcoded): overriding UPSTREAM_VERSION changes the output.
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"

# 1) Normal derived value.
sh "$REPO/build/derive-upstream-version.sh" >/dev/null 2>&1
UP="$(cat "$REPO/UPSTREAM_VERSION")"
OUT="$(cd "$REPO" && sh build/version.sh auto)"
echo "$OUT" | grep -q "FULL=${UP}-mavericks\." || { echo "FAIL: version.sh auto did not emit ${UP}-mavericks.N: $OUT" >&2; exit 1; }

# 2) Non-hardcoding: override UPSTREAM_VERSION and confirm it flows through.
printf '1.2p3\n' > "$REPO/UPSTREAM_VERSION"
OUT2="$(cd "$REPO" && sh build/version.sh auto)"
rm -f "$REPO/UPSTREAM_VERSION"
echo "$OUT2" | grep -q "FULL=1.2p3-mavericks\." || { echo "FAIL: overridden UPSTREAM_VERSION not honored (hardcoded?): $OUT2" >&2; exit 1; }

echo "ok: $OUT"
