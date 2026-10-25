#!/usr/bin/env bash
# Remove the Sumi shell and give Omarchy its own back.
#
#   ./uninstall.sh            turn the plugins off and remove what install.sh placed;
#                             the theme, wallpapers and fonts stay, as they may be in use
#   ./uninstall.sh --purge    also remove the theme, wallpapers and fonts
#   ./uninstall.sh --dry-run  print what would change, change nothing

set -euo pipefail

purge=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --purge) purge=true ;;
    --dry-run) dry_run=true ;;
    -h | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

config=${XDG_CONFIG_HOME:-$HOME/.config}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/sumi
plugins_dir="$config/omarchy/plugins"
suite=(notch menu osd notifications lock image-picker battery-saver)

say() { printf '%s\n' "$*"; }
run() { if $dry_run; then say "  would: $*" >&2; else "$@"; fi; }
die() { echo "uninstall.sh: $*" >&2; exit 1; }

[[ $(omarchy-shell shell ping 2>/dev/null) == ok ]] || die "the Omarchy shell isn't responding; start it and try again"
[[ $(omarchy-shell lock isLocked 2>/dev/null) != true ]] || die "the screen is locked"
$dry_run && say "Dry run: nothing will change."

# Turning each plugin off lets the shell put back the stock plugin it replaced
# (menu, osd, notifications, lock, image-picker) and Omarchy's own bar.
say "Turning the plugins off"
for name in "${suite[@]}"; do
  run omarchy plugin disable "sumi.$name" >/dev/null 2>&1 || true
done
if [[ $(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("bar", {}).get("id", ""))' "$config/omarchy/shell.json" 2>/dev/null) == sumi.notch ]]; then
  run omarchy plugin enable omarchy.bar >/dev/null 2>&1 || true
fi

say "Removing files"
for name in "${suite[@]}"; do
  run rm -rf "$plugins_dir/sumi.$name"
done
run rm -f "$HOME/.local/bin/sumi-keybindings" "$config/hypr/sumi.lua" "$config/fontconfig/conf.d/60-sumi-sans.conf"
hyprland_lua="$config/hypr/hyprland.lua"
if [[ -f $hyprland_lua ]] && grep -q 'require("hypr.sumi")' "$hyprland_lua"; then
  run sed -i '/^require("hypr\.sumi")$/d' "$hyprland_lua"
fi
if $purge; then
  [[ $(omarchy theme current 2>/dev/null | tr '[:upper:]' '[:lower:]') == sumi ]] &&
    say "  The Sumi theme is in use; pick another first (omarchy theme set <name>)." ||
    run rm -rf "$config/omarchy/themes/sumi" "$config/omarchy/backgrounds/sumi"
  run rm -rf "$HOME/.local/share/fonts/inter" "$HOME/.local/share/fonts/zen-kaku-gothic-new"
fi
run fc-cache -f >/dev/null

# The interface font install.sh replaced, if it recorded one.
previous_font=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("previousFont", ""))' "$state_dir/install.json" 2>/dev/null || true)
if [[ -n $previous_font && $previous_font != "'Inter 11'" ]]; then
  run gsettings set org.gnome.desktop.interface font-name "${previous_font//\'/}"
fi
run rm -f "$state_dir/install.json"

run omarchy-shell shell rescanPlugins >/dev/null
run hyprctl reload >/dev/null
run omarchy restart shell >/dev/null 2>&1
say "Done. Backups from earlier installs stay in $state_dir."
