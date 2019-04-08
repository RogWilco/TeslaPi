# ============================================================================
# Imports
# ============================================================================
source ~/.commonrc

# ============================================================================
# Tweaks
# ============================================================================
shopt -s checkwinsize   # Fix text wrapping on resized windows.

source ~/.git-prompt.sh
source ~/.git-completion.sh

export PS1_PRE="$NM[ $HI\u $HII\h $SI\w$NM ] "
export PS1_POST="$ $IN"

# Customized Prompt
export PROMPT_COMMAND='__git_ps1 "$PS1_PRE" "$(__svn_ps1)$PS1_POST"'

# ============================================================================
# Command History
# ============================================================================
export HISTFILESIZE=10240                   # Increases history filesize.
export HISTSIZE=10240                       # Increases maximum history items.
export HISTIGNORE="[bf]g:[ ]*:exit:??"      # Ignores common commands.
export HISTCONTROL=erasedups                # Doesn't log duplicates.

# Saves command history for all terminals.
shopt -s histappend
export PROMPT_COMMAND="$PROMPT_COMMAND; history -a"

# ============================================================================
# Bindings
# ============================================================================
bind "set completion-ignore-case on"    # Case-insensitive tab completion.

# ============================================================================
# Functions
# ============================================================================

# Replace target file/directory with a symlink pointing to the
# file/directory's new location (and move it there).
function swink() {
    TARGET=${1}
    DEST=${2}

    if [[ -d "${DEST}" && -f "${TARGET}" ]]; then
        mv "${TARGET}" "${DEST}"
        ln -s $(echo "${DEST}/${TARGET}" | sed s#//*#/#g) "${TARGET}"
    else
        mv "${TARGET}" "${DEST}"
        ln -s "${DEST}" "${TARGET}"
    fi
}

# Creates a symlink, overwriting an existing one if present.
function lln() {
    rm ${2}
    ln -s ${1} ${2}
}

cdl() {
    cd $(dirname $(readlink $1));
}

# ============================================================================
# Miscellaneous
# ============================================================================

eval "$(direnv hook bash)"
