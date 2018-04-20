#!/bin/bash
#
# An inner script, replacement of setup script
# based on postinst script by it25 owncloud integration
#


# Prepare data directories
DATADIR=/var/lib/owncloud
[ ! -e "$DATADIR" ]  && mkdir -p "$DATADIR"
chown -R www-data:www-data "$DATADIR"

# cleanup possible old installation leftovers
cleanup ()
{
	# dbexists=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$DB_NAME'"  | tail -1)
	dbexists=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "SELECT TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'oc_appconfig'"  | tail -1)
	if [ "$dbexists" = "$DB_NAME" ] ; then
		echo "Removing old owncloudadmin user and user_ldap settings"
		# remove owncloudadmin user
		mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "delete from oc_users where uid='owncloudadmin'" -D $DB_NAME || true
		# remove old ldap settings
		mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "delete from oc_appconfig where appid='user_ldap'" -D $DB_NAME || true
	fi
}

# Install owncloud
ucr set repository/online/component/php7=enabled \
	repository/online/component/php7/server="https://updates.software-univention.de/" \
	repository/online/component/php7/version=current \
	repository/online/component/php7/description="PHP 7 for UCS"

ucr set mysql/autostart=false

/usr/share/univention-docker-container-mode/setup "$@" || die "Setup failed"

#apt-get install -y --force-yes apache2-mpm-prefork wget php7.0-ldap
service apache2 stop
a2enmod ssl
a2ensite default-ssl
a2enmod php7.0
a2enmod headers
service apache2 start

echo > /etc/apache2/conf.d/HSTS.conf 'Header add Strict-Transport-Security: "max-age=15768000;includeSubdomains"'

cleanup

. /usr/share/univention-lib/all.sh

# from owncloud meta postinst
chown -R www-data:www-data /var/www/owncloud
chmod u+x /var/www/owncloud/occ


# set default UCR values
ucr set owncloud/directory/data?"/var/lib/owncloud" \
	owncloud/db/name?"$DB_NAME" \
	owncloud/join/users/update?"yes" \
	owncloud/join/users/filter?"(&(|(&(objectClass=posixAccount)(objectClass=shadowAccount))(objectClass=univentionMail)(objectClass=sambaSamAccount)(objectClass=simpleSecurityObject)(&(objectClass=person)(objectClass=organizationalPerson)(objectClass=inetOrgPerson)))(!(uidNumber=0))(!(|(uid=*$)(uid=owncloudsystemuser)(uid=join-backup)(uid=join-slave)))(!(objectClass=ownCloudUser)))" \
	owncloud/join/groups/filter?"" \
	owncloud/user/quota?"1000000000" \
	owncloud/user/enabled?"1" \
	owncloud/group/enabled?"0" \
	owncloud/group/enableDomainUsers?"1" \
	owncloud/ldap/disableMainServer?"0" \
	owncloud/ldap/cacheTTL?"600" \
	owncloud/ldap/user/quotaAttribute?"ownCloudQuota" \
	owncloud/ldap/user/homeAttribute?"uid" \
	owncloud/ldap/user/searchAttributes?"uid,givenName,sn,description,employeeNumber,mailPrimaryAddress" \
	owncloud/ldap/group/displayName?"cn" \
	owncloud/ldap/group/searchAttributes?"cn,description,mailPrimaryAddress" \
	owncloud/ldap/groupMemberAssoc?"uniqueMember" \
	owncloud/ldap/tls?"1" \
	owncloud/ldap/displayName?"displayName" \
	owncloud/ldap/base/users?"" \
	owncloud/ldap/base/groups?"" \
	owncloud/ldap/loginFilter?"(&(|(&(objectClass=posixAccount)(objectClass=shadowAccount))(objectClass=univentionMail)(objectClass=sambaSamAccount)(objectClass=simpleSecurityObject)(&(objectClass=person)(objectClass=organizationalPerson)(objectClass=inetOrgPerson)))(!(uidNumber=0))(!(uid=*$))(&(uid=%uid)(ownCloudEnabled=1)))" \
	owncloud/ldap/userlistFilter?"(&(|(&(objectClass=posixAccount)(objectClass=shadowAccount))(objectClass=univentionMail)(objectClass=sambaSamAccount)(objectClass=simpleSecurityObject)(&(objectClass=person)(objectClass=organizationalPerson)(objectClass=inetOrgPerson)))(!(uidNumber=0))(!(uid=*$))(&(ownCloudEnabled=1)))" \
	owncloud/ldap/groupFilter?"(&(objectClass=posixGroup)(ownCloudEnabled=1))" \
	owncloud/ldap/internalNameAttribute?"uid" \
	owncloud/ldap/UUIDAttribute?""

