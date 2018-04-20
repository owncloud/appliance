#!/bin/bash
#
# An outer script called after setup is called
# based on join script by it25 owncloud integration
#

VERSION="1"

. /usr/share/univention-lib/base.sh
. /usr/share/univention-lib/ldap.sh
. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh

joinscript_init

eval "$(ucr shell)"

set -x

# Get owncloud specifid UCR values from container
eval "$(joinscript_run_in_container ucr --shell search owncloud | grep ^owncloud)"

# add admin docs link to overview page
OVBASE='ucs/web/overview/entries/admin/owncloud-admindoc'
ucr set \
	${OVBASE}/description="ownCloud Administration Manual" \
	${OVBASE}/description/de="ownCloud Administrations-Handbuch (in Englisch)" \
	${OVBASE}/icon?"/owncloud/core/img/favicon.png" \
	${OVBASE}/label?"Admin Manual" \
	${OVBASE}/label/de?"Admin Handbuch" \
	${OVBASE}/link="https://doc.owncloud.com/server/9.1/admin_manual/" \
	${OVBASE}/priority?95

# Remove schema from previous owncloud installations
ucs_unregisterLDAPExtension "$@" --schema owncloud

# Register owncloud ldap schema
joinscript_register_schema "$@" || die

ucs_addServiceToLocalhost "ownCloud" "$@"

univention-directory-manager container/cn create "$@" --ignore_exists \
                --position "$ldap_base" \
                --set name=owncloud

univention-directory-manager container/cn create "$@" --ignore_exists \
                --position "cn=owncloud,$ldap_base" \
                --set name=sysusers

ocsyspw="$(joinscript_run_in_container cat /etc/owncloudsystemuser.secret)"

udm users/user create "$@" --ignore_exists \
	--position "cn=sysusers,cn=owncloud,$ldap_base" \
    --set username="owncloudsystemuser" --set password="$ocsyspw" \
    --set lastname="OwncloudSystemuser" --option ldap_pwd
# set current password if user already existed in above call
udm users/user modify "$@" \
	--dn "uid=owncloudsystemuser,cn=sysusers,cn=owncloud,$ldap_base" \
	--set password="$ocsyspw"

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

echo "Restarting UDM server..." >&2    
stop_udm_cli_server

#enable Domain Users as ownCloud group
if [ "$owncloud_group_enableDomainUsers" = 1 ] ; then
	DN=$(univention-ldapsearch -o ldif-wrap=no '(univentiondefaultgroup=*)' univentiondefaultgroup | grep -Fi 'univentiondefaultgroup:' | sed -re 's/^\S+\s+//')
	if [ -n "${DN}" ] ; then
		gn=`echo ${DN} | cut -f 1 -d ','`
		echo "Enabling group '${gn}' for owncloud..."
		univention-directory-manager groups/group modify "$@" \
       	    --dn "${DN}" \
       	    --set owncloudEnabled='1'

		ucr set owncloud/group/enableDomainUsers=0
	fi
fi

# Add docker host to trusted domains
ips="$(python  -c "
from univention.config_registry.interfaces import Interfaces
for name, iface in Interfaces().all_interfaces: print iface.get('address')")"


HOSTS="$(ucr get hostname).$(ucr get domainname)"

for ip in $ips; do
	HOSTS="${HOSTS}\n${ip}"
done

joinscript_run_in_container sh -c "printf '${HOSTS}' > /tmp/trusted_domain_hosts"
joinscript_run_in_container /usr/sbin/fix_owncloud_trusted_domains

joinscript_save_current_version
exit 0