#!/bin/bash
# unjoin
# outer script, running after container destroyed, think of postRemove
# - uninstall

VERSION=2
SERVICE="ownCloud"

. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
. /usr/share/univention-lib/ldap.sh

joinscript_init

eval "$(ucr shell)"
ucs_removeServiceFromLocalhost ${SERVICE} "$@" || die

if ucs_isServiceUnused "$SERVICE" "$@"; then
  ucr unset $(ucr search --key "^owncloud" | cut -d ":" -f 1 | grep owncloud | tr '\n' ' ')
fi

joinscript_remove_script_from_status_file owncloud

echo "[05.UNJOIN] Dropping ownCloud admin docs..." 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
OVBASE='ucs/web/overview/entries/admin/owncloud-admindoc'
ucr unset \
  ${OVBASE}/description \
  ${OVBASE}/description/de \
  ${OVBASE}/icon \
  ${OVBASE}/label \
  ${OVBASE}/label/de \
  ${OVBASE}/link \
  ${OVBASE}/priority

echo "[05.UNJOIN] Dropping ownCloud user docs..." 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
OVBASE='ucs/web/overview/entries/admin/owncloud-userdoc'
ucr unset \
  ${OVBASE}/description \
  ${OVBASE}/description/de \
  ${OVBASE}/icon \
  ${OVBASE}/label \
  ${OVBASE}/label/de \
  ${OVBASE}/link \
  ${OVBASE}/priority
  
udm container/cn remove "$@" --dn "cn=owncloud,cn=custom attributes,cn=univention,$(ucr get ldap/base)"
udm oidc/rpservice remove "$@" --dn "cn=owncloud,cn=oidc,cn=univention,$(ucr get ldap/base)"

echo "[05.UNJOIN] Dropping ownCloud database..." 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
mysql -u root -p$(cat /etc/mysql.secret) owncloud -e "DROP DATABASE IF EXISTS owncloud"

echo "[05.UNJOIN] removing owncloud.secret file"
rm /etc/owncloud.secret

exit 0