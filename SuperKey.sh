#!/bin/bash

function get_pinned_programs()
{
	local -n programs=$1

	local pinned_launchers=$(dconf dump /com/solus-project/budgie-panel/instance/icon-tasklist/ | tail -n +2)
	# Get only the part inside brackets "[ ... ]"
	pinned_launchers=${pinned_launchers#*[}
	pinned_launchers=${pinned_launchers%]}
	pinned_launchers=${pinned_launchers//,/}
	pinned_launchers=${pinned_launchers//\'/}
	programs=( $pinned_launchers )
}

function get_exec_from_desktop_entry()
{
	local desktop_link=$1
	local -n exec=$2
	local -n _wm_name=$3
	local desktop_entry

	desktop_path=/usr/share/applications
	if [ ! -f $desktop_path/$desktop_link ]; then
		desktop_path=/var/lib/snapd/desktop/applications/
	fi
	desktop_entry=$(sed -n '/^\[Desktop Entry\]/,/^\[/p' "$desktop_path/$desktop_link")

	exec=$(awk '/^Exec=/{print $0}' <<< "$desktop_entry")
	exec=${exec#*=}

	# Remove all %(one character), it's an exec-key field, we currently simply ignore
	exec=$(sed <<< $exec 's/%.//')

	# Search for StartupWMClass
	_wm_name=$(awk '/^StartupWMClass=/{print $0}' <<< "$desktop_entry")
	_wm_name=${_wm_name#*=}
	if [ "$_wm_name" == "" ]; then
		# Else take the last name of the link
		# ex. com.gexperts.Tilix.desktop results into "Tilix"
		_wm_name=${desktop_link%.desktop}
		_wm_name=${_wm_name##*.}
	fi
}

function get_program_by_index()
{
	local index=$1
	local -n _desktop_file_name=$2
	local -n _program_wmname=$3
	local -n _program_exec=$4
	get_pinned_programs program_list
	_desktop_file_name=${program_list[$index]}
	get_exec_from_desktop_entry $_desktop_file_name _program_exec _program_wmname
	if [ "$_program_wmname" == "chromium" ]; then
		_program_wmname="chromium-browser"
	fi
}

function activate_window()
{
	# Store all program id's, these are the open windows
	# ignore case, because some programs uses different class names than the program name
	# webex -> Webex or thunderbird
	local program_wm_name=$1
	local program_exec=$2
	local pid_list=( $(wmctrl -lix | awk '{print $1,tolower($3)}' | awk '/\.'"${program_wm_name,,}"'$| '"${program_wm_name,,}"'\./{print $1}') )
	local max_pid=$((${#pid_list[@]}-1))
	local pid
	local index=-1

	if [ "$verbose" == 1 ]; then
		printf "program_wm_name: '%s'\n" "$program_wm_name"
		printf "Window: %s\n" "${pid_list[@]}"
	fi

	if [[ "${#pid_list[@]}" > 0 ]]; then
		# program is already running

		# Find the index
		if [[ "${#pid_list[@]}" > 1 ]]; then
			# Check if the active window is one of the program instances
			local active_window=$(($(xprop  -root 32x '\t$0' _NET_ACTIVE_WINDOW | cut -f 2)))
			for (( search_index=0; search_index< ${#pid_list[@]}; search_index++)); do
				pid=$((${pid_list[$search_index]}))
				if [ $pid == $active_window ]; then
					index=$search_index
				fi
			done
		fi

		if [ $reverse == 0 ]; then
			index=$((index+1))
			index=$((index > max_pid ? 0 : index))
		else
			index=$((index-1))
			index=$((index < 0 ? max_pid : index))
		fi

		# Activate next or previous window (depends on $reverse)
		wmctrl -i -a ${pid_list[$index]}
	else
		# Program not running, start first instance
		$program_exec
	fi
}

function main()
{
	get_program_by_index $index desktop_filename program_name program_exec
	if [ "$verbose" == 1 ]; then
		printf "wmname: '%s' desktop_file: '%s' Exec: '%s'\n" "$program_name" "$desktop_filename" "$program_exec"
	fi

	if [ $new_window_forced == 1 ]; then
		# "$program_exec"
		gtk-launch "$desktop_filename"
	else
		activate_window "$program_name" "$program_exec" "$new_window_forced"
	fi
}


die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

key="1"
new_window_forced=0
reverse=0
verbose=0

while getopts "rnvk:-:" OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    k | key )		needs_arg; key="$OPTARG" ;;
    r | reverse )   reverse=1 ;;
    n | new )  		new_window_forced=1 ;;
	v | verbose )   verbose=1 ;;
    ??* )          die "Illegal option --$OPT" ;;  # bad long option
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# Super-1 is attached to index 0
index=$(($key-1))

function mainx()
{
	for ((index=0; index<14; index++)); do
		get_program_by_index $index desktop_filename program_name program_exec
		if [ "$verbose" == 1 ]; then
			printf "wmname: '%s' desktop_file: '%s' Exec: '%s'\n" "$program_name" "$desktop_filename" "$program_exec"
		fi
	done
}
main
