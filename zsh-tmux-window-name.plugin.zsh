if [[ -n ${__ZSH_TMUX_WINDOW_NAME_PLUGIN_LOADED-} ]]; then
  return 0
fi

typeset -g __ZSH_TMUX_WINDOW_NAME_PLUGIN_LOADED=1
typeset -gr __zsh_tmux_window_name_plugin_dir=${${(%):-%N}:A:h}
typeset -gr __zsh_tmux_window_name_refresh_script="$__zsh_tmux_window_name_plugin_dir/bin/tmux-window-name-refresh"
typeset -gr __zsh_tmux_window_name_window_original_option='@zsh_tmux_window_name_original'
typeset -gr __zsh_tmux_window_name_pane_running_option='@zsh_tmux_window_name_running'
typeset -gr __zsh_tmux_window_name_pane_command_option='@zsh_tmux_window_name_command'

__zsh_tmux_window_name_should_run() {
  [[ -o interactive ]] || return 1
  [[ -n ${TMUX-} ]] || return 1
  (( ${+commands[tmux]} )) || return 1
  [[ -x $__zsh_tmux_window_name_refresh_script ]] || return 1
  return 0
}

__zsh_tmux_window_name_shell_quote() {
  emulate -L zsh

  local value="$1"
  value=${value//\'/\'\\\'\'}
  print -r -- "'$value'"
}

__zsh_tmux_window_name_window_id() {
  emulate -L zsh

  tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null
}

__zsh_tmux_window_name_window_name() {
  emulate -L zsh

  tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null
}

__zsh_tmux_window_name_set_window_option() {
  emulate -L zsh

  local window_id="$1"
  local option_name="$2"
  local option_value="$3"

  tmux set-option -wq -t "$window_id" "$option_name" "$option_value" >/dev/null 2>&1
}

__zsh_tmux_window_name_show_window_option() {
  emulate -L zsh

  local window_id="$1"
  local option_name="$2"

  tmux show-options -wqv -t "$window_id" "$option_name" 2>/dev/null
}

__zsh_tmux_window_name_set_pane_option() {
  emulate -L zsh

  local option_name="$1"
  local option_value="$2"

  tmux set-option -pq -t "$TMUX_PANE" "$option_name" "$option_value" >/dev/null 2>&1
}

__zsh_tmux_window_name_unset_pane_option() {
  emulate -L zsh

  local option_name="$1"

  tmux set-option -puq -t "$TMUX_PANE" "$option_name" >/dev/null 2>&1
}

__zsh_tmux_window_name_refresh() {
  emulate -L zsh

  local window_id="$1"
  [[ -n $window_id ]] || return 1

  "$__zsh_tmux_window_name_refresh_script" "$window_id" >/dev/null 2>&1
}

__zsh_tmux_window_name_install_tmux_hooks() {
  emulate -L zsh

  local hook_shell
  local quoted_script
  local quoted_window

  quoted_script="$(__zsh_tmux_window_name_shell_quote "$__zsh_tmux_window_name_refresh_script")"
  quoted_window="$(__zsh_tmux_window_name_shell_quote '#{hook_window}')"
  hook_shell="${quoted_script} ${quoted_window}"

  tmux set-hook -g "after-select-pane[9000]" "run-shell \"${hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "after-select-window[9000]" "run-shell \"${hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "pane-exited[9000]" "run-shell \"${hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "after-kill-pane[9000]" "run-shell \"${hook_shell}\"" >/dev/null 2>&1
}

__zsh_tmux_window_name_is_ignored_command() {
  emulate -L zsh

  local word="$1"
  case "$word" in
    exit|logout)
      return 0
      ;;
  esac

  return 1
}

__zsh_tmux_window_name_is_assignment() {
  emulate -L zsh

  local word="$1"
  [[ $word == [A-Za-z_][A-Za-z0-9_]*=* ]]
}

__zsh_tmux_window_name_is_control_operator() {
  emulate -L zsh

  local word="$1"
  case "$word" in
    '|'|'||'|'|&'|'&&'|';'|'&')
      return 0
      ;;
  esac

  return 1
}

