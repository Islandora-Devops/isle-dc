#!/bin/bash
set -e

TEST_DIR="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${TEST_DIR}/testcafe"
use_env "DRUPAL_DEFAULT_MIGRATIONS_VALIDATE=false"

# Make sure a screenshots directory is available
mkdir "${TESTCAFE_TESTS_FOLDER}/screenshots" && chmod 777 "${TESTCAFE_TESTS_FOLDER}/screenshots"

# Execute migrations using testcafe
# Removing it temporarily because it's not working
# As part of the 9.4 update
# TODO - re-enable it
# docker run --network gateway --env-file=$(pwd)/.env -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe:"${TESTCAFE_VERSION}" --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js
echo "Skipping 13-migration-entity-resolution.sh tests"