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

COPY resources/nextcloud-11.0.1.tar.bz2 /root/
COPY resources/ldap-ocs.patch /root/

RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt-get -y update && apt-get install -y \
	apache2 \
	curl \
	libapache2-mod-php7.0 \
	php7.0 \
	php-curl \
	php-dompdf \
	php-gd \
	php-mbstring \
	php-xml \
	php-xml-serializer \
	php-zip \
	php-apcu \
	php-ldap \
	php-pgsql \
	wget \
	pwgen \
	sudo \
	lbzip2 \
	patch

RUN a2enmod ssl
RUN a2enmod headers
RUN a2enmod rewrite
RUN ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled

RUN export NC_DATADIR="/var/lib/nextcloud/" && \
	export NC_DB_NAME="nextcloud" && \
	export NC_DB_TYPE="pgsql" && \
	export NC_LOCAL_ADMIN="nc_admin" && \
	export NC_LOCAL_ADMIN_PWD="pwgen -y 30 1" && \
	pwgen -y 30 1 > /etc/postgresql-nextcloud.secret && \
	mkdir "$NC_DATADIR"

RUN cd /root/ && \
	tar -xf "nextcloud-11.0.1.tar.bz2" && \
	mv /root/nextcloud/* /var/www/html/ && \
	mv /root/nextcloud/.htaccess /var/www/html/.htaccess && \
	rm -Rf /root/nextcloud && \
	rm "nextcloud-11.0.1.tar.bz2" && \
	cd /var/www/html/ && \
	chmod +x occ && \
	patch -p1 < /root/ldap-ocs.patch

RUN sed -i '/DocumentRoot \/var\/www\/html/a \\tAlias \/nextcloud \/var\/www\/html' /etc/apache2/sites-enabled/000-default.conf

# perhaps unnecessary?
EXPOSE 80