# Add the user display attribute to the list of search attributes if not present
disp_attr=`ucr get owncloud/ldap/displayName`
search_attrs=`ucr get owncloud/ldap/user/searchAttributes`
if ! echo "${search_attrs}" | grep -wiq ${disp_attr}; then
	ucr set owncloud/ldap/user/searchAttributes=${search_attrs},${disp_attr}
fi

eval "$(univention-config-registry shell)"

# new installation, no config available
owncloudadminpw="owncloud"
if [ ! -f /var/www/owncloud/config/config.php ] && [ ! -f /var/lib/univention-appcenter/apps/owncloud82/conf/config.php ] ; then
cat > "/var/www/owncloud/config/autoconfig.php" <<EOF
<?php
\$AUTOCONFIG = array(
"dbtype" => 'mysql',
"dbhost" => '$DB_HOST:$DB_PORT',
"directory" => "$owncloud_directory_data",
"adminlogin" => "owncloudadmin",
"adminpass" => "$owncloudadminpw",
"dbuser" => "$DB_USER",
"dbpass" => "$DB_PASSWORD",
"dbname" => "$DB_NAME",
"trusted_domains" => array (
0 => "$hostname.$domainname",
1 => "$hostip",
EOF
	# add IPs to trusted Domains array
	# will be updated later, required for initial autoconfig
	n=1
	ips="$(python  -c "
from univention.config_registry.interfaces import Interfaces
for name, iface in Interfaces().all_interfaces: print iface.get('address')")"
	for ip in $ips; do
		n=`expr $n + 1`
		cat >> "/var/www/owncloud/config/autoconfig.php" <<EOF
$n => "$ip",
EOF
	done
	cat >> "/var/www/owncloud/config/autoconfig.php" <<EOF
),
);
?>
EOF

	# create  data directory
	if [ ! -d "$owncloud_directory_data" ] ; then
		mkdir -p "$owncloud_directory_data"
		chown -R www-data:www-data "$owncloud_directory_data"
	fi

	# kickoff auto setup
	host="$hostname.$domainname"
	chown www-data:www-data /var/www/owncloud/config/autoconfig.php
	wget -q --no-proxy --delete-after "http://$host/owncloud/index.php"
else
	# migration fix: if config.php exists in transfer-folder, update it with new credentials
	if [ -f /var/lib/univention-appcenter/apps/owncloud82/conf/config.php ] ; then
	cp /var/lib/univention-appcenter/apps/owncloud82/conf/config.php /var/www/owncloud/config/config.php
        cp /var/lib/univention-appcenter/apps/owncloud82/conf/config.php /var/www/owncloud/config/config.php.orig
        #make sure the config-folder has the right owner!
	chown -R www-data:www-data "/var/www/owncloud/config"
	# add new host to trusted domain, delete old one?
	td_amount=$(php /var/www/owncloud/occ config:system:get trusted_domains | wc -l)
	#sudo -u www-data php occ config:system:set trusted_domains $td_amount --value $hostname.$domainname
	su -c 'php /var/www/owncloud/occ config:system:set trusted_domains $td_amount --value $hostname.$domainname' www-data
	#su -c 'php /var/www/owncloud/occ config:system:set trusted_domains $td_amount --value $hostip' www-data
	#change host
	sed -i "s/'dbhost'.*/'dbhost' => '$DB_HOST:$DB_PORT',/" /var/www/owncloud/config/config.php
        
        #update password of owncloudadmin on the host-system
	export OC_PASS=$owncloudadminpw
	su -c 'php /var/www/owncloud/occ user:resetpassword owncloudadmin --password-from-env -q' www-data 2>&1 /var/log/owncloud_pwd_reset.log
        fi
	# start update to new version after the migration-fix and a normal update (e.g. 9.1.1 -> 9.1.5)
	su -c 'php /var/www/owncloud/occ upgrade' www-data 2>&1 /var/log/owncloud_update.log
