#!/bin/bash

# inner script, called to setup / configure the docker container

to_logfile () {
	tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
}

echo "enabling ldap app in docker setup script" 2>&1 | to_logfile

OWNCLOUD_PERMCONF_DIR="/var/lib/univention-appcenter/apps/owncloud/conf"
OWNCLOUD_LDAP_FILE="${OWNCLOUD_PERMCONF_DIR}/ldap"

n=0
until [ $n -ge 10 ]
do
  occ app:enable -q user_ldap 2>&1 | to_logfile

  n=$(($n+1))
  sleep 3
done

echo "Read base configs for ldap" 2>&1 | to_logfile
eval "$(< ${OWNCLOUD_LDAP_FILE})"

if [ -f /var/lib/univention-appcenter/apps/owncloud/data/files/tobemigrated ]
then
  echo "delete ldap config in docker setup script" 2>&1 | to_logfile
  su -c "php occ ldap:delete-config ''" www-data 2>&1 | to_logfile
  rm /var/lib/univention-appcenter/apps/owncloud/data/files/tobemigrated
fi

if [[ "$(occ ldap:show-config)" == "" ]]
then
  echo "creating new ldap config in docker setup script" 2>&1 | to_logfile
  su -c "php occ ldap:create-empty-config" www-data 2>&1 | to_logfile
fi

echo "setting variables from values in docker setup script" 2>&1 | to_logfile
occ ldap:set-config s01 ldapHost ${LDAP_MASTER} 2>&1 | to_logfile
occ ldap:set-config s01 ldapPort ${LDAP_MASTER_PORT} 2>&1 | to_logfile
occ ldap:set-config s01 ldapAgentName ${LDAP_HOSTDN} 2>&1 | to_logfile
occ ldap:set-config s01 ldapAgentPassword $(< /etc/machine.secret) 2>&1 | to_logfile
occ ldap:set-config s01 ldapBase ${owncloud_ldap_base} 2>&1 | to_logfile
occ ldap:set-config s01 ldapLoginFilter $owncloud_ldap_loginFilter 2>&1 | to_logfile
occ ldap:set-config s01 ldapUserFilter $owncloud_ldap_userFilter 2>&1 | to_logfile
occ ldap:set-config s01 ldapGroupFilter $owncloud_ldap_groupFilter 2>&1 | to_logfile
occ ldap:set-config s01 ldapQuotaAttribute $owncloud_ldap_user_quotaAttribute 2>&1 | to_logfile
occ ldap:set-config s01 ldapExpertUsernameAttr $owncloud_ldap_internalNameAttribute 2>&1 | to_logfile
occ ldap:set-config s01 ldapExpertUUIDUserAttr $owncloud_ldap_userUuid 2>&1 | to_logfile
occ ldap:set-config s01 ldapExpertUUIDGroupAttr $owncloud_ldap_groupUuid 2>&1 | to_logfile
occ ldap:set-config s01 ldapEmailAttribute $owncloud_ldap_emailAttribute 2>&1 | to_logfile
occ ldap:set-config s01 ldapGroupMemberAssocAttr $owncloud_ldap_memberAssoc 2>&1 | to_logfile
#occ ldap:set-config s01 ldapAttributesForUserSearch $owncloud_ldap_search_users 2>&1 | to_logfile
#occ ldap:set-config s01 ldapAttributesForGroupSearch $owncloud_ldap_search_groups 2>&1 | to_logfile
occ ldap:set-config s01 ldapBaseUsers $owncloud_ldap_base_users 2>&1 | to_logfile
occ ldap:set-config s01 ldapBaseGroups $owncloud_ldap_base_groups 2>&1 | to_logfile
occ ldap:set-config s01 useMemberOfToDetectMembership 0 2>&1 | to_logfile
occ ldap:set-config s01 ldapConfigurationActive 1 2>&1 | to_logfile

cat << EOF >| /etc/cron.d/sync
*/10  *  *  *  * root /usr/local/bin/occ user:sync -m disable 'OCA\User_LDAP\User_Proxy'
EOF

/usr/local/bin/occ user:sync -m disable "OCA\User_LDAP\User_Proxy" 2>&1 | to_logfile

## Added from request of Thomas, to have a working collabora setup out of the box

if [[ "$(occ config:app:get richdocuments wopi_url)" == "" ]]
then
   occ config:app:set richdocuments wopi_url --value https://"$docker_host_name" 2>&1 | to_logfile
fi

# Cron seems to igrore old cron files
test -f /etc/cron.d/owncloud && touch /etc/cron.d/owncloud
test -f /etc/cron.d/php && touch /etc/cron.d/php

# avatars permissions folder creation fix
chown -R www-data:www-data /var/lib/univention-appcenter/apps/owncloud/

# symlink für collabora
# ln -sf /etc/ssl/certs/ca-certificates.crt /var/www/owncloud/resources/config/ca-bundle.crt

# To reduce the size of the log file, log level will be set to error (3)
occ log:manage --level 3 2>&1 | to_logfile

exit 0
