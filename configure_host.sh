#!/bin/bash
# the file "/tmp/do-not-restart" is created in the PreInst and PreRm script.
if [ -e /tmp/do-not-restart ]
then
	rm /tmp/do-not-restart
else
	echo "sleep 10; univention-app restart owncloud" | at now
fi