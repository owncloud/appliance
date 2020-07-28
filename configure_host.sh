#!/bin/bash

# Test if openid connect is enabled and the udm entry exists
if udm modules | grep oidc/rpservice -q; then
	echo 'oidc provider installed'
	if ! udm oidc/rpservice list --filter name=owncloud | grep DN -q; then
		# oidc is installed, but no owncloud service exists!
		# mark owncloud joinscript as pending to create udm oidc/rpservice in there
		serverrole="$(ucr get server/role)"
		case $serverrole in
			domaincontroller_master|domaincontroller_backup)
				# can be run on dc master+backup
				# but only if no joinscript is currently running (owncloud inst runs 'univention-app configure owncloud')
				if ! pgrep -cf "/bin/bash /usr/sbin/univention-run-join-scripts --force --run-scripts 50owncloud.inst"; then
					univention-run-join-scripts --force --run-scripts 50owncloud.inst
				fi
				;;
			*)
				# admin has to run joinscript manually
				sed -i "/^owncloud v/d" /var/univention-join/status
				;;
		esac
	fi
else
	echo "No OIDC identity provider installed"
fi

# the file "/tmp/do-not-restart" is created in the PreInst and PreRm script.
if [ -e /tmp/do-not-restart ]
then
	rm /tmp/do-not-restart
else
	echo "sleep 10; univention-app restart owncloud" | at now
fi