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

echo "Clone drupal-project to /var/www/html"
git clone -b isle8-dev https://github.com/Born-Digital-US/drupal-project.git /var/www/html
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

echo "Enable Drupal & Solr modules"
drush en -y rdf \
  responsive_image \
  devel \
  syslog \
  serialization \
  basic_auth \
  rest restui \
  search_api \
  search_api_solr \
  search_api_solr_defaults \
  search_api_solr_admin \
  facets \
  content_browser \
  pdf \
  admin_toolbar \
  islandora_defaults \
  controlled_access_terms_defaults \
  islandora_breadcrumbs \
  islandora_iiif \
  islandora_oaipmh

echo "Enable and set Carapace theme"
drush -y theme:enable carapace
drush -y config-set system.theme default carapace
# After all of this, rebuild the cache.
drush -y cr

echo "Disabling & removing Drupal module - search"
drush pm-uninstall -y search

echo "Set Solr server & core config"
drush cset -y search_api.server.default_solr_server backend_config.connector_config.host solr
drush cset -y search_api.server.default_solr_server backend_config.connector_config.core islandora

echo "Clear all caches"
drush cr

exit