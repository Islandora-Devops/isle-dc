#!/bin/bash

# Drupal install script
# composer.json and composer.lock file were from:
# git clone https://github.com/drupal/recommended-project.git

# TO DO: Replace this block below with a git clone in MVP2
# TO DO: Determine what elements of the following composer.json files below go into the demo.
# https://github.com/drupal/recommended-project.git
# https://github.com/drupal-composer/drupal-project/blob/8.x/composer.json
# https://github.com/Islandora/drupal-project/blob/8.x-1.x/composer.json
# scripts/drupal.composer.json (checked into ISLE git repo resulting from MVP 1)

echo "Copying composer files to /var/www/html"
cp /scripts/drupal/composer.json /var/www/html/
cp /scripts/drupal/composer.lock /var/www/html/
chmod 755 /var/www/html/composer.*

# TO DO: mkdir theme dir and other necessary sub-folders

cd /var/www/html || exit

echo "composer update && installing Drupal console"
composer update
chmod u+w web/sites/default
composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader

echo "Installing Drupal site"
drupal site:install "$DRUPAL_INSTALL_TYPE"  \
--langcode="$DRUPAL_LANGUAGE"  \
--db-type="$DB_DRIVER"  \
--db-host="$DB_HOST"  \
--db-name="$DB_NAME"  \
--db-user="$DB_USER" \
--db-pass="$DB_PASSWORD"  \
--db-port="$DB_PORT"  \
--db-prefix="$DB_PREFIX" \
--site-name="$DRUPAL_SITE_NAME"  \
--site-mail="$DRUPAL_SITE_MAIL"  \
--account-name="$DRUPAL_USER"  \
--account-mail="$DRUPAL_USER_EMAIL"  \
--account-pass="$DRUPAL_USER_PASSWORD"

echo "Fixing perms on web/sites/default"
chmod u+w web/sites/default

echo "Enable Solr modules"
drush en -y search_api search_api_solr

echo "Enabling Drupal modules - search_api_solr_defaults search_api_solr_admin"
drush en -y search_api_solr_defaults search_api_solr_admin

echo "Disabling & removing Drupal module - search"
drush pm-uninstall -y search

echo "Set Solr server config"
drush cset search_api.server.default_solr_server backend_config.connector_config.host solr

exit