fi

###
# Owncloud autoconfig has run.

# Setup system user

if [ ! -e "/etc/owncloudsystemuser.secret" ]; then
	#create a user to use for ldap-searches
	. /usr/share/univention-lib/all.sh
	ocsyspw=$(create_machine_password)
	echo -n "$ocsyspw" > "/etc/owncloudsystemuser.secret"
	chmod 600 "/etc/owncloudsystemuser.secret"
else
	ocsyspw="$(cat "/etc/owncloudsystemuser.secret")"
	#fix a bug in from Join Script Version 2.
	if [ "$ocsyspw" == "ocsyspw" ]; then
		ocsyspw=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "select configvalue from oc_appconfig where appid='user_ldap' and configkey='ldap_agent_password'" -D $DB_NAME | tail -1 | base64 -d)
		echo -n "$ocsyspw" > "/etc/owncloudsystemuser.secret"
	fi
fi

ocsyspwb64=$(php -r "echo(base64_encode('$ocsyspw'));" | tail -1)

# Setup MYSQL database

run_mysql_ins_qry () {
	local appid=${4:-user_ldap}
	if [ "`mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -s -e "select count(configkey) from oc_appconfig where appid='$appid' AND configkey='$1'" -D $DB_NAME | tail -1`" -eq "0" ]; then
		if [ "$3" = "--func" ]; then
			value=$2
		else
			value="'$2'"
		fi
		mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "INSERT INTO oc_appconfig (appid, configkey, configvalue) VALUES ('$appid', '$1', $value)" -D $DB_NAME
	else
		echo "ownCloud config: value for $1 is already set, skipping."
		false
	fi
}

# TODO: what does this script do? Is it still required?
#if [ "$owncloud_join_users_update" = "yes" ]; then
#	/usr/share/owncloud/update-users.sh "$@"
#fi

need_occ_upgrade=false

run_mysql_ins_qry "ldap_host" "$ldap_server_name"
run_mysql_ins_qry "ldap_port" "$ldap_server_port"
run_mysql_ins_qry "ldap_dn" "uid=owncloudsystemuser,cn=sysusers,cn=owncloud,$ldap_base"
run_mysql_ins_qry "ldap_agent_password" "$ocsyspwb64"
run_mysql_ins_qry "ldap_base" "$ldap_base"
run_mysql_ins_qry "ldap_base_users" "$owncloud_ldap_base_users"
run_mysql_ins_qry "ldap_base_groups" "$owncloud_ldap_base_groups"
run_mysql_ins_qry "ldap_login_filter" "$owncloud_ldap_loginFilter"
run_mysql_ins_qry "ldap_userlist_filter" "$owncloud_ldap_userlistFilter"
run_mysql_ins_qry "ldap_group_filter" "$owncloud_ldap_groupFilter"
run_mysql_ins_qry "ldap_display_name" "$owncloud_ldap_displayName"
run_mysql_ins_qry "ldap_quota_attr" "$owncloud_ldap_user_quotaAttribute"
homeAttribute=""
if [ ! -z "$owncloud_ldap_user_homeAttribute" ]; then
	homeAttribute="attr:$owncloud_ldap_user_homeAttribute"
fi
run_mysql_ins_qry "home_folder_naming_rule" "$homeAttribute"
run_mysql_ins_qry "ldap_attributes_for_user_search" "REPLACE('$owncloud_ldap_user_searchAttributes', ',', '\n')" "--func"
run_mysql_ins_qry "ldap_attributes_for_group_search" "REPLACE('$owncloud_ldap_group_searchAttributes', ',', '\n')" "--func"
run_mysql_ins_qry "ldap_override_main_server" "$owncloud_ldap_disableMainServer"
run_mysql_ins_qry "ldap_tls" "$owncloud_ldap_tls"
run_mysql_ins_qry "ldap_nocase" "0"
run_mysql_ins_qry "ldap_cache_ttl" "$owncloud_ldap_cacheTTL"
run_mysql_ins_qry "ldap_group_member_assoc_attribute" "$owncloud_ldap_groupMemberAssoc"
run_mysql_ins_qry "ldap_group_display_name" "$owncloud_ldap_group_displayName"
run_mysql_ins_qry "ldap_expert_username_attr" "$owncloud_ldap_internalNameAttribute"
run_mysql_ins_qry "ldap_expert_uuid_attr" "$owncloud_ldap_UUIDAttribute"

