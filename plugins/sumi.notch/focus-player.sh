#!/bin/bash
# Focus the window a MPRIS player is playing in.
# Usage: focus-player.sh <dbus-name> <desktop-entry> <track-title>
name=$1 entry=${2,,} title=$3

pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
  GetConnectionUnixProcessID s "$name" 2>/dev/null | awk '{print $2}')

# Ancestors of the player's process, so a helper child still finds its window.
pids=()
p=$pid
while [[ -n $p && $p -gt 1 ]]; do
  pids+=("$p")
  p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
done

address=$(hyprctl clients -j | jq -r --argjson pids "$(printf '%s\n' "${pids[@]}" | jq -sc 'map(tonumber)')" \
  --arg entry "$entry" --arg title "$title" '
  def score: if $title != "" and (.title | contains($title)) then 1 else 0 end;
  [.[] | select(.pid as $p | $pids | index($p))] as $byPid
  | (if ($byPid | length) > 0 then $byPid
     else [.[] | select($entry != "" and ((.class | ascii_downcase) == $entry
       or (.initialClass | ascii_downcase) == $entry))] end)
  | sort_by(-score) | .[0].address // empty')

[[ -z $address ]] && exit 1
target="window = \"address:$address\""
hyprctl dispatch "hl.dsp.focus({ $target })" >/dev/null
hyprctl dispatch "hl.dsp.window.alter_zorder({ mode = \"top\", $target })" >/dev/null
