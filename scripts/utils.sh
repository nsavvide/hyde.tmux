#!/usr/bin/env bash

# Parse a key=value or "key value" file, skipping comments and blank lines.
# Usage: parse_theme_file <path>
# Outputs: key=value lines to stdout
parse_theme_file() {
  local path="$1"
  local expanded="${path/#\~/$HOME}"

  [[ ! -f "$expanded" ]] && return 1

  while IFS= read -r line; do
    # Strip leading whitespace
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    # Skip blank lines and comment lines
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    local key="" val=""

    # Try "key=value" form
    if [[ "$trimmed" =~ ^([A-Za-z0-9_./-]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
    # Try "key value" form (space-separated, kitty style)
    elif [[ "$trimmed" =~ ^([A-Za-z0-9_./-]+)[[:space:]]+([^[:space:]].*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
    fi

    [[ -z "$key" ]] && continue

    # Strip trailing inline comment: only when comment is preceded by whitespace
    # and the value so far is not itself a bare "#xxxxxx" hex token
    # We do this by checking if there's a " #" or "\t#" with content before it
    if [[ "$val" =~ ^(.+)[[:space:]]#.*$ ]]; then
      local candidate="${BASH_REMATCH[1]}"
      # Trim trailing whitespace from candidate
      candidate="${candidate%"${candidate##*[![:space:]]}"}"
      [[ -n "$candidate" ]] && val="$candidate"
    fi

    # Trim trailing whitespace from value
    val="${val%"${val##*[![:space:]]}"}"

    [[ -n "$val" ]] && echo "${key}=${val}"
  done < "$expanded"
}

# Normalize a hex color: strip leading #, lowercase, add # prefix.
# Returns empty string if not a valid hex color.
normalize_hex() {
  local val="${1#\#}"
  val="${val,,}"
  if [[ "$val" =~ ^[0-9a-f]{3}$|^[0-9a-f]{6}$ ]]; then
    echo "#$val"
  fi
}

# Relative luminance of a hex color (0-1).
relative_luminance() {
  local hex="${1#\#}"
  if [[ ${#hex} -eq 3 ]]; then
    hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
  fi
  [[ ${#hex} -ne 6 ]] && echo "0" && return
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  awk -v r="$r" -v g="$g" -v b="$b" '
    function lin(c,    v) {
      v = c / 255
      return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4
    }
    BEGIN { printf "%.6f\n", 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b) }
  '
}

# Returns 0 (success/true) if the hex color is a light background.
is_light() {
  local lum
  lum=$(relative_luminance "$1")
  awk -v l="$lum" 'BEGIN { exit (l >= 0.5) ? 0 : 1 }'
}

# Brighten a hex color by a percentage (0-100).
brighten_hex() {
  local hex="${1#\#}"
  local pct="${2:-10}"
  if [[ ${#hex} -eq 3 ]]; then
    hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
  fi
  [[ ${#hex} -ne 6 ]] && echo "#$hex" && return
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  awk -v r="$r" -v g="$g" -v b="$b" -v p="$pct" '
    function clamp(v) { return (v<0)?0:(v>255)?255:v }
    BEGIN {
      ratio = 1 + p/100
      printf "#%02x%02x%02x\n", clamp(int(r*ratio+0.5)), clamp(int(g*ratio+0.5)), clamp(int(b*ratio+0.5))
    }
  '
}

# Darken a hex color by a percentage (0-100).
darken_hex() {
  local hex="${1#\#}"
  local pct="${2:-10}"
  if [[ ${#hex} -eq 3 ]]; then
    hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
  fi
  [[ ${#hex} -ne 6 ]] && echo "#$hex" && return
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  awk -v r="$r" -v g="$g" -v b="$b" -v p="$pct" '
    function clamp(v) { return (v<0)?0:(v>255)?255:v }
    BEGIN {
      ratio = 1 - p/100
      printf "#%02x%02x%02x\n", clamp(int(r*ratio+0.5)), clamp(int(g*ratio+0.5)), clamp(int(b*ratio+0.5))
    }
  '
}

# Pick the first non-empty argument.
first_of() {
  local val
  for val in "$@"; do
    [[ -n "$val" ]] && echo "$val" && return
  done
}

# Mean channel delta between two hex colors (positive = color is brighter).
mean_channel_delta() {
  local c="${1#\#}" b="${2#\#}"
  if [[ ${#c} -eq 3 ]]; then c="${c:0:1}${c:0:1}${c:1:1}${c:1:1}${c:2:1}${c:2:1}"; fi
  if [[ ${#b} -eq 3 ]]; then b="${b:0:1}${b:0:1}${b:1:1}${b:1:1}${b:2:1}${b:2:1}"; fi
  [[ ${#c} -ne 6 || ${#b} -ne 6 ]] && echo "0" && return
  awk -v cr=$((16#${c:0:2})) -v cg=$((16#${c:2:2})) -v cb=$((16#${c:4:2})) \
      -v br=$((16#${b:0:2})) -v bg_r=$((16#${b:2:2})) -v bb=$((16#${b:4:2})) \
    'BEGIN { printf "%.2f\n", ((cr-br)+(cg-bg_r)+(cb-bb))/3 }'
}

# Find first color with enough contrast against bg.
# Usage: first_brighter_than_bg <bg_hex> <light_mode:0|1> <color1> [color2 ...]
first_brighter_than_bg() {
  local bg="$1" light="$2"
  shift 2
  local color delta
  local threshold=40 # Minimum contrast difference required
  for color in "$@"; do
    [[ -z "$color" ]] && continue
    delta=$(mean_channel_delta "$color" "$bg")
    if [[ "$light" -eq 1 ]]; then
      # In light mode, color must be significantly darker
      awk -v d="$delta" -v t="-$threshold" 'BEGIN { exit (d < t) ? 0 : 1 }' && echo "$color" && return
    else
      # In dark mode, color must be significantly brighter
      awk -v d="$delta" -v t="$threshold" 'BEGIN { exit (d > t) ? 0 : 1 }' && echo "$color" && return
    fi
  done
}
