#!/usr/bin/env bash
# Background watcher: re-applies theme whenever the palette file changes.
# Launched by hyde.tmux; killed when the tmux session ends.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FILE_PATH="${1:-$HOME/.config/kitty/theme.conf}"
DEBOUNCE="${2:-1}"   # seconds
LIGHTNESS_PCT="${3:-12}"

file_expanded="${FILE_PATH/#\~/$HOME}"

last_sig=""

get_sig() {
  stat -c "%Y:%s" "$file_expanded" 2>/dev/null
}

apply() {
  bash "$CURRENT_DIR/apply_theme.sh" "$FILE_PATH" "$LIGHTNESS_PCT"
}

# Initial apply
apply
last_sig=$(get_sig)

if command -v inotifywait &>/dev/null; then
  # Efficient: use inotifywait (Linux)
  while inotifywait -e close_write,moved_to -q "$(dirname "$file_expanded")" 2>/dev/null; do
    # Check the target file specifically changed
    sig=$(get_sig)
    [[ "$sig" == "$last_sig" ]] && continue
    last_sig="$sig"
    sleep "$DEBOUNCE"
    apply
  done
else
  # Fallback: poll every 2 seconds
  while true; do
    sleep 2
    sig=$(get_sig)
    if [[ "$sig" != "$last_sig" ]]; then
      last_sig="$sig"
      sleep "$DEBOUNCE"
      apply
    fi
  done
fi
