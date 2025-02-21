#!/usr/bin/env bash

script_name="kc"

function help {
	echo "Usage: $script_name <COMMAND> [OPTIONS...]"
	echo 
	echo "COMMAND:"
	echo
	echo "    start [kc|db|rp|mail]	Start the database and keycloak services"
	echo "    start-dev [-v]		Start in dev mode"
	echo "    stop			Stop the database and keycloak services"
	echo "    restart			Restart the database and keycloak services"
	echo "    status <db|kc>		Show the status of the parameter"
	echo "    cd				Cd into keycloak folder"
	echo "    log [stderr|stdout]		See the content of /var/log/keycloak/server.log"
	echo "    shortlog, sl		Last 1000 lines of /var/log/keycloak/server.log"
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
	elif [[ "$1" == "rp" ]]; then
		docker compose -f ~/Workspace/infra/keycloak-rp/haproxy/docker-compose.yml up -d
	elif [[ "$1" == "mail" ]]; then
		docker run -d --name maildev -p 1080:1080 -p 1025:1025 maildev/maildev
		echo "Maildev running at http://localhost:1080"
	elif [[ "$1" == "" ]]; then
		docker compose -f ~/Workspace/infra/keycloak-rp/haproxy/docker-compose.yml up -d
		sudo systemctl start mariadb
		sudo systemctl start keycloak
		echo "Keycloak is available at https://keycloak.local/auth/admin/master/console/"
	else
		exit-prg
	fi
}
function start-dev {
	if [[ "$1" == "-v" ]]; then
		/opt/keycloak/bin/kc.sh --verbose start-dev
	else
		/opt/keycloak/bin/kc.sh start-dev
	fi
}
function stop {
	if [[ "$1" == "kc" ]]; then
		sudo systemctl stop keycloak
	elif [[ "$1" == "db" ]]; then
		sudo systemctl stop mariadb
	elif [[ "$1" == "rp" ]]; then
		(cd ~/Workspace/infra/keycloak-rp/haproxy/ && docker compose down)
	elif [[ "$1" == "mail" ]]; then
		docker stop maildev
		docker container rm maildev
	elif [[ "$1" == "" ]]; then
		(cd ~/Workspace/infra/keycloak-rp/haproxy/ && docker compose down)
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
		start-dev $2
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
	"cd")
		cd /opt/keycloak/
		echo "Entering in a subshell..."
		echo "Type 'exit' to go to your previous shell."
		echo ""
		exec $SHELL
		;;
	"shortlog" | "sl")
		shortlog-server
		;;
	*)
		help
		;;
esac
