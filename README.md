# Sumi shell

A quiet, ink-dark desktop shell for [Omarchy](https://github.com/omacom/omarchy):
a menu bar with a notch and a dock, a control center, a launcher, a cascading
command menu, and restyled notifications, OSD, lock screen and theme picker,
all in the Sumi design (墨: Inter, Zen Kaku Gothic New, hairlines, line icons).

Built and tested on Omarchy 4.5.0rc1 with Hyprland 0.56.2 and its Lua config.

## Install

```bash
git clone git@github.com:astrokachi/sumi-shell.git ~/src/sumi-shell
cd ~/src/sumi-shell
./install.sh --apply-theme
```

Run it from your desktop session, with the screen unlocked. It restarts the
shell at the end. Add `--dry-run` to see what it would change first.

| Option | Effect |
|---|---|
| `--apply-theme` | also switch to the Sumi theme (otherwise it's installed but your theme stays) |
| `--link` | symlink the plugins, `bin` and `hypr` files to this checkout instead of copying, for the machine you develop on |
| `--dry-run` | print every change, make none |

### What it changes

- **Plugins:** `~/.config/omarchy/plugins/sumi.*` (notch, menu, osd,
  notifications, lock, image-picker, battery-saver). They're turned on through
  the shell. The clones switch off Omarchy's originals, and the shell restores
  those if Sumi is removed.
- **Hyprland:** `~/.config/hypr/sumi.lua`, plus one line in `hyprland.lua`,
  `require("hypr.sumi")`, right after `require("hypr.looknfeel")`.
- **Keybindings viewer:** `~/.local/bin/sumi-keybindings` (Super+K).
- **Theme and wallpapers:** `~/.config/omarchy/themes/sumi` and
  `~/.config/omarchy/backgrounds/sumi`.
- **Fonts:** `~/.local/share/fonts/{inter,zen-kaku-gothic-new}`, plus
  `~/.config/fontconfig/conf.d/60-sumi-sans.conf`.
- **Preferences:** the interface font becomes Inter 11, and Japanese text uses
  Zen Kaku (`omarchy font cjk jp`).

Anything it replaces goes to `~/.local/state/sumi/backup-<time>/`, and
`~/.local/state/sumi/install.json` records the install. Running it again
updates in place. A machine still on the pre-0.1 `astrokachi.*` plugins is
migrated to `sumi.*` automatically.

## Uninstall

```bash
./uninstall.sh            # turns Sumi off and gives Omarchy its own plugins back
./uninstall.sh --purge    # also removes the theme, wallpapers and fonts
```

## Making changes

The repo is the source of truth. On the machine you edit from, install with
`--link`, so the live plugins are this checkout:

1. Edit the files here.
2. Run `omarchy restart shell`. Plugin hot reload doesn't reliably apply QML
   edits; a restart does.
3. Add an entry to `CHANGELOG.md` under **Unreleased**: what changed, why,
   and for speed work the before and after.
4. Commit and push. Other machines update by pulling and running
   `./install.sh` again.

### Things learned the hard way

- **A surface that stays mapped while closed must shrink to 1×1.** The blur
  rule in `hypr/sumi.lua` covers Sumi's surfaces, and Hyprland blurs a
  blurred layer wherever what's under it changes, even a transparent one.
  Four fullscreen ones held the display at 30 FPS. Use `ParkedOverlayWindow`
  (or its pattern) for anything new.
- **Nothing slow before the first frame.** Starting processes, building
  guard scripts and refreshing data all go after the surface is on screen
  (a short `Timer`), and repeated work is cached.
- **A surface that draws its own motion needs Hyprland's off.** Add its
  namespace to the `no_anim` rule in `hypr/sumi.lua`, or Hyprland animates
  its geometry too (a parked surface then sweeps in from the corner).
- **Use `SumiSpring` for motion**, with values from `SumiTokens`: gentle and
  slightly springy in, critically damped and quicker out. Never assign a
  bound property from code (`target = …` on a spring whose target is bound):
  in QML that silently removes the binding.
- **Fill a `ListModel` with one `append(array)`.** Appending row by row re-runs
  every binding on its count for each row.
- **Keep `pgrep`/`pkill` off keypress paths.** Scanning `/proc` costs about
  50 ms here (180 ms on power-saver).
- **Never write `shell.json` while the screen is locked**, and always write
  it atomically (a temp file, then `mv`): a bad write can strand the lock
  screen. Prefer the shell's own commands (`omarchy plugin enable/disable`).
- **Menu overrides in `sumi-menu.jsonc` must be whole rows.** Unset fields
  become defaults (label = the id, no icon) and replace the stock row's.
- **The notch rescans plugins once per shell start.** On Omarchy 4.5.0rc1 the
  first `shell.json` change after start revokes bar-widget components.
  Recheck whether this is still needed on newer Omarchy.

### Measuring

- **FPS:** turn on Hyprland's overlay with
  `hyprctl eval 'hl.config({ debug = { overlay = true } })'`, and play a
  60 FPS test pattern
  (`mpv 'av://lavfi:testsrc2=size=640x360:rate=60'`).
- **A surface that maps fresh:** time it from Hyprland's event socket
  (`openlayer>>…`).
- **A parked surface:** take `grim` screenshots at fixed delays after
  triggering it.
- **Inside the shell:** use `console.warn` timestamps, read with
  `qs log --id <instance>` (find the id with `qs list --all`).
- **Testing input:** never simulate keystrokes (they land in whatever has
  focus). Drive the shell over IPC instead.

## IPC

```bash
omarchy-shell sumi.notch controlCenter | controlCenterAt <wifi|bluetooth|sound|display|battery|clocks>
omarchy-shell sumi.notch launcher | launcherWith <text> | apps | customize | controlTab <tab>
omarchy-shell shell summon omarchy.menu '{"menu":"root"}'   # the command menu (sumi.menu)
```

## Layout

```
plugins/sumi.*      the shell plugins (Omarchy's plugin format)
hypr/sumi.lua       Hyprland settings: borders, blur, overlay timing, shortcuts
bin/                sumi-keybindings
theme/sumi          the Omarchy theme
backgrounds/sumi    extra wallpapers (credits in theme/sumi/WALLPAPER-CREDITS.tsv)
fonts/, fontconfig/ Inter, Zen Kaku Gothic New, and the rule that makes them the defaults
install.sh, uninstall.sh
```

## Status

- **Tested:** the migration from `astrokachi.*` and the `--link` install, on
  the machine Sumi was built on.
- **Not yet tested:** a fresh install on a clean user account, and
  `uninstall.sh`. Run each with `--dry-run` first.

See `NOTICE.md` for what came from Omarchy, and the font and wallpaper licences.
