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

__go__is_interactive()
{
	[ -t 0 ] && true || false
}

if __go__is_interactive; then

# the first one is the default
: ${vc_options:=svn:git}
: ${vc_default:=${vc_options%%:*}}

# version control root and bookmark definitions
: ${go_projects_conf:=$HOME/go_bookmarks.conf}

# ignored folders
: ${go_ignore_dirs:="(CVS|\\.(svn|git|cvs|settings|kdev4))"}

# debug prints enabled ?
: ${go_debug:=0}

# debug print
__d() {
	: ${go_debug_syslog_tag:=rm-go}
	if [ "$go_debug" -eq 0 ]; then
		if [ -z "$1" ]; then
			cat
		else
			return;
		fi
	fi

	[ -n "$1" ] &&
		/usr/bin/logger -t $go_debug_syslog_tag -- "$@" ||
		( tee_file=/tmp/$$.$RANDOM; tee $tee_file | /usr/bin/logger -t $go_debug_syslog_tag; cat $tee_file; rm $tee_file )
}

# __included=$( ( [ "$(readlink -f $0)" == "/bin/bash" ] && [ "$( readlink -f "$go_script" )" == "$( readlink -f "${BASH_ARGV[0]}" )" ] ) && echo 1 || echo 0 )

if ! declare -p __go__script_loaded &>/dev/null; then
	__d go command loaded
	complete -F __go__get_completions -o dirnames -o nospace go;
fi

export __go__script_loaded=1

__go__is_known_vc()
{
	local vc=$1;
	[[ "$vc_options" =~ ^$vc:|:$vc:|$vc$ ]]
}

__go__is_defined()
{
	declare -p "cd_$1" &>/dev/null
}

__go__load_definitions()
{
	vc=$1;
	source $go_projects_conf
}

__go__resolve_definition()
{
	if [ -n "$1" ]; then
		__go__is_defined "$1" &&
			eval "echo \$cd_${1}"/;
	else
		echo $cd_root/
	fi
}

__go__definitions_regex()
{
	echo ${!cd_*} | sed s/cd_//g | sed 's/ /\|/g' | __d
}

__go__definitions_name()
{
	echo $( echo ${!cd_*} | sed s/cd_//g | sed 's/ /# /g' )'#' | __d
}

__go__find_and_ignore()
{
	local find_path=$1
	local find_chop=$2
	local find_paste=$3

	__d find_paste: $find_paste

	__d 'find -L '$find_path' -mindepth 1 -maxdepth 1 -type d | egrep -v "'$go_ignore_dirs'" | __d | grep '$find_chop' | cut -b'$(( ${#find_chop} + 1 ))'-  | while read x; do [ -n "$x" ] && echo '$find_paste'$x/; done | __d';
	find -L $find_path -mindepth 1 -maxdepth 1 -type d | egrep -v "$go_ignore_dirs" | __d | grep $find_chop | cut -b$(( ${#find_chop} + 1 ))-  | while read x; do [ -n "$x" ] && echo $find_paste$x/; done | __d;
}

__go__get_completions()
{
	__d -------------------------------------------------------------

	local cur=${COMP_WORDS[COMP_CWORD]}

	local reply;

	local first=${COMP_WORDS[1]}
	__d first_comp: $first

	if __go__is_known_vc $first; then
		vc=$first;
	fi

	__d vc: $vc
	__d cur: $cur

	__go__load_definitions $vc

	local resolved_base_path;
	local find_path
	local find_chop

	if [ -n "$cur" ]; then
		# are we dealing with definition offset
		# def#path/to/some/thing
		if [[ "$cur" =~ \# ]] && __go__is_defined ${cur%%#*}; then
			__d ------------------------- 1

			resolved_base_path=$( readlink -f $( __go__resolve_definition "${cur%%#*}" ) )
			if [[ "${cur##*#}" =~ / ]]; then
				find_path=${resolved_base_path}/$( dirname ${cur##*#} )
				find_chop=${find_path}/$( basename ${cur##*#} )
			else
				find_path=${resolved_base_path}
				find_chop=${find_path}/${cur##*#}
			fi
		elif [[ "$cur" =~ ^/ ]]; then
			__d ------------------------- 2
			resolved_base_path=$( readlink -f $( __go__resolve_definition root ) )
			if [[ "${cur:1}" =~ / ]]; then
				find_path=${resolved_base_path}$( dirname $cur )
				find_chop=${find_path}/$( basename ${cur##*#} )
			else
				find_path=${resolved_base_path}
				find_chop=${find_path}${cur}
			fi
		fi

		__d resolved_base_path: $resolved_base_path
		__d find_path: $find_path
		__d find_chop: $find_chop
	fi

	if [ -n "$find_path" -a -n "$find_chop" ]; then
		if [ -d "$find_chop" ]; then
			find_path=$( readlink -f $find_chop );
			find_chop=$find_path/;

			__d find_path: $find_path
			__d find_chop: $find_chop
		fi

		reply="$reply $( __go__find_and_ignore $find_path $find_chop $cur )";
		__d reply: $reply
	elif [ -n "$cur" ]; then
		reply="$reply $( __go__definitions_name | sed 's/ /\n/g' | grep ^$cur )"
		__d reply: $reply
	else
		reply="$reply $( __go__definitions_name | sed 's/ /\n/g' )"
		__d reply: $reply

		reply="$reply $( __go__find_and_ignore $cd_root "$cd_root" '' )";
		__d reply: $reply
	fi

	COMPREPLY=( $reply )
}

go()
{
	__d params: "$@"

	if __go__is_known_vc $1; then
		vc=$1;
		shift;
	fi

	__d vc: $vc

	__go__load_definitions $vc

	local def;
	local def_subpath;
	if [ -n "$1" ]; then
		# are we dealing with definition offset
		# def#path/to/some/thing
		if [[ "$1" =~ \# ]]; then
			def=${1%%#*}
			def_subpath=$(echo $1 | sed 's/.*#//')
		elif [[ "$1" =~ / ]]; then
			def=root
			def_subpath="$1"
		else
			def=$1
			def_subpath=''
		fi
	fi

	__d def: $def
	__cd_path="$( __go__resolve_definition "$def" )";
	[ -n "$def_subpath" ] &&
		__cd_path="${__cd_path}/${def_subpath}";

	[ -n "$__cd_path" ] &&
		cd $__cd_path ||
		echo GO path could not be found.
}

fi # if __go__is_interactive; then
