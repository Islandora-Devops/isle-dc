#!/bin/bash
set -e

BASE_TEST_FOLDER=11-file-deletion-tests
DRUPAL_CONTAINER_NAME=$(docker ps | awk '{print $NF}'|grep drupal)
CURRENT_DIR=$(pwd)

# The Docker registry used to obtain the migration assets image
assets_repo=${MIGRATION_ASSETS_REPO:-ghcr.io/jhu-sheridan-libraries/idc-isle-dc}
# The name of the Docker image for migration assets
assets_image=${MIGRATION_ASSETS_IMAGE:-migration-assets}
# The migration assets image tag
assets_image_tag=${MIGRATION_ASSETS_IMAGE_TAG:-088c482.1617637226}
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

# Back to parent directory
cd ${CURRENT_DIR}
