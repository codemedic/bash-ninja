#!/bin/bash

# Bash Ninja - go command
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

    : "${go_debug_syslog_tag:=rm-go}"

    if [ -n "$1" ]; then
        /usr/bin/logger -t "$go_debug_syslog_tag" -- "$@" </dev/null
    else
        # pipe through mode
        /usr/bin/logger -t "$go_debug_syslog_tag" -s 2>&1 | \
            cut -c"$((${#go_debug_syslog_tag}+2))-"
    fi
}

__go__is_defined()
{
    declare -p "cd_$1" &>/dev/null
}

__go__load_definitions()
{
    # shellcheck disable=SC1090
    source "$go_projects_conf"
}

__go__resolve_definition()
{
    if [ -n "$1" ]; then
        __go__is_defined "$1" &&
            eval "echo \$cd_${1}"/;
    else
        echo "${cd_root:-}/"
    fi
}

GoRegexBookmarkName='^[a-zA-Z0-9_]*$'
GoRegexBookmarkSuffix='^(([a-zA-Z0-9_]+)#)(.*)$'

__go__get_completions() {
    local cur bookmark

    __d "param $*"

    # help with testing; pass in as args
    if [ "$1" = go ]; then
        cur=${COMP_WORDS[COMP_CWORD]}
        __d cur: "$cur"

        __go__load_definitions
    else
        cur="$1"; shift
    fi

    # enable extended globs option; restored at the end!
    local saved_opts
    saved_opts="$(shopt -p); $(set +o)"
    shopt -s extglob

    [ "${go_bash_debug}" = 0 ] || {
        exec {BASH_XTRACEFD}>"$go_bash_debug_file"
        set -x
    }

    if [[ "$cur" =~ $GoRegexBookmarkSuffix ]]; then
        bookmark="${BASH_REMATCH[2]}"
        local preserve_prefix="${BASH_REMATCH[1]}"
        local suffix="${BASH_REMATCH[3]}"

        local find_completions=1 name_pattern=()
        # e.g cd_root=/
        local bookmark_var="cd_${bookmark}"
        [[ ! -v "$bookmark_var" ]] || {
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

            if [ "$find_completions" = 1 ]; then
                while read -r compl_option; do
                    [ "$compl_option" = '/' ] ||
                        COMPREPLY+=( "${preserve_prefix}${path_offset}${compl_option}" )
                done < <(
                    local symlink
                    find "$path" -maxdepth 1 "${name_pattern[@]}" -type d -printf "%P/\n"
                    find "$path" -maxdepth 1 "${name_pattern[@]}" -type l -printf "%P\n" | while read -r symlink; do
                        [ ! -d "$(readlink -f "${path}/${symlink}")" ] || echo "$symlink/"
                    done
                )
            fi
        }
    elif [[ "$cur" =~ $GoRegexBookmarkName ]]; then
        # shellcheck disable=SC2086
        for bookmark in ${!cd_*}; do
            [[ "$bookmark" != "cd_${cur}"* ]] || COMPREPLY+=( "${bookmark#cd_}#" )
        done
    fi

    __d "COMPREPLY: ${COMPREPLY[*]}"

    # restore saved shell options
    eval "$saved_opts"
}

go() {
    __d params: "$@"

    __go__load_definitions

    local def;
    local def_subpath;
    if [ -n "$1" ]; then
        # are we dealing with definition offset
        # def#path/to/some/thing
        if [[ "$1" == *'#'* ]]; then
            def=${1%%#*}
            def_subpath="${1#*#}"
        elif [[ "$1" =~ / ]]; then
            def=root
            def_subpath="$1"
        else
            def=$1
            def_subpath=''
        fi
    fi

    __d "def: $def"
    __cd_path="$( __go__resolve_definition "$def" )";
    [ -n "$def_subpath" ] &&
        __cd_path="${__cd_path}/${def_subpath}";

    { [ -n "$__cd_path" ] && cd "$__cd_path"; } ||
        echo "GO path could not be found."
}

go_add()
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


if ! declare -p __go__script_loaded &>/dev/null; then
    complete -F __go__get_completions -o dirnames -o nospace go;
fi

export __go__script_loaded=1
