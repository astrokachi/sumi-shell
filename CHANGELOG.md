# Changelog

Every change to Sumi gets an entry here: what changed, why, and, for anything
about speed, the measurement before and after. Newest first. Add new work under
**Unreleased** and give it a version when you tag a release.

## Unreleased

### Bar

- **The middle of the bar hosts widgets again.** It draws the layout's
  `center` section, so Omarchy's own clock sits there and a click opens its
  calendar. With an empty `center` it falls back to Sumi's plain time.
  Omarchy's agents and update widgets go in `right`, beside the indicators.
- **No Agents section in the control center.** Omarchy's agents widget is
  back on the bar and shows the same usage, so the control center drops its
  copy, along with the five-minute usage poll it ran in the background.

### Themes

- **Six more dark Japanese themes**, from the directions canvas: `andon`
  行灯 (washi lit by a lantern), `ai` 藍 (indigo dye), `ukiyoe` 浮世絵 (the
  night print), `urushi` 漆 (black lacquer and gold), `raku` 楽 (a tea bowl)
  and `yoru` 夜 (Tokyo after dark). Each is a full Omarchy theme
  (`colors.toml`, a `shell.toml` made from Sumi's hand-edited one, and a
  preview). Ukiyo-e draws solid Prussian-blue keylines on popups and menus,
  Urushi gold hairlines, Yoru faint cyan ones; the rest keep Sumi's
  hairlines. Yoru's canvas palette was neon; its accents are toned down.
- **12 wallpapers per theme** (72 in all): photographs, prints, screens and
  lacquerware, public domain, CC0, CC BY or CC BY-SA, each credited in
  `theme/<name>/WALLPAPER-CREDITS.tsv`. They're graded into the theme's
  palette with `tools/grade-wallpaper.sh`, so each set reads as one.
- **Your own wallpapers stay local.** Files named `*.local.jpg`,
  `*.local.png` or `*.local.tsv` (for their sources) in `backgrounds/<name>/`
  are ignored by git but still installed, for pictures you can't
  redistribute.
- **Every wallpaper is a true 3840×2160.** The first cut was 2560×1440, and
  most of Urushi's had been enlarged from 1,500–2,000 px originals, so they
  looked soft. Each one is now cut from a full-resolution original, nothing
  is enlarged by more than 10%, and images too small for that were replaced.
  Three Ukiyo-e prints and several Urushi pieces only exist as smaller or
  square scans; those are shown whole on a dark ground from the palette
  instead of being blown up.
- `install.sh` places every theme in `theme/` with its wallpapers;
  `uninstall.sh --purge` removes all seven.

### Motion

- **Springs, in Apple's terms.** `SumiSpring` (in `sumi.notch`) takes a
  response (seconds) and a damping ratio. It moves on from wherever it is at
  whatever speed it has, so reopening something while it closes turns around
  smoothly instead of jumping. It only draws frames while moving, and jumps
  when Hyprland's animations are off.
- **Surfaces settle in on a gentle spring.** The control center, launcher,
  command menu and notch controls open with response 0.38 s and damping 0.75:
  about 90% there in 180 ms, a ~1.5% overshoot, then a soft settle, scaling
  from 0.95 at the point they hang from. They close critically damped
  (0.24 s, no bounce) and quicker. Each is fully opaque about a third of the
  way in, so it is there at once and the spring shapes the settle.
- **Control center sections open on springs**: widen, then the body drops a
  beat later; the reverse on close. The battery's power modes are open in
  about 280 ms. Their height shows the spring's overshoot; their width never
  passes the panel's edge.
- **The notch's width, the controls card's height and its tab marker** move
  on springs too. The motion values live in `SumiTokens` (`openResponse`,
  `openDamping`, `closeResponse`, `closeDamping`, `settleFrom`, `opaqueAt`).

### Speed

