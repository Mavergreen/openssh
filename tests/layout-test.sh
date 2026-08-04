#!/bin/sh
# Verifies the replacement activation logic against a fake root ($ROOT): it backs up an existing
# "system" ssh, installs a symlink pointing at the /usr/local copy, and restores on uninstall.
# The scripts honor $ROOT (default /) so this test never touches the real system. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layout.XXXXXX")"; export ROOT
trap 'rm -rf "$ROOT"' EXIT

# Fake an existing system ssh and our /usr/local copy.
mkdir -p "$ROOT/usr/bin" "$ROOT/usr/local/bin"
printf '#!/bin/sh\necho vanilla\n' > "$ROOT/usr/bin/ssh"; chmod +x "$ROOT/usr/bin/ssh"
printf '#!/bin/sh\necho modern\n'  > "$ROOT/usr/local/bin/ssh"; chmod +x "$ROOT/usr/local/bin/ssh"

# Fake an existing system config and our /usr/local copy.
mkdir -p "$ROOT/etc" "$ROOT/usr/local/etc"
printf 'vanilla-sshd-config\n' > "$ROOT/etc/sshd_config"
printf 'modern-sshd-config\n'  > "$ROOT/usr/local/etc/sshd_config"

sh "$SELF/../scripts/preinstall"
sh "$SELF/../scripts/postinstall"

# /usr/bin/ssh is now a symlink to /usr/local/bin/ssh, and the original is backed up.
[ -L "$ROOT/usr/bin/ssh" ] || { echo "FAIL: /usr/bin/ssh not a symlink" >&2; exit 1; }
[ "$(sh "$ROOT/usr/bin/ssh")" = "modern" ] || { echo "FAIL: symlink does not resolve to modern ssh" >&2; exit 1; }
[ -f "$ROOT/var/backups/vanilla-openssh/usr/bin/ssh" ] || { echo "FAIL: original not backed up" >&2; exit 1; }

# /etc/sshd_config is now a symlink to our modern config, and the original is backed up.
[ -L "$ROOT/etc/sshd_config" ] || { echo "FAIL: /etc/sshd_config not a symlink" >&2; exit 1; }
[ "$(cat "$ROOT/etc/sshd_config")" = "modern-sshd-config" ] || { echo "FAIL: config symlink does not resolve to modern config" >&2; exit 1; }
[ -f "$ROOT/var/backups/vanilla-openssh/etc/sshd_config" ] || { echo "FAIL: original config not backed up" >&2; exit 1; }

sh "$SELF/../scripts/uninstall"
[ ! -L "$ROOT/usr/bin/ssh" ] || { echo "FAIL: symlink not removed on uninstall" >&2; exit 1; }
[ "$(sh "$ROOT/usr/bin/ssh")" = "vanilla" ] || { echo "FAIL: original not restored" >&2; exit 1; }
[ ! -L "$ROOT/etc/sshd_config" ] || { echo "FAIL: config symlink not removed on uninstall" >&2; exit 1; }
[ "$(cat "$ROOT/etc/sshd_config")" = "vanilla-sshd-config" ] || { echo "FAIL: original config not restored" >&2; exit 1; }
echo "ok: backup/symlink/restore round-trip (binary + config)"
