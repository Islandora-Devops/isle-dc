#!/usr/bin/env bash
set -e

# To be precise on the error message that matches the error this should address.
ERROR_MESSAGE=$(drush watchdog:show --severity=Error --filter="InvalidArgumentException: A valid cache entry key is required" | awk '{print $6}')

# If error message equals to "No such file or directory", then exit.
if [[ $ERROR_MESSAGE == *'InvalidArgumentException'* ]]; then
	# Install Drupal Console.
	composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader -W

	# Reinstall views
	/var/www/drupal/vendor/drupal/console/bin/drupal debug:views --status='Enabled' | awk '{system("/var/www/drupal/vendor/drupal/console/bin/drupal views:disable " $1)}'
	/var/www/drupal/vendor/drupal/console/bin/drupal debug:views --status='Disabled' | awk '{system("/var/www/drupal/vendor/drupal/console/bin/drupal views:enable " $1)}'

	# Install devel.
	composer require 'drupal/devel:^4.1' -W && drush pm:enable -y devel
	drush dev:reinstall islandora

	# Clear caches
	/var/www/drupal/vendor/drupal/console/bin/drupal cache:rebuild
	/var/www/drupal/vendor/drupal/console/bin/drupal cr all
	/var/www/drupal/vendor/drupal/console/bin/drupal node:access:rebuild
	drush cron
fi
