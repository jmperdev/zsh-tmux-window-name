if [[ -n ${__ZSH_TMUX_WINDOW_NAME_COMMON_LOADED-} ]]; then
  return 0
fi

typeset -g __ZSH_TMUX_WINDOW_NAME_COMMON_LOADED=1
typeset -gr __zsh_tmux_window_name_window_original_option='@zsh_tmux_window_name_original'
typeset -gr __zsh_tmux_window_name_pane_running_option='@zsh_tmux_window_name_running'
typeset -gr __zsh_tmux_window_name_pane_command_option='@zsh_tmux_window_name_command'
typeset -gr __zsh_tmux_window_name_field_separator=$'\x1f'

__zsh_tmux_window_name_state() {
  emulate -L zsh

  local target="$1"
  local separator="$__zsh_tmux_window_name_field_separator"

  tmux display-message -p -t "$target" "#{window_id}${separator}#{window_name}${separator}#{${__zsh_tmux_window_name_window_original_option}}${separator}#{P:#{${__zsh_tmux_window_name_pane_running_option}},#{${__zsh_tmux_window_name_pane_running_option}}}${separator}#{P:#{${__zsh_tmux_window_name_pane_running_option}},}${separator}#{P:,#{${__zsh_tmux_window_name_pane_running_option}}}${separator}#{P:,#{${__zsh_tmux_window_name_pane_command_option}}}" 2>/dev/null
}

__zsh_tmux_window_name_refresh() {
  emulate -L zsh

  local window_id="$1"
  local state
  local separator="$__zsh_tmux_window_name_field_separator"
  local current_window_name=''
  local original_window_name=''
  local all_running_flags=''
  local active_pane_running=''
  local active_pane_command=''
  local desired_window_name=''
  local -a tmux_args

  [[ -n $window_id ]] || return 1

  state="$(__zsh_tmux_window_name_state "$window_id")" || return 1
  [[ -n $state ]] || return 1
  IFS="$separator" read -r _ current_window_name original_window_name all_running_flags _ active_pane_running active_pane_command <<< "$state"

  if [[ $active_pane_running == 1 && -n $active_pane_command ]]; then
    desired_window_name="$active_pane_command"
  elif [[ -n $original_window_name ]]; then
    desired_window_name="$original_window_name"
  fi

  if [[ -n $desired_window_name && $desired_window_name != $current_window_name ]]; then
    tmux_args+=(rename-window -t "$window_id" "$desired_window_name")
  fi

  if [[ $all_running_flags != *1* && -n $original_window_name ]]; then
    (( ${#tmux_args} )) && tmux_args+=(\;)
    tmux_args+=(set-option -wuq -t "$window_id" "$__zsh_tmux_window_name_window_original_option")
  fi

  (( ${#tmux_args} )) || return 0

  tmux "${tmux_args[@]}" >/dev/null 2>&1
}
