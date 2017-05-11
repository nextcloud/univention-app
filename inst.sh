#!/bin/bash

# @copyright Copyright (c) 2017 Arthur Schiwon <blizzz@arthur-schiwon.de>
#
# @author Arthur Schiwon <blizzz@arthur-schiwon.de>
#
# @license GNU AGPL version 3 or any later version
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION=2
SERVICE="Nextcloud"

. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
. /usr/share/univention-lib/ldap.sh

joinscript_init
eval "$(ucr shell)"

NC_PERMCONFDIR="/var/lib/univention-appcenter/apps/nextcloud/conf"
NC_ADMIN_PWD_FILE="$NC_PERMCONFDIR/admin.secret"
NC_MEMBER_OF=0
HOST="https://${hostname}.${domainname}/nextcloud"
IS_UPDATE=false
NC_LDAP_BIND_DN="$appcenter_apps_nextcloud_hostdn"
NC_LDAP_BIND_PW_FILE="$(joinscript_container_file /etc/machine.secret)"
NC_LDAP_BIND_PW="$(< $NC_LDAP_BIND_PW_FILE)"

nextcloud_main() {
    if [ -e "/var/lib/univention-appcenter/apps/nextcloud/conf/initial_config_done" ] ; then
        IS_UPDATE=true
    fi
    ucs_addServiceToLocalhost "${SERVICE}" "$@"
    if [ "$JS_LAST_EXECUTED_VERSION" = 1 ]; then
        nextcloud_update_ldap_bind_account
    fi
    nextcloud_ensure_ucr
    nextcloud_attempt_memberof_support
    joinscript_register_schema "$@"
    nextcloud_ensure_extended_attributes "$@"
    nextcloud_configure_ldap_backend
    nextcloud_modify_users "$@"
    nextcloud_add_Administrator_to_admin_group
    nextcloud_mark_initial_conig_done
    joinscript_save_current_version
    exit 0
}

# ensures that UCR variables are set. They can be used to pre-set Nextcloud settings before install
nextcloud_ensure_ucr() {
    ucr set nextcloud/ucs/modifyUsersFilter?"(&(|(&(objectClass=posixAccount) (objectClass=shadowAccount)) (objectClass=univentionMail) (objectClass=sambaSamAccount) (objectClass=simpleSecurityObject) (&(objectClass=person) (objectClass=organizationalPerson) (objectClass=inetOrgPerson))) (!(uidNumber=0)) (!(|(uid=*$) (uid=nextcloud-systemuser) (uid=join-backup) (uid=join-slave))) (!(objectClass=nextcloudUser)))" \
            nextcloud/ucs/userEnabled?"1" \
            nextcloud/ucs/userQuota?"" \
            nextcloud/ldap/cacheTTL?"600" \
            nextcloud/ldap/homeFolderAttribute?"" \
            nextcloud/ldap/userSearchAttributes?"uid;givenName;sn;employeeNumber;mailPrimaryAddress" \
            nextcloud/ldap/userDisplayName?"displayName" \
            nextcloud/ldap/groupDisplayName?"cn" \
            nextcloud/ldap/base?"$ldap_base" \
            nextcloud/ldap/baseUsers?"cn=users,$ldap_base" \
            nextcloud/ldap/baseGroups?"cn=groups,$ldap_base" \
            nextcloud/ldap/filterLogin?"(&(objectclass=nextcloudUser)(nextcloudEnabled=1)(uid=%uid))" \
            nextcloud/ldap/filterUsers?"(&(objectclass=nextcloudUser)(nextcloudEnabled=1))" \
            nextcloud/ldap/filterGroups?"(&(objectclass=nextcloudGroup)(nextcloudEnabled=1))" \

    eval "$(ucr shell)"
}

# installs the memberof-overlay and saves the state in NC_MEMBER_OF
nextcloud_attempt_memberof_support() {
    NC_MEMBER_OF=`dpkg-query -W -f='${Status}\n' univention-ldap-overlay-memberof | grep Installed | grep "^i" -c`
}

# update ldap bind account to nextcloud user
nextcloud_update_ldap_bind_account() {
    local data
    local admin_password=`cat "$NC_ADMIN_PWD_FILE"`
    local configid="s01" # reasonable fall back. in v1 of the join script the configid was not saved.
    if [ -e "$NC_PERMCONFDIR/ldap-config-id" ]; then
        configid=`cat "$NC_PERMCONFDIR/ldap-config-id"`
    fi
    data="configData[ldapAgentName]="`nextcloud_urlEncode "$NC_LDAP_BIND_DN"`
    data+="&configData[ldapAgentPassword]="`nextcloud_urlEncode "$NC_LDAP_BIND_PW"`
    curl -X PUT -d "$data" \
        -H "OCS-APIREQUEST: true" -u "nc_admin:$admin_password" \
        "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config/$configid" > /dev/null
}

