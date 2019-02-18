#!/bin/bash
# join
# outer script
VERSION=2
SERVICE="ownCloud"

. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
. /usr/share/univention-lib/ldap.sh

joinscript_init
eval "$(ucr shell)"

ucs_addServiceToLocalhost ${SERVICE} "$@" || die
ICON_PATH="/univention/js/dijit/themes/umc/icons/scalable/apps-"$(univention-app get owncloud component_id --values-only)".svg"

echo "[03.JOIN] Creating ownCloud admin docs..."
OVBASE="ucs/web/overview/entries/admin/owncloud-admindoc"
ucr set \
  ${OVBASE}/description="ownCloud Administration Manual" \
  ${OVBASE}/description/de="ownCloud Administrations-Handbuch (in Englisch)" \
  ${OVBASE}/icon="$ICON_PATH" \
  ${OVBASE}/label?"Admin Manual" \
  ${OVBASE}/label/de?"Admin Handbuch" \
  ${OVBASE}/link="https://doc.owncloud.com/server/10.0/admin_manual/" \
  ${OVBASE}/priority?95

echo "[03.JOIN] Creating ownCloud user docs..."
OVBASE="ucs/web/overview/entries/admin/owncloud-userdoc"
ucr set \
  ${OVBASE}/description="ownCloud User Manual" \
  ${OVBASE}/description/de="ownCloud Benutzer-Handbuch (in Englisch)" \
  ${OVBASE}/icon="$ICON_PATH" \
  ${OVBASE}/label?"User Manual" \
  ${OVBASE}/label/de?"Benutzer Handbuch" \
  ${OVBASE}/link="https://doc.owncloud.com/server/10.0/user_manual/" \
  ${OVBASE}/priority?100

ucs_unregisterLDAPExtension "$@" --schema owncloud
joinscript_register_schema "$@" || die

univention-directory-manager container/cn create "$@" --ignore_exists \
  --position "cn=custom attributes,cn=univention,$ldap_base" \
  --set name=owncloud

univention-directory-manager settings/extended_attribute create "$@" \
  --position "cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" --set module="users/user" \
  --set ldapMapping='ownCloudEnabled' \
  --set objectClass='ownCloudUser' \
  --set name='ownCloudUserEnabled' \
  --set shortDescription='ownCloud enabled' \
  --set longDescription='Wether User may use ownCloud ' \
  --set translationShortDescription='"de_DE" "ownCloud aktiviert"' \
  --set translationLongDescription='"de_DE" "Der User darf ownCloud verwenden"' \
  --set tabName='ownCloud' \
  --set translationTabName='"de_DE" "ownCloud"' \
  --set overwriteTab='0' \
  --set valueRequired='0' \
  --set CLIName='owncloudEnabled' \
  --set syntax='boolean' \
  --set default="$owncloud_user_enabled" \
  --set tabAdvanced='1' \
  --set mayChange='1' \
  --set multivalue='0' \
  --set deleteObjectClass='0' \
  --set tabPosition='1' \
  --set overwritePosition='0' \
  --set doNotSearch='0' \
  --set hook='None' || \
  univention-directory-manager settings/extended_attribute modify "$@" \
  --dn "cn=ownCloudUserEnabled,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" \
  --set tabAdvanced='1' \
  --set default="$owncloud_user_enabled"

univention-directory-manager settings/extended_attribute create "$@" \
  --position "cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" --set module="users/user" \
  --set ldapMapping='ownCloudQuota' \
  --set objectClass='ownCloudUser' \
  --set name='ownCloudUserQuota' \
  --set shortDescription='ownCloud Quota' \
  --set longDescription='How much disk space may the user use' \
  --set translationShortDescription='"de_DE" "ownCloud Quota"' \
  --set translationLongDescription='"de_DE" "Wie viel Speicherplatz darf der User verwenden"' \
  --set tabName='ownCloud' \
  --set translationTabName='"de_DE" "ownCloud"' \
  --set overwriteTab='0' \
  --set valueRequired='0' \
  --set CLIName='owncloudQuota' \
  --set syntax='string' \
  --set default="$owncloud_user_quota" \
  --set tabAdvanced='1' \
  --set mayChange='1' \
  --set multivalue='0' \
  --set deleteObjectClass='0' \
  --set tabPosition='1' \
  --set overwritePosition='0' \
  --set doNotSearch='0' \
  --set hook='None' || \
  univention-directory-manager settings/extended_attribute modify "$@" \
  --dn "cn=ownCloudUserQuota,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" \
  --set tabAdvanced='1'

univention-directory-manager settings/extended_attribute create "$@" \
  --position "cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" --set module="groups/group" \
  --set ldapMapping='ownCloudEnabled' \
  --set objectClass='ownCloudGroup' \
  --set name='ownCloudGroupEnabled' \
  --set shortDescription='ownCloud enabled' \
  --set longDescription='Wether Group may be used in ownCloud ' \
  --set translationShortDescription='"de_DE" "ownCloud aktiviert"' \
  --set translationLongDescription='"de_DE" "Die Gruppe in ownCloud verwenden"' \
  --set tabName='ownCloud' \
  --set translationTabName='"de_DE" "ownCloud"' \
  --set overwriteTab='0' \
  --set valueRequired='0' \
  --set CLIName='owncloudEnabled' \
  --set syntax='boolean' \
  --set default="$owncloud_group_enabled" \
  --set tabAdvanced='0' \
  --set mayChange='1' \
  --set multivalue='0' \
  --set deleteObjectClass='0' \
  --set tabPosition='1' \
  --set overwritePosition='0' \
  --set doNotSearch='0' \
  --set hook='None' || \
  univention-directory-manager settings/extended_attribute modify "$@" \
  --dn "cn=ownCloudGroupEnabled,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base" \
  --set tabAdvanced='1'

OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"
OWNCLOUD_BACKUP_DIR="${OWNCLOUD_DATA}/backup"

#echo "[03.JOIN] database check"
#mysql -uroot -p$(cat /etc/mysql.secret) -e "show databases" >> /root/databasecheck
#mysql -uroot -p$(cat /etc/mysql.secret) owncloud < ${OWNCLOUD_BACKUP_DIR}/database.sql


FQDN="$(ucr get hostname).$(ucr get domainname)"
if [ "$(ucr get appcenter/apps/onlyoffice-ds/status)" = "installed" ]; then
    echo "[03.JOIN] check for installation of ONLYOFFICE"
    univention-app shell owncloud occ app:enable onlyoffice
    if [[ "$(univention-app shell owncloud occ config:app:get onlyoffice DocumentServerUrl)" == "" ]]; then
        univention-app shell owncloud occ config:app:set onlyoffice DocumentServerUrl --value="https://$FQDN/onlyoffice-documentserver"
    fi
fi

if [ "$(ucr get appcenter/apps/collabora/status)" = "installed" ] || [ "$(ucr get appcenter/apps/collabora-online/status)" = "installed" ]; then
    echo "[03.JOIN] check for installation of Collabora"
    univention-app shell owncloud occ app:enable richdocuments

    if [[ "$(univention-app shell owncloud occ config:app:get richdocuments wopi_url)" == "" ]]; then
        univention-app shell owncloud occ config:app:set richdocuments wopi_url --value https://$FQDN/
    fi
fi

joinscript_save_current_version

# Make Appliance Administrator=ownCloud Administrator

udm users/user modify --dn=uid=Administrator,cn=users,$(ucr get ldap/base) --set owncloudEnabled=1

univention-app shell owncloud occ group:add-member --member Administrator admin

exit 0
