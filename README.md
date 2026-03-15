# zsh-tmux-window-name

Zsh plugin for tmux window names based on the command you typed, not the underlying process name.

中文说明见 [README.zh-CN.md](README.zh-CN.md)。

On macOS, tmux automatic naming often ends up showing the executable that is actually running. For tools like `codex`, that can mean the window title becomes `node`. This plugin uses zsh hooks instead:

- Right before a command runs, it renames the current tmux window to the command you typed.
- When the shell returns to the prompt, it restores the previous window title.
- If a tmux window has multiple panes, the active pane decides what the window title should show.

That means:

- `codex` shows `codex`
- `sudo codex` still shows `codex`
- `env FOO=1 codex` still shows `codex`
- If you manually renamed the window before running a command, that custom title comes back after the command finishes
- In a multi-pane window, switching focus to a running pane shows that pane's command; switching to an idle pane restores the original title

## Requirements

- zsh
- tmux
- Oh My Zsh style plugin loading

## Install

Place this repository in your Oh My Zsh custom plugins directory, or symlink it there:

```sh
ln -s /path/to/zsh-tmux-window-name \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-tmux-window-name
```

Add it to your `plugins=(...)` list in `.zshrc`:

```sh
plugins=(
  # ...
  zsh-tmux-window-name
)
```

Reload your shell:

```sh
source ~/.zshrc
```

## tmux Config

This plugin relies on tmux window renames and tmux hooks. Add this to `.tmux.conf`:

```tmux
set -g automatic-rename off
```

Reload tmux config:

```sh
tmux source-file ~/.tmux.conf
```

## Behavior

- Only runs inside tmux
- Uses the first real command word from the zsh command line
- Skips leading environment assignments such as `FOO=1`
- Handles `sudo` and `env` prefixes
- Ignores `exit` and `logout`, so closing a pane does not temporarily rename the window to `exit`
- Restores the exact previous tmux window name on the next prompt
- In multi-pane windows, the active pane controls the visible window title
- If the active pane is idle, the original window title is shown even when another pane is still running a command

For compound commands like `codex | jq .` or `codex && echo ok`, the title is based on the first command in the line.
