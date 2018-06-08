#! /bin/bash
# Variables
OWNCLOUD_PERM_DIR="/var/lib/univention-appcenter/apps/owncloud"
OWNCLOUD_DATA="${OWNCLOUD_PERM_DIR}/data"
OWNCLOUD_CONF="${OWNCLOUD_PERM_DIR}/conf"
OWNCLOUD_CONF_LDAP="${OWNCLOUD_CONF}/ldap"
collabora_log=/var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
collabora_cert=/etc/univention/ssl/ucsCA/CAcert.pem
owncloud_certs=/var/www/owncloud/resources/config/ca-bundle.crt

echo "[03.RESTORE_DATA] Is the collabora certificate is mounted correctly" >> $collabora_log
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

echo "[03.RESTORE_DATA] enabling log log rotate" 
sed -i "s#);#  'log_rotate_size' => 104857600,\n&#" $OWNCLOUD_CONF/config.php

echo "[03.RESTORE_DATA] configuring owncloud for onlyoffice use"
sed -i "s#);#  'onlyoffice' => array ('verify_peer_off' => TRUE),\n&#" $OWNCLOUD_CONF/config.php