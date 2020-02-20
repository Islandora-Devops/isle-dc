#!/bin/bash

# Drupal install script
# composer.json and composer.lock file were from:
# git clone https://github.com/drupal/recommended-project.git

echo "Copying composer files to /var/www/html"
cp /scripts/drupal/composer.json /var/www/html/
cp /scripts/drupal/composer.lock /var/www/html/
chmod 755 /var/www/html/composer.*

cd /var/www/html || exit

echo "composer install"
composer install

echo "composer update && installing Drupal console"
chmod u+w web/sites/default
composer update
composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader

echo "Installing Drupal site"
drupal site:install $DRUPAL_INSTALL_TYPE  \
--langcode=$DRUPAL_LANGUAGE  \
--db-type=$DB_DRIVER  \
--db-host=$DB_HOST  \
--db-name=$DB_NAME  \
--db-user=$DB_USER  \
--db-pass=$DB_PASSWORD  \
--db-port=$DB_PORT  \
--site-name=$DRUPAL_SITE_NAME  \
--site-mail=$DRUPAL_SITE_MAIL  \
--account-name=$DRUPAL_USER  \
--account-mail=$DRUPAL_USER_EMAIL  \
--account-pass=$DRUPAL_USER_PASSWORD

echo "Updating Composer and dependencies"
chmod u+w web/sites/default
composer update

echo "Disabling & removing Drupal module - search"
drupal module:uninstall -y search
composer remove drupal/search

echo "Set Solr server config"
drupal settings:set -y search_api.server.default_solr_server backend_config.connector_config.host solr

exit