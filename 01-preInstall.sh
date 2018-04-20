#!/bin/bash
#
# An outer script called before setup is called
#


ARGS=("$@")
getarg() {
    local found=0
    for arg in "${ARGS[@]}"; do
        if [ "$found" -eq 1 ]; then
            echo "$arg"
            break
        fi
        if [ "$arg" = "$1" ]; then
            found=1
        fi
    done
}

service univention-firewall restart
# Check if there is already a config.php and save it
datadir="/var/lib/univention-appcenter/apps/owncloud82/conf"

if [ -f /var/www/owncloud/config/config.php ]
 then
  mkdir -p $datadir && cp  /var/www/owncloud/config/config.php $datadir
fi

# In case the owncloud app appliance was used, fix the docker image name
if [ "$(ucr get appcenter/apps/owncloud82/image)" = "owncloud82-app" ]; then
    ucr set appcenter/apps/owncloud82/image="docker.software-univention.de/ucs-appbox-amd64:4.1-3"
    file="$(getarg --error-file)"
    echo "A configuration error has been fixed. Please install the update again to continue" > "$file"
    exit 1
fi

exit 0
