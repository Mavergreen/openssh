#!/bin/sh
# Fetch the OpenSSH portable release tarball named by the derived version, verify its detached
# PGP signature against the pinned OpenSSH release-signing key (scripts/openssh-signing-key.asc),
# record its sha256 in SHA256SUMS, and unpack it. Signer-identity model: the pinned key vouches
# for versions that don't exist yet, so a Renovate ref bump needs no new hand-pasted hash.
# OpenSSH release key: Damien Miller <djm@mindrot.org>,
#   fpr 7168 B983 815A 5EEF 59A4 ADFD 2A3F 414E 7360 60BA  (verify on rotation).
# The gpg verification runs in CI on modern macOS (the workflow installs gnupg); gpg is not
# present on 10.9, but this fetch is a build-time step, not a 10.9 runtime step. POSIX /bin/sh.
set -eu

openssh_tarball_name() { printf 'openssh-%s.tar.gz\n' "$1"; }

verify_openssh_signature() {
  # $1 = tarball, $2 = detached .asc. Fails fast (no gpg call) when the signature is missing.
  [ -f "$2" ] || { echo "FATAL: missing signature $2" >&2; return 1; }
  ring="$(mktemp -d)"
  gpg --homedir "$ring" --import "$FETCH_KEY" >/dev/null 2>&1 || { echo "FATAL: cannot import signing key" >&2; return 1; }
  gpg --homedir "$ring" --trust-model always --verify "$2" "$1" >/dev/null 2>&1 \
    || { echo "FATAL: OpenSSH signature verification failed" >&2; return 1; }
  echo "verified OpenSSH signature for $1" >&2   # progress -> stderr; fetch_openssh's stdout must be ONLY the src path (it is captured)
}

fetch_openssh() {
  : "${WORK:?}"; : "${OPENSSH_VERSION:?}"
  mirror="https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable"
  tb="$(openssh_tarball_name "$OPENSSH_VERSION")"
  mkdir -p "$WORK"
  [ -f "$WORK/$tb" ]     || curl -fSL -o "$WORK/$tb"     "$mirror/$tb"
  [ -f "$WORK/$tb.asc" ] || curl -fSL -o "$WORK/$tb.asc" "$mirror/$tb.asc"
  verify_openssh_signature "$WORK/$tb" "$WORK/$tb.asc"
  shasum -a 256 "$WORK/$tb" >> "${SHA256SUMS:-$WORK/SHA256SUMS}"
  rm -rf "$WORK/openssh-${OPENSSH_VERSION}"
  tar -C "$WORK" -xzf "$WORK/$tb"
  echo "$WORK/openssh-${OPENSSH_VERSION}"
}

: "${FETCH_KEY:=$(cd "$(dirname "$0")/.." && pwd)/scripts/openssh-signing-key.asc}"
case "${1:-}" in
  --source-only) return 0 2>/dev/null || exit 0 ;;
esac
. "$(cd "$(dirname "$0")" && pwd)/versions.sh"
fetch_openssh
