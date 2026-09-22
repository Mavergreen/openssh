#!/bin/sh
# The flag-day migration (2026-09-22, ModernMavericks -> Mavergreen) for both pkgs:
#   1. the PRODUCT pkg's preinstall (build/flag-day-preinstall.sh) forgets its pre-rename receipt on
#      Installer's target volume, only there, and never fails the install;
#   2. the System-Replace pkg's preinstall (scripts/preinstall) forgets ITS pre-rename receipt the
#      same way, and leaves an already-replaced system exactly as it was: the symlinks the launchd
#      sshd runs through, the backup of the original OpenSSH and the migrated host keys;
#   3. the product's rendered postinstall retires the OLD updater .app + update-check agent. That is
#      shipyard's shared updater/agent-load.in, but it works only if the new label is the old one with
#      the prefix swapped -- this repo's to get right. The old names are what the pre-flag-day pkgs
#      actually installed.
# pkgutil, launchctl and sudo are PATH stubs that record their arguments, and everything happens under
# a fake root, so nothing here touches a real receipt database, the system OpenSSH or a launchd session.
# DELETABLE with build/flag-day-preinstall.sh (shipyard SKILL.md "Consolidation backlog").
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SELF/.." && pwd)"
t="$(mktemp -d "${TMPDIR:-/tmp}/flagday.XXXXXX")"   # template: 10.9 BSD mktemp requires one
trap 'rm -rf "$t"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir -p "$t/bin" "$t/vol"
for cmd in pkgutil launchctl sudo; do
  cat > "$t/bin/$cmd" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$t/$cmd.log"
exit \${STUB_RC:-0}
EOF
  chmod +x "$t/bin/$cmd"
done

# --- 1. the product pkg's preinstall -------------------------------------------------------------
sh "$REPO/build/flag-day-preinstall.sh" dev.modernmavericks.openssh "$t/s/preinstall"
[ -x "$t/s/preinstall" ] || fail "no executable preinstall rendered"
# Installer runs preinstall as: $1 pkg path, $2 install location, $3 target volume, $4 system root.
PATH="$t/bin:$PATH" "$t/s/preinstall" /x.pkg / "$t/vol" / || fail "product preinstall failed"
[ "$(cat "$t/pkgutil.log")" = "--volume $t/vol --forget dev.modernmavericks.openssh" ] \
  || fail "product: expected the old receipt forgotten on the target volume, got: $(cat "$t/pkgutil.log")"
rm -f "$t/pkgutil.log"
PATH="$t/bin:$PATH" STUB_RC=1 "$t/s/preinstall" /x.pkg / "$t/vol" / || fail "product: a failing pkgutil failed the install"
rm -f "$t/pkgutil.log"
PATH="$t/bin:$PATH" "$t/s/preinstall" || fail "product preinstall with no args failed"
[ ! -f "$t/pkgutil.log" ] || fail "product: pkgutil ran with no target volume: $(cat "$t/pkgutil.log")"
if sh "$REPO/build/flag-day-preinstall.sh" dev.mavergreen.openssh "$t/bad" 2>/dev/null; then
  fail "rendered a preinstall that forgets a dev.mavergreen.* receipt"
fi
grep -q 'flag-day-preinstall.sh" dev.modernmavericks.openssh "$SCR/preinstall"' "$REPO/build/package-pkg.sh" \
  || fail "package-pkg.sh does not render the flag-day preinstall"
grep -q -- '--scripts "$SCR"' "$REPO/build/package-pkg.sh" || fail "package-pkg.sh does not hand pkgbuild the scripts dir"

