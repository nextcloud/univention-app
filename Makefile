# @copyright Copyright (c) 2017 Arthur Schiwon <blizzz@arthur-schiwon.de>
#
# @author Arthur Schiwon <blizzz@arthur-schiwon.de>
#
# @license GNU AGPL app_version 3 or any later app_version
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either app_version 3 of the
# License, or (at your option) any later app_version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Goal: upload all things and publish.
# 1. New app_version   #make new app_version
# 2. Push          #make app_ver=11.0.4
# 3. Publish       #make publish

app_name=nextcloud
ucs_app_version=4.1

all:
	echo $(app_ver)
	if [ -z ${app_ver} ] ; then echo "no app_version specified"; exit 13; fi

add-version:
	if [ -z ${app_ver} ] ; then echo "no original app_version specified"; exit 13; fi
	if [ -z ${app_newver} ] ; then echo "no target app_version specified"; exit 13; fi
	univention-appcenter-control new-version "$(app_name)=$(app_ver)" "$(ucs_app_version)/$(app_name)=$(app_newver)"

