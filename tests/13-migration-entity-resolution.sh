#!/bin/bash
set -e

TEST_DIR="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${TEST_DIR}/testcafe"
use_env "DRUPAL_DEFAULT_MIGRATIONS_VALIDATE=false"

# Make sure a screenshots directory is available
mkdir "${TESTCAFE_TESTS_FOLDER}/screenshots" && chmod 777 "${TESTCAFE_TESTS_FOLDER}/screenshots"

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js
