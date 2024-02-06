#!/bin/bash

# base-path within which new go-workspaces (per-project) are created
goenv_base_path="$HOME/GoEnv"

# source-base-path is the directory where you keep your source for multiple projects.
# Expected directory structure there is as below
#  $HOME/source-base-path
#   +- git.server1.com
#   |   +- project1
#   |   |   +- repo1
#   |   |       +- Gopkg.toml
#   |   |       +- main.go
#   |   |   +- repo2
#   |   +- project2
#   |       +- repo1
#   |       +- repo2
#   +- github.com
#       +- user1
#       |   +- repo1
#       |       +- Gopkg.toml
#       |       +- main.go
#       |   +- repo2
#       +- company1
#           +- repo1
#           +- repo2
source_base_path="$HOME/development"

# replace the shell based on environment variables
goenv_replace_shell_env_vars=(
    # if invoked from VSCode Terminal
    'TERM_PROGRAM=vscode'
    # if invoked from IntelliJ (or derivatives) Terminal
    'TERMINAL_EMULATOR=JetBrains-JediTerm'
)

# trim "go-" prefix or "-go" suffix from project dir name
goenv_project_name_trim_go=true

# mount command to use, in order to place the source location inside the go-workspace. Options available are `bindfs`
# and "plain-old" `mount` (with `sudo`)
goenv_mount_method=mount

goenv() {
    local path ide
    local dep_ensure=0

    cli_opts="$(getopt -n goenv -o r:i:dh --long project-root:,open-ide:,dep-ensure,help -- "$@" )" || {
        goenv_cmd_usage_help "Invalid usage"
        return
    }
    eval "cli_opts=( ${cli_opts} )"
    for ((i = 0; i < ${#cli_opts[@]}; ++i)); do
        case "${cli_opts[$i]}" in
            -d|--dep-ensure)
                dep_ensure=1
                ;;
            -r|--project-root)
                path="${cli_opts[$((++i))]}"
                ;;
            -i|--open-ide)
                ide="${cli_opts[$((++i))]}"
                ;;
            -h|--help)
                goenv_cmd_usage_help
                return
                ;;
            --)
                ;;
            *)
                goenv_cmd_usage_help "Invalid usage"
                return
                ;;
        esac
    done

    # if not specified, assume that the curent directory is the project root
    path="$(realpath -s "${path:-.}")"

    local newly_created=0
    if ! goenv_path="$(goenv_get_path "$path")"; then
        if ! goenv_create "$path" || ! goenv_path="$(goenv_get_path "$path")"; then
            echo "Could not create goenv"
            return 1
        fi
        newly_created=1
    fi

    # shellcheck disable=SC1090
    . "${goenv_path}/.goenv"

    # shellcheck disable=SC2154
    # loaded from the sourcing above
    goenv_mount "${goenv_source_path}" "${goenv_package_path}"

    # Take recent history with you when you =Go
    history -a

    # New shell, ready to =Go
    # When you are done press Ctrl+D or invoke 'exit' command
    goenv_exec bash --rcfile <(
        cat "$HOME/.bashrc"
        echo "export __GOENV=1"
        echo "export GOPATH=\"$goenv_path\""
        echo "export GOBIN=\"\$GOPATH/bin\""
        echo "export PATH=\"\$GOBIN:$PATH\""
        echo "export CGO_ENABLED=0"
        echo "export GOENV_NAME=\"${goenv_name}\""
        echo "export GOENV_SOURCE_PATH=\"$goenv_source_path\""
        echo "export GOENV_PACKAGE_PATH=\"$goenv_package_path\""
        echo "export GOENV_PATH=\"$goenv_path\""
        echo "export GOENV_OLD_PS1='$PS1'"
        echo "PROMPT_DIRTRIM=2"
        echo "PS1='(=Go ${goenv_name}) $PS1'"
        echo "alias ~~=cd_gopath"
        echo "alias ~=goenv_cd"
        echo "alias ~source=goenv_cd_source_dir"
        echo "alias ~mount='goenv_mount \"$GOENV_SOURCE_PATH\" \"$GOENV_PACKAGE_PATH\"'"
        echo "alias ~umount=goenv_umount"
        echo "alias ~help=goenv_help"
        echo "goenv_setup_ide"
        echo "goenv_cd"
        echo "goenv_tab_title \"${goenv_name}\""
        echo "trap goenv_tab_title EXIT"

        if [[ "$newly_created" == 1 ]]; then
            echo "echo 'New GoEnv created; All good to Go!'"
            echo "echo"
            echo "goenv_help"
        fi

        if [ -n "${ide:-}" ]; then
            echo "echo 'Opening GoEnv in IDE'"
            echo "goenv_ide $ide"
        fi

        if [[ "$dep_ensure" == 1 ]]; then
            echo "if [[ -f 'Gopkg.toml' ]]; then"
            echo "    echo 'Running dep ensure'"
            echo "    dep ensure -v"
            echo "fi"
        fi
    )
}

