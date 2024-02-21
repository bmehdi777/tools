#!/usr/bin/env bash

script_name="kc"

function help {
	echo "Usage: $script_name <COMMAND> [OPTIONS...]"
	echo 
	echo "COMMAND:"
	echo
	echo "    start		Start the database and keycloak services"
	echo "    stop		Stop the database and keycloak services"
	echo "    status <db|kc>	Show the status of the parameter"
	echo "    log [stderr|stdout]	See the content of /var/log/keycloak/server.log"
	echo "    shortlog, sl	Last 1000 lines of /var/log/keycloak/server.log"
	echo
	echo "OPTIONS:"
	echo
	echo "    -h,--help		See the help"
}

function start {
	sudo systemctl start mariadb
	sudo systemctl start keycloak
}
function stop {
	sudo systemctl stop mysqld
	sudo systemctl stop keycloak
}

function show-status {
	if [[ "$1" == "kc" ]]; then
		status-keycloak
	elif [[ "$1" == "db" ]]; then
		status-db
	else
		echo "Wrong usage."
		help
		exit 1
	fi

}
function status-keycloak {
	systemctl status keycloak
}
function status-db {
	systemctl status mariadb
}

function log {
	if [[ "$1" == "stderr" ]]; then
		less /var/log/keycloak/stderr.log
	elif [[ "$1" == "stdout" ]]; then
		less /var/log/keycloak/stdout.log
	elif [[ "$1" == "" ]]; then
		less /var/log/keycloak/server.log
	else
		help
		exit 1
	fi
}
function shortlog-server {
	tail -f -n1000 /var/log/keycloak/server.log
}


case $1 in
	"start")
		start
		;;
	"stop")
		stop
		;;
	"status")
		show-status $2
		;;
	"log")
		log $2
		;;
	"shortlog" | "sl")
		shortlog-server
		;;
	*)
		help
		;;
esac
