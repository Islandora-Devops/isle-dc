#!/bin/bash
set -e

BASE_TEST_FOLDER="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="$BASE_TEST_FOLDER/testcafe"

# Start the backend that serves the media files to be migrated
# Listens internally on port 80 (addressed as http://<assets_container>/assets/)
startMigrationAssetsContainer

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js

# Verify migrations using go
# Build docker image (TODO: should it be defined in docker-compose.yml to avoid any env issues?)
docker build -t local/migration-backend-tests "${BASE_TEST_FOLDER}/verification"

# Execute tests in docker image, on the same docker network (gateway, idc_default?) as Drupal
# TODO: expose logs when failing tests?
# N.B. trailing slash on the BASE_ASSETS_URL is important.  uses the internal URL.
docker run --network gateway --env-file=$(pwd)/.env --rm -e BASE_ASSETS_URL=http://${assets_container}/assets/ local/migration-backend-tests
