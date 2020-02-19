#!/bin/bash

# Wodby Drupal install script
# composer.json and composer.lock file were from:
# git clone https://github.com/drupal/recommended-project.git
# Updates made to these files once configuring setup

#echo "Installing Drupal site code"
#docker exec -it isle_dc_proto_php bash -c "chmod u+w web/sites/default && composer install"

echo "Updating Composer and dependencies"
docker exec -it isle_dc_proto_php bash -c "chmod u+w web/sites/default && composer update"

echo "Enabling Drupal modules - search_api search_api_solr"
docker exec -it isle_dc_proto_php bash -c "drush en -y search_api search_api_solr"

echo "Disabling & removing Drupal module - search"
docker exec -it isle_dc_proto_php bash -c "drush pm-uninstall -y search"

echo "Enabling Drupal modules - search_api_solr_defaults search_api_solr_admin"
docker exec -it isle_dc_proto_php bash -c "drush en -y search_api_solr_defaults search_api_solr_admin"

echo "Updating Drupal console"
docker exec -it isle_dc_proto_php bash -c "chmod u+w web/sites/default && composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader"

echo "Updating Composer and dependencies"
docker exec -it isle_dc_proto_php bash -c "chmod u+w web/sites/default && composer update"

# echo "Import Solr config"

exit