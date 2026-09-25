#!/bin/sh
# platform: host-agnostic
# _ETC/_STATE let this test drive the real copy-in-host-keys logic against scratch dirs instead
# of /etc and @SYSCONFDIR@ -- the wrapper's default behavior (both unset) is untouched. The final
# @PREFIX@/bin/ssh-keygen and exec @PREFIX@/sbin/sshd calls are unsubstituted literal paths here
# (this runs the .in template directly, not a staged build) and so fail after the copy loop has
# already run; that failure is expected and ignored.
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/sshd-wrapper.XXXXXX")"; trap 'rm -rf "$W"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
ETC="$W/etc"; STATE="$W/state"
mkdir -p "$ETC" "$STATE"
echo apple-rsa > "$ETC/ssh_host_rsa_key"; chmod 600 "$ETC/ssh_host_rsa_key"
echo apple-rsa-pub > "$ETC/ssh_host_rsa_key.pub"
echo ours-ed > "$STATE/ssh_host_ed25519_key"

_ETC="$ETC" _STATE="$STATE" sh "$R/scripts/sshd-keygen-wrapper.in" >/dev/null 2>&1 || true

[ "$(cat "$STATE/ssh_host_rsa_key")" = apple-rsa ] \
  || fail "an /etc host key not yet in state is copied in before ssh-keygen -A runs"
[ "$(ls -l "$STATE/ssh_host_rsa_key" | cut -c1-10)" = -rw------- ] \
  || fail "a copied-in private key is left 0600"
[ "$(cat "$STATE/ssh_host_rsa_key.pub")" = apple-rsa-pub ] \
  || fail "the matching .pub is copied in too"
[ "$(cat "$STATE/ssh_host_ed25519_key")" = ours-ed ] \
  || fail "a key already in state is never overwritten by an /etc key"
echo "OK: sshd-keygen-wrapper carries over /etc host keys before minting new ones"
