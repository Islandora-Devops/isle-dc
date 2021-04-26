#!/bin/bash
set -e

TEST_DIR="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${TEST_DIR}/testcafe"

# Patch config to use parse_entity_lookup, ignore if previously applied
# TODO: this should be removed after the development branch configuration is updated to use the parse_entity_lookup plugin
patch -p1 -N < "${TEST_DIR}/config.patch" && make config-import

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --dev --selector-timeout 120000 --page-load-timeout 120000 --assertion-timeout 120000 --ajax-request-timeout 120000 --page-request-timeout 120000 --browser-init-timeout 120000 --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js
