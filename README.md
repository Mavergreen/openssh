# Mavericks OpenSSH

A community build of **OpenSSH 9.9p2 for Mavericks** (Mac OS X 10.9), with Apple's Keychain,
launchd, and sandbox integrations restored and modern crypto via statically-linked LibreSSL.
The family-maintained successor to Wowfunhappy's *Mavericks Forever* OpenSSH.

**Unofficial community build. Not affiliated with the OpenSSH or OpenBSD project.**

## Two installers

- **OpenSSH for Mavericks** (the product): installs under `/usr/local`, overwrites nothing.
  Put `/usr/local/bin` on your `PATH` to use the new `ssh`/`scp`/`sftp`. Includes a Sparkle
  updater that keeps `/usr/local` current.
- **Make it the system OpenSSH** (opt-in): backs up your existing OpenSSH to
  `/var/backups/vanilla-openssh` and symlinks the system `/usr` + `/etc` paths to the copies
  under `/usr/local`, so the built-in launchd `sshd` job runs the new server. Reversible.

## Credit

The Apple-integration patches originate from
[Wowfunhappy/OpenSSH-Mavericks-Update](https://github.com/Wowfunhappy/OpenSSH-Mavericks-Update).
