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
  openseadragon \
  islandora_defaults \
  controlled_access_terms_defaults \
  islandora_breadcrumbs \
  islandora_iiif \
  islandora_oaipmh \
  islandora_fits \
  islandora_search

echo "Import JWT config"
sudo drush config-import -y --partial --source=/opt/drupal_config

echo "Import features"
drush -y fim islandora_core_feature,controlled_access_terms_defaults,islandora_defaults,islandora_search

echo "Set file upload destinations (temporary and will change with MVP3)"
drush cset -y field.storage.media.field_media_file settings.uri_scheme public
drush cset -y field.storage.media.field_media_audio_file settings.uri_scheme public
drush cset -y field.storage.media.field_media_image settings.uri_scheme public
drush cset -y field.storage.media.field_media_video_file settings.uri_scheme public

echo "Copy openseadragon library definition"
cp /var/www/html/web/modules/contrib/openseadragon/openseadragon.json /var/www/html/web/sites/default/files/library-definitions

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

echo "Set JSONLD Config"
drush cset -y --input-format=yaml jsonld.settings remove_jsonld_format true

echo "Set message broker URL"
drush cset -y --input-format=yaml islandora.settings broker_url tcp://activemq:61613

echo "Set Gemini URL"
drush cset -y --input-format=yaml islandora.settings gemini_url http://gemini:8000/gemini

echo "Set pseudo field bundles"
drush cset -y --input-format=yaml islandora.settings gemini_pseudo_bundles.0 islandora_object:node
drush cset -y --input-format=yaml islandora.settings gemini_pseudo_bundles.1 image:media
drush cset -y --input-format=yaml islandora.settings gemini_pseudo_bundles.2 file:media
drush cset -y --input-format=yaml islandora.settings gemini_pseudo_bundles.3 audio:media
drush cset -y --input-format=yaml islandora.settings gemini_pseudo_bundles.4 video:media

echo "Set media urls"
drush cset -y --input-format=yaml media.settings standalone_url true

echo "Set iiif url"
drush cset -y --input-format=yaml openseadragon.settings iiif_server http://cantaloupe:8182/cantaloupe/iiif/2
drush cset -y --input-format=yaml islandora_iiif.settings iiif_server http://cantaloupe:8182/cantaloupe/iiif/2

echo "Set iiif manifest view"
drush cset -y --input-format=yaml openseadragon.settings manifest_view iiif_manifest



echo "Run migrations"
drush -y -l idcp.localhost --userid=1 mim --group=islandora

echo "Clear all caches"
drush cr

exit