__zsh_tmux_window_name_parse() {
  emulate -L zsh

  local line="$1"
  local -a words
  local index=1
  local word

  words=(${(z)line})
  (( ${#words} )) || return 1

  while (( index <= ${#words} )); do
    word=${words[index]}

    if __zsh_tmux_window_name_is_control_operator "$word"; then
      break
    fi

    if __zsh_tmux_window_name_is_assignment "$word"; then
      (( index++ ))
      continue
    fi

    if [[ $word == sudo ]]; then
      (( index++ ))

      while (( index <= ${#words} )); do
        word=${words[index]}
        case "$word" in
          --)
            (( index++ ))
            break
            ;;
          --user|--group|--host|--prompt|--chroot|--role|--type|--other-user)
            (( index += 2 ))
            ;;
          --user=*|--group=*|--host=*|--prompt=*|--chroot=*|--role=*|--type=*|--other-user=*)
            (( index++ ))
            ;;
          -u|-g|-h|-p|-C|-T|-R|-t|-r)
            (( index += 2 ))
            ;;
          -u*|-g*|-h*|-p*|-C*|-T*|-R*|-t*|-r*)
            (( index++ ))
            ;;
          -*)
            (( index++ ))
            ;;
          *)
            break
            ;;
        esac
      done

      continue
    fi

    if [[ $word == env ]]; then
      (( index++ ))

      while (( index <= ${#words} )); do
        word=${words[index]}
        case "$word" in
          --)
            (( index++ ))
            break
            ;;
          -u|-S|-C)
            (( index += 2 ))
            ;;
          -u*|-S*|-C*)
            (( index++ ))
            ;;
          -*)
            (( index++ ))
            ;;
          *)
            if __zsh_tmux_window_name_is_assignment "$word"; then
              (( index++ ))
              continue
            fi
            break
            ;;
        esac
      done

      continue
    fi

    print -r -- "$word"
    return 0
  done

  return 1
}

__zsh_tmux_window_name_preexec() {
  emulate -L zsh

  __zsh_tmux_window_name_should_run || return 0

  local line="$1"
  local next_name window_id original_name current_name

  next_name="$(__zsh_tmux_window_name_parse "$line")" || return 0
  [[ -n $next_name ]] || return 0
  __zsh_tmux_window_name_is_ignored_command "$next_name" && return 0

  window_id="$(__zsh_tmux_window_name_window_id)" || return 0
  [[ -n $window_id ]] || return 0

  original_name="$(__zsh_tmux_window_name_show_window_option "$window_id" "$__zsh_tmux_window_name_window_original_option")"
  if [[ -z $original_name ]]; then
    current_name="$(__zsh_tmux_window_name_window_name)" || return 0
    [[ -n $current_name ]] || return 0
    __zsh_tmux_window_name_set_window_option "$window_id" "$__zsh_tmux_window_name_window_original_option" "$current_name"
  fi

  __zsh_tmux_window_name_set_pane_option "$__zsh_tmux_window_name_pane_command_option" "$next_name"
  __zsh_tmux_window_name_set_pane_option "$__zsh_tmux_window_name_pane_running_option" 1
  __zsh_tmux_window_name_refresh "$window_id"
}

__zsh_tmux_window_name_precmd() {
  emulate -L zsh

  __zsh_tmux_window_name_should_run || return 0

  local window_id

  window_id="$(__zsh_tmux_window_name_window_id)" || return 0
  [[ -n $window_id ]] || return 0

  __zsh_tmux_window_name_unset_pane_option "$__zsh_tmux_window_name_pane_command_option"
  __zsh_tmux_window_name_unset_pane_option "$__zsh_tmux_window_name_pane_running_option"
  __zsh_tmux_window_name_refresh "$window_id"
}

if __zsh_tmux_window_name_should_run; then
  __zsh_tmux_window_name_install_tmux_hooks
fi

autoload -Uz add-zsh-hook
add-zsh-hook preexec __zsh_tmux_window_name_preexec
add-zsh-hook precmd __zsh_tmux_window_name_precmd
