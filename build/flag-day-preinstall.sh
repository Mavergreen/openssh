#!/bin/sh
#   usage: flag-day-preinstall.sh OLD_PKG_IDENTIFIER OUT_FILE
#          Writes the PRODUCT pkg's preinstall: the ONE-TIME MIGRATION off the ModernMavericks
#          identity (flag day 2026-09-22). DELETABLE once no pre-flag-day install survives (see
#          shipyard's SKILL.md "Consolidation backlog", "Retire the flag-day migration") -- delete this
#          file, its caller in build/package-pkg.sh, the matching block at the end of
#          scripts/preinstall (the System-Replace pkg's) and tests/flag-day-migration.sh.
#
#          The pkg identifier moved from dev.modernmavericks.openssh to dev.mavergreen.openssh, and to
#          Installer a different identifier is a different package: the old receipt would stay behind,
#          claiming files this pkg now owns, and `pkgutil --pkgs` would list both forever. Everything
#          else the old identity left is already handled: the /usr/local payload did not move (this pkg
#          overwrites it), and the old updater .app and its agent are retired by shipyard's shared
#          updater/agent-load.in, which the postinstall stage_updater.sh renders already runs.
set -eu
old="${1:?usage: flag-day-preinstall.sh OLD_PKG_IDENTIFIER OUT_FILE}"
out="${2:?usage: flag-day-preinstall.sh OLD_PKG_IDENTIFIER OUT_FILE}"
case "$old" in
  dev.modernmavericks.*) : ;;
  *) echo "flag-day-preinstall: '$old' is not a pre-flag-day identifier" >&2; exit 2 ;;
esac
mkdir -p "$(dirname "$out")"
cat > "$out" <<EOF
#!/bin/sh
# ONE-TIME MIGRATION off the ModernMavericks identity (flag day 2026-09-22).
# DELETABLE once no pre-flag-day install survives (see shipyard SKILL.md "Consolidation backlog").
# Rendered by build/flag-day-preinstall.sh -- do not edit here.
#
# Forget the receipt of the same product under its old identifier ($old). Scoped to
# Installer's target volume (\$3): with none, nothing is known about where the old install lives,
# so nothing is done. Best-effort: never fail the install over a receipt.
if [ -n "\${3:-}" ]; then
  pkgutil --volume "\$3" --forget "$old" >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod +x "$out"
