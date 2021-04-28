#!/bin/bash
set -e

TEST_DIR="$(pwd)/$(dirname $0)/$(basename $0 .sh)"
TESTCAFE_TESTS_FOLDER="${TEST_DIR}/testcafe"

# Patch config to use parse_entity_lookup, ignore if previously applied
# Accommodate the use of the static image in CI
# TODO: this should be removed after the development branch configuration is updated to use the parse_entity_lookup plugin
STATIC=`cat docker-compose.yml | grep DRUPAL_INSTANCE | grep static | wc -l`
if [ $STATIC -lt 1 ]; then
  patch -p1 -N < "${TEST_DIR}/config.patch"
  trap "git checkout -- codebase/config/sync/migrate_plus.migration.idc_ingest_new_items.yml" EXIT
else
  docker cp "${TEST_DIR}/config.patch" "${DRUPAL_CONTAINER_NAME}:/var/www/drupal"
  docker-compose exec -T drupal /bin/bash -c 'cat ./config.patch | patch --verbose -p 2'
fi
make config-import cache-rebuild

# Make sure a screenshots directory is available
mkdir "${TESTCAFE_TESTS_FOLDER}/screenshots" && chmod 777 "${TESTCAFE_TESTS_FOLDER}/screenshots"

# Execute migrations using testcafe
docker run --network gateway -v "${TESTCAFE_TESTS_FOLDER}":/tests testcafe/testcafe --screenshots path=/tests/screenshots,takeOnFails=true chromium /tests/**/*.js
