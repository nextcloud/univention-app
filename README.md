This is the Nextcloud app for Univention Corporate Server (UCS). This installs, configures and integrates Nextcloud into  UCS.

It is a docker based app, not relying on the UCS image.

# Features

* registers an LDAP schema
* add extended attributes so availability of Nextcloud to both users and group can be configured in *user/group settings* → *Advanced settings* → *Nextcloud*
* for users also the quota can be configured
* all users are enabled to login by default
* Administrator user has also admin privileges on Nextcloud

# Overview

## Install

* Nextcloud is preconfigured
    * PostgreSQL DB
    * Apache
    * Base install
    * LDAP Backend configuration
    * Cron
    * APCu as memcache
* UCS integration
    * user settings added: nextcloud enabled and quota
    * group settings added: nextcloud enabled
    * all users are set to be allowed to login to Nextcloud (login by uid)
    * Administrator gets Nextcloud admin privileges

## Upgrade

Totally replaces the container. Data and Config are kept, upgrade routine kick off automatically.

## Uninstall

Removes container, all data, all system integrations (except Schema)


# Tech info

## Environment

* UCS's PostgreSQL integration mechanism is being used.

## Dockerfile

The Dockerfile install the base system (based on Ubuntu 16.04) and copies the Nextcloud files into place. Also file permissions are set accordingly.

Furthermore unattended upgrades are enabled and the web server configured.

The entrypoint is a scrip that starts cron and eventually runs the web server in foreground.

## Installation process

When the UCS admin clicks on install Nextcloud following happens.

### 1. Docker

The docker container will be created. If one is present, it will be replaced.

### 2. Preinstall

The hostname  (retrieved from ucr) is saved within the permanent app config dir so setup within the Nextcloud container can do install and most basic configuration.

### 3. before setup

If a config.php exists, it will be copied from the permanent app folder to the usual destination within Nextcloud.

### 4. setup

`occ` is made executable.

Checks are done whether Nextcloud is installed and being upgraded.

On install

* The data directory (on the permanent app folder) will be created, if not existant,  and the permissions will be adjusted. 
* The admin password is created and placed as admin.secret in the permanent app conf directory
* Nextcloud is being installed
* Nextcloud is being configured:
    - trusted domain
    - disabling updatechecker (we rely on UCS AppCenter)
    - proxy settings (we're behind a reverse proxy)
    - .htaccess
    - APCu is set as memcache
    - cron is configured
    - the ldap app is enabled

In any case, a Nextcloud upgrade routine is attempted (it does not do anything if not necessary).

### 5. after setup

The current config.php is copied to the permanent app config folder.

### 6. joining UCS (inst)

#### Nextcloud service added to localhost

Just on UCS Api call / bash method invocation

#### Checks that some custom UCR variables are set

They also can be used for pre-configuration, however there are no dedicated GUI ways for this.

#### member of support

It is checked whether ``univention-ldap-overlay-memberof`` is installed to figure out one configuration flag for the Nextcloud LDAP backend.

#### register LDAP schema

With another single UCS bash method invocation.

#### extended attributes

Settings for enabling users and groups as well as setting user quota are registered.

#### configure LDAP backend

Nextcloud's LDAP backend is configured.

Most important:

* all users and groups are whitelisted that are of objectclass ``nextcloudUser`` or ``nextcloudGroup`` and where ``nextcloudEnabled`` is set to ``1``.

* The login attribute defaults to ``uid``.

* The user search attributes default to ``uid;givenName;sn;employeeNumber;mailPrimaryAddress`` and the group search attributes to ``cn``.

* The search base for users defaults to ``cn=users,LDAP_BASE`` and for groups to ``cn=groups,LDAP_BASE``. This means only users or groups underneath those default subtrees are considered. The search base can be changed before the installation by executing ``ucr set nextcloud/ldap/baseUsers="your-ldap-subtree"`` and ``ucr set nextcloud/ldap/baseGroups="your-ldap-subtree"`` on the UCS host or after the installation in the Nextcloud settings via Admin -> LDAP / AD integration -> Advanced -> Directory Settings.

#### modify users

Unless on update or empty ``$nextcloud_ucs_modifyUsersFilter`` all Users resulting by this filter¹ are modified. ``nextcloudEnabled`` is set to ``$nextcloud_ucs_userEnabled`` (defaults to 1) and ``nextcloudQuota`` is set to ``$nextcloud_ucs_userQuota``(default to empty, i.e. unlimited).

¹defaults to

```
(&(|(&(objectClass=posixAccount) (objectClass=shadowAccount)) (objectClass=univentionMail) (objectClass=sambaSamAccount) (objectClass=simpleSecurityObject) (&(objectClass=person) (objectClass=organizationalPerson) (objectClass=inetOrgPerson))) (!(uidNumber=0)) (!(|(uid=*$) (uid=nextcloud-systemuser) (uid=join-backup) (uid=join-slave))) (!(objectClass=nextcloudUser)))
```

#### UCS user Administrator becomes admin

This works by adding this user to the local Nextcloud group "admin" and empowers him to administer Nextcloud. 

(This user can give admin rights by adding other Users within the Nextcloud user management to the "admin" group.)

## Uninstallation process 

The uninstall script makes sure that UCS is left clean from any Nextcloud tracks. A subsequent install will have a fresh and empty instance.

The Nextcloud service is removed from the localhost (UCS bash method invocation).

Following steps are only done, when ``ucs_isServiceUnused`` returns ``true``.

* Nextcloud custom attributes are removed
* Nextcloud system user is removed
* All Nextcloud ucr variables are unset

The Nextcloud PostgreSQL database and user are removed unconditionally, because the database resides on the docker host.

UCS itself takes care of cleaning up the app folders. That means, that all data is deleted! To avoid this a manual backup has been done before (we can automatize it, but whereto?).

## Upgrade process

On upgrade the Nextcloud docker container is removed and all not-permanent data vanished. Before this, the Nextcloud config is copied to the permanent app config directory.

Subsequently the installation process kicks in. Therefore, all the upgrade switches in that logic :)

## Creating a new release

If the Dockerfile changes, you first need to build the image. If not continue with tagging and pushing to docker. Background: the app version on UCS as well as the docker tag should be the same (not a technical necessity, but best practice).

To build the container (from within the dir where the Dockerfile is located, replace $name accordingly):

``$ sudo docker  build -t $name .``

To tag, figure out the docker image id via ``sudo docker images``, eventually:

``sudo docker tag $imageID $repo/$name:$version``

and push it

``sudo docker push $repo/$name:$version``

In the Univention Provider Portal, open the Hamburger menu of the app and click "New app version". Pick the source and the target version and hit "Create". In the  app settings go to the "Docker" section and adjust the Docker image (update the tag).

Click the "save" icon and and the app is available in the test app center.


## Deploying to App Portal

### Prerequisites

First, having an account and access to the UCS App Provider portal.

Second, follow http://wiki.univention.de/index.php?title=Provider_Portal/Apps#Prerequisites

### Create a new version

$ make add-version app_ver='11.0.3-0' app_newver='11.0.3-90'
