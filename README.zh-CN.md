# zsh-tmux-window-name

一个给 tmux window 自动命名的 zsh 插件。它显示的是你实际输入的命令，而不是底层真实进程名。

在 macOS 上，tmux 的自动命名经常会根据实际执行的程序来命名。像 `codex` 这种工具，最终可能显示成 `node`。这个插件改用 zsh hook 来处理：

- 命令开始执行前，把当前 tmux window 临时改成你输入的命令名
- shell 回到提示符后，恢复执行前的 window 标题
- 如果一个 window 里有多个 pane，则由当前 active pane 决定此刻 window 标题该显示什么

这意味着：

- 输入 `codex`，显示 `codex`
- 输入 `sudo codex`，仍然显示 `codex`
- 输入 `env FOO=1 codex`，仍然显示 `codex`
- 如果你之前手动改过 window 标题，命令结束后会恢复成你原来的标题
- 多 pane 场景下，切换到正在运行命令的 pane，会显示该 pane 的命令；切换到空闲 pane，会恢复原标题

## 依赖

- zsh
- tmux
- Oh My Zsh 风格的插件加载方式

## 安装

把当前仓库放到 Oh My Zsh 的自定义插件目录，或者建立软链：

```sh
ln -s /path/to/zsh-tmux-window-name \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-tmux-window-name
```

然后在 `.zshrc` 的 `plugins=(...)` 中加入：

```sh
plugins=(
  # ...
  zsh-tmux-window-name
)
```

重新加载 shell：

```sh
source ~/.zshrc
```

## tmux 配置

这个插件依赖 tmux 的 window rename 和 tmux hook。请在 `.tmux.conf` 中加入：

```tmux
set -g automatic-rename off
```

然后重新加载 tmux 配置：

```sh
tmux source-file ~/.tmux.conf
```

## 行为说明

- 只在 tmux 内生效
- 从 zsh 命令行里提取“第一个真正执行的命令词”
- 会跳过前置环境变量赋值，例如 `FOO=1`
- 支持处理 `sudo` 和 `env` 前缀
- 会忽略 `exit` 和 `logout`，所以关闭 pane 时不会先把标题改成 `exit`
- 命令结束后恢复执行前的 tmux window 标题
- 多 pane window 中，可见标题由当前 active pane 决定
- 如果当前 active pane 是空闲的，即使别的 pane 还在跑命令，也会显示原标题

对于 `codex | jq .`、`codex && echo ok` 这类复合命令，标题会取整行里的第一个命令。
