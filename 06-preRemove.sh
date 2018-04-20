#!/bin/bash

pwd=$(cat /etc/owncloudDbUser.secret)

echo "Backing up ownCloud database..."
mysqldump --lock-tables -h localhost -u owncloudDbUser -p$pwd owncloud > /var/lib/owncloud/database.sql

echo "Getting the Container ID..."
owncloud82id="$(ucr get appcenter/apps/owncloud82/container | cut -c 1-12)"

echo "copy config.php"
docker cp $owncloud82id:/var/www/owncloud/config/config.php /var/lib/owncloud/
