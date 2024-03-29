#!/usr/bin/python3

import os.path
import os
import sys

base_conf = "/etc/univention/base.conf"
local_container_env_file = "/etc/entrypoint.d/05-univention-env.sh"

print("configuration script running...", file=sys.stderr)

if not os.path.isfile(base_conf):
	print("base.conf does not exist, exiting")
	sys.exit(1)

with open(base_conf) as f, open(local_container_env_file, "w") as t:
	oidc_enabled = False
	base_conf_lines = f.readlines()
	for line in base_conf_lines:
		keyvalue = line.split(": ", 1)
		if len(keyvalue) < 2:
			continue
		keyvalue[0] = keyvalue[0].replace("/", "_")
		if (	keyvalue[0].strip() == "OWNCLOUD_OPENID_LOGIN_ENABLED" and
				keyvalue[1].strip() == "true"
			):
			oidc_enabled = True
		if keyvalue[0].startswith(u"OWNCLOUD_OPENID"):
			keyvalue[0] = keyvalue[0].replace(u"OWNCLOUD_OPENID", u"OPENID", 1)
		keyvalue[1] = "'%s'" % keyvalue[1].strip()
		# print "%s=%s" % (keyvalue[0], keyvalue[1])
		t.write("export %s=%s\n" % (keyvalue[0], keyvalue[1]))

	# Special case when OPENID should be deactivated
	if not oidc_enabled:
		t.write("\nunset OPENID_PROVIDER_URL\n")


if os.path.isfile(local_container_env_file):
	os.chmod(local_container_env_file, 0o755)

sys.exit(0)
