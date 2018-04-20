#! /bin/bash
# Variables

collabora_log=/var/log/collabora-certs-check.log
collabora_cert=/etc/univention/ssl/ucsCA/CAcert.pem
owncloud_certs=/var/www/owncloud/resources/config/ca-bundle.crt

echo "Is the collabora certificate is mounted correctly" >> $collabora_log
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

echo "enabling log log rotate" 
sed -i "s#);#  'log_rotate_size' => 104857600,\n&#" $OWNCLOUD_CONF/config.php
