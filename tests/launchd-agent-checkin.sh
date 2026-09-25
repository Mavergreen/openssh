#!/bin/sh
# platform: macOS-only -- launchctl loads a real launchd job to test the agent's check-in
# Standing guard on the ssh-agent launchd check-in: launchd starts the agent as
# `ssh-agent -l` (see /System/Library/LaunchAgents/org.openbsd.ssh-agent.plist), and the agent
# must check in and then ANSWER a client on the socket launchd handed it.
#
# This is the one defect the compat guard structurally cannot see: the binary is perfectly
# 10.9-safe, it links, it runs -- and it exits 1 the moment launchd starts it, because our
# patches/ssh-agent-launchd.patch uses launch_msg(LAUNCH_KEY_CHECKIN), whose descriptor to
# launchd closefrom() destroys if the check-in runs after it. A client then blocks forever on a
# socket launchd holds for an agent that never lives, which takes out every login shell that
# runs `ssh-add -l` (10.5p1-mavericks.2 shipped exactly that).
#
# Only a real launchd can answer this, so it exits 77 (SKIP) off 10.9 or before a build.
# POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF/.." && pwd)"; export REPO_ROOT
. "$REPO_ROOT/build/versions.sh"

sw="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
case "$sw" in 10.9*) : ;; *) echo "not 10.9 ($sw) -- skipping"; exit 77;; esac

STAGE="${STAGE:-$WORK/staging}"
AGENT="${AGENT:-$STAGE$PREFIX/bin/ssh-agent}"
SSH_ADD="${SSH_ADD:-$STAGE$PREFIX/bin/ssh-add}"
[ -x "$AGENT" ] || { echo "not built ($AGENT) -- skipping"; exit 77; }
[ -x "$SSH_ADD" ] || { echo "not built ($SSH_ADD) -- skipping"; exit 77; }

LABEL="dev.mavergreen.openssh-checkin-test.$$"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/launchd-checkin.XXXXXX")"
SOCK="$TMP/agent.sock"
PLIST="$TMP/test.plist"
ERR="$TMP/agent.err"

cleanup() {
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$LABEL</string>
	<key>ProgramArguments</key>
	<array><string>$AGENT</string><string>-l</string></array>
	<key>ServiceIPC</key><true/>
	<key>Sockets</key>
	<dict><key>Listeners</key><dict>
		<key>SockPathName</key><string>$SOCK</string>
		<key>SockPathMode</key><integer>384</integer>
	</dict></dict>
	<key>StandardErrorPath</key><string>$ERR</string>
</dict>
</plist>
EOF

launchctl load "$PLIST" || { echo "FAIL: launchctl could not load the test job" >&2; exit 1; }

# Ask the agent to list identities. A live agent answers immediately -- with "no identities"
# and exit 1, which is a SUCCESSFUL conversation. A dead one leaves us blocked on launchd's
# socket, so the client runs in the background under a bounded wait instead of hanging the suite.
SSH_AUTH_SOCK="$SOCK" "$SSH_ADD" -l >"$TMP/out" 2>&1 &
client=$!
answered=no
i=0
while [ "$i" -lt 100 ]; do
  kill -0 "$client" 2>/dev/null || { answered=yes; break; }
  sleep 0.1
  i=$((i + 1))
done

if [ "$answered" = no ]; then
  kill "$client" 2>/dev/null || true
  echo "FAIL: ssh-agent -l never answered a client on launchd's socket." >&2
  echo "      The check-in must run BEFORE closefrom(), which closes liblaunch's" >&2
  echo "      descriptor to launchd; see patches/ssh-agent-launchd.patch." >&2
  [ -s "$ERR" ] && { echo "      agent stderr:" >&2; sed 's/^/        /' "$ERR" >&2; }
  exit 1
fi

wait "$client" 2>/dev/null || true
if [ -s "$ERR" ]; then
  echo "FAIL: ssh-agent wrote to stderr under launchd:" >&2
  sed 's/^/  /' "$ERR" >&2
  exit 1
fi

echo "ok: ssh-agent checked in with launchd and answered a client"
