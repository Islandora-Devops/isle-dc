#!/bin/bash
set -e

BASE_TEST_FOLDER="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${BASE_TEST_FOLDER}/testcafe"
TESTCAFE_IMAGE=testcafe/testcafe
use_env "DRUPAL_DEFAULT_MIGRATIONS_VALIDATE=false"

# Start the backend that serves the media files to be migrated
# Listens internally on port 80 (addressed as http://<assets_container>/assets/)
startMigrationAssetsContainer

# Execute migrations using testcafe
docker run --env-file=$(pwd)/.env --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests ${TESTCAFE_IMAGE} --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/init.js --selector-timeout 120000 --assertion-timeout 120000 --page-load-timeout 120000 --ajax-request-timeout 120000 --page-request-timeout 120000 --browser-init-timeout 120000

# Verify migrations using go
# Build docker image (TODO: should it be defined in docker-compose.yml to avoid any env issues?)
docker build -t local/derivative-backend-tests "${BASE_TEST_FOLDER}/verification"

# Execute tests in docker image, on the same docker network (gateway, idc_default?) as Drupal
# TODO: expose logs when failing tests?
# N.B. trailing slash on the BASE_ASSETS_URL is important.  uses the internal URL.
docker run --env-file=$(pwd)/.env --network gateway --rm -e PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME} -e ALPACA_HOMERUS_HTTP_SOCKET_TIMEOUT_MS=${ALPACA_HOMERUS_HTTP_SOCKET_TIMEOUT_MS} local/derivative-backend-tests

# Test to make sure the JWT expiry is equal to or greater than 14400
docker-compose exec -T drupal bash -lc "set -vex ; drush en jwt_auth_issuer && apk add jq && printf '%s-' $(date '+%s') > /tmp/calc ; curl -s -u admin:password http://localhost/jwt/token | jq .token |cut -f 2 -d "."|base64 -d 2>/dev/null|awk 'BEGIN {RS=\",\";FS=\":\";} /exp/ { print \$2\"\\n\"}' | sed -e '/^$/d' >> /tmp/calc ; cat /tmp/calc; bc < /tmp/calc |sed -e s/-// > /tmp/res ; [ 14400 -le \`cat /tmp/res\` ]"
