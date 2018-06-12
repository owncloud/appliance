#!/bin/bash
# store data
# outer script
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

#echo "[04.STORE_DATA] Backing up config files..." 
# experimental
#[ -d ${OWNCLOUD_CONF} ] && cp -R ${OWNCLOUD_CONF} ${OWNCLOUD_BACKUP_DIR}

exit 0