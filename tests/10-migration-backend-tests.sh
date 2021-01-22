#!/bin/sh
set -e

BASE_TEST_FOLDER=10-migration-backend-tests
DRUPAL_CONTAINER_NAME=$(docker ps | awk '{print $NF}'|grep drupal)
CURRENT_DIR=$(pwd)

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

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js

# Verify migrations using go

# Build docker image (TODO: should it be defined in docker-compose.yml to avoid any env issues?)
docker build -t local:migration-backend-tests ./verification

# Execute tests in docker image, on the same docker network (gateway, idc_default?) as Drupal
# TODO: expose logs when failing tests?
docker run --network gateway --rm local:migration-backend-tests

# Back to parent directory
cd ${CURRENT_DIR}
