if [[ -n ${__ZSH_TMUX_WINDOW_NAME_PLUGIN_LOADED-} ]]; then
  return 0
fi

typeset -g __ZSH_TMUX_WINDOW_NAME_PLUGIN_LOADED=1
typeset -gr __zsh_tmux_window_name_plugin_dir=${${(%):-%N}:A:h}
typeset -gr __zsh_tmux_window_name_refresh_script="$__zsh_tmux_window_name_plugin_dir/bin/tmux-window-name-refresh"
source "$__zsh_tmux_window_name_plugin_dir/lib/zsh-tmux-window-name-common.zsh"

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

__zsh_tmux_window_name_install_tmux_hooks() {
  emulate -L zsh

  local selection_hook_shell
  local event_hook_shell
  local quoted_script
  local quoted_current_window
  local quoted_hook_window

  quoted_script="$(__zsh_tmux_window_name_shell_quote "$__zsh_tmux_window_name_refresh_script")"
  quoted_current_window="$(__zsh_tmux_window_name_shell_quote '#{window_id}')"
  quoted_hook_window="$(__zsh_tmux_window_name_shell_quote '#{hook_window}')"
  selection_hook_shell="${quoted_script} ${quoted_current_window}"
  event_hook_shell="${quoted_script} ${quoted_hook_window}"

  tmux set-hook -g "after-select-pane[9000]" "run-shell \"${selection_hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "after-select-window[9000]" "run-shell \"${selection_hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "pane-exited[9000]" "run-shell \"${event_hook_shell}\"" >/dev/null 2>&1
  tmux set-hook -g "after-kill-pane[9000]" "run-shell \"${event_hook_shell}\"" >/dev/null 2>&1
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
  local next_name state window_id current_name original_name
  local separator="$__zsh_tmux_window_name_field_separator"
  local -a tmux_args

  next_name="$(__zsh_tmux_window_name_parse "$line")" || return 0
  [[ -n $next_name ]] || return 0
  __zsh_tmux_window_name_is_ignored_command "$next_name" && return 0

  state="$(__zsh_tmux_window_name_window_state "$TMUX_PANE")" || return 0
  [[ -n $state ]] || return 0
  IFS="$separator" read -r window_id current_name original_name <<< "$state"
  [[ -n $window_id ]] || return 0

  if [[ -z $original_name && -n $current_name ]]; then
    tmux_args+=(set-option -wq -t "$window_id" "$__zsh_tmux_window_name_window_original_option" "$current_name" \;)
  fi

  tmux_args+=(set-option -pq -t "$TMUX_PANE" "$__zsh_tmux_window_name_pane_command_option" "$next_name" \;)
  tmux_args+=(set-option -pq -t "$TMUX_PANE" "$__zsh_tmux_window_name_pane_running_option" 1)
  tmux "${tmux_args[@]}" >/dev/null 2>&1
  __zsh_tmux_window_name_refresh "$window_id"
}

__zsh_tmux_window_name_precmd() {
  emulate -L zsh

  __zsh_tmux_window_name_should_run || return 0

  local window_id
  local state
  local separator="$__zsh_tmux_window_name_field_separator"

  state="$(__zsh_tmux_window_name_window_state "$TMUX_PANE")" || return 0
  [[ -n $state ]] || return 0
  IFS="$separator" read -r window_id _ <<< "$state"
  [[ -n $window_id ]] || return 0

  tmux set-option -puq -t "$TMUX_PANE" "$__zsh_tmux_window_name_pane_command_option" \; \
    set-option -puq -t "$TMUX_PANE" "$__zsh_tmux_window_name_pane_running_option" >/dev/null 2>&1
  __zsh_tmux_window_name_refresh "$window_id"
}

if __zsh_tmux_window_name_should_run; then
  __zsh_tmux_window_name_install_tmux_hooks
fi

autoload -Uz add-zsh-hook
add-zsh-hook preexec __zsh_tmux_window_name_preexec
add-zsh-hook precmd __zsh_tmux_window_name_precmd
