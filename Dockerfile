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

COPY resources/nextcloud-12.0.1RC1.tar.bz2 /root/nextcloud.tar.bz2
COPY resources/entrypoint.sh /usr/sbin/
COPY resources/60-nextcloud.ini /etc/php/7.0/apache2/conf.d/
COPY resources/60-nextcloud.ini /etc/php/7.0/cli/conf.d/


RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt-get -y update && apt-get -y full-upgrade && apt-get install -y \
	apache2 \
	cron \
	curl \
	libapache2-mod-php \
	php \
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
	php-smbclient \
	wget \
	pwgen \
	sudo \
	lbzip2 \
	unattended-upgrades

RUN a2enmod headers
RUN a2enmod rewrite

RUN cd /root/ && \
	tar -xf "nextcloud.tar.bz2" && \
	mv /root/nextcloud/* /var/www/html/ && \
	mv /root/nextcloud/.htaccess /var/www/html/ && \
	mv /root/nextcloud/.user.ini /var/www/html/ && \
	rm -Rf /root/nextcloud && \
	rm "nextcloud.tar.bz2" && \
	cd /var/www/html/ && \
	chmod +x occ && \
	chown -R www-data /var/www/html

RUN sed -i '/DocumentRoot \/var\/www\/html/a \\tAlias \/nextcloud \/var\/www\/html' /etc/apache2/sites-enabled/000-default.conf

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh
