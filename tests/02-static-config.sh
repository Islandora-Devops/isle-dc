#!/bin/sh
set -e

# Verifies that bad configuration in config/sync will cause a startup failure for Docker

# First, check to seee if docker-compose.yml defines DRUPAL_INSTANCE: static.  If not, we're not
# using the static environment and should skip this test
STATIC=`cat docker-compose.yml | grep DRUPAL_INSTANCE | grep static | wc -l`
if [ $STATIC -lt 1 ]; then
	echo "Skipping tests on non-static environment"
	exit 0
fi

# corrupt a config file, stop Drupal, and start it.  Expect an error upon startup
docker-compose exec -T drupal mv config/sync/core.extension.yml config/sync/_core.extension.yml
echo "Corrupting the config and re-starting Drupal"
docker-compose stop drupal 
make up  && echo "Did not encounter error when starting Drupal with corrupt config" && exit 1
echo "Drupal failed as expected"