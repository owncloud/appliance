#!/bin/bash
# pre install 
# outer script, only called when ownCloud App is installed

echo "[01.PRE_INST] folder declaration"
OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"
OWNCLOUD_BACKUP_DIR="${OWNCLOUD_DATA}/backup"

echo "[01.PRE_INST] folder creation"
mkdir -p $OWNCLOUD_CONF
mkdir -p "$OWNCLOUD_DATA/files"

echo "[01.PRE_INST] enable logging"
to_logfile () {
  tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
}

echo "[01.PRE_INST] Test for broken ownCloud installation and fix it to enable updating"
if [ -d "/root/setup-ldap.sh" ]; then
	mv /root/setup-ldap.sh /root/setup-ldap.sh.canbedeleted
	touch /root/setup-ldap.sh
	# start the owncloud container
	docker start $(ucr get appcenter/apps/owncloud/container)
fi

echo "[01.PRE_INST] read environment variables"
eval $(ucr shell)

#echo "$(hostname -f|cut -f1 -d ' ')" > $OWNCLOUD_PERM_DIR/domainname.php

echo "[01.PRE_INST] look for binddn and bindpwdfile"

while [ $# -gt 0 ]
do
    case "$1" in
        "--binddn")
            shift
            binddn="$1"
            shift
            ;;
        "--bindpwdfile")
            shift
            pwdfile="$1"
            shift
            ;;
  *)
      shift
      ;;
  esac
done

echo "[01.PRE_INST] configure mariadb"
# check: if mariadb is installed, set options to enable utf8mb4 support for owncloud
if [ -n "$mysql_config_mysqld_innodb_file_format" ] && [ "$mysql_config_mysqld_innodb_file_format" != "Barracuda" ]; then
	echo "Error: innodb_file_format set to value that has to be user modified. Exiting to not overwrite user configuration."
	exit 1
fi

ucr set mysql/config/mysqld/innodb_large_prefix?ON \
		mysql/config/mysqld/innodb_file_format?Barracuda \
		mysql/config/mysqld/innodb_file_per_table?ON \
		mysql/config/mysqld/innodb_default_row_format?dynamic

if dpkg-query -W -f '${Status}' univention-mariadb 2>/dev/null | grep -q "^install"; then
	# mariadb installed, restart server with new settings
	service mariadb restart
fi



MACHINE_PWD="$(< $pwdfile)"

echo "[01.PRE_INST] Check if owncloud 9 was installed previously"
if [ -f  $OWNCLOUD_DATA/files/tobemigrated ]

then

udm settings/ldapschema modify --binddn="$binddn" --bindpwdfile="$pwdfile" \
--dn="cn=owncloud82,cn=ldapschema,cn=univention,$ldap_base" \
--set name=owncloud --set filename=owncloud.schema

fi

echo "[01.PRE_INST] Base configuration for ownCloud" | to_logfile

echo "[01.PRE_INST] getting ldap password"

while ! test -f "/etc/machine.secret"; do

  sleep 1
  echo "Still waiting" 2>&1

done

#ldappwd=$(cat /etc/machine.secret | base64 -w 0)
ldappwd=$(cat /etc/machine.secret)

ucr set \
  owncloud/user/enabled?"1" \
  owncloud/group/enabled?"0" \
  owncloud/ldap/base?"$ldap_base" \
  owncloud/ldap/loginFilter?"(&(objectclass=person)(ownCloudEnabled=1)(|(uid=%uid)(mailPrimaryAddress=%uid)))" \
  owncloud/ldap/userFilter?"(&(objectclass=person)(ownCloudEnabled=1))" \
  owncloud/ldap/groupFilter?"(&(objectclass=posixGroup)(ownCloudEnabled=1))" \
  owncloud/ldap/internalNameAttribute?"uid" \
  owncloud/ldap/userUuid?"uid" \
  owncloud/ldap/groupUuid?"gidNumber" \
  owncloud/ldap/emailAttribute?"mailPrimaryAddress" \
  owncloud/ldap/memberAssoc?"memberUid" \
  owncloud/ldap/user/quotaAttribute?"ownCloudQuota" \
  owncloud/ldap/base/users?"$ldap_base" \
  owncloud/ldap/base/groups?"$ldap_base" \
  owncloud/ldap/search/users?"" \
  owncloud/ldap/search/groups?""

