#!/bin/bash

# base-path within which new go-workspaces (per-project) are created
goenv_base_path="$HOME/GoEnv"

# replace the shell based on environment variables
goenv_replace_shell_env_vars=(
    # if invoked from VSCode Terminal
    TERM_PROGRAM=vscode
    # if invoked from IntelliJ (or derivatives) Terminal
    _INTELLIJ_FORCE_SET_GOPATH
)

# mount command to use, in order to place the source location inside the go-workspace. Options available are `bindfs`
# and "plain-old" `mount` (with `sudo`)
goenv_mount_method=mount

goenv() {
    local path

    # If no arguments are give, assume that the curent directory is the project root
    : "${path:="${1:-.}"}"
    path="$(realpath -s "$path")"

    if ! goenv_path="$(goenv_get_path "$path")"; then
        goenv_create "$path"
        if ! goenv_path="$(goenv_get_path "$path")"; then
            echo "Could not create goenv"
            return 1
        fi
    fi

    . "${goenv_path}/.goenv"

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
        echo "alias ~=goenv_cd"
        echo "alias ~source=goenv_cd_source_dir"
        echo 'alias ~mount="goenv_mount \"$GOENV_SOURCE_PATH\" \"$GOENV_PACKAGE_PATH\""'
        echo "alias ~umount=goenv_umount"
        echo "goenv_cd"
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

    local base_path
    : "${base_path:="${goenv_base_path:?Define goenv_base_path}"}"

    local dot_goenv
    if [ -f "${path}/.goenv" ]; then
        dot_goenv="${path}/.goenv"
    elif [[ "$path" =~ .*/((bitbucket\.[^/]+|github\.com|exercism)/([^/]+)/([^/]+)) ]]; then
        local package project_path
        package="${BASH_REMATCH[1]}"
        project_path="${base_path}/$(basename "$package")"
        if [ -d "${project_path}" ] || [ -f "${project_path}/.goenv" ]; then
            dot_goenv="${project_path}/.goenv"
        fi
    fi

    if [ -z "$dot_goenv" ] || [ ! -f "$dot_goenv" ]; then
        return 1
    fi

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

    local base_path
    : "${base_path:="${goenv_base_path:?Define goenv_base_path}"}"

    if [[ "$path" =~ .*/((bitbucket\.[^/]+|github\.com|exercism)/([^/]+)/([^/]+)) ]] && goenv_dir_has_go_file "$path"; then
        local package project_path
        package="${BASH_REMATCH[1]}"
        project_path="${base_path}/$(basename "$package")"
        if [ -d "${project_path}" ]; then
            echo "$project_path already exists; remove it and try again"
            return 1
        fi

        mkdir -p "${project_path}/src/${package}" "${project_path}/bin"
        goenv_mount "${BASH_REMATCH[0]}" "${project_path}/src/${package}"
        {
            echo "local goenv_name goenv_path goenv_package_path goenv_source_path goenv_source_package"
            echo "goenv_name=${BASH_REMATCH[3]}/${BASH_REMATCH[4]}"
            echo "goenv_path=$project_path" 
            echo "goenv_package_path=${project_path}/src/${package}" 
            echo "goenv_source_path=${BASH_REMATCH[0]}" 
            echo "goenv_source_package=${package}" 
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
            if [[ "$PWD" = "$GOENV_PATH"* ]]; then
                cd "$GOENV_SOURCE_PATH" || :
            fi

            echo "Removing $GOENV_PATH"
            rm -rvf "$GOENV_PATH" 2>&1 | __goenv_prefix "    "
            PS1='(=Go INVALID) '"$GOENV_OLD_PS1"

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
        cd "$GOENV_SOURCE_PATH"
    fi
}

goenv_cd() {
    if goenv_is_valid; then
        cd "$GOENV_PACKAGE_PATH"
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
    for f in "$1"/*.go "$1"/Gopkg.toml; do
        if [ -f "$f" ]; then
            return 0
        fi
    done

    return 1
}