# We know for sure which mail attribute is used here, regardless of the groupware being used
run_mysql_ins_qry "ldap_email_attr" "mailPrimaryAddress"

# locks the filter in raw mode, otherwise the LDAP Wizard would overwrite them
run_mysql_ins_qry "ldap_user_filter_mode" "1"
run_mysql_ins_qry "ldap_login_filter_mode" "1"
run_mysql_ins_qry "ldap_group_filter_mode" "1"

# activate configuration
run_mysql_ins_qry "ldap_configuration_active" "1"

mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "UPDATE oc_appconfig SET configvalue='yes' WHERE appid='user_ldap' AND configkey='enabled'" -D $DB_NAME
#in case it's not there (purge)
run_mysql_ins_qry "installed_version" "0.1.99" && need_occ_upgrade=true
run_mysql_ins_qry "enabled" "yes"

$need_occ_upgrade && su -c "/var/www/owncloud/occ upgrade" www-data 2>&1

run_mysql_ins_qry "types" "authentication"

# Set default mode to cron if not already set
if run_mysql_ins_qry "backgroundjobs_mode" "cron" '' "core"; then
	# TODO: this should probably be executed in the container
	CF=/var/www/owncloud/config/config.php
	cp ${CF} ${CF}.bak
	(
		grep -vF ');' ${CF}.bak
		echo "  'overwritewebroot' => '/owncloud',"
		echo ');'
	) >${CF}
	# establish a cron job every $CRON_MINUTES (only if not already present)
	CRON_MINUTES=15
	CRON_START=$((1+(${RANDOM}%(${CRON_MINUTES}-1))))
	if ! crontab -lu www-data 2>/dev/null | grep -q 'owncloud/cron.php'; then
		echo "Adding crontab entry for user www-data..."
		(
			crontab -lu www-data 2>/dev/null
			echo
			echo "# added by owncloud on `date`"
			echo "${CRON_START}-59/${CRON_MINUTES} * * * *	[ -f /var/www/owncloud/cron.php ] && `which php` /var/www/owncloud/cron.php"
		) | crontab -u www-data -
	fi
fi

# switch off usage of memberof overlay
run_mysql_ins_qry "use_memberof_to_detect_membership" "0"

# End setup MYSQL database

# Switch off update check: not needed here.
CONF=/var/www/owncloud/config/config.php
(
	echo '<?php'
	echo -n '$CONFIG = '
	php -r "include('${CONF}'); \$CONFIG['updatechecker'] = false; var_export(\$CONFIG);"
	echo ';'
) >${CONF}.new
chown www-data:www-data ${CONF}.new
mv -f ${CONF}.new ${CONF}

# Add UCS ROOT CA to the CA bundle shipped since 8.1
[ -x /usr/share/owncloud/maintain-ca-bundle.sh ] && /usr/share/owncloud/maintain-ca-bundle.sh

# Prepare script to update trusted_domains, will be adapted and executed in joinscript
cat >/usr/sbin/fix_owncloud_trusted_domains <<__EOF__
#!/bin/bash
cd /var/www/owncloud/config
(
echo '<?php'
echo -ne '\$CONFIG = '
php -r "include('config.php'); \\\$hosts = file('/tmp/trusted_domain_hosts', FILE_IGNORE_NEW_LINES); \\\$CONFIG['trusted_domains'] = \\\$hosts; var_export(\\\$CONFIG);"
echo ';'
) > config.php.updated
mv -f config.php.updated config.php
chown www-data:www-data config.php
chmod 640 config.php
__EOF__
chmod +x /usr/sbin/fix_owncloud_trusted_domains


exit 0