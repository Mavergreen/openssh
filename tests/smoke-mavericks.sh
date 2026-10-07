#!/bin/sh
# platform: macOS-only -- exercises the installed ssh/sshd binaries on a real 10.9 box
# Real-10.9 smoke: exercise the built product on an actual Mavericks box. Exits 77 (SKIP)
# anywhere that isn't 10.9 or where the product isn't installed, so it never gates CI -- it is
# the one-time manual validation of the initial cross-build. POSIX /bin/sh.
set -eu
sw="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
case "$sw" in 10.9*) : ;; *) echo "not 10.9 ($sw) -- skipping"; exit 77;; esac
[ -x /usr/local/mavergreen/openssh/bin/ssh ] || { echo "product not installed -- skipping"; exit 77; }
# The host keys are root-owned 0600, so an unprivileged sshd exits "no hostkeys available" -- a
# test that cannot run yet SKIPs rather than reporting the product broken.
[ "$(id -u)" = 0 ] || { echo "not root -- skipping"; exit 77; }

# A failure names what failed, then shows both ends' own logs: a CI job's log is all there is to
# diagnose from.
fail() {
  echo "FAIL: $1" >&2
  for f in /tmp/sshd.log /tmp/ssh.log; do
    if [ -s "$f" ]; then echo "--- $f, last 30 lines:" >&2; tail -n 30 "$f" >&2; fi
  done
  exit 1
}
: > /tmp/sshd.log; : > /tmp/ssh.log

/usr/local/mavergreen/openssh/bin/ssh -V > /tmp/ssh.log 2>&1 || fail "ssh -V exited non-zero"
grep -q OpenSSH /tmp/ssh.log || fail "ssh -V does not say OpenSSH"
port=2222
/usr/local/mavergreen/openssh/sbin/sshd -d -p "$port" -o UsePAM=no -h /usr/local/mavergreen/var/openssh/ssh_host_rsa_key >/tmp/sshd.log 2>&1 &
pid=$!; sleep 2
kill -0 "$pid" 2>/dev/null || fail "sshd exited before the client connected"
/usr/local/mavergreen/openssh/bin/ssh -v -p "$port" -o StrictHostKeyChecking=no -o BatchMode=yes localhost true 2>/tmp/ssh.log || true
kill "$pid" 2>/dev/null || true
grep -q 'Connection from' /tmp/sshd.log || fail "sshd saw no connection"
# A connection alone proves sshd listens, not that SSH works: key exchange has to complete. The
# client has no key, so authentication itself is meant to fail.
grep -q 'SSH2_MSG_NEWKEYS received' /tmp/sshd.log || fail "sshd took the connection, but key exchange never completed"
echo "ok: real-10.9 smoke"
