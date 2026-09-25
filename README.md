# Mavericks OpenSSH

A community build of **OpenSSH 9.9p2 for Mavericks** (Mac OS X 10.9), with Apple's Keychain,
launchd, and sandbox integrations restored and modern crypto via statically-linked LibreSSL.
The family-maintained successor to Wowfunhappy's *Mavericks Forever* OpenSSH.

**Unofficial community build. Not affiliated with the OpenSSH or OpenBSD project.**

## Download

Two `.pkg` installers are published on the
[latest release](https://github.com/Mavergreen/openssh/releases/latest):

| Installer | What it is |
|---|---|
| `OpenSSH-<version>.pkg` | **The product** — installs OpenSSH under `/usr/local/mavergreen/openssh`, overwrites nothing. |
| `OpenSSH-System-Replace-<version>.pkg` | **Optional add-on** — makes that build your *system* `ssh`/`sshd`. |

(e.g. `OpenSSH-9.9p2-mavericks.1.pkg` and `OpenSSH-System-Replace-9.9p2-mavericks.1.pkg`.)

## 1. Install OpenSSH — `OpenSSH-<version>.pkg`

Double-click it. OpenSSH installs under `/usr/local/mavergreen/openssh` and **overwrites nothing**.
The commands are on your `PATH` as `/usr/local/mavergreen/bin/ssh`, `/usr/local/mavergreen/bin/scp`,
`/usr/local/mavergreen/bin/sftp`, and `/usr/local/mavergreen/sbin/sshd` — but come after `/usr/bin`
unless System Replace (step 2) is installed. Configs and host keys live in
`/usr/local/mavergreen/var/openssh` and survive upgrades. A Sparkle updater keeps the tree current
in the background.

On its own, this does **not** change your Mac's default `ssh` or the built-in `sshd` — it lives
alongside them under `/usr/local/mavergreen/openssh`.

## 2. (Optional) Make it the system OpenSSH — `OpenSSH-System-Replace-<version>.pkg`

Want the modern build to *be* the default `ssh` and the server the built-in launchd job runs?
**Install the product (step 1) first**, then double-click this second installer. It:

- saves your existing OpenSSH binaries aside (the 12 `/usr/bin`, `/usr/sbin` and `/usr/libexec`
  paths OpenSSH ships) and symlinks each of them to the matching copy under
  `/usr/local/mavergreen/openssh`;
- leaves `/etc` untouched — the modern build reads its config and host keys from
  `/usr/local/mavergreen/var/openssh`, not `/etc`;
- so the untouched `/System/Library/LaunchDaemons/ssh.plist` job now runs the modern `sshd`, and
  the default `ssh` in your `PATH` is the modern one.

**Order matters:** the product must be installed first — this installer only creates symlinks that
point *into* `/usr/local/mavergreen/openssh`.

**Reverting:** run `sudo mavergreen system-restore openssh`, which removes the symlinks and
restores the saved originals. To remove OpenSSH for Mavericks entirely, run
`sudo mavergreen uninstall openssh` (this restores the system paths first).

## Credit

The Apple-integration patches originate from
[Wowfunhappy/OpenSSH-Mavericks-Update](https://github.com/Wowfunhappy/OpenSSH-Mavericks-Update).
