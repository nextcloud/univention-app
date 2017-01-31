#!/bin/bash
VERSION=1
SERVICE="Nextcloud"
NC_PERMCONFDIR="/var/lib/univention-appcenter/apps/nextcloud/conf"
NC_LDAP_SYSUSER_PWD_FILE="$NC_PERMCONFDIR/ldap/nextcloud.secret"
NC_ADMIN_PWD_FILE="$NC_PERMCONFDIR/admin.secret"

. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
. /usr/share/univention-lib/ldap.sh
joinscript_init

eval "$(ucr shell)"

urlEncode() {
  python -c 'import urllib, sys; print urllib.quote(sys.argv[1], sys.argv[2])' \
    "$1" ""
}

HOST="https://${hostname}.${domainname}/nextcloud"

ucs_addServiceToLocalhost "${SERVICE}" "$@"

univention-install univention-ldap-overlay-memberof
NC_MEMBER_OF=`aptitude search univention-ldap-overlay-memberof | grep  -v "^p" -c`

if [ ! -e $NC_LDAP_SYSUSER_PWD_FILE ] ; then
    joinscript_add_simple_app_system_user "$@"
fi
NC_LDAP_PWD=`cat $(joinscript_container_file "/etc/nextcloud.secret")`
NC_ADMIN_PWD=`cat "$NC_ADMIN_PWD_FILE"`

data="configData[ldapHost]="`urlEncode "$ldap_server_name"`
data+="&configData[ldapPort]="`urlEncode "$ldap_server_port"`
data+="&configData[ldapAgentName]="`urlEncode "uid=nextcloud-systemuser,cn=users,$ldap_base"`
data+="&configData[ldapAgentPassword]="`urlEncode "$NC_LDAP_PWD"`
data+="&configData[ldapBase]="`urlEncode "$ldap_base"`
data+="&configData[ldapBaseUsers]="`urlEncode "cn=users,$ldap_base"`
data+="&configData[ldapBaseGroups]="`urlEncode "cn=groups,$ldap_base"`
data+="&configData[ldapUserFilter]="`urlEncode "(&(objectclass=nextcloudUser)(nextcloudEnabled=1))"`
data+="&configData[ldapUserFilterMode]=1"
data+="&configData[ldapLoginFilter]="`urlEncode "(&(objectclass=nextcloudUser)(nextcloudEnabled=1)(uid=%uid))"`
data+="&configData[ldapLoginFilterMode]=1"
data+="&configData[ldapLoginFilterUsername]=1"
data+="&configData[ldapGroupFilter]="`urlEncode "(&(objectclass=nextcloudGroup)(nextcloudEnabled=1))"`
data+="&configData[ldapGroupFilterMode]=1"
data+="&configData[ldapGroupFilterObjectclass]=nextcloudGroup"
data+="&configData[ldapUserDisplayName]=uid"
data+="&configData[ldapGroupDisplayName]=cn"
data+="&configData[ldapEmailAttribute]=mailPrimaryAddress"
data+="&configData[ldapGroupMemberAssocAttr]=uniqueMember"
data+="&configData[ldapCacheTTL]=600"
data+="&configData[ldapConfigurationActive]=1"
data+="&configData[ldapAttributesForUserSearch]="`urlEncode "uid,givenName,sn,employeeNumber,mailPrimaryAddress"`
data+="&configData[ldapExpertUsernameAttr]=uid"
data+="&configData[ldapExpertUUIDUserAttr]="
data+="&configData[useMemberOfToDetectMembership]=$NC_MEMBER_OF"
data+="&configData[ldapNestedGroups]=0"
data+="&configData[turnOnPasswordChange]=0"
data+="&configData[ldapExperiencedAdmin]=1"

RESULT=`curl --cacert /etc/univention/ssl/ucsCA/CAcert.pem -X POST -H "OCS-APIREQUEST: true"  -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config"`
STATUS=`echo $RESULT | grep "<statuscode>200</statuscode>" -c`
if [ ! $STATUS -eq 1 ] ; then
    die "Could not create LDAP Config at Nextcloud"
fi
CONFIGID=`echo $RESULT | grep -oP '(?<=<configID>).*?(?=</configID>)'`
curl --cacert /etc/univention/ssl/ucsCA/CAcert.pem -X PUT -d "$data" -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config/$CONFIGID"

curl -v --cacert /etc/univention/ssl/ucsCA/CAcert.pem -X GET -H "OCS-APIREQUEST: true" -u "nc_admin:$NC_ADMIN_PWD" "$HOST/ocs/v2.php/apps/user_ldap/api/v1/config/$CONFIGID"

# moar settings: quota,homeAttr,groupSearchAttr

joinscript_register_schema

univention-directory-manager container/cn create "$@" --ignore_exists \
    --position "cn=custom attributes,cn=univention,$ldap_base" \
    --set name=nextcloud

univention-directory-manager settings/extended_attribute create "$@" \
    --position "cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" --set module="users/user" \
    --set ldapMapping='nextcloudEnabled' \
    --set objectClass='nextcloudUser' \
    --set name='nextcloudUserEnabled' \
    --set shortDescription='Nextcloud enabled' \
    --set longDescription='whether user or group should be available in Nextcloud ' \
    --set translationShortDescription='"de_DE" "Nextloud aktiviert"' \
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
	--set default="1"

JoinUsersFilter="(&(|(&(objectClass=posixAccount) (objectClass=shadowAccount)) (objectClass=univentionMail) (objectClass=sambaSamAccount) (objectClass=simpleSecurityObject) (&(objectClass=person) (objectClass=organizationalPerson) (objectClass=inetOrgPerson))) (!(uidNumber=0)) (!(|(uid=*$) (uid=nextcloud-systemuser) (uid=join-backup) (uid=join-slave))) (!(objectClass=nextcloudUser)))"

for dn in $(udm users/user list "$@" --filter "$JoinUsersFilter" | sed -ne 's/^DN: //p') ; do
	echo "modyfing $dn .."
	udm users/user modify "$@" --dn "$dn" \
		--set nextcloudEnabled="1" \
		--set nextcloudQuota=""
done

joinscript_save_current_version
exit 0
