#!/bin/bash

# is placed in /usr/bin by univention app center integration - setup script
# all user syncs for owncloud should use this script, which applies
# options configured by app settings for the usersync

if [ -e /etc/entrypoint.d/05-univention-env.sh ]; then
	source /etc/entrypoint.d/05-univention-env.sh
fi

MODE="${OWNCLOUD_SYNC_DISABLE_MODE}"
if [ -z "$MODE" ]; then
	MODE="disable"
fi

REACTIVATE=
if [ "$OWNCLOUD_SYNC_ACCOUNT_REACTIVATION" == "true" ]; then
	REACTIVATE="-r"
fi

/usr/bin/occ user:sync -m $MODE $REACTIVATE 'OCA\User_LDAP\User_Proxy'
