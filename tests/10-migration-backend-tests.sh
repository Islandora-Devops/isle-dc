#!/bin/bash
set -e

BASE_TEST_FOLDER=10-migration-backend-tests
DRUPAL_CONTAINER_NAME=$(docker ps | awk '{print $NF}'|grep drupal)
CURRENT_DIR=$(pwd)

# The Docker registry used to obtain the migration assets image
assets_repo=${MIGRATION_ASSETS_REPO:-ghcr.io/jhu-sheridan-libraries/idc-isle-dc}
# The name of the Docker image for migration assets
assets_image=${MIGRATION_ASSETS_IMAGE:-migration-assets}
# The migration assets image tag
assets_image_tag=${MIGRATION_ASSETS_IMAGE_TAG:-9a3b4d9.1617309560}
# The *external* port the migration assets HTTP server listens on
ext_assets_port=${MIGRATION_ASSETS_PORT:-8081}
# The name used by the migration assets container
assets_container=${MIGRATION_ASSETS_CONTAINER:-migration-assets}

# Locate test directory
if [ ! -d ${BASE_TEST_FOLDER} ] ;
then
  BASE_TEST_FOLDER=tests/${BASE_TEST_FOLDER}
  if [ ! -d ${BASE_TEST_FOLDER} ] ;
  then
    echo "Missing expected test directory ${BASE_TEST_FOLDER}"
    exit 1
  else
    cd ${BASE_TEST_FOLDER}
  fi
else
  cd ${BASE_TEST_FOLDER}
fi

TESTCAFE_TESTS_FOLDER=$(pwd)/testcafe

# Start the backend that serves the media files to be migrated
# Listens internally on port 80 (addressed as http://<assets_container>/assets/)
docker run --name ${assets_container} --network gateway --rm -d ${assets_repo}/${assets_image}:${assets_image_tag}
trap "docker stop ${assets_container}" EXIT

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js

# Verify migrations using go
# Build docker image (TODO: should it be defined in docker-compose.yml to avoid any env issues?)
docker build -t local/migration-backend-tests ./verification

# Execute tests in docker image, on the same docker network (gateway, idc_default?) as Drupal
# TODO: expose logs when failing tests?
# N.B. trailing slash on the BASE_ASSETS_URL is important.  uses the internal URL.
docker run --network gateway --rm -e BASE_ASSETS_URL=http://${assets_container}/assets/ local/migration-backend-tests

# Back to parent directory
cd ${CURRENT_DIR}
