#!/bin/sh
# platform: host-agnostic
_rc=0
_defaults="$ROOT/usr/local/mavergreen/openssh/share/openssh"
_state="$ROOT/usr/local/mavergreen/var/openssh"
mkdir -p "$_state" || _rc=1
for _f in ssh_config sshd_config moduli; do
  if [ ! -e "$_state/$_f" ]; then cp -p "$_defaults/$_f" "$_state/$_f" || _rc=1; fi
done
for _hk in "$ROOT"/etc/ssh_host_*; do
  [ -e "$_hk" ] || continue
  if [ ! -e "$_state/${_hk##*/}" ]; then cp -p "$_hk" "$_state/${_hk##*/}" || _rc=1; fi
done
[ "$_rc" -eq 0 ]
