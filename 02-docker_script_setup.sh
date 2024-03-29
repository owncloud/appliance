#!/bin/bash
# docker script setup
# inner script, called to setup / configure the docker container

to_logfile () {
  tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
}

chown -R www-data:www-data /var/lib/univention-appcenter/apps/owncloud
OWNCLOUD_PERMCONF_DIR="/var/lib/univention-appcenter/apps/owncloud/conf"
OWNCLOUD_LDAP_FILE="${OWNCLOUD_PERMCONF_DIR}/ldap"

echo "[02.DOCKER_SETUP] Enable user_ldap app" 2>&1 | to_logfile
n=1
until [ $n -ge 20 ]
do 
  r=$(occ app:enable user_ldap 2>&1)
  t=$?
  echo -n "."
  [[ $t == 0 ]] && break
  n=$(($n + 1))
  sleep 1
done
echo

if [ $n -ge 20 ]
then
echo "[02.DOCKER_SETUP] Enabling of user_ldap FAILED! after $n tries" 2>&1 | to_logfile
echo $r
else
echo "[02.DOCKER_SETUP] user_ldap enabled successfully! after $n tries" 2>&1 | to_logfile
fi

echo "[02.DOCKER_SETUP] Waiting for LDAP app testing..." 2>&1 | to_logfile

n=1
until [ $n -ge 40 ]
do 
  r=$(occ ldap:show-config 2>&1)
  t=$?
  echo -n "."
  [[ $t == 0 ]] && break
  n=$(($n + 1))
  sleep 1
done
echo

if [ $n -ge 40 ]
then
echo "[02.DOCKER_SETUP] Testing of user_ldap FAILED! after $n tries" 2>&1 | to_logfile
echo $r
else
echo "[02.DOCKER_SETUP] user_ldap tested successfully! after $n tries" 2>&1 | to_logfile
fi

echo "[02.DOCKER_SETUP] Read base configs for ldap" 2>&1 | to_logfile
eval "$(< ${OWNCLOUD_LDAP_FILE})"

if [ -f /var/lib/univention-appcenter/apps/owncloud/data/files/tobemigrated ]
then
  echo "[02.DOCKER_SETUP] delete ldap config in docker setup script" 2>&1 | to_logfile
  su -c "php occ ldap:delete-config ''" www-data 2>&1 | to_logfile
  rm /var/lib/univention-appcenter/apps/owncloud/data/files/tobemigrated
fi

if [[ "$(occ ldap:show-config)" == "" ]]
then
  echo "[02.DOCKER_SETUP] creating new ldap config in docker setup script" 2>&1 | to_logfile
  su -c "php occ ldap:create-empty-config" www-data 2>&1 | to_logfile
fi

echo "[02.DOCKER_SETUP] setting variables from values in docker setup script" 2>&1 | to_logfile
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

echo "[02.DOCKER_SETUP] setting up user sync in cron"
cat << EOF >| /etc/cron.d/sync
*/10  *  *  *  * root /usr/bin/occ user:sync -m disable 'OCA\User_LDAP\User_Proxy'
EOF
echo "[02.DOCKER_SETUP] first user sync"
/usr/bin/occ user:sync -m disable "OCA\User_LDAP\User_Proxy" 2>&1 | to_logfile


# Cron seems to igrore old cron files
echo "[02.DOCKER_SETUP] cron fix"
test -f /etc/cron.d/owncloud && touch /etc/cron.d/owncloud
test -f /etc/cron.d/php && touch /etc/cron.d/php


# avatars permissions folder creation fix
echo "[02.DOCKER_SETUP] avatars fix"
chown -R www-data:www-data /var/lib/univention-appcenter/apps/owncloud/

# symlink für collabora
# ln -sf /etc/ssl/certs/ca-certificates.crt /var/www/owncloud/resources/config/ca-bundle.crt

# To reduce the size of the log file, log level will be set to error (3)
echo "[02.DOCKER_SETUP] log level 3"
occ log:manage --level 3 2>&1 | to_logfile

#restore data
# Variables
OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"
collabora_log=/var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
collabora_cert=/etc/univention/ssl/ucsCA/CAcert.pem
owncloud_certs=/var/www/owncloud/resources/config/ca-bundle.crt

echo "[02.DOCKER_SETUP] Is the collabora certificate is mounted correctly" >> $collabora_log
if [ -f $collabora_cert ]
then
        echo "Yes.
        Was it updated?" >> $collabora_log
        # Declaring the marker-string
        collab="This is a certificate for Collabora for ownCloud"
        if grep -Fq "$collab" "$owncloud_certs"
        then
                echo "Yes. 
                Certificate was already updated" >> $collabora_log
        else
                echo "No. 
                Updating Certificate..." >>$collabora_log
                echo "$collab" >> $owncloud_certs
                cat $collabora_cert >> $owncloud_certs
                echo "Certificate has been succesfully updated" >> $collabora_log
        fi
else 
        echo "There is no Collabora Certificate" >> $collabora_log        
fi
#cat $collabora_log

echo "[02.DOCKER_SETUP] enabling log log rotate" 
sed -i "s#);#  'log_rotate_size' => 104857600,\n&#" $OWNCLOUD_CONF/config.php

echo "[02.DOCKER_SETUP] configuring owncloud for onlyoffice use"
sed -i "s#);#  'onlyoffice' => array ('verify_peer_off' => TRUE),\n&#" $OWNCLOUD_CONF/config.php

#setting collabora URL

#occ app:enable richdocuments 

#if [[ "$(occ config:app:get richdocuments wopi_url)" == "" ]]
#then
#   occ config:app:set richdocuments wopi_url --value https://"$docker_host_name" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
#fi

#occ app:disable richdocuments

echo "[02.DOCKER_SETUP] reactivate apps that may have been disabled during an app update" 
if [ -f /var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list ]; then
  for app in $(</var/lib/univention-appcenter/apps/owncloud/conf/owncloud_app_list); do
    occ app:enable "$app"
  done
else
  echo "[02.DOCKER_SETUP] no file found which contains app list" 
fi

# set default values for app settings

# DEFAULT_LANGUAGE
if ! grep OWNCLOUD_DEFAULT_LANGUAGE /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_DEFAULT_LANGUAGE: en" >> /etc/univention/base.conf
fi

# OWNCLOUD_DOMAIN
#if ! grep OWNCLOUD_DOMAIN /etc/univention/base.conf > /dev/null; then
#   printf "\nOWNCLOUD_DOMAIN: localhost" >> /etc/univention/base.conf
#fi

# OWNCLOUD_SUB_URL
if ! grep OWNCLOUD_SUB_URL /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_SUB_URL: /owncloud" >> /etc/univention/base.conf
fi

# LOG_LEVEL
if ! grep OWNCLOUD_LOG_LEVEL /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_LOG_LEVEL: 3" >> /etc/univention/base.conf
fi

# LOST_PASSWORD_LINK
if ! grep OWNCLOUD_LOST_PASSWORD_LINK /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_LOST_PASSWORD_LINK: true" >> /etc/univention/base.conf
fi

# OWNCLOUD_UPDATE_CHECKER
if ! grep OWNCLOUD_UPDATE_CHECKER /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_UPDATE_CHECKER: false" >> /etc/univention/base.conf
fi

# OWNCLOUD_TRASHBIN_RETENTION_OBLIGATION
if ! grep OWNCLOUD_TRASHBIN_RETENTION_OBLIGATION /etc/univention/base.conf > /dev/null; then
    printf "\nOWNCLOUD_TRASHBIN_RETENTION_OBLIGATION: 7, 14" >> /etc/univention/base.conf
fi

true