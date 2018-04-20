#!/bin/bash

# outer script, running after container destroyed, think of postRemove
# - update
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

echo "Dropping ownCloud admin docs..."
OVBASE='ucs/web/overview/entries/admin/owncloud-admindoc'
ucr unset \
  ${OVBASE}/description \
  ${OVBASE}/description/de \
  ${OVBASE}/icon \
  ${OVBASE}/label \
  ${OVBASE}/label/de \
  ${OVBASE}/link \
  ${OVBASE}/priority

echo "Dropping ownCloud user docs..."
OVBASE='ucs/web/overview/entries/admin/owncloud-userdoc'
ucr unset \
  ${OVBASE}/description \
  ${OVBASE}/description/de \
  ${OVBASE}/icon \
  ${OVBASE}/label \
  ${OVBASE}/label/de \
  ${OVBASE}/link \
  ${OVBASE}/priority
  
udm container/cn remove "$@" --dn "cn=owncloud,cn=custom
attributes,cn=univention,$(ucr get ldap/base)"

echo "Dropping ownCloud database..."
mysql -u root -p$(cat /etc/mysql.secret) owncloud -e "DROP DATABASE IF EXISTS owncloud"

exit 0
