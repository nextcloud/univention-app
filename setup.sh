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

NC_PERMDATADIR="/var/lib/univention-appcenter/apps/nextcloud/data"
NC_DATADIR="$NC_PERMDATADIR/nextcloud/data"

NC_PERMCONFDIR="/var/lib/univention-appcenter/apps/nextcloud/conf"
NC_UCR_FILE="$NC_PERMCONFDIR/ucr"
NC_ADMIN_PWD_FILE="$NC_PERMCONFDIR/admin.secret"

NC_DB_TYPE="pgsql"
NC_LOCAL_ADMIN="nc_admin"
NC_LOCAL_ADMIN_PWD=`pwgen -y 30 1`
echo "$NC_LOCAL_ADMIN_PWD" > "$NC_ADMIN_PWD_FILE"

cd /var/www/html
if [ ! -x occ ]; then
	echo "occ missing or not executable"
	exit 1
fi

mkdir -p "$NC_DATADIR"
chown www-data:www-data -R "$NC_PERMDATADIR/nextcloud"

./occ maintenance:install \
    --admin-user    "$NC_LOCAL_ADMIN" \
    --admin-pass    "$NC_LOCAL_ADMIN_PWD" \
    --database      "$NC_DB_TYPE" \
    --database-host "$DB_HOST" \
    --database-port "$DB_PORT" \
    --database-name "$DB_NAME" \
    --database-user "$DB_USER" \
    --database-pass "$DB_PASSWORD" \
    --data-dir      "$NC_DATADIR"

STATE=$?
if [[ $STATE != 0 ]]; then
    echo  "Error while installing Nextcloud"
    exit 1;
fi

chown -R www-data "$NC_DATADIR"

./occ check
./occ status
./occ app:list
./occ upgrade

eval "`cat \"$NC_UCR_FILE\"`"

# basic Nextcloud configuration
./occ config:system:set trusted_domains 0 --value="$NC_UCR_DOMAIN"      # FIXME: fmove to joinscript
./occ config:system:set htaccess.RewriteBase --value="/nextcloud/"
./occ maintenance:update:htaccess
./occ config:system:set --value "\OC\Memcache\APCu" memcache.local
./occ app:enable user_ldap
# TODO: Other settings necessary? Proxy?

# Apache configuration
cat /etc/apache2/apache2.conf |awk '/<Directory \/var\/www\/>/,/AllowOverride None/{sub("None", "All",$0)}{print}' > /tmp/apache2.conf && \
mv /tmp/apache2.conf /etc/apache2/apache2.conf
sed -i '/SSLEngine on/a Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"' /etc/apache2/sites-enabled/default-ssl.conf

# TODO LDAP Configuration

