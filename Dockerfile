# Nextcloud - Demo Docker
#
# @copyright Copyright (c) 2017 Arthur Schiwon (blizzz@arthur-schiwon.de)
# @copyright Copyright (c) 2017 Lukas Reschke (lukas@statuscode.ch)
# @copyright Copyright (c) 2016 Marcos Zuriaga Miguel (wolfi@wolfi.es)
# @copyright Copyright (c) 2016 Sander Brand (brantje@gmail.com)
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

FROM ubuntu:16.04
RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
	apt-get -y update && apt-get install -y \
	apache2 \
	curl \
	libapache2-mod-php7.0 \
	php7.0 \
	php7.0-mysql \
	php-curl \
	php-dompdf \
	php-gd \
	php-mbstring \
	php-xml \
	php-xml-serializer \
	php-zip \
	php-apcu \
	php-ldap \
	wget \
	unzip \
	pwgen \
	sudo

RUN a2enmod ssl
RUN a2enmod headers
RUN a2enmod rewrite
RUN ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled

# FIXME: trusted domain
# FIXME: Rewrite Base, proxy settings?

RUN export NC_DATADIR="/var/lib/nextcloud/" && \
	export NC_DB_NAME="nextcloud" && \
	export NC_DB_TYPE="pgsql" && \
	export NC_LOCAL_ADMIN="nc_admin" && \
	export NC_LOCAL_ADMIN_PWD="pwgen -y 30 1" && \
	mkdir "$NC_DATADIR" && \
	cd /var/www/html && \
	cd /root/ && wget https://download.nextcloud.com/server/releases/nextcloud-11.0.0.zip && unzip /root/nextcloud-11.0.0.zip && \
	mv /root/nextcloud/* /var/www/html/ && \
	mv /root/nextcloud/.htaccess /var/www/html/.htaccess && \
	cd /var/www/html/ && \
	chmod +x occ && \
	./occ maintenance:install --admin-user "$NC_LOCAL_ADMIN" --admin-pass "$NC_LOCAL_ADMIN_PWD" --database "$NC_DB_TYPE" --database-host "$DB_HOST" --database-port "$DB_PORT" --database-name "$NC_DB_NAME" --database-user "$DB_USER" --database-pass "$DB_PASSWORD" --data-dir "$NC_DATADIR" && \
	chown -R www-data "$NC_DATADIR" && \
	./occ check && \
	./occ status && \
	./occ app:list && \
	./occ upgrade && \
	./occ config:system:set trusted_domains 3 --value=demo.nextcloud.com && \
	./occ config:system:set htaccess.RewriteBase --value="/" && \
	./occ maintenance:update:htaccess && \
	/var/www/html/occ config:system:set --value "\OC\Memcache\APCu" memcache.local && \
	chown -R www-data /var/www && \
	cat /etc/apache2/apache2.conf |awk '/<Directory \/var\/www\/>/,/AllowOverride None/{sub("None", "All",$0)}{print}' > /tmp/apache2.conf && \
	mv /tmp/apache2.conf /etc/apache2/apache2.conf && \
	sed -i '/SSLEngine on/a Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"' /etc/apache2/sites-enabled/default-ssl.conf

EXPOSE 80
EXPOSE 443
