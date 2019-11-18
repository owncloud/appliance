# Commands for using the Univention Corperate Server

```
# Activate Testappcenter to install apps for testing

univention-install -y univention-appcenter-dev; univention-app dev-use-test-appcenter; univention-app update


# Install an app

univention-app install owncloud=9.1.4-test2

# Remove an app

univention-app remove owncloud=9.1.4-test2

# Log in to docker container

univention-app shell owncloud

# Install newer app

univention-app install owncloud

# Log in to docker container

univention-app shell owncloud

# Deactivate Testappcenter

univention-app dev-use-test-appcenter --revert

# Update Scripts

univention-app update

# Get List of all versions

univention-app list owncloud
