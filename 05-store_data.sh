#!/bin/bash
# store data
# outer script
# called on update and remove
OWNCLOUD_PERMDATA_DIR="/var/lib/univention-appcenter/apps/owncloud/data"
OWNCLOUD_BACKUP_DIR="${OWNCLOUD_PERMDATA_DIR}/backup"

mkdir -p ${OWNCLOUD_BACKUP_DIR}

echo "[05.STORE_DATA] Dumping ownCloud database..." 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
mysqldump \
  -u${OWNCLOUD_DB_USERNAME} \
  -p${OWNCLOUD_DB_PASSWORD} \
  -h${OWNCLOUD_DB_HOST} \
  ${OWNCLOUD_DB_NAME} > ${OWNCLOUD_BACKUP_DIR}/database.sql

exit 0