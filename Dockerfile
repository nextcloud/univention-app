# Nextcloud - Demo Docker
#
# @copyright Copyricht (c) 2018 Nico Gulden (gulden@univention.de)
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

FROM ubuntu:18.04

ADD https://download.nextcloud.com/server/prereleases/nextcloud-15.0.8.tar.bz2 /root/nextcloud.tar.bz2
ADD https://github.com/nextcloud/richdocuments/releases/download/v3.3.3/richdocuments.tar.gz /root/richdocuments.tar.gz
ADD https://github.com/ONLYOFFICE/onlyoffice-nextcloud/releases/download/v2.1.10/onlyoffice.tar.gz /root/onlyoffice.tar.gz
COPY resources/entrypoint.sh /usr/sbin/
COPY resources/60-nextcloud.ini /etc/php/7.2/apache2/conf.d/
COPY resources/60-nextcloud.ini /etc/php/7.2/cli/conf.d/
COPY resources/000-default.conf /etc/apache2/sites-enabled/

# uncomment and set to true if a patch nededs to be applied
#COPY resources/13120.patch /root/13120.patch
ENV NC_IS_PATCHED false

RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt-get -y update && apt-get -y full-upgrade && apt-get install -y \
	apache2 \
	cron \
	curl \
	libapache2-mod-php \
	patch \
	php \
	php-curl \
	php-dompdf \
	php-gd \
	php-imagick \
	php-intl \
	php-mbstring \
	php-xml \
	php-zip \
	php-apcu \
	php-ldap \
	php-oauth \
	php-pgsql \
	php-smbclient \
	wget \
	pwgen \
	sudo \
	lbzip2 \
	unattended-upgrades

RUN apt clean

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

RUN cd /var/www/html/apps && \
    mkdir richdocuments && \
    tar -xf /root/richdocuments.tar.gz -C richdocuments --strip-components=1 && \
    chown -R www-data:nogroup /var/www/html/apps/richdocuments && \
    rm /root/richdocuments.tar.gz

RUN cd /var/www/html/apps && \
    mkdir onlyoffice && \
    tar -xf /root/onlyoffice.tar.gz -C onlyoffice --strip-components=1 && \
    chown -R www-data:nogroup /var/www/html/apps/onlyoffice && \
    rm /root/onlyoffice.tar.gz

# uncomment and adjust following block if a patch needs to be applied
#RUN cd /var/www/html/ && \
#    patch -p1 -t < /root/13120.patch && \
#    rm /root/13120.patch

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh
