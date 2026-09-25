#!/usr/bin/env bats
# platform: host-agnostic
# fetch-openssh derives the tarball name from the version and refuses a missing/mismatched sig.
# These tests are gpg-free: the missing-signature path returns before gpg is invoked.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  . "$REPO/build/fetch-openssh.sh" --source-only
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/openssh-verify.XXXXXX")"
}
teardown() { rm -rf "$TMP"; }

@test "tarball name derives from the dotted version" {
  run openssh_tarball_name 9.9p2
  [ "$status" -eq 0 ]
  [ "$output" = "openssh-9.9p2.tar.gz" ]
}

@test "tarball name derives for a different version" {
  run openssh_tarball_name 10.1p1
  [ "$output" = "openssh-10.1p1.tar.gz" ]
}

@test "verify fails fast when the signature file is absent" {
  echo x > "$TMP/openssh-9.9p2.tar.gz"
  run verify_openssh_signature "$TMP/openssh-9.9p2.tar.gz" "$TMP/missing.asc"
  [ "$status" -ne 0 ]
}
