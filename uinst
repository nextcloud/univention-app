#!/usr/bin/env bash

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

VERSION=1
SERVICE="Nextcloud"
. /usr/share/univention-join/joinscripthelper.lib
. /usr/share/univention-appcenter/joinscripthelper.sh
joinscript_init

ucs_removeServiceFromLocalhost "${SERVICE}" "$@" || die

if ucs_isServiceUnused "$SERVICE" "$@"; then
    . /usr/share/univention-lib/ldap.sh
    eval "$(ucr shell)"

    univention-directory-manager container/cn remove "$@" \
        --dn "cn=nextcloud,cn=custom attributes,cn=univention,$ldap_base" || die

    ucr unset `ucr search --key "^nextcloud" | cut -d ":" -f 1 | grep nextcloud | tr '\n' ' '`

fi

# Remove the database  (apps permanent data and config folder are removed automatically)
su -c "psql -c \"drop database nextcloud\"" - postgres && \
    su -c "dropuser \"nextcloud\"" - postgres || die

joinscript_remove_script_from_status_file nextcloud
exit 0
