#!/bin/sh
# Derive the dotted OpenSSH portable version (e.g. 9.9p2) from the upstream tag form
# (V_9_9_P2) pinned in components/openssh/version, and write it to UPSTREAM_VERSION.
# Conversion: strip leading "V_", "_P" -> "p", remaining "_" -> ".".
# With `--print <TAG>`, print the derived value for the given tag and exit (used by tests).
# POSIX /bin/sh; runs on 10.9. Must run before anything configures CMake.
set -eu

derive() {
  # $1 = tag like V_9_9_P2
  printf '%s\n' "$1" | sed -e 's/^V_//' -e 's/_P\([0-9][0-9]*\)$/p\1/' -e 's/_/./g'
}

validate_tag() {
  case "$1" in
    V_[0-9]*) : ;;
    *) echo "malformed OpenSSH tag (expected V_x_y[_Pz]): $1" >&2; return 1 ;;
  esac
}

if [ "${1:-}" = "--print" ]; then
  [ -n "${2:-}" ] || { echo "usage: derive-upstream-version.sh --print <TAG>" >&2; exit 2; }
  validate_tag "$2" || exit 2
  derive "$2"
  exit 0
fi

SELF="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SELF/.." && pwd)"
PIN="$ROOT/components/openssh/version"
[ -f "$PIN" ] || { echo "missing pin: $PIN" >&2; exit 1; }
TAG="$(tr -d ' \t\r\n' < "$PIN")"
[ -n "$TAG" ] || { echo "empty pin: $PIN" >&2; exit 1; }
validate_tag "$TAG" || exit 1
derive "$TAG" > "$ROOT/UPSTREAM_VERSION"
echo "derived UPSTREAM_VERSION=$(cat "$ROOT/UPSTREAM_VERSION") from $TAG" >&2
