Commands for using the Univention Corperate Server

### Activate Testappcenter to install apps for testing

```
univention-install -y univention-appcenter-dev; univention-app dev-use-test-appcenter; univention-app update
```

### Deactivate Testappcenter

`univention-app dev-use-test-appcenter --revert`

### Create PWDFILE (replace "123123123" with your Administrator Password) (Remove File after you are done)

`echo "123123123" > PWDFILE`

### Update App Catalog

`univention-app update`

### Install owncloud (latest)

`univention-app install owncloud --noninteractive --pwdfile PWDFILE`

### Install specific ownCloud version for testing

`univention-app install owncloud=10.7.0 --noninteractive --pwdfile PWDFILE`

### Upgrade to latest version

`univention-app upgrade owncloud --noninteractive --pwdfile PWDFILE`

### You can specify a user other than the Admin to perform the upgrade

`univention-app upgrade owncloud --noninteractive --username USERNAME --pwdfile PWDFILE`

### Remove an app

`univention-app remove owncloud --noninteractive --pwdfile PWDFILE`

### Log in to docker container

`univention-app shell owncloud`

### Get List of all versions

`univention-app list owncloud`

### enter docker app with env variables

`docker exec -ti owncloud_owncloud_1 entrypoint bash`

### restart owncloud container

`univention-app restart owncloud`

### restart apache process while in docker container

`pkill -U 0 -f /usr/sbin/apache2 --signal SIGUSR1`

### Install Package

`univention-install <package-name>` 

### Get to the Web management console

`/FQDN/umc`

`/FQDN/univention/management`
