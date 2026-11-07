#!/bin/sh
# platform: host-agnostic -- reads Mach-O with clang22's llvm-nm (build/fetch-clang22.sh)
# spec: tests/no-libc-pselect.sh -- no shipped binary may call 10.9's libc pselect(). That pselect sets
#       the signal mask, calls select(), then restores the mask, as three separate steps (Libc-997.90.3
#       gen/FreeBSD/pselect.c; xnu has no pselect syscall before 10.11's xnu-3248). A SIGCHLD that lands
#       between the unmask and the select() runs sshd-session's handler, and the select() then sleeps
#       with no timeout: the exited child is never reaped and the client never gets its exit status.
#       mavericks-vm run 42299349324 hung that way for three hours on packer's scp upload, with scp a
#       zombie under its sshd-session. clang22's clang.cfg links librecaulk.a before -lSystem, and
#       Recaulk (20261107.1 and later) defines a race-free pselect there, so the call never reaches libc.
#
# Exits 77 (SKIP) when the staging tree isn't built yet, like compat-guard.sh. POSIX /bin/sh.
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$R"; . "$R/build/versions.sh"
STAGE="${STAGE:-$WORK/staging}"
[ -d "$STAGE$PREFIX/bin" ] || { echo "no staged payload at $STAGE$PREFIX -- skipping (run build/build-openssh.sh first)"; exit 77; }
NM="${NM:-$(sh "$R/build/fetch-clang22.sh")/bin/llvm-nm}"

n=0; bad=0
for b in "$STAGE$PREFIX"/bin/* "$STAGE$PREFIX"/sbin/* "$STAGE$PREFIX"/libexec/*; do
  [ -f "$b" ] || continue
  file "$b" | grep -q 'Mach-O' || continue
  n=$((n + 1))
  # Read the imports first: an nm that cannot read Mach-O must fail here, not match nothing.
  u="$("$NM" -u "$b")" || { echo "FAIL: $NM cannot list ${b#"$STAGE"}'s imports"; exit 1; }
  if printf '%s\n' "$u" | grep -q '^_pselect'; then
    echo "FAIL: ${b#"$STAGE"} calls libc's pselect, which loses a SIGCHLD on 10.9"
    bad=1
  fi
done
[ "$n" -gt 0 ] || { echo "no Mach-O binaries under $STAGE$PREFIX -- skipping"; exit 77; }
[ "$bad" -eq 0 ] || exit 1
echo "OK: none of the $n shipped binaries calls libc's pselect"
