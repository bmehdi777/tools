#!/usr/bin/env bash

script_name="kc"

function help {
	echo "Usage: $script_name <COMMAND> [OPTIONS...]"
	echo 
	echo "COMMAND:"
	echo
	echo "    start [kc|db]	Start the database and keycloak services"
	echo "    start-dev		Start in dev mode"
	echo "    stop		Stop the database and keycloak services"
	echo "    restart		Restart the database and keycloak services"
	echo "    status <db|kc>	Show the status of the parameter"
	echo "    log [stderr|stdout]	See the content of /var/log/keycloak/server.log"
	echo "    shortlog, sl	Last 1000 lines of /var/log/keycloak/server.log"
	echo
	echo "OPTIONS:"
	echo
	echo "    -h,--help		See the help"
}

function exit-prg {
		echo "Wrong usage."
		help
		exit 1
}
function start {
	if [[ "$1" == "kc" ]]; then
		sudo systemctl start keycloak
	elif [[ "$1" == "db" ]]; then
		sudo systemctl start mariadb
	elif [[ "$1" == "" ]]; then
		sudo systemctl start mariadb
		sudo systemctl start keycloak
	else
		exit-prg
	fi
}
function start-dev {
	/opt/keycloak/bin/kc.sh start-dev
}
function stop {
	if [[ "$1" == "kc" ]]; then
		sudo systemctl stop keycloak
	elif [[ "$1" == "db" ]]; then
		sudo systemctl stop mariadb
	elif [[ "$1" == "" ]]; then
		sudo systemctl stop mariadb
		sudo systemctl stop keycloak
	else
		exit-prg
	fi
}
function restart {
	if [[ "$1" == "kc" ]]; then
		sudo systemctl restart keycloak
	elif [[ "$1" == "db" ]]; then
		sudo systemctl restart mariadb
	elif [[ "$1" == "" ]]; then
		sudo systemctl restart mariadb
		sudo systemctl restart keycloak
	else
		exit-prg
	fi
}

function show-status {
	if [[ "$1" == "kc" || "$1" == "" ]]; then
		status-keycloak
	elif [[ "$1" == "db" ]]; then
		status-db
	else
		exit-prg
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
		exit-prg
	fi
}
function shortlog-server {
	tail -f -n1000 /var/log/keycloak/server.log
}


case $1 in
	"start")
		start $2
		;;
	"start-dev")
		start-dev
		;;
	"stop")
		stop $2
		;;
	"restart")
		restart $2
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
