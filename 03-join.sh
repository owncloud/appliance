#!/bin/bash
# join
# outer script
VERSION=3
SERVICE="ownCloud"

. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
. /usr/share/univention-lib/ldap.sh

joinscript_init
eval "$(ucr shell)"

ucs_addServiceToLocalhost ${SERVICE} "$@" || die
ICON_PATH="/univention/js/dijit/themes/umc/icons/scalable/apps-"$(univention-app get owncloud component_id --values-only)".svg"

ICON_USER="/usr/share/univention-management-console-frontend/js/dijit/themes/umc/icons/scalable/owncloudUser.svg"
ICON_GROUP="/usr/share/univention-management-console-frontend/js/dijit/themes/umc/icons/scalable/owncloudGroup.svg"
[ -e "$ICON_USER" ] && rm "$ICON_USER"
ln -s "apps-$(univention-app get owncloud component_id --values-only)".svg "$ICON_USER"
[ -e "$ICON_GROUP" ] && rm "$ICON_GROUP"
ln -s "apps-$(univention-app get owncloud component_id --values-only)".svg "$ICON_GROUP"

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

exit 0
