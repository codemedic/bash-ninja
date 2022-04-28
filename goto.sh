#!/usr/bin/env bash

# go2 command - love commandline and love bookmarks, this is their love child!
#
# License: Creative Commons License
#          (details available here http://creativecommons.org/licenses/by-sa/3.0/deed.en_US)
# Author: Dino Korah
# URL: https://github.com/codemedic/bash-ninja
#
# Description:
# Helps you navigate through source trees using custome book marks and
# comes complete with auto-complete

[ -t 0 ] || return 0

# version control root and bookmark definitions
: "${go_projects_conf:=$HOME/go_bookmarks.conf}"

# debug prints enabled ?
: "${go_debug:=0}"

# bash debug/xtrace enabled ?
: "${go_bash_debug:=0}"
: "${go_bash_debug_file:="$HOME/go-xtrace.txt"}"

# debug print
__d() {
    [ "$go_debug" -eq 1 ] || {
        # if debug is disables, the pipe form of invocations should still oipe through
        [ -n "$1" ] || cat
        return
    }

    : "${go_debug_syslog_tag:=go2}"

    if [ -n "$1" ]; then
        /usr/bin/logger -t "$go_debug_syslog_tag" -- "$@" </dev/null
    else
        # pipe through mode
        /usr/bin/logger -t "$go_debug_syslog_tag" -s 2>&1 | \
            cut -c"$((${#go_debug_syslog_tag}+2))-"
    fi
}

__go__load_definitions()
{
    # shellcheck disable=SC1090
    source "$go_projects_conf"
}

GoRegexBookmarkName='^[a-zA-Z0-9_]*$'
GoRegexBookmarkSuffix='^(([a-zA-Z0-9_]+)#)(.*)$'

__go__find() {
    if command -v gfind &>/dev/null; then
        gfind "$@"
    else
        find "$@"
    fi
}

__go__get_completions_paths() {
    local bookmark="$1" preserve_prefix="$2" suffix="$3"; shift 3

    local find_completions=1 name_pattern=()

    # e.g cd_root=/
    local bookmark_var="cd_${bookmark}"
    if declare -p "${bookmark_var}" &> /dev/null; then
        local path="${!bookmark_var}" path_offset
        # e.g root#dev/
        if [[ "$suffix" =~ /$ ]] && [ -d "${path}/${suffix}" ]; then
            path_offset="$suffix"
            path="${path}/${path_offset}"
        # If there is a path in the suffix, look only in the closest directory (a level up) if that exists
        # e.g root#dev/sel
        elif [[ "$suffix" == */* ]] && [ -d "${path}/${suffix/%+([^\/])}" ]; then
            # strip out the suffix
            path_offset="${suffix/%+([^\/])}"
            path="${path}/${path_offset}"
            name_pattern=( -name "$(basename "$suffix")*" )
        # a non-empty suffix and has no '/' in it (name pattern cannot have '/' in them)
        elif [ -n "$suffix" ] && [[ "$suffix" != */* ]]; then
            name_pattern=( -name "${suffix}*" )
        elif [ -n "$suffix" ]; then
            find_completions=0
        fi

        if [ "$find_completions" = 1 ] && [ -d "$path" ]; then
            while read -r compl_option; do
                COMPREPLY+=( "${preserve_prefix}${path_offset}${compl_option}" )
            done < <(__go__find -L "$path" -maxdepth 1 -mindepth 1 "${name_pattern[@]}" \( -type d -or -type l -xtype d \) -printf '%P/\n')
        fi
    fi
}

__go__get_completions() {
    __d "param $*"

    local cur=${COMP_WORDS[COMP_CWORD]}
    __d cur: "$cur"

    __go__load_definitions

    # enable extended globs option; restored at the end!
    local saved_opts; saved_opts="$(shopt -p); $(set +o | grep -v history)"
    shopt -s extglob

    [ "${go_bash_debug}" = 0 ] || {
        exec {BASH_XTRACEFD}>"$go_bash_debug_file"
        set -x
    }

    if [[ "$cur" == /* ]]; then
        __go__get_completions_paths root '' "$1"
    elif [[ "$cur" =~ $GoRegexBookmarkSuffix ]]; then
        __go__get_completions_paths "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
    elif [[ "$cur" =~ $GoRegexBookmarkName ]]; then
        # shellcheck disable=SC2086
        for bookmark in ${!cd_*}; do
            [[ "$bookmark" != "cd_${cur}"* ]] || COMPREPLY+=( "${bookmark#cd_}#" )
        done
    fi

    __d "COMPREPLY: ${COMPREPLY[*]}"

    # restore saved shell options
    set +x; # make sure debug is off
    # toggle history around the eval so that it doesn't get added to command-history
    set +o history
    eval "$saved_opts"
    set -o history
}

go2() {
    __d params: "$@"

    __go__load_definitions

    local bookmark;
    local suffix;
    if [ -n "$1" ]; then
        # are we dealing with a bookmark with path suffix
        # bookmark#path/to/some/thing
        if [[ "$1" =~ $GoRegexBookmarkSuffix ]]; then
            bookmark="${1%%#*}"
            suffix="${1#*#}"
        # or if it is path with no bookmark; i.e using the "root" bookmark
        elif [[ "$1" == /* ]]; then
            bookmark=root
            suffix="$1"
        # else assume it is a bookmark name
        elif [[ "$1" =~ $GoRegexBookmarkName ]]; then
            bookmark="$1"
            suffix=''
        fi
    fi

    __d "bookmark: $bookmark"
    local bookmark_var="cd_${bookmark}"
    declare -p "${bookmark_var}" &> /dev/null ||
        echo "Unknown bookmark '${bookmark}'"

    local cd_path="${!bookmark_var}";
    [ -n "$suffix" ] &&
        cd_path="${cd_path}/${suffix}";

    { [ -n "$cd_path" ] && cd "$cd_path"; } ||
        echo "GO path could not be found."
}

go2_add()
{
    local shortcut dir;
    if [ -z "$1" ]; then
        echo Shortcut name not given.
        return 1
    elif ! [[ "$1" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Shortcut name must be a valid bash variable name"
        return 1;
    fi

    shortcut="$1"; shift;
    dir="${1:-$(pwd)}";

    echo "cd_$shortcut=\"$dir\"" >> "${go_projects_conf}";
}

go2_enable_bash_debug() {
    go_bash_debug="${1:-1}"
    echo "Logging xtrace to ${go_bash_debug_file}" 1>&2
}

if ! declare -p __go__script_loaded &>/dev/null; then
    complete -F __go__get_completions -o dirnames -o nospace go2;

    alias goto=go2
    complete -F __go__get_completions -o dirnames -o nospace goto;

    __go__script_loaded=1
fi