goenv_exec() {
    local cmd=("$@")
    local v en ev replace=false
    for v in "${goenv_replace_shell_env_vars[@]}"; do
        if [[ "$v" = *=* ]] && [[ -v "${v%%=*}" ]]; then
            en="${v%%=*}"
            ev="${v##*=}"
            if [ "${!en}" = "$ev" ]; then
                replace=true
                break
            fi
        elif [[ -v "$v" ]]; then
            replace=true
            break
        fi
    done

    if "$replace"; then
        cmd=(exec "${cmd[@]}")
    fi

    command "${cmd[@]}"
}

goenv_get_path() {
    local path
    # If no arguments are give, assume that the curent directory is the project root
    : "${path:="${1:-.}"}"
    path="$(realpath -s "$path")"

    local dot_goenv
    if [ -f "${path}/.goenv" ]; then
        dot_goenv="${path}/.goenv"
    elif [[ "$path" =~ .*/((bitbucket.[^/]+|github.com|exercism)/([^/]+)/([^/]+)) ]]; then
        local package project_path
        package="${BASH_REMATCH[1]}"
        project_path="${goenv_base_path}/$(basename "$package")"
        if [ -d "${project_path}" ] || [ -f "${project_path}/.goenv" ]; then
            dot_goenv="${project_path}/.goenv"
        fi
    fi

    if [ -z "$dot_goenv" ] || [ ! -f "$dot_goenv" ]; then
        return 1
    fi

    # shellcheck disable=SC1090
    . "$dot_goenv"

    if [ ! -d "$goenv_path" ]; then
        return 1
    fi

    echo "$goenv_path"
}

goenv_create() {
    local path
    # If no arguments are give, assume that the curent directory is the project root
    : "${path:="${1:-.}"}"
    path="$(realpath -s "$path")"

    if [[ "$path" =~ .*/((bitbucket.[^/]+|github.com|exercism)/([^/]+)/([^/]+)) ]] && goenv_dir_has_go_file "$path"; then
        local package project_path parent_dir project_dir source_path
        source_path="${BASH_REMATCH[0]}"
        package="${BASH_REMATCH[1]}"
        parent_dir="${BASH_REMATCH[3]}"
        project_dir="${BASH_REMATCH[4]}"
        if [[ "$goenv_project_name_trim_go" == true ]] && [[ "$project_dir" =~ ^(go-)?(.+)(-go)?$ ]]; then
            project_dir="${BASH_REMATCH[2]}"
        fi
        goenv_name="${parent_dir}#${project_dir}"
        project_path="${goenv_base_path}/${goenv_name}"
        project_path_templated="\${goenv_base_path}/${goenv_name}"
        if [ -d "${project_path}" ]; then
            echo "$project_path already exists; remove it and try again"
            return 1
        fi

        mkdir -p "${project_path}/src/${package}" "${project_path}/bin"
        goenv_mount "${source_path}" "${project_path}/src/${package}"
        {
            if [[ "$source_path" == "$source_base_path"* ]]; then
                source_path="\${source_base_path}/${source_path#"$source_base_path"/}"
            fi

            echo "# config file generated by goenv command"
            echo "# see https://github.com/codemedic/bash-ninja"
            echo ""
            echo "local goenv_name goenv_path goenv_package_path goenv_source_path goenv_source_package"
            echo ""
            echo "goenv_name=\"$goenv_name\""
            echo "goenv_path=\"$project_path_templated\""
            echo "goenv_package_path=\"${project_path_templated}/src/${package}\""
            echo "goenv_source_path=\"${source_path}\""
            echo "goenv_source_package=\"${package}\""
        } >"$path/.goenv"
        cp "$path/.goenv" "${project_path}"
    else
        echo "Unknown path structure; path:$path"
        return 1
    fi
}

__goenv_prefix() {
    while read -r line; do
        echo "$1$line"
    done
}

goenv_destroy() {
    if goenv_is_valid; then
        if goenv_umount; then
            # shellcheck disable=SC2153
            if [[ "$PWD" = "$GOENV_PATH"* ]]; then
                cd "$GOENV_SOURCE_PATH" || :
            fi

            echo "Removing $GOENV_PATH"
            chmod -R u+w "$GOENV_PATH"
            rm -rvf "$GOENV_PATH" 2>&1 | __goenv_prefix "    "
            PS1='(=Go INVALID) '"$GOENV_OLD_PS1"

            # shellcheck disable=SC2153
            echo "GoEnv '${GOENV_NAME}' destroyed."
            echo "Please close this terminal session."
        else
            echo "Failed to unmount source-path"
        fi
    else
        echo "No active goenv"
    fi
}

