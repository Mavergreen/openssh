#!/bin/sh
# Master versions/paths file. Source this from a script that lives in build/ (its $0 anchors
# REPO_ROOT, matching the golang template). Pins every ingredient baked into the artifact so
# Renovate + repackage-on-ingredient-bump can track them. POSIX /bin/sh.
set -eu
VERSIONS_SELF="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$VERSIONS_SELF/.." && pwd)"; export REPO_ROOT

# --- Ingredient pins (Renovate customManagers key on these lines) ---
LIBRESSL_VERSION=4.3.2            # renovate: libressl/portable
export LIBRESSL_VERSION

# --- Derived upstream (written by derive-upstream-version.sh) ---
[ -f "$REPO_ROOT/UPSTREAM_VERSION" ] || sh "$VERSIONS_SELF/derive-upstream-version.sh"
OPENSSH_VERSION="$(cat "$REPO_ROOT/UPSTREAM_VERSION")"; export OPENSSH_VERSION   # e.g. 9.9p2
OPENSSH_TAG="$(tr -d ' \t\r\n' < "$REPO_ROOT/components/openssh/version")"; export OPENSSH_TAG

# --- Layout ---
PREFIX=/usr/local; export PREFIX
SYSCONFDIR=/usr/local/etc; export SYSCONFDIR

# --- Build workspace (heavy I/O off the NFS tree) ---
: "${WORK:=${HOME}/.cache/mavericks-openssh/work}"; export WORK

# --- Locate shared-cmake scripts ---
. "$VERSIONS_SELF/msc.sh" 2>/dev/null || true