# configures the LDAP backend at Nextcloud using its OCS API
nextcloud_configure_ldap_backend() {
    if [ $IS_UPDATE = true ] ; then
        echo "Not attempting to set LDAP configuration, because NC is already installed and set up."
        return
    fi
    local NC_ADMIN_PWD=`cat "$NC_ADMIN_PWD_FILE"`

    data="configData[ldapHost]="`nextcloud_urlEncode "$ldap_server_name"`
    data+="&configData[ldapPort]="`nextcloud_urlEncode "$ldap_server_port"`
    data+="&configData[ldapAgentName]="`nextcloud_urlEncode "$NC_LDAP_BIND_DN"`
    data+="&configData[ldapAgentPassword]="`nextcloud_urlEncode "$NC_LDAP_BIND_PW"`
    data+="&configData[ldapBase]="`nextcloud_urlEncode "$nextcloud_ldap_base"`
    data+="&configData[ldapBaseUsers]="`nextcloud_urlEncode "$nextcloud_ldap_baseUsers"`
    data+="&configData[ldapBaseGroups]="`nextcloud_urlEncode "$nextcloud_ldap_baseGroups"`
    data+="&configData[ldapUserFilter]="`nextcloud_urlEncode "$nextcloud_ldap_filterUsers"`
    data+="&configData[ldapUserFilterMode]=1"
    data+="&configData[ldapLoginFilter]="`nextcloud_urlEncode "$nextcloud_ldap_filterLogin"`
    data+="&configData[ldapLoginFilterMode]=1"
    data+="&configData[ldapLoginFilterUsername]=1"
    data+="&configData[ldapGroupFilter]="`nextcloud_urlEncode "$nextcloud_ldap_filterGroups"`
    data+="&configData[ldapGroupFilterMode]=1"
    data+="&configData[ldapGroupFilterObjectclass]=nextcloudGroup"
    data+="&configData[ldapUserDisplayName]="`nextcloud_urlEncode "$nextcloud_ldap_userDisplayName"`
    data+="&configData[ldapGroupDisplayName]="`nextcloud_urlEncode "$nextcloud_ldap_groupDisplayName"`
    data+="&configData[ldapEmailAttribute]=mailPrimaryAddress"
    data+="&configData[ldapQuotaAttribute]=nextcloudQuota"
    data+="&configData[homeFolderNamingRule]="`nextcloud_urlEncode "$nextcloud_ldap_homeFolderAttribute"`
    data+="&configData[ldapGroupMemberAssocAttr]=uniqueMember"
    data+="&configData[ldapCacheTTL]="`nextcloud_urlEncode "$nextcloud_ldap_cacheTTL"`
    data+="&configData[ldapConfigurationActive]=1"
    data+="&configData[ldapAttributesForUserSearch]="`nextcloud_urlEncode "$nextcloud_ldap_userSearchAttributes"`
    data+="&configData[ldapExpertUsernameAttr]=uid"
    data+="&configData[ldapExpertUUIDUserAttr]="
    data+="&configData[useMemberOfToDetectMembership]=$NC_MEMBER_OF"
    data+="&configData[ldapNestedGroups]=0"
    data+="&configData[turnOnPasswordChange]=0"
    data+="&configData[ldapExperiencedAdmin]=1"

    RESULT=`curl -X POST -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config"`
    STATUS=`echo $RESULT | grep "<statuscode>200</statuscode>" -c`
    if [ ! $STATUS -eq 1 ] ; then
        die "Could not create LDAP Config at Nextcloud"
    fi
    CONFIGID=`echo $RESULT | grep -oP '(?<=<configID>).*?(?=</configID>)'`
    echo "$CONFIGID" > "$NC_PERMCONFDIR/ldap-config-id"
    curl -X PUT -d "$data" -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" \
        "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config/$CONFIGID" \
        > /dev/null | die "Configuring LDAP Backend failed"
}

nextcloud_add_Administrator_to_admin_group() {
    if [ $IS_UPDATE = true ] ; then
        echo "Not attempting to add Administrator to admin group, because NC is already installed and set up."
        return
    fi

    local NC_ADMIN_PWD=`cat "$NC_ADMIN_PWD_FILE"`

    # triggers the mapping
    RESULT=`curl -X GET -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/cloud/users?search=Administrator"`
    # we expect the username (nc internal) to be Administrator
    STATUS=`echo $RESULT | grep "<element>Administrator</element>" -c`
    if [ ! $STATUS -eq 1 ] ; then
        echo "Could not Administrator to admin group, because user was not found:"
        echo $RESULT
        die
    fi

    RESULT=`curl -X POST -d "groupid=admin" -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/cloud/users/Administrator/groups"`
    STATUS=`echo $RESULT | grep "<statuscode>200</statuscode>" -c`
    if [ ! $STATUS -eq 1 ] ; then
        echo "Could not Administrator to admin group, because adding as group member failed:"
        echo $RESULT
        die
    fi
}

nextcloud_urlEncode() {
  python -c 'import urllib, sys; print urllib.quote(sys.argv[1], sys.argv[2])' \
    "$1" ""
}

