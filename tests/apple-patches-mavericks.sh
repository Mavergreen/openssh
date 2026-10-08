#!/bin/sh
# platform: macOS-only -- exercises the installed product's Apple-restored behaviours on a real 10.9 box
# What the Apple patches put back, pinned as behaviour rather than as a hunk applying: a patch can
# apply and still be wrong. Exits 77 (SKIP) anywhere that isn't 10.9, where the product isn't
# installed, or without root (sshd's host keys are root's). Every check runs under a time limit,
# and a failure says what failed, with the logs. POSIX /bin/sh.
set -eu
sw="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
case "$sw" in 10.9*) : ;; *) echo "not 10.9 ($sw) -- skipping"; exit 77;; esac
# OPENSSH_BIN, OPENSSH_SBIN: another install to exercise (default: the product's)
B="${OPENSSH_BIN:-/usr/local/mavergreen/openssh/bin}"; SB="${OPENSSH_SBIN:-/usr/local/mavergreen/openssh/sbin}"
[ -x "$B/ssh-add" ] || { echo "product not installed -- skipping"; exit 77; }
[ "$(id -u)" = 0 ] || { echo "not root -- skipping"; exit 77; }

T="$(mktemp -d /tmp/apple-patches.XXXXXX)"
fail() {
  echo "FAIL: $1" >&2
  for f in "$T"/*.log; do
    if [ -s "$f" ]; then echo "--- $f, last 30 lines:" >&2; tail -n 30 "$f" >&2; fi
  done
  exit 1
}
# 10.9 has no timeout(1); perl's alarm ends a hung command with SIGALRM (status 142).
within() { perl -e '$t = shift; alarm $t; exec @ARGV or die "exec $ARGV[0]: $!\n"' "$@"; }

# 1. ssh-add's --apple-use-keychain and --apple-load-keychain are options it parses. With an agent
#    running, so that ssh-add gets as far as its options (a missing agent is reported first, and
#    would mask a missing option), it never complains about the option.
eval "$(within 10 "$B/ssh-agent" -s)" > /dev/null || fail "could not start an ssh-agent for the ssh-add checks"
parses() {  # $1 = an option, then any argument it takes; 0 when the product's ssh-add parses it
  within 10 "$B/ssh-add" "$@" > "$T/ssh-add.log" 2>&1 || true
  if grep -qiE 'illegal option|unrecognized option|invalid option|usage:' "$T/ssh-add.log"; then return 1; fi
  if grep -qi 'Could not open a connection' "$T/ssh-add.log"; then return 1; fi
}
parses --apple-load-keychain || fail "ssh-add does not parse --apple-load-keychain"
parses --apple-use-keychain /nonexistent || fail "ssh-add does not parse --apple-use-keychain"
# The control: an option nobody defined must fail the same check, on the same ssh-add, or the check
# could not tell a parsed option from an unknown one. (No unpatched ssh-add can be counted on: the
# guest's own /usr/bin/ssh-add is already the family's.)
if parses --apple-not-an-option; then fail "the check passed an option ssh-add has not got: it tells nothing"; fi
within 10 "$B/ssh-add" -Z > "$T/ssh-add-usage.log" 2>&1 || true
grep -q -- '--apple-use-keychain' "$T/ssh-add-usage.log" || fail "ssh-add's usage does not list --apple-use-keychain"
kill "$SSH_AGENT_PID" 2>/dev/null || true
rm -f "$T"/ssh-add.log

# 2. ssh-agent's -l is the launchd mode: outside launchd it fails checking in, never as an option.
st=0; within 10 "$B/ssh-agent" -l > "$T/ssh-agent.log" 2>&1 || st=$?
[ "$st" -ne 142 ] || fail "ssh-agent -l hung"
if grep -q 'illegal option' "$T/ssh-agent.log"; then fail "ssh-agent does not take -l"; fi
grep -q 'launch_msg' "$T/ssh-agent.log" || fail "ssh-agent -l did not try to check in with launchd"

# 3. An askpass helper that answers the host-key question with nonsense is asked once, and the
#    connection is cancelled; unpatched, ssh asks it again and again.
cat > "$T/askpass" <<'EOF'
#!/bin/sh
echo asked >> "$(dirname "$0")/askpass.count"
echo maybe
EOF
chmod 755 "$T/askpass"
port=2223
# A host key of its own, so the check does not depend on where an install keeps its keys.
within 30 "$B/ssh-keygen" -q -t ed25519 -N '' -f "$T/hostkey" > "$T/ssh-keygen.log" 2>&1 || fail "ssh-keygen could not make a host key"
"$SB/sshd" -d -p "$port" -o UsePAM=no -h "$T/hostkey" > "$T/sshd.log" 2>&1 &
pid=$!; sleep 2
kill -0 "$pid" 2>/dev/null || fail "sshd exited before the client connected"
st=0
SSH_ASKPASS="$T/askpass" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 within 30 "$B/ssh" -p "$port" \
  -o StrictHostKeyChecking=ask -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \
  -o PreferredAuthentications=none localhost true < /dev/null > "$T/ssh.log" 2>&1 || st=$?
kill "$pid" 2>/dev/null || true
[ "$st" -ne 142 ] || fail "ssh kept asking the askpass helper about the host key until stopped"
grep -q 'Invalid host key confirmation response from askpass' "$T/ssh.log" \
  || fail "ssh did not cancel on a nonsense askpass answer"
asked="$(wc -l < "$T/askpass.count" | tr -d ' ')"
[ "$asked" = 1 ] || fail "the askpass helper was asked $asked times, not once"

rm -rf "$T"
echo "ok: the Apple patches' behaviours, on real 10.9"
