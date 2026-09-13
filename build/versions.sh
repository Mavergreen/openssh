#!/bin/sh
# Master versions/paths file. Sourced, not executed. Callers may pre-export REPO_ROOT (e.g. a
# test under tests/); otherwise it defaults from $0, which is correct when sourced by a script
# that lives in build/. This ${REPO_ROOT:=...} idiom matches the golang template and lets any
# caller source it without $0 games. Pins every ingredient baked into the artifact so Renovate
# + repackage-on-ingredient-bump can track them. POSIX /bin/sh.
: "${REPO_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"; export REPO_ROOT

# --- Ingredient pins (Renovate customManagers key on these lines) ---
LIBRESSL_VERSION=4.3.2            # renovate: libressl/portable
export LIBRESSL_VERSION

# --- Derived upstream (written by derive-upstream-version.sh) ---
[ -f "$REPO_ROOT/UPSTREAM_VERSION" ] || sh "$REPO_ROOT/build/derive-upstream-version.sh"
OPENSSH_VERSION="$(cat "$REPO_ROOT/UPSTREAM_VERSION")"; export OPENSSH_VERSION   # e.g. 9.9p2
OPENSSH_TAG="$(tr -d ' \t\r\n' < "$REPO_ROOT/components/openssh/version")"; export OPENSSH_TAG

# --- Layout ---
PREFIX=/usr/local; export PREFIX
SYSCONFDIR=/usr/local/etc; export SYSCONFDIR

# --- Build workspace (heavy I/O off the NFS tree) ---
: "${WORK:=${HOME}/.cache/mavericks-openssh/work}"; export WORK

# --- Locate shipyard scripts ($SHIPYARD) ---
. "$REPO_ROOT/build/msc.sh" 2>/dev/null || true
