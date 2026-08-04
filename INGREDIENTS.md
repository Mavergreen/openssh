# Ingredients

Every input baked into the shipped artifacts, where it is pinned, its Renovate status, and
what a bump does. A bump to any ingredient (not the OpenSSH upstream) cuts a `-mavericks.N+1`
repackage via `repackage-on-ingredient-bump`.

| Ingredient | Pinned in | Renovate | On bump |
|---|---|---|---|
| OpenSSH portable (upstream) | `components/openssh/version` (tag form `V_x_y_Pz`) | ✅ github-tags `openssh/openssh-portable` | new upstream → `-mavericks.1` (auto-cut on main) |
| LibreSSL portable (static crypto) | `build/versions.sh` `LIBRESSL_VERSION` | ✅ github-tags `libressl/portable` | repackage `-mavericks.N+1` |
| Apple-restoration patches + keychain.{h,m} | `patches/` (vendored from Wowfunhappy) | ❌ untrackable (hand-maintained fork of Apple's integrations; no upstream release feed) | repackage `-mavericks.N+1` |
| OpenSSH release signing key | `scripts/openssh-signing-key.asc` | ❌ untrackable (stable signer identity; rotated rarely, by hand) | n/a |
| Sparkle framework, 10.9 SDK, EdDSA tools | fetched by shared-cmake | ✅ tracked in shared-cmake | via `shared-cmake@v1` |

## Provenance / credit

`patches/*.patch` and `patches/keychain.{h,m}` are vendored from
`github.com/Wowfunhappy/OpenSSH-Mavericks-Update` (restores Apple's Keychain, launchd, and
sandbox integrations, plus the `sshd-session` inetd fix). Thank you to Wowfunhappy.

## Conformance deviations

_None currently._
