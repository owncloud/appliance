# Commands for using the Univention Corperate Server

```
# Activate Testappcenter to install apps for testing

univention-install -y univention-appcenter-dev; univention-app dev-use-test-appcenter; univention-app update


# Deactivate Testappcenter

univention-app dev-use-test-appcenter --revert




# Install an app

univention-app install owncloud

# Remove an app

univention-app remove owncloud

# Log in to docker container

univention-app shell owncloud


# Log in to docker container

univention-app shell owncloud



# Update Scripts

univention-app update

# Get List of all versions

univention-app list owncloud

# enter docker app with env variables

docker exec -ti owncloud_owncloud_1 entrypoint bash

# restart owncloud container

univention-app restart owncloud

# restart apache process

pkill -U 0 -f /usr/sbin/apache2 --signal SIGUSR1
