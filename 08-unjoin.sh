#!/bin/bash
#
# An outer script called after container removal
# based on unjoin script by it25 owncloud integration
#

VERSION="1"

. /usr/share/univention-lib/base.sh
. /usr/share/univention-lib/ldap.sh
. /usr/share/univention-join/joinscripthelper.lib

joinscript_init

SERVICE="ownCloud"

eval "$(ucr shell)"

ucs_removeServiceFromLocalhost "${SERVICE}" "$@"

if ucs_isServiceUnused "${SERVICE}" "$@"; then
        # remove LDAP tracks
        echo "Cleaning up LDAP ..."
        udm users/user remove "$@" --dn="uid=owncloudsystemuser,cn=sysusers,cn=owncloud,$ldap_base"
        udm settings/extended_attribute remove "$@" --dn="cn=ownCloudUserEnabled,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base"
        udm settings/extended_attribute remove "$@" --dn="cn=ownCloudGroupEnabled,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base"
        udm settings/extended_attribute remove "$@" --dn="cn=ownCloudUserQuota,cn=owncloud,cn=custom attributes,cn=univention,$ldap_base"
        udm container/cn remove "$@" --dn="cn=sysusers,cn=owncloud,$ldap_base"
        udm container/cn remove "$@" --dn="cn=owncloud,$ldap_base"
        udm container/cn remove "$@" --dn="cn=owncloud,cn=custom attributes,cn=univention,$ldap_base"

        stop_udm_cli_server
fi

joinscript_remove_script_from_status_file owncloud82

OVBASE='ucs/web/overview/entries/admin/owncloud-admindoc'
ucr unset \
        ${OVBASE}/description \
        ${OVBASE}/description/de \
        ${OVBASE}/icon \
        ${OVBASE}/label \
        ${OVBASE}/label/de \
        ${OVBASE}/link \
        ${OVBASE}/priority

echo "Creating markerfile..."
mkdir -p /var/lib/univention-appcenter/apps/owncloud/data/files/
echo "if this file exists and you install the ownCloud 10 App, your data of oC 9 will be migrated" > /var/lib/univention-appcenter/apps/owncloud/data/files/tobemigrated

exit 0
