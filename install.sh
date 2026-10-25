#!/usr/bin/env bash
# Install the Sumi shell on an Omarchy machine.
#
#   ./install.sh                 copy everything into place
#   ./install.sh --link          symlink plugins, bin and hypr from this checkout,
#                                so edits here are live (the machine you develop on)
#   ./install.sh --apply-theme   also switch to the Sumi theme
#   ./install.sh --dry-run       print what would change, change nothing
#
# Safe to run again: it updates in place. Anything it replaces goes to
# ~/.local/state/sumi/backup-<time>/, and uninstall.sh reverses it.
# A machine still on the old astrokachi.* plugin ids is migrated to sumi.*.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mode=copy
apply_theme=false
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --link) mode=link ;;
    --apply-theme) apply_theme=true ;;
    --dry-run) dry_run=true ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

config=${XDG_CONFIG_HOME:-$HOME/.config}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/sumi
backup="$state_dir/backup-$(date +%Y%m%d-%H%M%S)"
shell_json="$config/omarchy/shell.json"
plugins_dir="$config/omarchy/plugins"
suite=(notch menu osd notifications lock image-picker battery-saver)

say() { printf '%s\n' "$*"; }
run() { if $dry_run; then say "  would: $*" >&2; else "$@"; fi; }
die() { echo "install.sh: $*" >&2; exit 1; }

# ---- checks ------------------------------------------------------------------

for cmd in omarchy omarchy-shell hyprctl python3 fc-cache; do
  command -v "$cmd" >/dev/null || die "$cmd not found; this installs onto Omarchy"
done
[[ $(omarchy-shell shell ping 2>/dev/null) == ok ]] || die "the Omarchy shell isn't responding; start it and try again"
# shell.json must never be written while the screen is locked: a write then
# can strand the lock screen.
[[ $(omarchy-shell lock isLocked 2>/dev/null) != true ]] || die "the screen is locked"

say "Sumi shell $(cat "$repo/VERSION") ($mode install from $repo)"
$dry_run && say "Dry run: nothing will change."

# ---- placing files -------------------------------------------------------------

