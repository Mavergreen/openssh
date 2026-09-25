#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$R"; . "$R/build/versions.sh"
STAGE="${STAGE:-$WORK/staging}"
[ -d "$STAGE$PREFIX/bin" ] || { echo "no staged payload at $STAGE$PREFIX -- skipping (run build/build-openssh.sh first)"; exit 77; }
n=0
while IFS= read -r r; do
  [ -n "$r" ] || continue
  rel="${r#*=}"
  [ -x "$STAGE$PREFIX/$rel" ] \
    || { echo "FAIL: $r names $rel, which the staged tree does not ship -- system-replace would refuse, or launchd's ssh job would run nothing"; exit 1; }
  n=$((n + 1))
done < "$R/build/system-replaces"
[ "$n" -eq 12 ] || { echo "FAIL: expected the 12 replaces entries R2 lists, found $n"; exit 1; }
grep -qx '/usr/libexec/sshd-keygen-wrapper=libexec/sshd-keygen-wrapper' "$R/build/system-replaces" \
  || { echo "FAIL: 10.9's ssh.plist runs /usr/libexec/sshd-keygen-wrapper, so it must be replaced"; exit 1; }
[ ! -e "$STAGE/usr/local/mavergreen/var" ] || { echo "FAIL: nothing may be staged under var/ -- the configs ship as defaults in share/openssh"; exit 1; }
for f in ssh_config sshd_config moduli; do
  [ -f "$STAGE$PREFIX/share/openssh/$f" ] || { echo "FAIL: the default $f must ship in the tree"; exit 1; }
done
echo "OK: every system-replaces entry resolves in the staged tree"
