#!/bin/sh
# platform: host-agnostic
# Thin wrapper: the logic lives in shipyard (scripts/version.sh) so it cannot drift.
# UPSTREAM_VERSION is a build product written by derive-upstream-version.sh; ensure it exists first.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$SELF/.." && pwd)"; export MAVERICKS_ROOT
[ -f "$MAVERICKS_ROOT/UPSTREAM_VERSION" ] || sh "$SELF/derive-upstream-version.sh"
MAVERICKS_UPSTREAM_FILE="$MAVERICKS_ROOT/UPSTREAM_VERSION"; export MAVERICKS_UPSTREAM_FILE
. "$SELF/msc.sh"
exec sh "$SHIPYARD/version.sh" "$@"
