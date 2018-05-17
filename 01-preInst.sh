#!/bin/bash
# preinst script
# outer script, only called when ownCloud App is installed
echo "folder declaration"
OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"

echo "folder creation"
mkdir -p $OWNCLOUD_CONF
mkdir -p "$OWNCLOUD_DATA/files"
touch /root/setup-ldap.sh

echo "enable logging"
to_logfile () {
	tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
}
echo "read environment variables"
eval $(ucr shell)

echo "look for binddn and bindpwdfile"
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


MACHINE_PWD="$(< $pwdfile)"

echo "Check if owncloud 9 was installed previously"
if [ -f  $OWNCLOUD_DATA/files/tobemigrated ]

then

udm settings/ldapschema modify --binddn="$binddn" --bindpwdfile="$pwdfile" \
--dn="cn=owncloud82,cn=ldapschema,cn=univention,$ldap_base" \
--set name=owncloud --set filename=owncloud.schema

fi

echo "Base configuration for ownCloud" | to_logfile
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

echo "Check if this is a migration from 9.1"
if [ -f  $OWNCLOUD_DATA/files/tobemigrated ]
then
  echo "Found ownCloud 9.1 backup, restoring data"
  echo "- Importing files"
  mv /var/lib/owncloud/* $OWNCLOUD_DATA/files
  echo "- Import config"
  mv $OWNCLOUD_DATA/files/config.php $OWNCLOUD_CONF/config.php
  sed -i "s#'datadirectory'.*#'datadirectory' => '/var/lib/univention-appcenter/apps/owncloud/data/files',#" $OWNCLOUD_CONF/config.php

  echo "- Importing database"
  mysql -u root -p$(cat /etc/mysql.secret) \
    owncloud < $OWNCLOUD_DATA/files/database.sql

  echo "- Update storages"
  mysql -u root -p$(cat /etc/mysql.secret) owncloud \
    -e "UPDATE oc_storages SET id='local::/var/lib/univention-appcenter/apps/owncloud/data/files' \
    WHERE id='local::/var/lib/owncloud/'"

  echo "- Getting Certificate for LDAP"
  cp /etc/univention/ssl/ucsCA/CAcert.pem $OWNCLOUD_CONF

  echo "ownCloud data restored"

  echo "adding apps path"
  sed -i "s#= array (.*#&\n 'apps_paths' => \n   array ( \n 0 => \n array ( \n 'path' => '/var/www/owncloud/apps', \n 'url' => '/apps', \n 'writable' => false, \n ), \n 1 => \n array ( \n 'path' => '/var/lib/univention-appcenter/apps/owncloud/data/custom', \n 'url' => '/custom', \n 'writable' => true, \n ), \n ),#" $OWNCLOUD_CONF/config.php  

  echo "adding performance tuning options"
  sed -i "s#'overwritewebroot' => '/owncloud',.*#&\n'ldapIgnoreNamingRules' => false, \n'filelocking.enabled' => 'false',\n 'htaccess.RewriteBase' => '/owncloud', \n 'integrity.check.disabled' => true, #" $OWNCLOUD_CONF/config.php

  echo "generating pre-update config script"
cat << EOF >| /root/setup-ldap.sh
#!/usr/bin/env bash

to_logfile () {
	tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
}

echo "Fixing LDAP Settings"
OWNCLOUD_PERMCONF_DIR="/var/lib/univention-appcenter/apps/owncloud/conf"
OWNCLOUD_LDAP_FILE="\${OWNCLOUD_PERMCONF_DIR}/ldap"

eval "\$(< \${OWNCLOUD_LDAP_FILE})"
echo -e "\n\n------"
cat \${OWNCLOUD_LDAP_FILE}
echo "enabling ldap user app in preinst script"
occ app:enable user_ldap

echo "set ldap config with values from variables"
occ config:app:set user_ldap ldap_host --value="\${LDAP_MASTER}" 2>&1 | to_logfile
occ config:app:get user_ldap ldap_host
occ config:app:set user_ldap ldap_port --value="\${LDAP_MASTER_PORT}" 2>&1 | to_logfile
occ config:app:get user_ldap ldap_port
occ config:app:set user_ldap ldap_dn --value="\${LDAP_HOSTDN}" 2>&1 | to_logfile
occ config:app:get user_ldap ldap_dn

while ! test -f "/etc/machine.secret"; do
  sleep 1 | to_logfile
  echo "Still waiting"
done

# getting LDAP password and encoding it
ldap_pwd_encoded=\$(cat /etc/machine.secret | base64 -w 0)
echo \$ldap_pwd_encoded > ldap_pwd

echo "setting ldap password"
occ config:app:set user_ldap ldap_agent_password --value="\$(cat ldap_pwd)" 2>&1 | to_logfile
rm ldap_pwd

echo "setting ldap_base" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_base --value="\${owncloud_ldap_base}" 2>&1 | to_logfile
occ config:app:get user_ldap ldap_base

echo "configure ldap" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_login_filter --value="\${owncloud_ldap_loginFilter}" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_User_Filter --value="\${owncloud_ldap_userFilter}" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_Group_Filter --value="\${owncloud_ldap_groupFilter}" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_Quota_Attribute --value="\${owncloud_ldap_user_quotaAttribute}" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_Expert_Username_Attr --value="\${owncloud_ldap_internalNameAttribute}" 2>&1 | to_logfile
occ config:app:set user_ldap ldap_Expert_UUID_User_Attr --value="\${owncloud_ldap_userUuid}" 2>&1 | to_logfile
occ config:app:set user_ldap ldapExpertUUIDGroupAttr --value="\${owncloud_ldap_groupUuid}" 2>&1 | to_logfile
occ config:app:set user_ldap ldapEmailAttribute --value="\${owncloud_ldap_internalNameAttribute}" 2>&1 | to_logfile
occ config:app:set user_ldap ldapGroupMemberAssocAttr --value="\${owncloud_ldap_memberAssoc}" 2>&1 | to_logfile
occ config:app:set user_ldap ldapBaseUsers --value="\${owncloud_ldap_base_users}" 2>&1 | to_logfile
occ config:app:set user_ldap ldapBaseGroups --value="\${owncloud_ldap_base_groups}" 2>&1 | to_logfile
occ config:app:set user_ldap useMemberOfToDetectMembership --value="0" 2>&1 | to_logfile
occ config:app:set user_ldap ldapConfigurationActive --value="1" 2>&1 | to_logfile

EOF

fi

echo "Updating Icon Image for ownCloud docs"

eval "$(ucr shell)"

ICON_PATH="/univention/js/dijit/themes/umc/icons/scalable/apps-"$(univention-app get owncloud component_id --values-only)".svg"

OVBASE="ucs/web/overview/entries/admin/owncloud-admindoc"
ucr set ${OVBASE}/icon="$ICON_PATH"

OVBASE="ucs/web/overview/entries/admin/owncloud-userdoc"
ucr set ${OVBASE}/icon="$ICON_PATH"


exit 0
