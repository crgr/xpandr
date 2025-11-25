# xpandr Bash integration
# Requires `xpandr` on $PATH.
# Source this from your ~/.bashrc:
#   source /path/to/xpandr.sh

# If xpandr is not available, do nothing.
if ! command -v xpandr >/dev/null 2>&1; then
    return 0 2>/dev/null || true
fi

: "${XPANDR_CURSOR_MARKER:='%|'}"
XPANDR_CURSOR_MARKER_USED=

# Expand the last SHORT trigger at the end of the line.
# SHORT can be:
#   - a single word (e.g. "gc")
#   - or two words separated by a space (e.g. "git cm")
_xpandr_expand_trigger() {
    XPANDR_CURSOR_MARKER_USED=

    local line=$READLINE_LINE
    local point=$READLINE_POINT
    local left=${line:0:point}
    local right=${line:point}

    local word1 word2 tmp phrase trigger expanded prefix

    # Last word
    if [[ $left =~ [[:space:]] ]]; then
        word1=${left##*[[:space:]]}
    else
        word1=$left
    fi

    [[ -z $word1 ]] && return 1

    # Try two-word trigger "word2 word1" first
    if [[ $left =~ [[:space:]]$word1$ ]]; then
        tmp=${left%$word1}
        tmp=${tmp%[[:space:]]}
        if [[ -n $tmp ]]; then
            if [[ $tmp =~ [[:space:]] ]]; then
                word2=${tmp##*[[:space:]]}
            else
                word2=$tmp
            fi
        fi
    fi

    trigger=""
    if [[ -n $word2 ]]; then
        phrase="$word2 $word1"
        expanded=$(xpandr expand -- "$phrase" 2>/dev/null) || return 1
        if [[ "$expanded" != "$phrase" ]]; then
            trigger="$phrase"
        fi
    fi

    # Fallback to single-word trigger
    if [[ -z $trigger ]]; then
        expanded=$(xpandr expand -- "$word1" 2>/dev/null) || return 1
        if [[ "$expanded" == "$word1" ]]; then
            return 1
        fi
        trigger="$word1"
    fi

    # Compute prefix from left by stripping the trigger
    prefix=${left%$trigger}
    if [[ "$prefix$trigger" != "$left" ]]; then
        # Pattern mismatch (e.g. weird spacing); bail out safely
        return 1
    fi

    # Handle cursor marker
    if [[ "$expanded" == *"$XPANDR_CURSOR_MARKER"* ]]; then
        XPANDR_CURSOR_MARKER_USED=1
        local pre=${expanded%%"$XPANDR_CURSOR_MARKER"*}
        local post=${expanded#*"$XPANDR_CURSOR_MARKER"}
        READLINE_LINE="${prefix}${pre}${post}${right}"
        READLINE_POINT=$(( ${#prefix} + ${#pre} ))
    else
        READLINE_LINE="${prefix}${expanded}${right}"
        READLINE_POINT=$(( ${#prefix} + ${#expanded} ))
    fi

    return 0
}

# Space key: expand then maybe insert space.
_xpandr_space() {
    local old_line=$READLINE_LINE old_point=$READLINE_POINT

    if _xpandr_expand_trigger; then
        # We did expand
        if [[ -z $XPANDR_CURSOR_MARKER_USED ]]; then
            READLINE_LINE="${READLINE_LINE:0:READLINE_POINT} ${READLINE_LINE:READLINE_POINT}"
            READLINE_POINT=$((READLINE_POINT + 1))
        fi
    else
        # No expansion; just insert a space
        READLINE_LINE="${old_line:0:old_point} ${old_line:old_point}"
        READLINE_POINT=$((old_point + 1))
    fi
}

# Enter key: expand then let Readline accept the line.
_xpandr_enter() {
    _xpandr_expand_trigger || true
    # After this function returns, Readline will accept the (possibly modified) line.
}

# Keybindings:
#   Space        -> _xpandr_space
#   Enter (^M)   -> _xpandr_enter
#   Ctrl-J       -> accept-line (no xpandr)
#   Ctrl-X Space -> plain space (no xpandr)
bind -x '" ":"_xpandr_space"'
bind -x '"\C-m":"_xpandr_enter"'
bind '"\C-j":"accept-line"'
bind '"\C-x ":" "'
