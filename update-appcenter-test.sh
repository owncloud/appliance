#!/bin/bash

set -e
set -x

# Put app provider portal username into $HOME/.univention-appcenter-user and the password into $HOME/.univention-appcenter-pwd

# upload to latest owncloud version in test app center
APP_VERSION="4.4/owncloud"

selfservice () {
	local uri="https://provider-portal.software-univention.de/appcenter-selfservice/univention-appcenter-control"
	local first=$1
	shift

	USERNAME="$USER"
	[ -e "$HOME/.univention-appcenter-user" ] && USERNAME="$(< $HOME/.univention-appcenter-user)"

	PWDFILE="~/.selfservicepwd"
	[ -e "$HOME/.univention-appcenter-pwd" ] && PWDFILE="$HOME/.univention-appcenter-pwd"

	curl -sSfL "$uri" | python - "$first" --username=${USERNAME} --pwdfile=${PWDFILE} "$@"
}

die () {
	echo "$@"
	exit 1
}

[ "$IGN_GIT" != "true" ] && test -n "$(git status -s)" && die "Changes in repo, will not upload! (to override: IGN_GIT=true)"

# rename files to upload script can associate files correctly
cp 01-preInstall.sh preinst
cp 02-docker_script_setup.sh setup
cp 03-join.sh inst
cp 04-store_data.sh store_data
cp 05-unjoin.sh uinst
cp app-settings.ini settings
cp configure_host.sh configure_host
cp configure.py configure
cp docker-compose.yml compose
cp PreRm.sh prerm

# upload
selfservice upload "$APP_VERSION" preinst setup inst store_data uinst settings configure_host configure compose prerm test listener_trigger schema

rm -f preinst setup inst store_data uinst settings configure_host configure compose prerm
