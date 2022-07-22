#!/usr/bin/env bash

# to be called from this directory
# usage: _bump.sh TARGET_VERSION

TARGET_VERSION=${1}

function main() {
  BRANCH="prepare/${TARGET_VERSION}"
  git fetch
  git checkout -b ${BRANCH} origin/master

  # OLD_VERSION=$(grep -Po '^ADD.*nextcloud-\K[0-9]{2,3}\.[0-9]\.[0-9]{1,2}[^\.]*' Dockerfile)
  sed -i -E "s/nextcloud-[0-9]{2,3}\.[0-9]\.[0-9]{1,2}[^\.]*/nextcloud-${TARGET_VERSION}/" Dockerfile

  SHIPPED_APPS=(richdocuments onlyoffice)
  for APPID in ${SHIPPED_APPS[@]}; do
    DOWNLOADLINK=$(get_app_download_uri ${APPID})
    sed -i -E "s#ADD.* /root/${APPID}.tar.gz#ADD ${DOWNLOADLINK} /root/${APPID}.tar.gz#" Dockerfile
    echo $DOWNLOADLINK
  done

  # FIXME: adjust version in Makefile

  git diff
  git commit -sam "prepare ${TARGET_VERSION}"
  # FIXME: allow to override tag
  git tag "${TARGET_VERSION}-0"
  git push --tags origin "${BRANCH}"

  TODOS=$(cat <<EOL
* [ ] test fresh install
* [ ] test upgrade
* [ ] request publish
* [ ] assert publishedgit
EOL
  )

  # FIXME: GITHUB_TOKEN not set
  PULL_REQUEST=$(curl --silent \
      -X POST \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      https://api.github.com/repos/nextcloud/univention-app/pulls \
      -d "{
        \"title\":\"prepare ${TARGET_VERSION}\",
        \"body\":\"${TODOS}\",
        \"head\":\"${BRANCH}\",
        \"base\":\"master\"
      }") \
      && echo "PR opened at $(${PULL_REQUEST} | jq -r .html_url)"

  # FIXME: call make add-version
  # FIXME: call push-files
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
