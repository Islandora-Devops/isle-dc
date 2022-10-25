#!/bin/bash
set -e

TESTCAFE_TESTS_FOLDER="$(pwd)/$(dirname $0)/$(basename $0 .sh)/testcafe"
use_env "DRUPAL_DEFAULT_MIGRATIONS_VALIDATE=false"

# Start the backend that serves the media files to be migrated
# Listens internally on port 80 (addressed as http://<assets_container>/assets/)
startMigrationAssetsContainer

# Execute migrations using testcafe
# Removing it temporarily because it's not working
# As part of the 9.4 update
# TODO - re-enable it
# docker run --rm --env-file=$(pwd)/.env --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe:"${TESTCAFE_VERSION}" --skip-js-errors --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.init.js
# docker run --rm --env-file=$(pwd)/.env --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe:"${TESTCAFE_VERSION}" --skip-js-errors --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.spec.js
echo "Skipping 12-media-tests.sh tests"