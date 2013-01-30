#!/bin/bash

# Bash Ninja - go command
# License: Creative Commons License
#          (details available here http://creativecommons.org/licenses/by-sa/3.0/deed.en_US)
# Author: Dino Korah
# URL: https://github.com/codemedic/bash-ninja.
# 
# Description:
# Helps you navigate through source trees using custome book marks and
# comes complete with auto-complete

: ${go_projects_conf:=$HOME/bin/my_projects}
# : ${go_script:=$HOME/tmp/new_go.sh}

# ignored folders
: ${go_ignore_dirs:="(CVS|\\.(svn|git|cvs))"}

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
	echo ${!cd_*} | sed s/cd_//g | sed 's/ /\|/g'
}

__go__definitions_name()
{
	echo $( echo ${!cd_*} | sed s/cd_//g | sed 's/ /# /g' )'#'
}

__go__normalise_path()
{
	echo $1 | sed 's#//+#/#g'
}

__go__find_and_ignore()
{
	find_path="$( __go__normalise_path "$1" )";
	common_prefix="$( __go__normalise_path "$2" )";

	__d "find -L $find_path -mindepth 1 -maxdepth 1 -type d | egrep -v \"$go_ignore_dirs\" | __d | awk -F \"$common_prefix\" '\$1 ~ /^$/ { print \"'$3'\"\$2\"/\" }'";
	find -L $find_path -mindepth 1 -maxdepth 1 -type d | egrep -v "$go_ignore_dirs" | __d | awk -F "$common_prefix" '$1 ~ /^$/ { print "'$3'"$2"/" }' | __d;
}

__go__get_completions()
{
	__d -------------------------------------------------------------

	local cur=${COMP_WORDS[COMP_CWORD]}

	local reply;

	local vc;
	local first=${COMP_WORDS[1]}
	__d first_comp: $first

	case "$first" in
	git)
		vc=git;
		;;
	svn)
		vc=svn;
		;;
	*)
		vc=svn;
		;;
	esac

	__d vc: $vc
	__d cur: $cur

	__go__load_definitions $vc

	local def;
	local def_real;
	local def_subpath;
	local def_subpath_dir;
	local def_subpath_comp;

	if [ -n "$cur" ]; then
		# are we dealing with definition offset
		# def#path/to/some/thing
		if [[ "$cur" =~ \# ]]; then
			def=${cur%%#*}
			def_real=$def
			def_subpath=$(echo $cur | sed 's/.*#//')
			def_subpath_dir=$( dirname "$def_subpath" )
			def_subpath_comp=$( basename "$def_subpath" )
		elif [[ "$cur" =~ / ]]; then
			def=root
			def_real=root
			def_subpath="$cur"
			def_subpath_dir=$( dirname "$def_subpath" )
			def_subpath_comp=$( basename "$def_subpath" )
		else
			def=$cur
			def_real=$def
			def_subpath=''
			def_subpath_dir=''
			def_subpath_comp=''
		fi
	fi

	__d def: $def
	__d def_subpath: $def_subpath
	__d def_subpath_dir: $def_subpath_dir

	if [ -n "$def_subpath_dir" -o -n "$def_subpath" ]; then
		local resolved_base_path=$( __go__resolve_definition "$def" )

		if [ -n "$def_subpath" -a -d "$resolved_base_path/$def_subpath" ]; then
			def_subpath_dir="$def_subpath"
			def_subpath_comp=''
		fi

		if [ -n "$def_subpath_dir" ]; then
			local find_path=$resolved_base_path/$def_subpath_dir/;
			__d find_path: $find_path

			reply="$reply $( __go__find_and_ignore $find_path "$find_path$def_subpath_comp" "$cur" )";
			__d reply: $reply
		fi
	elif [ -n "$def" ]; then
		if [[ "|$(__go__definitions_regex)|" =~ |${def}.*?| ]]; then
			reply="$reply $(__go__definitions_name | sed 's/ /\n/g' | grep ^$def)"
			__d reply: $reply
		fi
	else
		reply="$reply $(__go__definitions_name | sed 's/ /\n/g')"
		__d reply: $reply

		reply="$reply $( __go__find_and_ignore $cd_root "$cd_root" '' )";
		__d reply: $reply
	fi

	COMPREPLY=( $reply )
}

go()
{
	__d params: "$@"

	case "$1" in
	git)
		vc=git;
		shift;
		;;
	svn)
		vc=svn;
		shift;
		;;
	*)
		vc=svn;
		;;
	esac

	__d vc: $vc
	__d cur: $cur

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
	cd $( __go__resolve_definition "$def" )/$def_subpath
}

