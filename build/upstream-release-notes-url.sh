#!/bin/sh
# platform: host-agnostic
# Print the URL of the release notes for one upstream OpenSSH portable version. shipyard's
# upstream-notes.sh links it from our release notes when a release ships a NEW upstream.
#   usage: upstream-release-notes-url.sh <upstream-version>      (bare: 9.9p2)
set -eu
printf 'https://www.openssh.com/releasenotes.html#%s\n' "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
