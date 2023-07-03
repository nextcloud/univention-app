# Nextcloud - Dockerfile
#
# @copyright Copyright (c) 2022 Arthur Schiwon (blizzz@arthur-schiwon.de)
# @copyright Copyricht (c) 2018 Nico Gulden (gulden@univention.de)
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

FROM ubuntu:20.04

ADD https://download.nextcloud.com/server/releases/nextcloud-25.0.8.tar.bz2 /root/nextcloud.tar.bz2
ADD https://github.com/nextcloud-releases/richdocuments/releases/download/v7.1.4/richdocuments-v7.1.4.tar.gz /root/richdocuments.tar.gz
ADD https://github.com/ONLYOFFICE/onlyoffice-nextcloud/releases/download/v7.8.0/onlyoffice.tar.gz /root/onlyoffice.tar.gz
COPY resources/entrypoint.sh /usr/sbin/
COPY resources/60-nextcloud.ini /etc/php/8.1/apache2/conf.d/
COPY resources/60-nextcloud.ini /etc/php/8.1/cli/conf.d/
COPY resources/000-default.conf /etc/apache2/sites-enabled/

# uncomment and set to true if a patch nededs to be applied
#COPY resources/19439.patch /root/nc.patch
ENV NC_IS_PATCHED false

RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt-get -y update && apt-get -y full-upgrade && apt-get install -y \
    software-properties-common

RUN DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:ondrej/php

RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt-get -y update && apt-get -y full-upgrade && apt-get install -y \
	apache2 \
	cron \
	curl \
	libapache2-mod-php8.1 \
	libfuse2 \
	patch \
	php8.1 \
	php8.1-bcmath \
	php8.1-curl \
	php8.1-dev \
	php8.1-gd \
	php8.1-imagick \
	php8.1-intl \
	php8.1-mbstring \
	php8.1-xml \
	php8.1-zip \
	php8.1-apcu \
	php8.1-ldap \
	php8.1-oauth \
	php8.1-pgsql \
	php8.1-gmp \
	php8.1-smbclient \
	wget \
	pwgen \
	sudo \
	lbzip2 \
	libmagickcore-6.q16-6-extra \
	libsmbclient-dev \
	unattended-upgrades \
	unzip

COPY resources/ldap.conf /etc/ldap/

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
	chown -R www-data /var/www/html

RUN rm -Rf /var/www/html/apps/updatenotification

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

RUN /bin/bash -c "export DEBIAN_FRONTEND=noninteractive" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
	apt purge -y software-properties-common && apt autoremove -y && apt clean

# uncomment and adjust following block if a patch needs to be applied
#RUN cd /var/www/html/ && \
#    patch -p1 -t < /root/nc.patch && \
#    rm /root/nc.patch

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh
