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

NC_PERMCONFDIR="/var/lib/univention-appcenter/apps/nextcloud/conf"
NC_UCR_FILE="$NC_PERMCONFDIR/ucr"

# the folder is not yet created, as expected
mkdir -p "$NC_PERMCONFDIR"

cat >"$NC_UCR_FILE" <<EOL
export NC_UCR_DOMAIN="`ucr get hostname`"."`ucr get domainname`"
export NC_HOST_IPS="`ucr dump | grep interfaces | grep address | cut -d ":" -f2`"
EOL

chmod +x "$NC_UCR_FILE"

exit 0
