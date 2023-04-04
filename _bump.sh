#!/usr/bin/env bash

# to be called from this directory
# usage: _bump.sh TARGET_VERSION

TARGET_VERSION=${1}

function main() {
  # OLD_VERSION=$(grep -Po '^ADD.*nextcloud-\K[0-9]{2,3}\.[0-9]\.[0-9]{1,2}[^\.]*' Dockerfile)
  sed -i -E "s/nextcloud-[0-9]{2,3}\.[0-9]\.[0-9]{1,2}[^\.]*/nextcloud-${TARGET_VERSION}/" Dockerfile

  SHIPPED_APPS=(richdocuments onlyoffice)
  for APPID in ${SHIPPED_APPS[@]}; do
    DOWNLOADLINK=$(get_app_download_uri ${APPID})
    sed -i -E "s#ADD.* /root/${APPID}.tar.gz#ADD ${DOWNLOADLINK} /root/${APPID}.tar.gz#" Dockerfile
    echo $DOWNLOADLINK
  done

  sed -i -E "s/app_version=[0-9]{2,3}\.[0-9]\.[0-9]{1,2}-1/app_version=${TARGET_VERSION}-0/" Makefile
}

function get_app_download_uri() {
  APPID=${1}
  echo $(get_apps_json | jq -r -c ".[] | select(.id == \"${APPID}\") | .releases | .[0] | .download")
}

function get_apps_json() {
  # downloads it just once from poor appstore
  APPS_JSON=${APPS_JSON:=$(curl --silent https://apps.nextcloud.com/api/v1/platform/${TARGET_VERSION}/apps.json)}
  echo ${APPS_JSON}
}

main
