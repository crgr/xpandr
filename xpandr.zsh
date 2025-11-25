# xpandr Zsh integration
# Requires `xpandr` binary to be on $PATH.

# Cursor marker inside expansions
: ${XPANDR_CURSOR_MARKER:="%|"}

# Associative array: SHORT trigger -> expansion
typeset -gA XPANDR_MAP

# State: whether the last expansion used a cursor marker
typeset -g XPANDR_CURSOR_MARKER_USED

# Load triggers from `xpandr dump` into XPANDR_MAP
xpandr_load() {
  XPANDR_MAP=()
  local key val
  # dump format: SHORT<TAB>EXPANSION
  while IFS=$'\t' read -r key val; do
    [[ -z $key ]] && continue
    XPANDR_MAP[$key]=$val
  done < <(xpandr dump 2>/dev/null)
}

# Initial load at shell start
xpandr_load

# Expand the shortest suffix at the end of $LBUFFER that matches a trigger.
# Supports:
#   - two-word SHORTs, like "git cm"
#   - single-word SHORTs, like "gc"
xpandr_expand_word() {
  XPANDR_CURSOR_MARKER_USED=
  local word1 word2 trigger expanded before after
  local orig_L=$LBUFFER orig_R=$RBUFFER
  local prefix

  # Last word
  word1=${LBUFFER##*[[:space:]]}
  [[ -z $word1 ]] && return 1

  # Try two-word SHORT first: "word2 word1"
  if [[ $LBUFFER == *[[:space:]]$word1 ]]; then
    # Remove the last word1 and any whitespace before it to find word2
    local tmp=${LBUFFER%$word1}
    tmp=${tmp%[[:space:]]}
    if [[ -n $tmp ]]; then
      word2=${tmp##*[[:space:]]}
      local phrase="$word2 $word1"
      if [[ -n ${XPANDR_MAP[$phrase]+_} ]]; then
        # Check that phrase really is the end of LBUFFER (with a single space)
        prefix=${LBUFFER%$phrase}
        if [[ "$prefix$phrase" == "$LBUFFER" ]]; then
          trigger=$phrase
        fi
      fi
    fi
  fi

  # If no 2-word trigger, fall back to 1-word
  if [[ -z $trigger ]]; then
    if [[ -z ${XPANDR_MAP[$word1]+_} ]]; then
      return 1
    fi
    trigger=$word1
    prefix=${LBUFFER%$trigger}
    if [[ "$prefix$trigger" != "$LBUFFER" ]]; then
      # Shouldn't happen in normal use; bail out instead of mangling the line
      return 1
    fi
  fi

  expanded=${XPANDR_MAP[$trigger]}
  [[ -z $expanded ]] && return 1

  # Handle cursor marker inside the expansion
  if [[ "$expanded" == *"$XPANDR_CURSOR_MARKER"* ]]; then
    XPANDR_CURSOR_MARKER_USED=1
    before=${expanded%%"$XPANDR_CURSOR_MARKER"*}
    after=${expanded#*"$XPANDR_CURSOR_MARKER"}
    LBUFFER="${prefix}${before}"
    RBUFFER="${after}${orig_R}"
  else
    # No marker: just replace the trigger, keep RBUFFER unchanged
    LBUFFER="${prefix}${expanded}"
  fi

  return 0
}

# Widget: expand then (maybe) insert the key pressed (space).
xpandr_space_widget() {
  local old_L=$LBUFFER old_R=$RBUFFER
  xpandr_expand_word
  local did_expand=$?

  # If nothing expanded, behave like a normal space.
  if (( did_expand != 0 )); then
    LBUFFER+="$KEYS"
    return
  fi

  # If we expanded but *did not* use a cursor marker, insert a space.
  # If a cursor marker was used, respect the explicit cursor position.
  if [[ -z $XPANDR_CURSOR_MARKER_USED ]]; then
    LBUFFER+="$KEYS"
  fi
}

# Widget: expand then accept the line (Enter).
xpandr_enter_widget() {
  xpandr_expand_word
  zle accept-line
}

# Register widgets with ZLE.
zle -N xpandr_space_widget
zle -N xpandr_enter_widget

# Default keybindings:
#   Space  -> expand then insert space
#   Enter  -> expand then accept line
bindkey ' '  xpandr_space_widget
bindkey '^M' xpandr_enter_widget

# Escape hatches:
#   Ctrl-J        -> accept the line as-is (no expansion)
#   Ctrl-X Space  -> insert plain space (no expansion)
bindkey '^J'  accept-line
bindkey '^X ' magic-space

# Optional wrapper: reload triggers after add/rm in this shell
xpandr_cmd() {
  command xpandr "$@"
  case "$1" in
    add|rm)
      xpandr_load
      ;;
  esac
}

alias xpandr=xpandr_cmd
