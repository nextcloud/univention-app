# @copyright Copyright (c) 2022 Arthur Schiwon <blizzz@arthur-schiwon.de>
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
# GNU Affero General Public License for more details
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

app_name=nextcloud
app_version=29.0.3-0
app_upgrade_from=28.0.7-0

ucs_version=5.0

docker_repo=nextcloud
docker_login=`cat ~/.docker-account-user`
docker_pwd=`cat ~/.docker-account-pwd`

.PHONY: all
all: push-files docker

.PHONY: add-version
add-version:
	if [ -z ${app_ver} ] ; then echo "no original app_version specified"; exit 13; fi
	if [ -z ${app_newver} ] ; then echo "no target app_version specified"; exit 13; fi
	univention-appcenter-control new-version "$(ucs_version)/$(app_name)=$(app_ver)" "$(ucs_version)/$(app_name)=$(app_newver)"

.PHONY: push-files
push-files:
	univention-appcenter-control upload --noninteractive $(ucs_version)/$(app_name)=$(app_version) \
		attributes \
		env \
		restore_data_before_setup \
		setup \
		restore_data_after_setup \
		preinst \
		inst \
		store_data \
		uinst \
		update_app_version \
		nextcloud.schema \
		i18n/en/README_INSTALL_EN \
		i18n/de/README_INSTALL_DE \
		i18n/en/README_POST_INSTALL_EN \
		i18n/de/README_POST_INSTALL_DE \
		i18n/en/README_UNINSTALL_EN \
		i18n/de/README_UNINSTALL_DE \
		i18n/en/README_POST_UPDATE_EN \
		i18n/de/README_POST_UPDATE_DE
	univention-appcenter-control set --noninteractive $(ucs_version)/$(app_name)=$(app_version) \
		--json '{"DockerImage": "ghcr.io/nextcloud/univention-app:$(app_version)", "UMCOptionsAttributes": "nextcloudEnabled", "WebInterface": "/nextcloud", "MinPhysicalRam": "512", "RequiredUcsVersion": "5.0-0", "SupportedUCSVersions": "5.0-0", "RequiredAppVersionUpgrade": "$(app_upgrade_from)"}'

.PHONY: docker
docker:
	if [ `systemctl is-active docker` = "inactive" ] ; then sudo systemctl start docker; fi
	sudo docker build -t $(docker_repo)/univention-app:$(app_version) .