- **Battery saver boosts through heavy load.** Power-saver pins every core at
  800 MHz, so a build or a batch of renders crawled on battery. When all
  cores stay at least 70% busy for 20 s on power-saver (battery 20% or more),
  `sumi.battery-saver` takes a power-profiles-daemon performance hold. It lets
  go after 30 s under 35% busy, on plug-in, or below 20% battery. Measured
  under the same load (17 on 8 threads): 800 MHz before, 1.3–1.5 GHz boosted.
  A hold leaves the remembered profile alone, and picking a profile by hand
  drops it and stops boosts for 10 minutes. The hold's process exits within
  5 s if quickshell dies, so it can't stay on. `powerprofilesctl list-holds`
  shows it as `sumi.battery-saver`.

### Fixes

- **One menu at a time.** Opening any menu now closes the one already out,
  instead of letting them pile up: the control center, the notch controls,
  the launcher, a bar widget's popout, the dock's app menu and app library,
  the command menu and the notification panel. The notch keeps the rule
  (`closeMenusExcept`); the command menu and notification panel tell it when
  they open or close (`omarchy-shell sumi.notch menuOpened|menuClosed <id>`),
  and `sumi.notch debug` lists what is open under `menus`.

- **The control center opens where it hangs.** Growing back from its parked
  1×1, Hyprland animated the resize, so it swept in from the screen's corner.
  `hypr/sumi.lua` now turns Hyprland's animation off for `sumi-cc` and
  `sumi-control`, as Omarchy already does for its menu and pickers; the
  shell draws the motion itself.
- **The notch controls no longer shake after opening.** The notch's width ran
  on a spring with damping 0.36, which overshot by ~30% and rang for half a
  second after any hover change, and the card followed the notch's moving
  geometry. The notch now springs at damping 0.82 without ringing, and the
  card centres on the bar.

## 0.1.0 (2026-10-25)

The first packaged release: the suite as it runs on the machine it was built
on, with every fix from the 2026-10-25 performance pass.

### Packaging

- **One installable suite.** `install.sh` puts the plugins, the Hyprland
  settings, the keybindings viewer, the theme, wallpapers and fonts in place,
  turns everything on and restarts the shell; `uninstall.sh` gives Omarchy its
  own back. `--link` runs a machine straight from the checkout, so edits are
  live and land in the repo.
- **Plugin ids are `sumi.*`** (were `astrokachi.*`), as are the layer names
  (`sumi-cc`, `sumi-control`, ...). The installer migrates a machine still on
  the old ids: it renames them in `shell.json` in one atomic write and moves
  the old plugin folders into its backup.
- **Sumi's Hyprland settings live in `hypr/sumi.lua`**, loaded right after
  `hypr.looknfeel` and before Omarchy's toggles, so the glassy toggles still
  set their own blur. Personal settings stay in the user's own files.
- **The menu's Sumi rows ship with the plugin** (`sumi.menu/sumi-menu.jsonc`),
  merged between Omarchy's defaults and the user's extension file, so the
  user's file is never edited and their rows still win.
- **Shibumi widgets are hidden** from the notch's Layout tab unless Shibumi's
  runtime is running. Without it they can only sit on the bar blank.

### Speed

Measured on an HP laptop with Intel UHD 620, Omarchy 4.5.0rc1, Hyprland 0.56.2.

- **The command menu, launcher, control center and image picker open in about
  30–40 ms** (were 180–670 ms). Each used to build a new fullscreen window on
  every open, wait for the display scale, then fade in through Hyprland. They
  now stay mapped while closed: transparent, click-through, without keyboard
  focus. The shared window is `sumi.notch/ParkedOverlayWindow.qml`.
- **The display runs at 60 FPS** (was locked at 30 while anything moved under
  a blurred layer). Hyprland blurs a blurred layer wherever the content under
  it changes, even when the layer is transparent. Closed surfaces now shrink
  to one pixel in the corner and grow back on open.
