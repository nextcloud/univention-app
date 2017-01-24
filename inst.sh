#!/bin/bash
VERSION=1
SERVICE="Nextcloud"
NC_PERMCONFDIR="/var/lib/univention-appcenter/apps/nextcloud/conf"
NC_LDAP_SYSUSER_PWD_FILE="$NC_PERMCONFDIR/ldap/nextcloud.secret"
NC_ADMIN_PWD_FILE="$NC_PERMCONFDIR/admin.secret"

. /usr/share/univention-join/joinscripthelper.lib
joinscript_init

eval "$(ucr shell)"

urlEncode() {
  python -c 'import urllib, sys; print urllib.quote(sys.argv[1], sys.argv[2])' \
    "$1" ""
}

HOST="https://${hostname}.${domainname}/nextcloud/"

ucs_addServiceToLocalhost "${SERVICE}" "$@"

univention-install univention-ldap-overlay-memberof
NC_MEMBER_OF=`aptitude search univention-ldap-overlay-memberof | grep  -v "^p" -c`

if [ ! -e $NC_LDAP_SYSUSER_PWD_FILE ] ; then
    joinscript_add_simple_app_system_user "$@"
    mkdir -p "$NC_PERMCONFDIR/ldap"
    cp /etc/nextcloud.secret "$NC_LDAP_SYSUSER_PWD_FILE"
fi
NC_LDAP_PWD=`cat "$NC_LDAP_SYSUSER_PWD_FILE"`
NC_ADMIN_PWD=`cat "$NC_ADMIN_PWD_FILE"`

data="configData[ldapHost]="`urlEncode "ldaps://$ldap_server_name"`
data+="configData[ldapPort]="`urlEncode "$ldap_server_port"`
data+="configData[ldapAgentName]="`urlEncode "uid=nextcloud-systemuser,cn=users,$ldap_base"`
data+="configData[ldapAgentPassword]="`urlEncode "$NC_LDAP_PWD"`
data+="configData[ldapBase]="`urlEncode "$ldap_base"`
data+="configData[ldapBaseUsers]="`urlEncode "cn=users,$ldap_base"`
data+="configData[ldapBaseGroups]="`urlEncode "cn=groups,$ldap_base"`
data+="configData[ldapUserFilter]="`urlEncode "(&(objectclass=nextcloudUser)(nextcloudEnabled=TRUE))"`
data+="configData[ldapUserFilterMode]=1"
data+="configData[ldapLoginFilter]="`urlEncode "(&(objectclass=nextcloudUser)(nextcloudEnabled=TRUE)(uid=%uid))"`
data+="configData[ldapLoginFilterMode]=1"
data+="configData[ldapLoginFilterUsername]=1"
data+="configData[ldapGroupFilter]="`urlEncode "(&(objectclass=nextcloudGroup)(nextcloudEnabled=TRUE))"`
data+="configData[ldapGroupFilterMode]=1"
data+="configData[ldapGroupFilterObjectclass]=nextcloudGroup"
data+="configData[ldapUserDisplayName]=uid"
data+="configData[ldapGroupDisplayName]=cn"
data+="configData[ldapEmailAttribute]=mailPrimaryAddress"
data+="configData[ldapGroupMemberAssocAttr]=uniqueMember"
data+="configData[ldapCacheTTL]=600"
data+="configData[ldapConfigurationActive]=1"
data+="configData[ldapAttributesForUserSearch]="`urlEncode "uid,givenName,sn,employeeNumber,mailPrimaryAddress"`
data+="configData[ldapExpertUsernameAttr]=uid"
data+="configData[ldapExpertUUIDUserAttr]="
data+="configData[useMemberOfToDetectMembership]=$NC_MEMBER_OF"
data+="configData[ldapNestedGroups]=0"
data+="configData[turnOnPasswordChange]=0"
data+="configData[ldapExperiencedAdmin]=1"

RESULT=curl -X POST -H "OCS-APIREQUEST: true"  -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config"
STATUS=`echo $RESULT | grep "<statuscode>200</statuscode>" -c`
if [ ! $STATUS -eq 1 ] ; then
    die "Could not create LDAP Config at Nextcloud"
fi
CONFIGID=`echo $RESULT | grep -oP '(?<=<configID>).*?(?=</configID>)'`
curl -X PUT -d "$data" -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config/$CONFIGID"

# moar settings: quota,homeAttr,groupSearchAttr

# worst case: fire occ using joinscript_run_in_container

joinscript_save_current_version
exit 0
