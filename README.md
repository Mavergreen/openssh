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
| `OpenSSH-<version>.pkg` | **The product** — installs OpenSSH under `/usr/local`, overwrites nothing. |
| `OpenSSH-System-Replace-<version>.pkg` | **Optional add-on** — makes that build your *system* `ssh`/`sshd`. |

(e.g. `OpenSSH-9.9p2-mavericks.1.pkg` and `OpenSSH-System-Replace-9.9p2-mavericks.1.pkg`.)

## 1. Install OpenSSH — `OpenSSH-<version>.pkg`

Double-click it. OpenSSH installs under `/usr/local` and **overwrites nothing**. Put
`/usr/local/bin` on your `PATH` to use the new `ssh`/`scp`/`sftp` (and `/usr/local/sbin/sshd`).
A Sparkle updater keeps `/usr/local` current in the background.

On its own, this does **not** change your Mac's default `ssh` or the built-in `sshd` — it lives
alongside them under `/usr/local`.

## 2. (Optional) Make it the system OpenSSH — `OpenSSH-System-Replace-<version>.pkg`

Want the modern build to *be* the default `ssh` and the server the built-in launchd job runs?
**Install the product (step 1) first**, then double-click this second installer. It:

- backs up your existing OpenSSH (binaries, configs, host keys) to `/var/backups/vanilla-openssh`;
- symlinks the system `/usr` + `/etc` OpenSSH paths to the copies under `/usr/local`;
- so the untouched `/System/Library/LaunchDaemons/ssh.plist` job now runs the modern `sshd`, and
  the default `ssh` in your `PATH` is the modern one.

**Order matters:** the product must be installed first — this installer only creates symlinks that
point *into* `/usr/local`.

**Reverting:** run `sudo /usr/local/libexec/openssh-mavericks-deactivate`, which removes the
symlinks and restores the originals from `/var/backups/vanilla-openssh`.

## Credit

The Apple-integration patches originate from
[Wowfunhappy/OpenSSH-Mavericks-Update](https://github.com/Wowfunhappy/OpenSSH-Mavericks-Update).
