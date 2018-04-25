#! /bin/bash
# Variables

collabora_cert=/etc/univention/ssl/ucsCA/CAcert.pem
owncloud_certs=/var/www/owncloud/resources/config/ca-bundle.crt

echo "Is the collabora certificate is mounted correctly" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
if [ -f $collabora_cert ]
then
        echo "Yes.
        Was it updated?" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
        # Declaring the marker-string
        collab="This is a certificate for Collabora for ownCloud"
        if grep -Fq "$collab" "$owncloud_certs"
        then
                echo "Yes. 
                Certificate was already updated" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
        else
                echo "No. 
                Updating Certificate..." 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
                echo "$collab" >> $owncloud_certs
                cat $collabora_cert >> $owncloud_certs
                echo "Certificate has been succesfully updated" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log
        fi
else 
	echo "There is no Collabora Certificate" 2>&1 | tee --append /var/lib/univention-appcenter/apps/owncloud/data/files/owncloud-appcenter.log        
fi
#cat $collabora_log

echo "enabling log log rotate" 
sed -i "s#);#  'log_rotate_size' => 104857600,\n&#" $OWNCLOUD_CONF/config.php