# --- 2. the System-Replace pkg's preinstall, over a system an old replace pkg already took over ---
R="$t/root"
mkdir -p "$R/usr/bin" "$R/usr/local/bin" "$R/etc" "$R/usr/local/etc" "$R/var/backups/vanilla-openssh/usr/bin"
printf '#!/bin/sh\necho vanilla\n' > "$R/var/backups/vanilla-openssh/usr/bin/ssh"
printf '#!/bin/sh\necho modern\n'  > "$R/usr/local/bin/ssh"; chmod +x "$R/usr/local/bin/ssh"
printf 'modern-sshd-config\n' > "$R/usr/local/etc/sshd_config"
printf 'host-key\n' > "$R/usr/local/etc/ssh_host_ed25519_key"; cp "$R/usr/local/etc/ssh_host_ed25519_key" "$R/etc/"
ln -s "$R/usr/local/bin/ssh" "$R/usr/bin/ssh"
ln -s "$R/usr/local/etc/sshd_config" "$R/etc/sshd_config"
snap() { ( cd "$R" && find . \( -type l -exec sh -c 'printf "%s -> %s\n" "$1" "$(readlink "$1")"' _ {} \; \) -o \( -type f -exec cksum {} \; \) | sort ); }
before="$(snap)"
rm -f "$t/pkgutil.log"
PATH="$t/bin:$PATH" ROOT="$R" sh "$REPO/scripts/preinstall" /x.pkg / "$t/vol" / || fail "replace preinstall failed"
[ "$(cat "$t/pkgutil.log")" = "--volume $t/vol --forget dev.modernmavericks.openssh.replace" ] \
  || fail "replace: expected the old receipt forgotten on the target volume, got: $(cat "$t/pkgutil.log")"
[ "$(snap)" = "$before" ] || fail "replace preinstall changed an already-replaced system:
$(printf '%s\n' "$before" > "$t/a"; snap > "$t/b"; diff "$t/a" "$t/b")"
[ "$(sh "$R/usr/bin/ssh")" = modern ] || fail "replace: /usr/bin/ssh no longer runs the modern ssh"
rm -f "$t/pkgutil.log"
PATH="$t/bin:$PATH" STUB_RC=1 ROOT="$R" sh "$REPO/scripts/preinstall" /x.pkg / "$t/vol" / \
  || fail "replace: a failing pkgutil failed the install"
rm -f "$t/pkgutil.log"
PATH="$t/bin:$PATH" ROOT="$R" sh "$REPO/scripts/preinstall" || fail "replace preinstall with no args failed"
[ ! -f "$t/pkgutil.log" ] || fail "replace: pkgutil ran with no target volume: $(cat "$t/pkgutil.log")"

# --- 3. the product's old updater + agent --------------------------------------------------------
# SHIPYARD_SCRIPTS is what CI packages with (install@v1 exports it), so it is what must retire the
# old updater. Unset (a plain local run), there is no shipyard to render with: skip this half.
if [ -z "${SHIPYARD_SCRIPTS:-}" ] || [ ! -f "$SHIPYARD_SCRIPTS/stage_updater.sh" ]; then
  echo "OK: flag-day migration (SHIPYARD_SCRIPTS unset: skipped the updater-retirement half)"
  exit 0
fi
OLD_LABEL=dev.modernmavericks.openssh-updatecheck; APP=OpenSSHUpdater.app
label=dev.mavergreen.${OLD_LABEL#dev.modernmavericks.}
grep -qF -- "--agent-label \"$label\"" "$REPO/build/package-pkg.sh" \
  || fail "package-pkg.sh no longer stages its agent as $label: the shared retirement derives the old
      label from the new one, so it would miss $OLD_LABEL"
grep -qF "/$APP}\"" "$REPO/build/package-pkg.sh" || fail "the updater is no longer $APP; update this test with it"
V="$t/vol-upd"; OLDAPPS="$V/Library/Application Support/ModernMavericks"
mkdir -p "$V/Library/LaunchAgents" "$OLDAPPS/$APP/Contents/MacOS" "$t/$APP/Contents/MacOS"
touch "$V/Library/LaunchAgents/$OLD_LABEL.plist" "$OLDAPPS/$APP/Contents/MacOS/x"
sh "$SHIPYARD_SCRIPTS/stage_updater.sh" --stage "$t/stage" --app "$t/$APP" \
  --app-dir "/Library/Application Support/Mavergreen" --agent-label "$label" \
  --scripts-out "$t/scripts" 2>/dev/null || fail "stage_updater.sh failed"
PATH="$t/bin:$PATH" sh "$t/scripts/postinstall" /x.pkg / "$V" / || fail "product postinstall failed"
if [ -f "$V/Library/LaunchAgents/$OLD_LABEL.plist" ] || [ -d "$OLDAPPS/$APP" ]; then
  fail "the postinstall left the old updater behind ($OLD_LABEL, $APP). A shipyard at
      $SHIPYARD_SCRIPTS that predates the flag day retires nothing: package with one released after it."
fi
echo "OK: flag-day migration (product + System-Replace receipts, old updater retired, replaced system untouched)"
