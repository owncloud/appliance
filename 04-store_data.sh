#!/bin/bash
# store data
# inner script
# called on update and remove

echo "store a list of apps, and deactivate them (will be reactivated in new app's setup script)"
occ app:list --shipped=false --output=json | jq -r '.enabled | keys[]' > /var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list

app_whitelist="comments files_videoplayer firstrunwizard market notifications systemtags user_ldap onlyoffice richdocuments"

for app in $(</var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list); do
	for whitelisted_app in $app_whitelist; do 
		[ "$app" == "$whitelisted_app" ] && continue 2  # Continue on outer loop
	done
	occ app:disable "$app"
done

true
