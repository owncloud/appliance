#!/bin/bash
# store data
# inner script
# called on update and remove
OWNCLOUD_PERMDATA_DIR="/var/lib/univention-appcenter/apps/owncloud/data"
OWNCLOUD_BACKUP_DIR="${OWNCLOUD_PERMDATA_DIR}/backup"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"
mkdir -p ${OWNCLOUD_BACKUP_DIR}

echo "[04.STORE_DATA] Dumping ownCloud database..." 
mysqldump \
  -u${OWNCLOUD_DB_USERNAME} \
  -p${OWNCLOUD_DB_PASSWORD} \
  -h${OWNCLOUD_DB_HOST} \
  ${OWNCLOUD_DB_NAME} > ${OWNCLOUD_BACKUP_DIR}/database.sql

echo "store a list of apps, and deactivate them (will be reactivated in new app's setup script)"
apt-get -q update; apt-get -q -y install jq
occ app:list --shipped=false --output=json | jq -r '.enabled | keys[]' > /var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list

app_whitelist="comments files_videoplayer firstrunwizard market notifications systemtags user_ldap onlyoffice richdocuments"

for app in $(</var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list); do
	for whitelisted_app in $app_whitelist; do 
		[ "$app" == "$whitelisted_app" ] && continue 2  # Continue on outer loop
	done
	occ app:disable "$app"
done

true
