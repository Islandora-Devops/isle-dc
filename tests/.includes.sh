#!/bin/bash

#
# Shell functions and environment common to all tests go here
#

# The name of the currently running Drupal Docker container
DRUPAL_CONTAINER_NAME=$(docker ps | awk '{print $NF}'|grep drupal)

# The Docker registry used to obtain the migration assets image
assets_repo=${MIGRATION_ASSETS_REPO:-ghcr.io/jhu-sheridan-libraries/idc-isle-dc}
# The name of the Docker image for migration assets
assets_image=${MIGRATION_ASSETS_IMAGE:-migration-assets}
# The migration assets image tag
assets_image_tag=${MIGRATION_ASSETS_IMAGE_TAG}
# The *external* port the migration assets HTTP server listens on
ext_assets_port=${MIGRATION_ASSETS_PORT:-8081}
# The name used by the migration assets container
assets_container=${MIGRATION_ASSETS_CONTAINER:-migration-assets}

# Starts the assets container used for migrations
function startMigrationAssetsContainer {
  startContainer ${assets_container} ${assets_repo}/${assets_image}:${assets_image_tag}
}

function startContainer {
  local name="$1"
  local image="$2"
  local network="$3"

  if [ -z "$name" ] ; then
    echo "'name' argument is required"
    exit 1
  fi

  if [ -z "$image" ] ; then
    echo "'image' argument is required"
    exit 1
  fi

  if [ -z "$network" ] ; then
    network="gateway"
  fi

  docker run --rm -d --name "${name}" --network "${network}" "${image}"
  trap "docker stop ${name}" EXIT
}

function stopContainer {
  local name="$1"
  local rm="$2"

  if [ -z "$name" ] ; then
    echo "'name' argument is required"
    exit 1
  fi

  docker stop "${name}"

  if [ "true" == "$rm" ] ; then
    docker rm -f "${name}"
  fi
}
