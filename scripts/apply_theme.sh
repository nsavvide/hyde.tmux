#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/utils.sh"

# ---------------------------------------------------------------------------
# Helpers for reading TPM-style plugin options from tmux
# ---------------------------------------------------------------------------

get_tmux_option() {
  local opt="$1" default="$2"
  local val
  val="$(tmux show-option -gqv "$opt" 2>/dev/null)"
  echo "${val:-$default}"
}

# ---------------------------------------------------------------------------
# Build the color palette from the theme file
# ---------------------------------------------------------------------------

build_palette() {
  local file_path="$1"
  declare -A raw

  # Load all key=value pairs
  while IFS='=' read -r key val; do
    raw["$key"]="$val"
  done < <(parse_theme_file "$file_path")

  declare -A palette

  local keys=(
    "bg:background"
    "fg:foreground"
    "black:color0"
    "red:color1"
    "green:color2"
    "yellow:color3"
    "blue:color4"
    "magenta:color5"
    "cyan:color6"
    "white:color7"
    "black_bright:color8"
    "red_bright:color9"
    "green_bright:color10"
    "yellow_bright:color11"
    "blue_bright:color12"
    "magenta_bright:color13"
    "cyan_bright:color14"
    "white_bright:color15"
    "selection_bg:selection_background"
    "active_tab_bg:active_tab_background"
    "inactive_tab_bg:inactive_tab_background"
    "inactive_tab_fg:inactive_tab_foreground"
  )

  for entry in "${keys[@]}"; do
    local internal="${entry%%:*}"
    local source_key="${entry##*:}"
    local hex
    hex=$(normalize_hex "${raw[$source_key]:-}")
    [[ -n "$hex" ]] && palette["$internal"]="$hex"
  done

  # Emit as KEY=VALUE for eval
  for k in "${!palette[@]}"; do
    echo "${k}=${palette[$k]}"
  done
}

# ---------------------------------------------------------------------------
# Apply palette to tmux
# ---------------------------------------------------------------------------

apply_theme() {
  local file_path="${1:-~/.config/kitty/theme.conf}"
  local lightness_pct="${2:-12}"

  declare -A p

  while IFS='=' read -r k v; do
    p["$k"]="$v"
  done < <(build_palette "$file_path")

  local bg="${p[bg]:-}"
  local fg="${p[fg]:-}"

  # Detect light mode
  local light_mode=0
  if [[ -n "$bg" ]] && is_light "$bg"; then
    light_mode=1
  fi

  # Effective background (darkened slightly in light mode for tab surfaces)
  local effective_bg="$bg"
  if [[ "$light_mode" -eq 1 && -n "$bg" ]]; then
    effective_bg=$(darken_hex "$bg" "$lightness_pct")
    effective_bg="${effective_bg:-$bg}"
  fi

  # Tab fallback — first color brighter (or darker in light) than effective_bg
  local tab_fallback
  tab_fallback=$(first_brighter_than_bg \
    "$effective_bg" "$light_mode" \
    "${p[black]}" "${p[black_bright]}" \
    "${p[inactive_tab_bg]}" "${p[inactive_tab_fg]}" \
    "${p[selection_bg]}")

  if [[ -z "$tab_fallback" ]]; then
    tab_fallback=$(first_of "${p[black]}" "${p[inactive_tab_bg]}" "${p[inactive_tab_fg]}" "${p[selection_bg]}")
  fi

  local active_tab_bg
  active_tab_bg=$(first_of "${p[active_tab_bg]}" "$tab_fallback" "$effective_bg")

  # Use the contrast loop to find a legible inactive tab foreground color
  local inactive_tab_fg
  inactive_tab_fg=$(first_brighter_than_bg \
    "$effective_bg" "$light_mode" \
    "${p[inactive_tab_fg]}" \
    "${p[black_bright]}" \
    "${p[white]}" \
    "${p[white_bright]}" \
    "$fg")

  # Fallback to standard foreground if nothing passed the contrast check
  if [[ -z "$inactive_tab_fg" ]]; then
    inactive_tab_fg=$(first_of "$fg" "${p[white]}" "#ffffff")
  fi

  local border_fg
  border_fg=$(first_of "${p[black_bright]}" "$tab_fallback" "$fg")

  local active_border_fg
  active_border_fg=$(first_of "${p[blue]}" "$fg")

  local selection_bg
  selection_bg=$(first_of "${p[selection_bg]}" "$tab_fallback" "$effective_bg")

  # -------------------------------------------------------------------------
  # Apply tmux options
  # -------------------------------------------------------------------------

  # Overall status bar
  [[ -n "$effective_bg" && -n "$fg" ]] &&
    tmux set-option -g status-style "bg=${effective_bg},fg=${fg}"

  # Left/right segments inherit status-style by default; only override if needed
  [[ -n "$effective_bg" && -n "$fg" ]] &&
    tmux set-option -g status-left-style "bg=${effective_bg},fg=${fg}"
  [[ -n "$effective_bg" && -n "$fg" ]] &&
    tmux set-option -g status-right-style "bg=${effective_bg},fg=${fg}"

  # Reset format strings so inline colors from other themes don't override styles
  tmux set-window-option -gu window-status-format
  tmux set-window-option -gu window-status-current-format
  tmux set-window-option -gu window-status-activity-style
  tmux set-window-option -gu window-status-bell-style

  # Inactive window tab
  [[ -n "$effective_bg" && -n "$inactive_tab_fg" ]] &&
    tmux set-option -g window-status-style "bg=${effective_bg},fg=${inactive_tab_fg}"

  # Active window tab
  [[ -n "$active_tab_bg" && -n "$fg" ]] &&
    tmux set-option -g window-status-current-style "bg=${active_tab_bg},fg=${fg},bold"

  # Pane borders
  [[ -n "$border_fg" ]] &&
    tmux set-option -g pane-border-style "fg=${border_fg}"
  [[ -n "$active_border_fg" ]] &&
    tmux set-option -g pane-active-border-style "fg=${active_border_fg}"

  # Message / command line
  [[ -n "$effective_bg" && -n "$fg" ]] &&
    tmux set-option -g message-style "bg=${effective_bg},fg=${fg}"
  [[ -n "$effective_bg" && -n "$fg" ]] &&
    tmux set-option -g message-command-style "bg=${effective_bg},fg=${fg}"

  # Copy / selection mode
  [[ -n "$selection_bg" && -n "$fg" ]] &&
    tmux set-option -g mode-style "bg=${selection_bg},fg=${fg},dim"

  # Clock mode color
  [[ -n "${p[blue]}" ]] &&
    tmux set-option -g clock-mode-colour "${p[blue]}"
}

apply_theme "$@"
