#!/bin/sh
# platform: macOS-only -- exercises the installed product's Apple-restored behaviours on a real 10.9 box
# What the Apple patches put back, pinned as behaviour rather than as a hunk applying: a patch can
# apply and still be wrong. Exits 77 (SKIP) anywhere that isn't 10.9, where the product isn't
# installed, or without root (sshd's host keys are root's). Every check runs under a time limit,
# and a failure says what failed, with the logs. POSIX /bin/sh.
set -eu
sw="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
case "$sw" in 10.9*) : ;; *) echo "not 10.9 ($sw) -- skipping"; exit 77;; esac
B=/usr/local/mavergreen/openssh/bin; SB=/usr/local/mavergreen/openssh/sbin
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

# 1. ssh-add's --apple-use-keychain and --apple-load-keychain are options it parses: with no agent,
#    it complains about the agent, never about the option.
parses_apple_options() {  # $1 = an ssh-add; 0 when both long options parse
  for opt in --apple-load-keychain "--apple-use-keychain /nonexistent"; do
    # shellcheck disable=SC2086 # the second option carries its file argument
    SSH_AUTH_SOCK='' within 10 "$1" $opt > "$T/ssh-add.log" 2>&1 || true
    if grep -qiE 'illegal option|unrecognized option|invalid option' "$T/ssh-add.log"; then return 1; fi
    grep -qi 'agent' "$T/ssh-add.log" || return 1
  done
}
parses_apple_options "$B/ssh-add" || fail "ssh-add does not parse --apple-use-keychain and --apple-load-keychain"
within 10 "$B/ssh-add" -Z > "$T/ssh-add-usage.log" 2>&1 || true
grep -q -- '--apple-use-keychain' "$T/ssh-add-usage.log" || fail "ssh-add's usage does not list --apple-use-keychain"
# The control: 10.9's own ssh-add predates those options, so this check must fail it -- or it
# could not tell a patched ssh-add from an unpatched one.
if parses_apple_options /usr/bin/ssh-add; then fail "the check passed 10.9's own ssh-add too: it tells nothing"; fi
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
"$SB/sshd" -d -p "$port" -o UsePAM=no -h /usr/local/mavergreen/var/openssh/ssh_host_rsa_key > "$T/sshd.log" 2>&1 &
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
