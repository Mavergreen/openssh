#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d "${TMPDIR:-/tmp}/openssh-hook.XXXXXX")"; trap 'rm -rf "$W"' EXIT
fail() { echo "FAIL: $1"; exit 1; }
V="$W/vol"; D="$V/usr/local/mavergreen/openssh/share/openssh"; S="$V/usr/local/mavergreen/var/openssh"
mkdir -p "$D" "$V/etc"
for f in ssh_config sshd_config moduli; do echo "default $f" > "$D/$f"; done
echo apple-rsa > "$V/etc/ssh_host_rsa_key"; chmod 600 "$V/etc/ssh_host_rsa_key"
ROOT="$V" sh "$R/scripts/postinstall-hook.sh" || fail "the hook must succeed on a fresh volume"
for f in ssh_config sshd_config moduli; do
  [ "$(cat "$S/$f")" = "default $f" ] || fail "a fresh install seeds $f from the tree's defaults"
done
[ "$(cat "$S/ssh_host_rsa_key")" = apple-rsa ] || fail "the target volume's own host key is carried over, so the host keeps its identity"
[ "$(ls -l "$S/ssh_host_rsa_key" | cut -c1-10)" = -rw------- ] || fail "a carried-over host key keeps its 0600 mode"
echo edited > "$S/sshd_config"; echo ours-rsa > "$S/ssh_host_rsa_key"; echo ours-ed > "$S/ssh_host_ed25519_key"
echo "new default" > "$D/sshd_config"
ROOT="$V" sh "$R/scripts/postinstall-hook.sh" || fail "the hook must succeed on an upgrade"
[ "$(cat "$S/sshd_config")" = edited ] || fail "an upgrade never overwrites a config already in var/openssh"
[ "$(cat "$S/ssh_host_rsa_key")" = ours-rsa ] || fail "an upgrade never replaces a host key already in var/openssh"
[ "$(cat "$S/ssh_host_ed25519_key")" = ours-ed ] || fail "a host key /etc does not have survives the upgrade"
[ ! -e "$V/usr/local/etc" ] || fail "nothing is written to the old /usr/local/etc"
B="$W/bare"; mkdir -p "$B/usr/local/mavergreen/openssh/share/openssh"
for f in ssh_config sshd_config moduli; do : > "$B/usr/local/mavergreen/openssh/share/openssh/$f"; done
ROOT="$B" sh "$R/scripts/postinstall-hook.sh" || fail "a volume with no /etc host keys is not a failure; sshd-keygen-wrapper makes them"
echo "OK: openssh postinstall hook"
