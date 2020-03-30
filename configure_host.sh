#!/bin/bash
# the file "/tmp/do-not-restart" is created in the PreInst and PreRm script.

eval $(ucr shell)
set -x

main () 
{
shib2_xml="/var/lib/univention-appcenter/apps/owncloud/conf/shibboleth2.xml"
shibd_conf="/var/lib/univention-appcenter/apps/owncloud/conf/shibd.conf"
apache_subpath_conf="/var/lib/univention-appcenter/apps/owncloud/conf/apache_subpath.conf"

write_configfiles

docker cp "$apache_subpath_conf" "$(ucr get appcenter/apps/owncloud/container)":/root/
docker cp "$shibd_conf" "$(ucr get appcenter/apps/owncloud/container)":/etc/apache2/conf-enabled/
docker cp "$shib2_xml" "$(ucr get appcenter/apps/owncloud/container)":/etc/shibboleth/shibboleth2.xml
# TODO: its fine to use local UMC cache, but maybe try to download current metadata from IdP?
docker cp /usr/share/univention-management-console/saml/idp/*.xml "$(ucr get appcenter/apps/owncloud/container)":/etc/shibboleth/idp.xml
ssl_path=$(ucr get appcenter/apps/owncloud/hostdn | python -c 'import ldap, sys; print ldap.dn.str2dn(sys.stdin.read())[0][0][1]')
docker cp "/etc/univention/ssl/$ssl_path/cert.pem" "$(ucr get appcenter/apps/owncloud/container)":/etc/shibboleth/sp-cert.pem
docker cp "/etc/univention/ssl/$ssl_path/private.key" "$(ucr get appcenter/apps/owncloud/container)":/etc/shibboleth/sp-key.pem

if [ -e /tmp/do-not-restart ]
then
	rm /tmp/do-not-restart
else
	service apache2 reload
	echo "sleep 10; univention-app restart owncloud" | at now
fi
}

write_configfiles ()
{
# Docker container shibboleth / apache2 config
cat >/var/lib/univention-appcenter/apps/owncloud/conf/shibboleth2.xml.template <<__EOF__
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"    
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">

    <!--
    By default, in-memory StorageService, ReplayCache, ArtifactMap, and SessionCache
    are used. See example-shibboleth2.xml for samples of explicitly configuring them.
    -->

    <!--
    To customize behavior for specific resources on Apache, and to link vhosts or
    resources to ApplicationOverride settings below, use web server options/commands.
    See https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPConfigurationElements for help.
    
    For examples with the RequestMap XML syntax instead, see the example-shibboleth2.xml
    file, and the https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPRequestMapHowTo topic.
    -->

    <!-- The ApplicationDefaults element is where most of Shibboleth's SAML bits are defined. -->
    <ApplicationDefaults entityID="https://@%@hostname@%@.@%@domainname@%@@%@owncloud/saml/path@%@"
                         REMOTE_USER="eppn persistent-id targeted-id">

        <!--
        Controls session lifetimes, address checks, cookie handling, and the protocol handlers.
        You MUST supply an effectively unique handlerURL value for each of your applications.
        The value defaults to /Shibboleth.sso, and should be a relative path, with the SP computing
        a relative value based on the virtual host. Using handlerSSL="true", the default, will force
        the protocol to be https. You should also set cookieProps to "https" for SSL-only sites.
        Note that while we default checkAddress to "false", this has a negative impact on the
        security of your site. Stealing sessions via cookie theft is much easier with this disabled.
        -->
        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false" handlerSSL="false" cookieProps="http">

            <!--
            Configures SSO for a default IdP. To allow for >1 IdP, remove
            entityID property and adjust discoveryURL to point to discovery service.
            (Set discoveryProtocol to "WAYF" for legacy Shibboleth WAYF support.)
            You can also override entityID on /Login query string, or in RequestMap/htaccess.
            -->
            <SSO entityID="@%@umc/saml/idp-server@%@"
                 discoveryProtocol="SAMLDS" discoveryURL="https://ds.example.org/DS/WAYF">
              SAML2 SAML1
            </SSO>

            <!-- SAML and local-only logout. -->
            <Logout>SAML2 Local</Logout>
            
            <!-- Extension service that generates "approximate" metadata based on SP configuration. -->
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>

            <!-- Status reporting service. -->
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>

            <!-- Session diagnostic service. -->
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>

            <!-- JSON feed of discovery information. -->
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>

        <!--
        Allows overriding of error template information/filenames. You can
        also add attributes with values that can be plugged into the templates.
        -->
        <Errors supportContact="root@localhost"
            helpLocation="/about.html"
            styleSheet="/shibboleth-sp/main.css"/>
        
        <!-- Example of remotely supplied batch of signed metadata. -->
        <!--
        <MetadataProvider type="XML" uri="http://federation.org/federation-metadata.xml"
              backingFilePath="federation-metadata.xml" reloadInterval="7200">
            <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
            <MetadataFilter type="Signature" certificate="fedsigner.pem"/>
        </MetadataProvider>
        -->

        <!-- Example of locally maintained metadata. -->
        <MetadataProvider type="XML" file="idp.xml"/>

        <!-- Map to extract attributes from SAML assertions. -->
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        
        <!-- Use a SAML query if no attributes are supplied during SSO. -->
        <AttributeResolver type="Query" subjectMatch="true"/>

        <!-- Default filtering policy for recognized attributes, lets other data pass. -->
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>

        <!-- Simple file-based resolver for using a single keypair. -->
        <CredentialResolver type="File" key="sp-key.pem" certificate="sp-cert.pem"/>

        <!--
        The default settings can be overridden by creating ApplicationOverride elements (see
        the https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPApplicationOverride topic).
        Resource requests are mapped by web server commands, or the RequestMapper, to an
        applicationId setting.
        
        Example of a second application (for a second vhost) that has a different entityID.
        Resources on the vhost would map to an applicationId of "admin":
        -->
        <!--
        <ApplicationOverride id="admin" entityID="https://admin.example.org/shibboleth"/>
        -->
    </ApplicationDefaults>
    
    <!-- Policies that determine how to process and authenticate runtime messages. -->
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>

    <!-- Low-level configuration about protocols and bindings available for use. -->
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>

</SPConfig>
__EOF__

cat /var/lib/univention-appcenter/apps/owncloud/conf/shibboleth2.xml.template | ucr filter > "$shib2_xml" 


cat >/var/lib/univention-appcenter/apps/owncloud/conf/shibd.conf.template <<__EOF__
@%@UCRWARNING=# @%@
#
# Load the Shibboleth module.
#
LoadModule mod_shib /usr/lib64/shibboleth/mod_shib_24.so

#
# Ensures handler will be accessible.
#
<Location /Shibboleth.sso>
  AuthType None
  Require all granted
</Location>

#
# Configure the module for content.
#

#
# Besides the exceptions below, this location is now under control of
# Shibboleth
#
<Location @%@owncloud/saml/path@%@>
        AuthType shibboleth
        ShibRequireSession On
        ShibUseHeaders Off
        ShibExportAssertion On
        require valid-user
</Location>

#
# Allow access to Sharing API (and others) without Shibboleth
#
<Location ~ "/ocs">
        AuthType None
        Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow non
# shibboleth webdav access
#
<Location ~ "@%@owncloud/saml/path@%@/remote.php/nonshib-webdav">
        AuthType None
        Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow public link
# sharing
#
<Location ~ \
"@%@owncloud/saml/path@%@/(status.php$\
|index.php/s/\
|public.php\
|cron.php$\
|core/img/\
|index.php/apps/files_sharing/ajax/publicpreview.php$\
|index.php/apps/files/ajax/upload.php$\
|apps/files/templates/fileexists.html$\
|index.php/apps/files/ajax/mimeicon.php$\
|index.php/apps/files_sharing/ajax/list.php$\
|themes/\
|index.php/apps/files_pdfviewer/\
|apps/files_pdfviewer/)">
  AuthType None
  Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow public gallery
# sharing
#
<Location ~ \
"@%@owncloud/saml/path@%@/(index.php/apps/gallery/s/\
|index.php/apps/gallery/slideshow$\
|index.php/apps/gallery/.*\.public)">
  AuthType None
  Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow onlyoffice and collabora
#
<Location ~ \
"@%@owncloud/saml/path@%@/(index.php/apps/richdocuments/\
|index.php/apps/onlyoffice/)">
  AuthType None
  Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow public link
# sharing
#
<Location ~ "@%@owncloud/saml/path@%@/.*\.css">
  AuthType None
  Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow public link
# sharing
#
<Location ~ "@%@owncloud/saml/path@%@/.*\.js">
  AuthType None
  Require all granted
</Location>

#
# Shibboleth is disabled for the following location to allow public link
# sharing
#
<Location ~ "@%@owncloud/saml/path@%@/.*\.woff">
  AuthType None
  Require all granted
</Location>
__EOF__

cat /var/lib/univention-appcenter/apps/owncloud/conf/shibd.conf.template | ucr filter > "$shibd_conf"


cat >/var/lib/univention-appcenter/apps/owncloud/conf/apache_subpath.conf.template <<__EOF__
@%@UCRWARNING=# @%@
<VirtualHost *:80>
  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/owncloud

  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined

  #RewriteEngine On
  #RewriteCond %{REQUEST_URI} !^${OWNCLOUD_SUB_URL}
  #RewriteRule ^(.*)$ ${OWNCLOUD_SUB_URL}$1 [R=301,L]

  Alias ${OWNCLOUD_SUB_URL} /var/www/owncloud
  Alias @%@owncloud/saml/path@%@ /var/www/owncloud

  <Directory ${OWNCLOUD_SUB_URL}>
    AllowOverride All
    Options -Indexes
  </Directory>

  <IfModule mod_headers.c>
    Header always set Strict-Transport-Security "max-age=15768000; preload"
  </IfModule>
</VirtualHost>

<IfModule mod_ssl.c>
  <VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/owncloud

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    #RewriteEngine On
    #RewriteCond %{REQUEST_URI} !^${OWNCLOUD_SUB_URL}
    #RewriteRule ^(.*)$ ${OWNCLOUD_SUB_URL}$1 [R=301,L]

    Alias ${OWNCLOUD_SUB_URL} /var/www/owncloud
    Alias @%@owncloud/saml/path@%@ /var/www/owncloud

    <Directory ${OWNCLOUD_SUB_URL}>
      AllowOverride All
      Options -Indexes
    </Directory>

    <IfModule mod_headers.c>
      Header always set Strict-Transport-Security "max-age=15768000; preload"
    </IfModule>

    SSLEngine on
    SSLCertificateFile ${OWNCLOUD_VOLUME_CERTS}/ssl-cert.crt
    SSLCertificateKeyFile ${OWNCLOUD_VOLUME_CERTS}/ssl-cert.key
  </VirtualHost>
</IfModule>
__EOF__

cat /var/lib/univention-appcenter/apps/owncloud/conf/apache_subpath.conf.template | ucr filter > "$apache_subpath_conf"

# UCS apache2 config

python -c "from univention.appcenter.app_cache import Apps
from univention.appcenter.utils import app_ports
from univention.config_registry import ConfigRegistry

configRegistry = ConfigRegistry()
configRegistry.load()

for app_id, container_port, host_port in app_ports():
	if app_id == 'owncloud':
		app = Apps().find(app_id)
		scheme = app.web_interface_proxy_scheme
		if scheme == 'both':
			scheme = 'https'
		if app.web_interface_port_https == container_port:
			print '''# Written by owncloud app configuer_host script
ProxyPass %(web_interface)s %(scheme)s://127.0.0.1:%(web_port)s%(web_interface)s retry=0
ProxyPass /Shibboleth.sso/ %(scheme)s://127.0.0.1:%(web_port)s/Shibboleth.sso/ retry=0
''' % {'id': app.id, 'web_interface': configRegistry.get('owncloud/saml/path', '/oc-shib'), 'web_port': host_port, 'scheme': scheme}" > /etc/apache2/ucs-sites.conf.d/owncloud_shibboleth_proxy.conf
}

main "$@"
