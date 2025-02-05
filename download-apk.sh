#!/usr/bin/env bash

script_name="dlapk"

function help {
	echo "Usage: $script_name BUNDLE_ID"
}

if [[ "$1" == "" || "$2" != "" ]]; then
	echo  "Wrong usage."
	help
	exit 1
fi

bundleId=$1
apk=`adb shell pm path $bundleId`
apk=`echo $apk | awk '{print $NF}' FS=':' | tr -d '\r\n'`
adb pull $apk app.apk