goenv_is_valid() {
    [ -v GOENV_PACKAGE_PATH ] && [ -d "$GOENV_PACKAGE_PATH" ]
}

goenv_cd_source_dir() {
    if goenv_is_valid; then
        cd "$GOENV_SOURCE_PATH" || :
    fi
}

cd_gopath() {
    cd "$GOPATH" || :
}

goenv_cd() {
    if goenv_is_valid; then
        cd "$GOENV_PACKAGE_PATH" || :
    fi
}

goenv_mount() {
    if ! mountpoint -q "$2"; then
        case "$goenv_mount_method" in
        mount)
            sudo mount --bind "$1" "$2"
            ;;
        bindfs)
            bindfs --no-allow-other "$1" "$2"
            ;;
        *)
            echo Unknown goenv_mount_method option.
            ;;
        esac
    fi
}

goenv_umount() {
    # get out of the way for umount
    if [[ "$PWD" = "$GOENV_PACKAGE_PATH"* ]]; then
        cd "$GOENV_SOURCE_PATH" || :
    fi
    if goenv_is_valid && mountpoint -q "$GOENV_PACKAGE_PATH"; then
        echo "Unmounting $GOENV_PACKAGE_PATH"
        case "$goenv_mount_method" in
        mount)
            sudo umount "$GOENV_PACKAGE_PATH"
            ;;
        bindfs)
            fusermount -u "$GOENV_PACKAGE_PATH"
            ;;
        *)
            echo Unknown goenv_mount_method option.
            ;;
        esac
    fi
}

goenv_dir_has_go_file() {
    for f in "$1"/*.go "$1"/Gopkg.toml "$1"/go.mod; do
        if [ -f "$f" ]; then
            return 0
        fi
    done

    return 1
}

goenv_setup_ide() {
    if goland_bin=$(which goland 2>/dev/null); then
        # shellcheck disable=SC2139
        alias goland="goenv_ide \"$goland_bin\""
    fi
    if code_bin=$(which code 2>/dev/null); then
        # shellcheck disable=SC2139
        alias code="goenv_ide \"$code_bin\""
    fi
}

goenv_quiet() {
    if [[ "${1:-1}" == 1 ]]; then
        exec &>/dev/null
    fi
}

goenv_tab_title() {
    echo -n -e "\\033]0;$*\\007"
}

goenv_ide() {
    local ide_bin
    local quiet

    ide_bin="$1"; shift

    # if you specify options
    if [ $# -gt 0 ]; then
        # they are passed on to the IDE
        (
            (
                goenv_quiet "${quiet:-1}"
                # FIX: The IDE ignores SIGINT: the "Stop" button in run configurations may not work.
                trap - SIGINT
                "$ide_bin" "$@"
            )&
            disown
        )
    else
        # otherwise open the current GoEnv
        (
            (
                goenv_quiet "${quiet}"
                # FIX: The IDE ignores SIGINT: the "Stop" button in run configurations may not work.
                trap - SIGINT
                "$ide_bin" "$GOENV_PATH"
            )&
            disown
        )
    fi
}

goenv_cmd_usage_help() {
    if [ -n "$*" ]; then
        echo "error: $*"
    fi

    cat <<-GoEnvUsage
goenv [--open-ide=<IDE>] [--project-root=<ProjectPath>] [--help]

-i <IDE>, --open-ide=<IDE>
    Open the project in the specified IDE. IDEs supported are goland and vs-code

-r <ProjectPath>, --project-root=<ProjectPath> (default: '.')
    Use the specified path as the project root, rather than the default '.'

-h,--help Show this help.

GoEnvUsage
    if [ -n "$*" ]; then
        return 1
    fi
}

goenv_help() {
    cat <<-GoEnvHelp
Commands available to work with GoEnv.
 ~        cd to location of the package within GoEnv
 ~~       cd to GOPATH ( $GOPATH )
 ~source  cd to the original source location of the package
 ~mount   mount package path (say, after a restart)
 ~umount  unmount package path
 goland   available if goland is installed and available as goland command.
          If invoked without any parameters, opens GoEnv as a project. Do
          remember to set GOPATH to "$GOPATH"
 code     available if VS Code is installed. If invoked without any
          parameters, opens GoEnv as a project. Do remember to have
          "Infer GOPATH from the workspace root" option to be ON.
 ~help    To see this help again
GoEnvHelp
}
