#!/bin/bash

echo "[PRE_RM]"
# instruct "Configuration script run on the Docker Host" to restart or not
touch /tmp/do-not-restart

OWNCLOUD_BACKUP_DIR="/var/lib/univention-appcenter/apps/owncloud/data/backup"
mkdir -p ${OWNCLOUD_BACKUP_DIR}
DB_PASSWORD=$(cat /etc/mysql.secret)

echo "[PRE_RM] Backing up ownCloud database..." 
mysqldump \
  -uroot \
  -p${DB_PASSWORD} \
  -h${OWNCLOUD_DB_HOST} \
  ${OWNCLOUD_DB_NAME} > ${OWNCLOUD_BACKUP_DIR}/database.sql

true