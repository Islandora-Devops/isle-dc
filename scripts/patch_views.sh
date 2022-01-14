#!/usr/bin/env bash
set -e

# Reinstall views
/var/www/drupal/vendor/drupal/console/bin/drupal views:debug | grep Enabled | awk '{system("/var/www/drupal/vendor/drupal/console/bin/drupal views:disable " $1)}'
/var/www/drupal/vendor/drupal/console/bin/drupal views:debug | grep Disabled | awk '{system("/var/www/drupal/vendor/drupal/console/bin/drupal views:enable " $1)}'

# Install devel.
composer require 'drupal/devel:^4.1' -W && drush pm:enable -y devel
drush dev:reinstall islandora

# Clear caches
/var/www/drupal/vendor/drupal/console/bin/drupal cache:rebuild
/var/www/drupal/vendor/drupal/console/bin/drupal cr all
/var/www/drupal/vendor/drupal/console/bin/drupal node:access:rebuild
drush cron
