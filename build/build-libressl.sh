#!/bin/sh
# Build LibreSSL portable as a STATIC library against the pinned 10.9 SDK, into a build-local
# prefix, for OpenSSH to link. Fetches upstream's own published SHA256 for the pinned version and
# verifies against it. Sourced with --source-only to expose functions to tests. POSIX /bin/sh.
#
# Checksum source: ftp.openbsd.org, LibreSSL's canonical distribution home. As of v4.3.2 the
# GitHub libressl/portable release for the tag carries NO attached tarball/checksum assets (only
# the auto-generated source archive under the git tag). The release tarball + its published
# SHA256 live at https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/. The SHA256 file lists lines of the
# form:  SHA256 (libressl-4.3.2.tar.gz) = <hex>
set -eu

LIBRESSL_BASE_URL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL"

verify_libressl_tarball() {
  # $1 = tarball path, $2 = expected sha256 (hex)
  [ -n "$2" ] || { echo "FATAL: no expected sha256 for LibreSSL" >&2; return 1; }
  _got="$(shasum -a 256 "$1" | awk '{print $1}')"
  [ "$_got" = "$2" ] || { echo "FATAL: LibreSSL sha256 mismatch: got $_got want $2" >&2; return 1; }
  echo "verified LibreSSL tarball ($_got)" >&2   # progress -> stderr (build_libressl's stdout is captured; must be ONLY the prefix path)
}

libressl_expected_sha() {
  # Fetch upstream's published SHA256 for libressl-${LIBRESSL_VERSION}.tar.gz. Fail loudly if
  # the checksum entry is absent (never pass an empty expectation to the verifier).
  : "${LIBRESSL_VERSION:?}"
  _want_file="libressl-${LIBRESSL_VERSION}.tar.gz"
  # Lines look like:  SHA256 (libressl-4.3.2.tar.gz) = <hex>
  # Field-split gives: $1=SHA256  $2=(<file>)  $3="="  $4=<hex>. Match $2 as the exact literal
  # "(<file>)" (string compare, no regex, so a dot in the version can't act as a wildcard) and
  # emit only $4.
  _sha="$(curl -fsSL "$LIBRESSL_BASE_URL/SHA256" \
    | awk -v tok="($_want_file)" '$1 == "SHA256" && $2 == tok { print $4 }')"
  case "$_sha" in
    [0-9a-f][0-9a-f]*) : ;;  # non-empty, starts hex
    *) echo "FATAL: no published SHA256 for $_want_file" >&2; return 1 ;;
  esac
  # Guard length: a SHA256 hex digest is exactly 64 chars.
  [ "${#_sha}" -eq 64 ] || { echo "FATAL: malformed SHA256 for $_want_file: $_sha" >&2; return 1; }
  printf '%s\n' "$_sha"
}

build_libressl() {
  : "${WORK:?}"; : "${LIBRESSL_VERSION:?}"; : "${MSC:?}"
  SDK="$(sh "$MSC/fetch_sdk.sh")"
  mkdir -p "$WORK"
  tb="$WORK/libressl-${LIBRESSL_VERSION}.tar.gz"
  [ -f "$tb" ] || curl -fSL -o "$tb" "$LIBRESSL_BASE_URL/libressl-${LIBRESSL_VERSION}.tar.gz"
  verify_libressl_tarball "$tb" "$(libressl_expected_sha)"
  rm -rf "$WORK/libressl-${LIBRESSL_VERSION}"
  tar -C "$WORK" -xzf "$tb"
  # configure/make/make install emit to stdout; send it all to stderr so the ONLY thing this
  # function writes to stdout is the final prefix path (build-openssh.sh captures it).
  ( cd "$WORK/libressl-${LIBRESSL_VERSION}"
    CFLAGS="-mmacosx-version-min=10.9 -isysroot $SDK -O2" \
    ./configure --prefix="$WORK/libressl-install" --enable-static --disable-shared --disable-asm
    make -j"$(sysctl -n hw.ncpu)"
    make install ) >&2
  echo "$WORK/libressl-install"
}

# Expose the functions without building when invoked with --source-only (whether sourced by a
# test or run directly): `return` succeeds when sourced, `exit 0` when executed. Otherwise this
# script was executed to actually build, so source the pins and run.
case "${1:-}" in
  --source-only) return 0 2>/dev/null || exit 0 ;;
esac
. "$(cd "$(dirname "$0")" && pwd)/versions.sh"
build_libressl