- **Typing in the command menu:** the first letter takes about 0.14 s (was
  1.1–1.6 s) and later letters about 40 ms (were 45–125 ms, with stalls up to
  0.4 s).
  - The result list is filled in one append, not one row at a time. Each row
    re-ran every binding that depends on the row count, about 4 ms a row.
  - Each entry's search text and every submenu's child count are cached until
    the menu's contents change. Text is matched before the slower visibility
    check.
  - The list height is summed from plain rows, not `ListModel.get()`.
  - A single letter shows the top 40 results until the second letter.
  - The background checks that fill in values and checkmarks wait until typing
    pauses, run at the lowest CPU priority, and only rebuild the menu when a
    result actually changed. They had been stalling the first keystrokes.
- **Opening the command menu** no longer waits on those checks. They start
  after the menu is on screen; they used to block it for 30–40 ms.
- **Super+K (keybindings)** appears in about 0.1 s (was 0.5 s, or about 2 s
  after any Hyprland reload). It opens straight from the cached list and
  re-checks the cache in the background. It builds its request with one `jq`
  instead of three `perl` runs, and the picker fills its list in one append.
- **The control center's nine status readers** start just after it appears,
  not before its first frame.
- **The theme picker** opens directly. A wrapper asked the Shibumi plugin
  first, which was off, and spent about 0.4 s on a login shell and a failed
  lookup every time.

### Fixes

- **The power profile came back to performance on AC.** The battery saver
  set power-saver on unplug but never restored the AC profile, so the CPU sat
  near 700 MHz of 3400 MHz while plugged in. It now applies the AC profile on
  plug-in and at startup.
- **Seven panel shortcuts work again**: Super+Ctrl+A/B/D/W/P and
  Super+Ctrl+Alt+D/E. They pointed at the stock bar's panels, which the notch
  replaces, and only logged "no live bar widget". They now open the matching
  control center section.
- **Search ranking:** among equally good matches the label the query covers
  most comes first, so "them" finds Theme before Theme Corners.
- **The control center's top edge** is a single hairline. A second "glass"
  line under it had made it twice as thick.
- **Picker requests are no longer orphaned.** When a new request replaced an
  open one, or the shell restarted, the waiting `omarchy-menu-select` or
  `omarchy-menu-images` polled for an answer forever; the images one woke 100
  times a second. The menu now answers replaced requests as cancelled and
  stops orphaned waiters when the shell starts.
- **Learn › Keybindings** shows its name and icon again. A one-field override
  had replaced the whole row.

### Motion

- **The control center, launcher and command menu fade in** with a slight
  settle (scale 0.98 → 1) over 160 ms, and fade out in 120 ms. They settle
  from where they hang: the status glyphs, the bar's mark, or the centre for
  dialogs. Clicks and focus switch at once; only the drawing eases. What was
  on screen stays put while it fades out.
- **Control center sections open in about 260 ms** (were about 600 ms). The
  widening and the drop now overlap, and the scroll after is shorter.
- **Overlays Hyprland animates** (notifications, polkit prompts) use the
  same 160 / 120 ms on the same curve (were 400 ms in). Omarchy already
  turns Hyprland's animation off for its menu, pickers, emojis and clipboard.
- Motion lives in `SumiTokens` (`openMs`, `closeMs`, `easeOut`) and goes
  through `Style.duration()`, so turning off Hyprland's animations turns it
  off too.

## Before packaging (2026-10-22 to 2026-10-24)

Built as `astrokachi.*` plugins in `~/.config/omarchy/plugins`, before this
repo existed.

- The notch bar and dock replaced Shibumi's bar, and the dependency on
  Shibumi was removed. The notch no longer hosts Shibumi's widget runtime, and
  its Theme and Wallpaper buttons open Sumi's picker.
- The Sumi design system: the ink-dark palette, Inter and Zen Kaku Gothic New,
  JetBrains Mono for figures, and the Sumi line icons (`Icons.js`,
  `SumiIcon.qml`, `SumiTokens.qml`).
- Restyled clones of Omarchy's menu (a cascading dropdown), OSD,
  notifications, lock screen and theme/wallpaper picker.
- The control center: Wi-Fi, Bluetooth, sound, display and battery open in
  place. Battery health and power draw are read from sysfs where UPower has
  nothing.