# Put $1 at $2, by link or copy. Whatever is already at $2 is moved into the
# backup first, unless it is already this link.
place() {
  local src="$1" dst="$2"
  if [[ $mode == link && -L $dst && $(readlink "$dst") == "$src" ]]; then
    return
  fi
  if [[ $mode == copy && -e $dst && ! -L $dst ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
    return
  fi
  if [[ -e $dst || -L $dst ]]; then
    run mkdir -p "$backup/$(dirname "${dst#$HOME/}")"
    run mv "$dst" "$backup/${dst#$HOME/}"
  fi
  run mkdir -p "$(dirname "$dst")"
  if [[ $mode == link ]]; then
    run ln -s "$src" "$dst"
  else
    run cp -a "$src" "$dst"
  fi
}

# Copied, never linked: assets the user may change or that must survive the
# checkout moving.
place_copy() { local mode=copy; place "$@"; }

say "Plugins"
for name in "${suite[@]}"; do
  place "$repo/plugins/sumi.$name" "$plugins_dir/sumi.$name"
done

say "Keybindings viewer and Hyprland settings"
place "$repo/bin/sumi-keybindings" "$HOME/.local/bin/sumi-keybindings"
place "$repo/hypr/sumi.lua" "$config/hypr/sumi.lua"

say "Theme, wallpapers, fonts"
place_copy "$repo/theme/sumi" "$config/omarchy/themes/sumi"
place_copy "$repo/backgrounds/sumi" "$config/omarchy/backgrounds/sumi"
for family in "$repo"/fonts/*/; do
  family=${family%/}
  place_copy "$family" "$HOME/.local/share/fonts/$(basename "$family")"
done
place_copy "$repo/fontconfig/60-sumi-sans.conf" "$config/fontconfig/conf.d/60-sumi-sans.conf"
run fc-cache -f >/dev/null

# ---- hyprland.lua --------------------------------------------------------------

# Load hypr/sumi.lua right after hypr.looknfeel, before Omarchy's toggles, so
# the glassy toggles still set their own blur.
hyprland_lua="$config/hypr/hyprland.lua"
if [[ -f $hyprland_lua ]] && ! grep -q 'require("hypr.sumi")' "$hyprland_lua"; then
  say "Loading hypr/sumi.lua from hyprland.lua"
  run mkdir -p "$backup/.config/hypr"
  run cp -a "$hyprland_lua" "$backup/.config/hypr/hyprland.lua"
  if ! $dry_run; then
    python3 -I - "$hyprland_lua" <<'PY'
import sys
path = sys.argv[1]
lines = open(path).read().split("\n")
line = 'require("hypr.sumi")'
at = next((i for i, l in enumerate(lines) if l.strip() == 'require("hypr.looknfeel")'), None)
if at is None:
    lines.append(line)
else:
    lines.insert(at + 1, line)
open(path, "w").write("\n".join(lines))
PY
  fi
fi

# ---- shell.json ----------------------------------------------------------------

# The shell has to know the sumi.* plugins before shell.json names them.
run omarchy-shell shell rescanPlugins >/dev/null

# A machine still on astrokachi.* ids: rename them in shell.json in one atomic
# write (the shell watches the file), then retire the old plugin folders.
legacy=()
for name in "${suite[@]}"; do
  [[ -e $plugins_dir/astrokachi.$name ]] && legacy+=("$name")
done
if [[ -f $shell_json ]] && grep -q '"astrokachi\.' "$shell_json"; then
  say "Migrating shell.json from astrokachi.* to sumi.*"
  run mkdir -p "$backup/.config/omarchy"
  run cp -a "$shell_json" "$backup/.config/omarchy/shell.json"
  if ! $dry_run; then
    python3 -I - "$shell_json" "${suite[@]}" <<'PY'
import json, os, sys, tempfile
path, suite = sys.argv[1], set(sys.argv[2:])
def rename(value):
    if isinstance(value, dict):
        return {k: rename(v) for k, v in value.items()}
    if isinstance(value, list):
        return [rename(v) for v in value]
    if isinstance(value, str) and value.startswith("astrokachi.") and value[11:] in suite:
        return "sumi." + value[11:]
    return value
config = json.load(open(path))
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".shell.json.")
with os.fdopen(fd, "w") as out:
    json.dump(rename(config), out, indent=2, ensure_ascii=False)
    out.write("\n")
os.replace(tmp, path)
PY
  fi
fi
for name in "${legacy[@]}"; do
  say "Retiring astrokachi.$name"
  run mkdir -p "$backup/retired"
  run mv "$plugins_dir/astrokachi.$name" "$backup/retired/"
done

# ---- turning it on ---------------------------------------------------------------

run omarchy-shell shell rescanPlugins >/dev/null

# Enabled means named in shell.json: as the bar, or in plugins[]. Enabling a
# clone (menu, osd, notifications, lock, image-picker) switches its stock
# original off, and the shell remembers to restore it if Sumi is removed.
enabled() {
  python3 -I -c '
import json, sys
c = json.load(open(sys.argv[1]))
ids = {c.get("bar", {}).get("id")} | {p.get("id") if isinstance(p, dict) else p for p in c.get("plugins", [])}
sys.exit(0 if sys.argv[2] in ids else 1)' "$shell_json" "$1"
}
for name in "${suite[@]}"; do
  if $dry_run || ! enabled "sumi.$name"; then
    say "Enabling sumi.$name"
    run omarchy plugin enable "sumi.$name" >/dev/null
  fi
done
# The notch brings its own dock.
if ! $dry_run && omarchy plugin list --json | python3 -I -c '
import json, sys
sys.exit(0 if any(p["id"] == "omarchy.dock" and p["active"] for p in json.load(sys.stdin)) else 1)'; then
  run omarchy plugin disable omarchy.dock >/dev/null
fi

# ---- preferences ---------------------------------------------------------------

previous_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)
if [[ -n $previous_font && $previous_font != "'Inter 11'" ]]; then
  say "Interface font: Inter"
  run gsettings set org.gnome.desktop.interface font-name 'Inter 11'
fi
if [[ $(omarchy font cjk 2>/dev/null) != jp ]]; then
  run omarchy font cjk jp >/dev/null
fi
if $apply_theme; then
  say "Theme: Sumi"
  run omarchy theme set sumi
fi

if ! $dry_run; then
  mkdir -p "$state_dir"
  python3 -I - "$state_dir/install.json" "$(cat "$repo/VERSION")" "$mode" "$repo" "$backup" "$previous_font" <<'PY'
import json, sys, time
path, version, mode, repo, backup, font = sys.argv[1:7]
json.dump({"version": version, "mode": mode, "repo": repo, "backup": backup,
           "previousFont": font, "installedAt": time.strftime("%Y-%m-%dT%H:%M:%S")},
          open(path, "w"), indent=2)
PY
fi

# ---- reload --------------------------------------------------------------------

run hyprctl reload >/dev/null
run omarchy restart shell >/dev/null 2>&1
say "Done.$([[ -d $backup ]] && printf ' Replaced files are in %s.' "$backup")"
