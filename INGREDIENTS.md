# Ingredients

Every input baked into the shipped artifacts, where it is pinned, its Renovate status, and
what a bump does. A bump to any ingredient (not the OpenSSH upstream) cuts a `-mavericks.N+1`
repackage via `repackage-on-ingredient-bump`.

| Ingredient | Pinned in | Renovate | On bump |
|---|---|---|---|
| OpenSSH portable (upstream) | `components/openssh/version` (tag form `V_x_y_Pz`) | ✅ github-tags `openssh/openssh-portable` | new upstream → `-mavericks.1` (auto-cut on main) |
| LibreSSL portable (static crypto) | `build/versions.sh` `LIBRESSL_VERSION` | ✅ github-tags `libressl/portable` | repackage `-mavericks.N+1` |
| Apple-restoration patches + keychain.{h,m} | `patches/` (derived from Apple's OpenSSH; see Provenance) | ⚠️ untrackable as files, but their SOURCE has a feed: `apple-oss-distributions/OpenSSH` publishes tags (`OpenSSH-354.120.2`, ...). Not wired to Renovate because a bump there is a prompt to re-read, never an automatic edit — see Provenance. | repackage `-mavericks.N+1` |
| `sshd-keygen-wrapper` (launchd's sshd Program on 10.9) | `scripts/sshd-keygen-wrapper.in`, staged with `@PREFIX@` substituted | ❌ untrackable (ours, not upstream's: OpenSSH portable ships no such file, and Apple's own predates ecdsa/ed25519 host keys, so we generate them with `ssh-keygen -A` instead of restoring it verbatim) | repackage `-mavericks.N+1` |
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
targets current macOS; we target 10.9. Their `ssh-agent.c` now calls `launch_activate_socket()`,
which the 10.9 SDK's `launch.h` does not declare — so clang compiles it on an implicit declaration,
guessing the prototype for what is, at this deployment target, an undocumented SPI.

Precisely (an earlier revision of this file overstated it): the symbol is NOT absent. It is exported
by `/usr/lib/system/libxpc.dylib` on 10.9.5 and re-exported through libSystem, and a call to it
links and runs there, returning `ENOTSUP`. What we actually know is that it is undeclared, that the
compiler is therefore guessing its signature, and that this was verified only on 10.9.5 — not on
10.9.0-10.9.4, which the product also targets.

So we keep the older `launch_msg(LAUNCH_KEY_CHECKIN)` check-in: 10.9's `launch.h` declares it, the
prototype is the real one, Wowfunhappy's users exercise it, and it needs no hand-written prototype
for an SPI.

**Do NOT also take Apple's placement — the two choices are coupled, and an earlier revision of this
file got it backwards.** It said the check-in "must sit after `closefrom()`, which is new in 10.x and
would otherwise purge the listener fds." That is right for Apple, whose `launch_activate_socket()`
reaches launchd over a Mach port that closing descriptors cannot disturb. `launch_msg()` talks to
launchd over a socket whose descriptor liblaunch caches, and `closefrom()` closes it: every
subsequent check-in fails with `EPERM`, the agent exits 1, launchd respawns it forever, and any
client — `ssh-add -l` in a login shell, say — blocks on a socket no agent will ever answer. Measured
on 10.9.5, both orders, under a real launchd job; 10.5p1-mavericks.2 shipped the broken one.

So our check-in sits BEFORE `closefrom()`, and the purge then runs from above the listener
descriptors launchd handed us rather than from `STDERR_FILENO + 1`, which would close the very
sockets we just checked in for. `tests/launchd-agent-checkin.sh` is the standing check: it loads a
real launchd job on 10.9 and fails unless the agent answers a client.

A tag moving in Apple's tree is therefore a signal to go and read, not a change to apply. Last
synced from Wowfunhappy: commit `d7b66a7` (2026-09-11), which added `ssh-askpass-confirm.patch`.
Its build-script changes
(https download URLs, `curl --fail --proto '=https'`, a `PACKAGE_REVISION` axis) are deliberately
NOT taken: we already fetch over https from ftp.openbsd.org with `curl -fSL`, verify OpenSSH by
PGP signer identity and LibreSSL against its published SHA256, and `-mavericks.N` is our
packaging axis.

## Conformance deviations

_None currently._