# adds extended attributes to UCS so admins can enable or disable Nextcloud access for users and groups
nextcloud_ensure_extended_attributes () {
    univention-directory-manager container/cn create "$@" --ignore_exists \
        --position "cn=custom attributes,cn=univention,$ldap_base" \
        --set name=nextcloud

    univention-directory-manager settings/extended_attribute create "$@" \
        --position "cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" --set module="users/user" \
        --set ldapMapping='nextcloudEnabled' \
        --set objectClass='nextcloudUser' \
        --set name='nextcloudUserEnabled' \
        --set shortDescription='Access to Nextcloud' \
        --set longDescription='Whether user may access Nextcloud' \
        --set translationShortDescription='"de_DE" "Zugang für Nextloud"' \
        --set translationLongDescription='"de_DE" "Der Benutzer kann auf Nextcloud zugreifen"' \
        --set tabName='Nextcloud' \
        --set translationTabName='"de_DE" "Nextcloud"' \
        --set overwriteTab='0' \
        --set valueRequired='0' \
        --set CLIName='nextcloudEnabled' \
        --set syntax='boolean' \
        --set default="1" \
        --set tabAdvanced='1' \
        --set mayChange='1' \
        --set multivalue='0' \
        --set deleteObjectClass='0' \
        --set tabPosition='1' \
        --set overwritePosition='0' \
        --set doNotSearch='0' \
        --set hook='None' || \
    univention-directory-manager settings/extended_attribute modify "$@" \
        --dn "cn=nextcloudUserEnabled,cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" \
        --set tabAdvanced='1' \
        --set default="1" || die

    univention-directory-manager settings/extended_attribute create "$@" \
        --position "cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" --set module="users/user" \
        --set ldapMapping='nextcloudQuota' \
        --set objectClass='nextcloudUser' \
        --set name='nextcloudUserQuota' \
        --set shortDescription='Nextcloud Quota' \
        --set longDescription='Amount of storage available to the user' \
        --set translationShortDescription='"de_DE" "Nextcloud Quota"' \
        --set translationLongDescription='"de_DE" "Der verfügbare Speicherplatz für den Benutzer"' \
        --set tabName='Nextcloud' \
        --set translationTabName='"de_DE" "Nextcloud"' \
        --set overwriteTab='0' \
        --set valueRequired='0' \
        --set CLIName='nextcloudQuota' \
        --set syntax='string' \
        --set default="" \
        --set tabAdvanced='1' \
        --set mayChange='1' \
        --set multivalue='0' \
        --set deleteObjectClass='0' \
        --set tabPosition='1' \
        --set overwritePosition='0' \
        --set doNotSearch='0' \
        --set hook='None' || \
    univention-directory-manager settings/extended_attribute modify "$@" \
        --dn "cn=nextcloudUserQuota,cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" \
        --set tabAdvanced='1' || die

    univention-directory-manager settings/extended_attribute create "$@" \
        --position "cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" --set module="groups/group" \
        --set ldapMapping='nextcloudEnabled' \
        --set objectClass='nextcloudGroup' \
        --set name='nextcloudGroupEnabled' \
        --set shortDescription='Available in Nextcloud' \
        --set longDescription='The group is available in Nextcloud' \
        --set translationShortDescription='"de_DE" "In Nextcloud verfügbar"' \
        --set translationLongDescription='"de_DE" "Die Gruppe ist in Nextcloud verfügbar"' \
        --set tabName='Nextcloud' \
        --set translationTabName='"de_DE" "Nextcloud"' \
        --set overwriteTab='0' \
        --set valueRequired='0' \
        --set CLIName='nextcloudEnabled' \
        --set syntax='boolean' \
        --set default="0" \
        --set tabAdvanced='0' \
        --set mayChange='1' \
        --set multivalue='0' \
        --set deleteObjectClass='0' \
        --set tabPosition='1' \
        --set overwritePosition='0' \
        --set doNotSearch='0' \
        --set hook='None' || \
    univention-directory-manager settings/extended_attribute modify "$@" \
        --dn "cn=nextcloudGroupEnabled,cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" \
        --set tabAdvanced='1' || die
}

# Enables all Users that fit the filter to access Nextcloud
nextcloud_modify_users() {
    if [ $IS_UPDATE = true ] || [ -z "$nextcloud_ucs_modifyUsersFilter"  ] ; then
        echo "Not attempting to modify users."
        return
    fi

    for dn in $(udm users/user list "$@" --filter "$nextcloud_ucs_modifyUsersFilter" | sed -ne 's/^DN: //p') ; do
        echo "modifying $dn .."
        udm users/user modify "$@" --dn "$dn" \
            --set nextcloudEnabled="$nextcloud_ucs_userEnabled" \
            --set nextcloudQuota="$nextcloud_ucs_userQuota"
    done
}

nextcloud_mark_initial_conig_done() {
    touch "/var/lib/univention-appcenter/apps/nextcloud/conf/initial_config_done" || die
}

nextcloud_main "$@"
