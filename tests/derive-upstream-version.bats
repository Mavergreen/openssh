#!/usr/bin/env bats
# Verifies V_x_y_Pz (OpenSSH tag form) converts to the dotted portable version x.yPz -> x.ypz.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

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

@test "writes UPSTREAM_VERSION from components/openssh/version when no arg" {
  run sh "$REPO/build/derive-upstream-version.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/UPSTREAM_VERSION")" = "9.9p2" ]
  rm -f "$REPO/UPSTREAM_VERSION"
}
