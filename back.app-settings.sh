# Settings that can be used to configure the App. ini file format.


[OWNCLOUD_LICENSE_KEY]
Description = OwnCloud enterprise license Key
Description[de] = OwnCloud Enterprise Lizenzschlüssel
Type = String
InitialValue = ""
Required = false
Show = Settings

[OWNCLOUD_MARKETPLACE_APIKEY]
Description = OwnCloud marketplace API key
Description[de] = OwnCloud Markt API Schlüssel
Type = String
InitialValue = ""
Required = false
Show = Settings

[OWNCLOUD_DEFAULT_LANGUAGE]
Description = Configure the ownCloud default language. Valid values: 'en', 'de', 'fr', ...
Description[de] = Konfiguriert die Standard Sprache. Gültige Werte sind z.B. 'en', 'de', 'fr', ...
Type = String
InitialValue = en
Required = false
Show = Settings

[OWNCLOUD_DOMAIN]
Description = Setting for OWNCLOUD_DOMAIN env variable. Together with SUB_URL this defines the owncloud setting overwrite.cli.url. 
Description[de] = Einstellung für die OWNCLOUD_DOMAIN env Variable. Zusammen mit der Einstellung SUB_URL wird die Option overwrite.cli.url gesetzt. 
Type = String
InitialValue = @%@hostname@%@.@%@domainname@%@
Required = false
Show = Settings

[OWNCLOUD_SUB_URL]
Description = Setting for OWNCLOUD_SUB_URL env variable. Together with DOMAIN this defines the owncloud setting overwrite.cli.url. This setting also configues the htaccess.RewriteBase option. (default: /owncloud)
Description[de] = Einstellung für die OWNCLOUD_SUB_URL env Variable. Zusammen mit der Einstellung DOMAIN wird die Option overwrite.cli.url gesetzt. Diese Einstellung konfiguriert außerdem die Option htaccess.RewriteBase. (Standard: /owncloud)
Type = String
InitialValue = /owncloud
Required = false
Show = Settings

[OWNCLOUD_LOG_LEVEL]
Description = Configure the ownCloud Log Level. Valid values are 0, 1, 2, 3, 4.
Description[de] = Setzt den ownCloud Log Level. Gültige Werte sind 0, 1, 2, 3, 4.
Type = String
InitialValue = 3
Required = false
Show = Settings

[OWNCLOUD_LOST_PASSWORD_LINK]
Description = Configure the Reset Password Link. Valid values are true or false.
Description[de] = Konfiguriert den Password Reset Link. Gültige Werte sind true oder false.
Type = String
InitialValue = true
Required = false
Show = Settings

[OWNCLOUD_UPDATE_CHECKER]
Description = Configure the ownCloud Update Checker. Valid values are true or false.
Description[de] = Konfiguriert den Update Checker. Gültige Werte sind true oder false.
Type = String
InitialValue = false
Required = false
Show = Settings


# Configuration script run in the Docker Container.
#!/usr/bin/python

import os.path
import os
import sys

base_conf = "/etc/univention/base.conf"
local_container_env_file = "/etc/entrypoint.d/05-univention-env.sh"

print >> sys.stderr, "configuration script running..."

if not os.path.isfile(base_conf):
	print "base.conf does not exist, exiting"
	sys.exit(1)

with open(base_conf) as f, open(local_container_env_file, "w") as t:
	for line in f:
		keyvalue = line.split(": ", 1)
		if len(keyvalue) < 2:
			continue
		keyvalue[0] = keyvalue[0].replace("/", "_")
		keyvalue[1] = "'%s'" % keyvalue[1].strip()
		# print "%s=%s" % (keyvalue[0], keyvalue[1])
		t.write("%s=%s\n" % (keyvalue[0], keyvalue[1]))

if os.path.isfile(local_container_env_file):
	os.chmod(local_container_env_file, 755)

sys.exit(0)



# Path to script inside the container (absolute)


/tmp/configure



# Configuration script run on the Docker Host.


#!/bin/bash
# the file "/tmp/do-not-restart" is created in the PreInst and PreRm script.
if [ -e /tmp/do-not-restart ]
then
	rm /tmp/do-not-restart
else
	echo "sleep 10; univention-app restart owncloud" | at now
fi
