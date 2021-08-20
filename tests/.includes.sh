#!/bin/bash

#
# Shell functions and environment common to all tests go here
#

# The name of the currently running Drupal Docker container
DRUPAL_CONTAINER_NAME=$(docker ps | awk '{print $NF}' | grep drupal)

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
  local hostname="$4"
  local port="$5"

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

  docker run --rm -d -P --name "${name}" --network "${network}" "${image}"
  trap "docker stop ${name}" EXIT

  if [ -z "${port}" ] ; then
    port=$(docker inspect -f "{{json .NetworkSettings.Ports }}" ${name}|jq -r '.[]|.[]|.HostPort')

    if [ -z "${port}" ] ; then
      echo "Cannot detect if ${name} has started, it doesn't publish any ports. Continuing on."
      return
    fi

    if [ $(echo ${port} | awk '{print NF}') -eq 2 ] ; then
      # the same port may be published twice, once for ipv4 and once for ipv6.
      if [ $(echo ${port} | awk '{print $1}') -eq $(echo ${port} | awk '{print $2}') ] ; then
        port=$(echo ${port} | awk '{print $1}')
      fi
    fi

    if [ $(echo ${port} | awk '{print NF}') -gt 1 ] ; then
      echo "Cannot detect if ${name} has started, it publishes multiple ports. Continuing on."
      return
    fi
  fi

  if [ -z "${hostname}" ] ; then
    hostname="localhost"
  fi

  wait_for_http "http://${hostname}:${port}/" 200
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

function wait_for_http() {
  # allow curl to error
  set +e
  local url="$1"
  local code="$2"
  local attempts="$3"
  local sleep_s="$4"
  if [ -z "$attempts" ]; then
    attempts=30
  fi
  if [ -z "${sleep_s}" ]; then
    sleep_s=1
  fi

  i=0
  while [ "$i" -lt "${attempts}" ]; do
    ((i = i + 1))
    result=$(curl -o /dev/null -s -w '%{http_code}' "$url")

    if [ "${result}" -eq "${code}" ]; then
      # reset exit flag
      set -e
      return
    else
      echo "Waiting for HTTP code ${code} from ${url} ..."
      sleep ${sleep_s}
    fi
  done

  echo "Timed out waiting for HTTP code ${code} from ${url}"
  exit 1
}

# Re-starts the Docker environment with the given environment variables appended to the existing .env
# Argument is a string that will be concatenatd with the .env file (i.e. like "FOO=BAR").
function use_env {
	if [ -f "docker-compose.yml" ]; then cp docker-compose.yml .docker-compose.yml; fi
	echo -e "\nUsing additional environment variables and re-loading containers\n\n$1\n\n"
	ENV_FILE="/tmp/$(date +%s).env"
	cat .env > "${ENV_FILE}"
	echo "$1" >> "${ENV_FILE}"

	echo -e "CI is '${CI}'\n"

	#if [ "$TEST_ENVIRONMENT" == "static" ]; then
	if [ -z ${CI} ]; then
		echo "NOT Using static environment"
		make -B docker-compose.yml args="--env-file ${ENV_FILE}"
	else
		echo "Using static environment"
		make -B static-docker-compose.yml env="${ENV_FILE}";
	fi

	make up
	mv .docker-compose.yml docker-compose.yml || make docker-compose.yml
}
