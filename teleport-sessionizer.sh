#!/usr/bin/env bash

# flags :
# current pane : -c
# new pane : vertical -sv
# new pane : horizontal -sh

usage () {
	echo "Usage: \`tshs\` [option]"
	echo
	echo "Destination"
	echo -e "  -c  \tCurrent pane"
	echo -e "  -sv \tVertical pane"
	echo -e "  -sh \tHorizontal pane"
	echo
	echo "Information: without any flag, \`tshs\` will open ssh connection in a new session"
}
selectSsh () {
	selected=$(tsh ls | fzf --header-lines=2 | cut -d" " -f1)

	if [[ -z $selected ]]; then
		exit 0
	fi

	preselected_user=("nodejs" "ubuntu" "root" "centos")
	user=$(printf "%s\n" "${preselected_user[@]}" | fzf)

	if [[ -z $user ]]; then
		exit 0
	fi

	selected_name=$(basename "$selected" | tr . _)
	tmux_running=$(pgrep tmux)
}

case $1 in
	"-c")
		selectSsh
		tsh ssh $user@$selected
		;;
	"-sv")
		selectSsh
		tmux split-window -v "tsh ssh $user@$selected"
		exit 0
		;;
	"-sh")
		selectSsh
		tmux split-window -h "tsh ssh $user@$selected"
		exit 0
		;;
	"")
		selectSsh
		if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
			tmux new-session -s $selected_name -d "tsh ssh $user@$selected"
			exit 0
		fi

		if ! tmux has-session -t=$selected_name 2> /dev/null; then
			tmux new-session -ds $selected_name -d "tsh ssh $user@$selected"
		fi
		tmux switch-client -t $selected_name
		;;
	"-h")
		usage
		;;
	*)
		echo "Error: parameter \`$1\` doesn't exist."
		echo
		usage
		;;
esac

