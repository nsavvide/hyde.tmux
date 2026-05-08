# hyde-tmux

`hyde-tmux` keeps tmux in sync with your [HyDE](https://github.com/hyde-project/hyde) setup. It reads your Kitty theme file and applies the colors to tmux's status bar, pane borders, and mode highlights — the same source of truth as `hyde.nvim`.

It also detects whether your Kitty background is light or dark and picks appropriate fallback surface colors automatically.

## Requirements

- `bash` 4+
- `awk`
- `inotifywait` (optional, from `inotify-tools`) — used for efficient file watching; falls back to polling if unavailable

## Installation

### TPM

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'nsavvide/hyde.tmux'
```

Then press `prefix + I` to install.

### Manual

Clone the repo and source the entry point from `~/.tmux.conf`:

```tmux
run-shell /path/to/hyde-tmux/hyde.tmux
```

## Minimal Config

No configuration needed. The plugin reads `~/.config/kitty/theme.conf` by default and applies colors on tmux startup, then watches for changes.

```tmux
run-shell /path/to/hyde-tmux/hyde.tmux
```

## Full Config

All options are set as tmux options before sourcing the plugin:

```tmux
# Path to the Kitty theme file to read colors from.
set -g @hyde_file_path "~/.config/kitty/theme.conf"

# Watch the theme file and re-apply on change ("on" / "off").
set -g @hyde_watch "on"

# Seconds to wait after a file change before re-applying.
set -g @hyde_debounce "1"

# How much to darken the background in light mode (0-100).
set -g @hyde_lightness_pct "12"

run-shell /path/to/hyde-tmux/hyde.tmux
```

## What Gets Styled

| tmux option                   | Source color                                        |
| ----------------------------- | --------------------------------------------------- |
| `status-style`                | `background` / `foreground`                         |
| `status-left-style`           | `background` / `foreground`                         |
| `status-right-style`          | `background` / `foreground`                         |
| `window-status-style`         | `background` / inactive tab foreground              |
| `window-status-current-style` | `active_tab_background` / `foreground`              |
| `pane-border-style`           | `color8` (bright black)                             |
| `pane-active-border-style`    | `color4` (blue)                                     |
| `message-style`               | `background` / `foreground`                         |
| `message-command-style`       | `background` / `foreground`                         |
| `mode-style`                  | `selection_background` / `foreground`               |
| `clock-mode-colour`           | `color4` (blue)                                     |

## Light Mode

When the plugin detects a light Kitty background (relative luminance ≥ 0.5):

- The effective background is darkened by `@hyde_lightness_pct` percent to give tabs and borders visible contrast.
- The tab fallback color is picked from the first color that is *darker* than the effective background.

## Color Mapping

Colors are read from the Kitty theme file using the standard 16-color terminal palette keys:

| Internal     | Kitty key                   |
| ------------ | --------------------------- |
| `bg`         | `background`                |
| `fg`         | `foreground`                |
| `black`      | `color0`                    |
| `red`        | `color1`                    |
| `green`      | `color2`                    |
| `yellow`     | `color3`                    |
| `blue`       | `color4`                    |
| `magenta`    | `color5`                    |
| `cyan`       | `color6`                    |
| `white`      | `color7`                    |
| `black_bright`    | `color8`               |
| `red_bright`      | `color9`               |
| `green_bright`    | `color10`              |
| `yellow_bright`   | `color11`              |
| `blue_bright`     | `color12`              |
| `magenta_bright`  | `color13`              |
| `cyan_bright`     | `color14`              |
| `white_bright`    | `color15`              |
| `selection_bg`    | `selection_background` |
| `active_tab_bg`   | `active_tab_background`|
| `inactive_tab_bg` | `inactive_tab_background`|
| `inactive_tab_fg` | `inactive_tab_foreground`|

# Credits

[Hyde.nvim](https://github.com/iamharshdabas/hyde.nvim)

