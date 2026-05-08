#!/usr/bin/env bash
# hyde.tmux — TPM entry point
# Add to ~/.tmux.conf:
#   set -g @plugin 'your-username/hyde-tmux'
# Or source directly:
#   run-shell /path/to/hyde.tmux

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_opt() {
  local opt="$1" default="$2"
  local val
  val="$(tmux show-option -gqv "$opt" 2>/dev/null)"
  echo "${val:-$default}"
}

HYDE_FILE_PATH="$(get_opt "@hyde_file_path" "~/.config/kitty/theme.conf")"
HYDE_WATCH="$(get_opt "@hyde_watch" "on")"
HYDE_DEBOUNCE="$(get_opt "@hyde_debounce" "1")"
HYDE_LIGHTNESS_PCT="$(get_opt "@hyde_lightness_pct" "12")"

# Kill any previous watcher for this session
WATCHER_PID_FILE="/tmp/hyde-tmux-watcher-${TMUX_PANE}.pid"
if [[ -f "$WATCHER_PID_FILE" ]]; then
  old_pid=$(cat "$WATCHER_PID_FILE")
  kill "$old_pid" 2>/dev/null
  rm -f "$WATCHER_PID_FILE"
fi

if [[ "$HYDE_WATCH" == "on" ]]; then
  bash "$CURRENT_DIR/scripts/watch_theme.sh" \
    "$HYDE_FILE_PATH" "$HYDE_DEBOUNCE" "$HYDE_LIGHTNESS_PCT" &
  echo $! > "$WATCHER_PID_FILE"
else
  bash "$CURRENT_DIR/scripts/apply_theme.sh" "$HYDE_FILE_PATH" "$HYDE_LIGHTNESS_PCT"
fi
