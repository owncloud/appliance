#!/bin/bash

# should be placed in /usr/bin/
# otherwise, the listener_trigger script and the owncloud sync cronjob has to be adapted

source /etc/entrypoint.d/05-univention-env.sh

MODE="${OWNCLOUD_SYNC_DISABLE_MODE}"
if [ -z "$MODE" ]; then
	MODE="disable"
fi

REACTIVATE=
if [ "$OWNCLOUD_SYNC_ACCOUNT_REACTIVATION" == "true" ]; then
	REACTIVATE="-r"
fi

/usr/bin/occ user:sync -m $MODE $REACTIVATE 'OCA\User_LDAP\User_Proxy'
