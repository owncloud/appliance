#!/bin/bash

OWNCLOUD_PERMCONF_DIR="/var/lib/univention-appcenter/apps/owncloud/conf"
OWNCLOUD_LDAP_FILE="${OWNCLOUD_PERMCONF_DIR}/ldap"

mkdir -p ${OWNCLOUD_PERMCONF_DIR}
eval "$(ucr shell)"

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

ucr --shell search owncloud | grep ^owncloud >| ${OWNCLOUD_LDAP_FILE}

exit 0