ucr --shell search owncloud | grep ^owncloud >| ${OWNCLOUD_CONF_LDAP}

### Update 9.1 -> 10.0, markerfile "tobemigrated" created by unjoin.sh in 9.1

echo "[01.PRE_INST] Check if this is a migration from 9.1"
if [ -f  $OWNCLOUD_DATA/files/tobemigrated ]
then
  echo "[01.PRE_INST] Found ownCloud 9.1 backup, restoring data"
  echo "[01.PRE_INST] - Importing files"
  mv /var/lib/owncloud/* $OWNCLOUD_DATA/files
  echo "[01.PRE_INST] - Import config"
  mv $OWNCLOUD_DATA/files/config.php $OWNCLOUD_CONF/config.php
  sed -i "s#'datadirectory'.*#'datadirectory' => '/var/lib/univention-appcenter/apps/owncloud/data/files',#" $OWNCLOUD_CONF/config.php

  echo "[01.PRE_INST] - Importing database"
  mysql -u root -p$(cat /etc/mysql.secret) \
    owncloud < $OWNCLOUD_DATA/files/database.sql

  echo "[01.PRE_INST] - Update storages"

  mysql -u root -p$(cat /etc/mysql.secret) owncloud \
    -e "UPDATE oc_storages SET id='local::/var/lib/univention-appcenter/apps/owncloud/data/files' \
    WHERE id='local::/var/lib/owncloud/'"

  echo "[01.PRE_INST] - Getting Certificate for LDAP"
  cp /etc/univention/ssl/ucsCA/CAcert.pem $OWNCLOUD_CONF

  echo "[01.PRE_INST] ownCloud data restored"

  echo "[01.PRE_INST] adding apps path"
  sed -i "s#= array (.*#&\n 'apps_paths' => \n   array ( \n 0 => \n array ( \n 'path' => '/var/www/owncloud/apps', \n 'url' => '/apps', \n 'writable' => false, \n ), \n 1 => \n array ( \n 'path' => '/var/lib/univention-appcenter/apps/owncloud/data/custom', \n 'url' => '/custom', \n 'writable' => true, \n ), \n ),#" $OWNCLOUD_CONF/config.php  

  echo "[01.PRE_INST] adding performance tuning options"
  sed -i "s#'overwritewebroot' => '/owncloud',.*#&\n'ldapIgnoreNamingRules' => false, \n'filelocking.enabled' => 'false',\n 'htaccess.RewriteBase' => '/owncloud', \n 'integrity.check.disabled' => true, #" $OWNCLOUD_CONF/config.php

else
  echo "[01.PRE_INST] no previous installation found"

fi

echo "[01.PRE_INST] Updating Icon Image for ownCloud docs"

eval "$(ucr shell)"

ICON_PATH="/univention/js/dijit/themes/umc/icons/scalable/apps-"$(univention-app get owncloud component_id --values-only)".svg"

OVBASE="ucs/web/overview/entries/admin/owncloud-admindoc"
ucr set ${OVBASE}/icon="$ICON_PATH"

OVBASE="ucs/web/overview/entries/admin/owncloud-userdoc"
ucr set ${OVBASE}/icon="$ICON_PATH"

# instruct "Configuration script run on the Docker Host" to restart or not

touch /tmp/do-not-restart

# upgrade to 10.3: disable gallery + videoplayer app
univention-app shell owncloud  occ app:disable gallery
univention-app shell owncloud  occ app:disable files_videoplayer

exit 0
