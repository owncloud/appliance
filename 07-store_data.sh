#!/bin/bash

OWNCLOUD_PERMDATA_DIR="/var/lib/univention-appcenter/apps/owncloud/data"
OWNCLOUD_BACKUP_DIR="${OWNCLOUD_PERMDATA_DIR}/backups"

mkdir -p ${OWNCLOUD_BACKUP_DIR}

echo "Dumping ownCloud database..."
mysqldump \
  -u${OWNCLOUD_DB_USERNAME} \
  -p${OWNCLOUD_DB_PASSWORD} \
  -h${OWNCLOUD_DB_HOST} \
  ${OWNCLOUD_DB_NAME} > ${OWNCLOUD_BACKUP_DIR}/database.sql

exit 0
