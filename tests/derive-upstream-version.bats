#!/usr/bin/env bats
# platform: host-agnostic
# Verifies V_x_y_Pz (OpenSSH tag form) converts to the dotted portable version x.yPz -> x.ypz.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

teardown() { rm -f "$REPO/UPSTREAM_VERSION"; }

@test "V_9_9_P2 derives to 9.9p2" {
  run sh "$REPO/build/derive-upstream-version.sh" --print V_9_9_P2
  [ "$status" -eq 0 ]
  [ "$output" = "9.9p2" ]
}

@test "V_10_1_P1 derives to 10.1p1" {
  run sh "$REPO/build/derive-upstream-version.sh" --print V_10_1_P1
  [ "$status" -eq 0 ]
  [ "$output" = "10.1p1" ]
}

@test "V_9_9 (no pN suffix) derives to 9.9" {
  run sh "$REPO/build/derive-upstream-version.sh" --print V_9_9
  [ "$status" -eq 0 ]
  [ "$output" = "9.9" ]
}

@test "a malformed tag is rejected" {
  run sh "$REPO/build/derive-upstream-version.sh" --print not-a-tag
  [ "$status" -ne 0 ]
}

# The four cases above pin the TRANSFORM with fixed inputs. This one pins the PLUMBING: that
# no-arg mode reads the committed tag and writes what --print would say for it. Deriving the
# expectation instead of hardcoding a version is deliberate -- this test asserted "9.9p2" and so
# failed the moment components/openssh/version moved to V_10_5_P1, turning every upstream bump
# into a red build a human had to hand-edit. A test that must be edited to accept a new upstream
# is not testing the upstream, it is blocking it.
@test "writes UPSTREAM_VERSION from components/openssh/version when no arg" {
  tag="$(tr -d ' \t\r\n' < "$REPO/components/openssh/version")"
  want="$(sh "$REPO/build/derive-upstream-version.sh" --print "$tag")"
  run sh "$REPO/build/derive-upstream-version.sh"
  [ "$status" -eq 0 ]
  [ -n "$want" ]
  [ "$(cat "$REPO/UPSTREAM_VERSION")" = "$want" ]
  rm -f "$REPO/UPSTREAM_VERSION"
}
