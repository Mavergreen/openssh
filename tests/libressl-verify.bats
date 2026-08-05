#!/usr/bin/env bats
# The LibreSSL checksum gate must reject a mismatched tarball and accept a matching one.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/libressl-verify.XXXXXX")"
  # Source only the functions (no build).
  . "$REPO/build/build-libressl.sh" --source-only
  printf 'fake libressl bytes\n' > "$TMP/fake.tar.gz"
  GOOD_SHA="$(shasum -a 256 "$TMP/fake.tar.gz" | awk '{print $1}')"
}
teardown() { rm -rf "$TMP"; }

@test "rejects a mismatched checksum" {
  run verify_libressl_tarball "$TMP/fake.tar.gz" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  [ "$status" -ne 0 ]
}

@test "rejects an empty expected checksum (fail closed)" {
  run verify_libressl_tarball "$TMP/fake.tar.gz" ""
  [ "$status" -ne 0 ]
}

@test "accepts a matching checksum" {
  run verify_libressl_tarball "$TMP/fake.tar.gz" "$GOOD_SHA"
  [ "$status" -eq 0 ]
}

@test "success writes NOTHING to stdout (progress goes to stderr; build_libressl's stdout is the captured prefix)" {
  # build-openssh.sh does LIBRESSL="$(build-libressl.sh)", so any stray stdout corrupts the path.
  out="$(verify_libressl_tarball "$TMP/fake.tar.gz" "$GOOD_SHA" 2>/dev/null)"
  [ -z "$out" ]
}
