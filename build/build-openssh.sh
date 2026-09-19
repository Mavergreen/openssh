#!/bin/sh
# Configure + build OpenSSH against the static LibreSSL and the pinned 10.9 SDK, re-adding the
# Apple integrations, and stage into a DESTDIR laid out for /usr/local. Cross-built on modern
# macOS in CI; targets 10.9 via -isysroot <SDK> + -mmacosx-version-min=10.9 and Apple clang
# (/usr/bin/clang) for the ObjC keychain code. POSIX /bin/sh.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/versions.sh"

SDK="$(sh "$SHIPYARD/fetch_sdk.sh")"
CC=/usr/bin/clang        # Apple clang: required for ObjC (keychain.m) + blocks

SRC="$(sh "$SELF/fetch-openssh.sh")"
sh "$SELF/apply-patches.sh" "$SRC"
LIBRESSL="$(sh "$SELF/build-libressl.sh")"

STAGE="${STAGE:-$WORK/staging}"
rm -rf "$STAGE"; mkdir -p "$STAGE"

APPLE_DEFS="-D__APPLE_KEYCHAIN__ -D__APPLE_MEMBERSHIP__ -D__APPLE_LAUNCHD__ -D__APPLE_SANDBOX_NAMED_EXTERNAL__"
# We cross-build the x86_64 / 10.9 product on a modern arm64 runner, so the arch is explicit
# (-arch x86_64) and configure runs in cross mode (--host) -- the 10.9 SDK is Intel-only, so a
# default (arm64) compile "cannot create executables", and cross mode avoids needing to RUN
# x86_64 test binaries (no Rosetta dependency).
( cd "$SRC"
  CC="$CC" \
  CFLAGS="-arch x86_64 -mmacosx-version-min=10.9 -isysroot $SDK -I$LIBRESSL/include $APPLE_DEFS" \
  LDFLAGS="-arch x86_64 -mmacosx-version-min=10.9 -isysroot $SDK -L$LIBRESSL/lib -framework CoreFoundation -framework Security -framework DirectoryService -lbsm" \
  ./configure \
    --host=x86_64-apple-darwin \
    --prefix="$PREFIX" --sysconfdir="$SYSCONFDIR" \
    --with-ssl-dir="$LIBRESSL" \
    --with-pam --with-audit=bsm --with-kerberos5=/usr \
    --with-sandbox=darwin \
    --with-privsep-path=/var/empty --with-privsep-user=_sshd \
    --disable-strip
  make -j"$(sysctl -n hw.ncpu)"
  make install-nokeys DESTDIR="$STAGE" )

# 10.9's ssh.plist runs sshd through /usr/libexec/sshd-keygen-wrapper, which the replacement pkg
# symlinks into our prefix -- upstream OpenSSH has no such file, so we ship one or launchd's ssh
# job points at nothing (tests/replace-links-resolve.sh is the standing check).
mkdir -p "$STAGE$PREFIX/libexec"
sed "s|@PREFIX@|$PREFIX|g" "$SELF/../scripts/sshd-keygen-wrapper.in" \
  > "$STAGE$PREFIX/libexec/sshd-keygen-wrapper"
chmod +x "$STAGE$PREFIX/libexec/sshd-keygen-wrapper"

# Config munge: match Wowfunhappy -- UsePAM + interop shims (idempotent appends).
CONF="$STAGE$SYSCONFDIR"
grep -q '^UsePAM yes' "$CONF/sshd_config" || echo 'UsePAM yes' >> "$CONF/sshd_config"
for f in sshd_config ssh_config; do
  grep -q '^HostKeyAlgorithms +ssh-rsa'        "$CONF/$f" || echo 'HostKeyAlgorithms +ssh-rsa'        >> "$CONF/$f"
  grep -q '^PubkeyAcceptedAlgorithms +ssh-rsa' "$CONF/$f" || echo 'PubkeyAcceptedAlgorithms +ssh-rsa' >> "$CONF/$f"
done

echo "$STAGE"
