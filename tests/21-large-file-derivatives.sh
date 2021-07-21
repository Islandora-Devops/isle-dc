#!/bin/bash
set -e

BASE_TEST_FOLDER="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${BASE_TEST_FOLDER}/testcafe"
TESTCAFE_IMAGE=testcafe/testcafe

# Start the backend that serves the media files to be migrated
# Listens internally on port 80 (addressed as http://<assets_container>/assets/)
startMigrationAssetsContainer

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests ${TESTCAFE_IMAGE} --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/init.js --selector-timeout 120000 --assertion-timeout 120000 --page-load-timeout 120000 --ajax-request-timeout 120000 --page-request-timeout 120000 --browser-init-timeout 120000

# Verify migrations using go
# Build docker image (TODO: should it be defined in docker-compose.yml to avoid any env issues?)
docker build -t local/derivative-backend-tests "${BASE_TEST_FOLDER}/verification"

# Execute tests in docker image, on the same docker network (gateway, idc_default?) as Drupal
# TODO: expose logs when failing tests?
# N.B. trailing slash on the BASE_ASSETS_URL is important.  uses the internal URL.
docker run --network gateway --rm -e PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME} -e ALPACA_HOMERUS_HTTP_SOCKET_TIMEOUT_MS=${ALPACA_HOMERUS_HTTP_SOCKET_TIMEOUT_MS} local/derivative-backend-tests
