#!/bin/sh
# Real-10.9 smoke: exercise the built product on an actual Mavericks box. Exits 77 (SKIP)
# anywhere that isn't 10.9 or where the product isn't installed, so it never gates CI -- it is
# the one-time manual validation of the initial cross-build. POSIX /bin/sh.
set -eu
sw="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
case "$sw" in 10.9*) : ;; *) echo "not 10.9 ($sw) -- skipping"; exit 77;; esac
[ -x /usr/local/bin/ssh ] || { echo "product not installed -- skipping"; exit 77; }

/usr/local/bin/ssh -V 2>&1 | grep -q OpenSSH || { echo "FAIL: ssh -V" >&2; exit 1; }
port=2222
/usr/local/sbin/sshd -d -p "$port" -o UsePAM=no -h /usr/local/etc/ssh_host_rsa_key >/tmp/sshd.log 2>&1 &
pid=$!; sleep 2
/usr/local/bin/ssh -p "$port" -o StrictHostKeyChecking=no -o BatchMode=yes localhost true 2>/tmp/ssh.log || true
kill "$pid" 2>/dev/null || true
grep -q 'Connection from' /tmp/sshd.log || { echo "FAIL: sshd saw no connection" >&2; exit 1; }
echo "ok: real-10.9 smoke"
