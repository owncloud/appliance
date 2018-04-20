#!/bin/bash

n=0
until [ $n -ge 10 ]
do
  occ app:enable -q user_ldap >>/var/log/appcenter-install.log 2>&1

  n=$(($n+1))
  sleep 3
done

OWNCLOUD_PERMCONF_DIR="/var/lib/univention-appcenter/apps/owncloud/conf"
OWNCLOUD_LDAP_FILE="${OWNCLOUD_PERMCONF_DIR}/ldap"

eval "$(< ${OWNCLOUD_LDAP_FILE})"

if [[ "$(occ ldap:show-config)" == "" ]]
then
  occ ldap:create-empty-config >>/var/log/appcenter-install.log 2>&1
fi

occ ldap:set-config s01 ldapHost ${LDAP_MASTER} >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapPort ${LDAP_MASTER_PORT} >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapAgentName ${LDAP_HOSTDN} >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapAgentPassword $(< /etc/machine.secret) >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapBase ${owncloud_ldap_base} >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapLoginFilter $owncloud_ldap_loginFilter >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapUserFilter $owncloud_ldap_userFilter >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapGroupFilter $owncloud_ldap_groupFilter >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapQuotaAttribute $owncloud_ldap_user_quotaAttribute >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapExpertUsernameAttr $owncloud_ldap_internalNameAttribute >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapExpertUUIDUserAttr $owncloud_ldap_userUuid >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapExpertUUIDGroupAttr $owncloud_ldap_groupUuid >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapEmailAttribute $owncloud_ldap_emailAttribute >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapGroupMemberAssocAttr $owncloud_ldap_memberAssoc >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapAttributesForUserSearch $owncloud_ldap_search_users >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapAttributesForGroupSearch $owncloud_ldap_search_groups >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapBaseUsers $owncloud_ldap_base_users >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapBaseGroups $owncloud_ldap_base_groups >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 useMemberOfToDetectMembership 0 >>/var/log/appcenter-install.log 2>&1
occ ldap:set-config s01 ldapConfigurationActive 1 >>/var/log/appcenter-install.log 2>&1

cat << EOF >| /etc/cron.d/sync
*/10  *  *  *  * root /usr/local/bin/occ user:sync -m disable 'OCA\User_LDAP\User_Proxy'
EOF

/usr/local/bin/occ user:sync -m disable 'OCA\User_LDAP\User_Proxy' >>/var/log/appcenter-install.log 2>&1

exit 0
