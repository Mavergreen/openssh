# Ingredients

Every input baked into the shipped artifacts, where it is pinned, its Renovate status, and
what a bump does. A bump to any ingredient (not the OpenSSH upstream) cuts a `-mavericks.N+1`
repackage via `repackage-on-ingredient-bump`.

| Ingredient | Pinned in | Renovate | On bump |
|---|---|---|---|
| OpenSSH portable (upstream) | `components/openssh/version` (tag form `V_x_y_Pz`) | ✅ github-tags `openssh/openssh-portable` | new upstream → `-mavericks.1` (auto-cut on main) |
| LibreSSL portable (static crypto) | `build/versions.sh` `LIBRESSL_VERSION` | ✅ github-tags `libressl/portable` | repackage `-mavericks.N+1` |
| Apple-restoration patches + keychain.{h,m} | `patches/` (derived from Apple's OpenSSH; see Provenance) | ⚠️ untrackable as files, but their SOURCE has a feed: `apple-oss-distributions/OpenSSH` publishes tags (`OpenSSH-354.120.2`, ...). Not wired to Renovate because a bump there is a prompt to re-read, never an automatic edit — see Provenance. | repackage `-mavericks.N+1` |
| OpenSSH release signing key | `scripts/openssh-signing-key.asc` | ❌ untrackable (stable signer identity; rotated rarely, by hand) | n/a |
| Sparkle framework, 10.9 SDK, EdDSA tools | fetched by shipyard | ✅ tracked in shipyard | via `shipyard@v1` |

## Provenance / credit

`patches/*.patch` and `patches/keychain.{h,m}` restore Apple's Keychain and launchd
integrations. They originate in **Apple's own OpenSSH**
(`github.com/apple-oss-distributions/OpenSSH`) and reached us via
`github.com/Wowfunhappy/OpenSSH-Mavericks-Update`, which rebased them onto a 10.9-buildable
OpenSSH. Thank you to Wowfunhappy.

**Apple's tree is the real upstream, and it IS versioned** — releases are tagged
(`OpenSSH-354.120.2`, based on OpenSSH 10.2p1, at the 2026-09-13 sync). Diffing Apple's
`ssh-agent.c` against the upstream OpenSSH it is based on yields exactly our seven
`__APPLE_LAUNCHD__` hunks, which is how the 10.5p1 port was derived rather than hand-rewritten.
Do the same next time: `apple-oss-distributions/OpenSSH` at its newest tag, diffed against the
matching openbsd tarball, is the authoritative source for these patches.

**But do not take Apple's newest blindly, and that is why this is not wired to Renovate.** Apple
targets current macOS; we target 10.9, and they have already diverged in a way that builds green
and fails on the platform. Their `ssh-agent.c` now calls `launch_activate_socket()`, introduced in
10.10, undeclared in the 10.9 SDK's `launch.h` and absent from its libSystem — it compiles with
only an implicit-declaration warning, links, and passes the compat guard. We deliberately keep the
older `launch_msg(LAUNCH_KEY_CHECKIN)` check-in, which 10.9 declares. What we DO take from Apple is
placement: the check-in must sit after `closefrom()`, which is new in 10.x and would otherwise
purge the listener fds.

A tag moving in Apple's tree is therefore a signal to go and read, not a change to apply. Last
synced from Wowfunhappy: commit `d7b66a7` (2026-09-11), which added `ssh-askpass-confirm.patch`.
Its build-script changes
(https download URLs, `curl --fail --proto '=https'`, a `PACKAGE_REVISION` axis) are deliberately
NOT taken: we already fetch over https from ftp.openbsd.org with `curl -fSL`, verify OpenSSH by
PGP signer identity and LibreSSL against its published SHA256, and `-mavericks.N` is our
packaging axis.

## Conformance deviations

_None currently._
