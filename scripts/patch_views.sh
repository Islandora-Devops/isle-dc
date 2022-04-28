#!/usr/bin/env bash
set -e

# To be precise on the error message that matches the error this should address.
ERROR_MESSAGE=$(drush watchdog:show --severity=Error --filter="InvalidArgumentException: A valid cache entry key is required" | awk '{print $6}')

# If error message equals to "No such file or directory", then exit.
if [[ $ERROR_MESSAGE == *'InvalidArgumentException'* ]]; then

	# Install Drupal Console.
	drupal_console_installed() {
		composer show 'drupal/console' | grep -q '/var/www/drupal/vendor/drupal/console'
	}
	if drupal_console_installed; then
		echo 'Package installed'
	else
		composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader -W
	fi

	# Reinstall views
	enabled_view=`/var/www/drupal/vendor/drupal/console/bin/drupal debug:views --status='Enabled' | cut -d ' ' -f 2 | tail -n +2`
	for dis_view in $enabled_view; do
		echo "Disabling view $dis_view"
		/var/www/drupal/vendor/drupal/console/bin/drupal views:disable $dis_view
	done

	for en_view in $enabled_view; do
		echo "Reenabling view $en_view"
		/var/www/drupal/vendor/drupal/console/bin/drupal views:enable $en_view
	done

	# Install devel.
	devel_installed() {
		composer show 'drupal/devel' | grep -q '/var/www/drupal/web/modules/contrib/devel'
	}
	if devel_installed; then
		echo 'Package installed'
	else
		composer require 'drupal/devel:^4.1' -W
	fi
	drush pm:enable -y devel

	echo -e "\n\nThis will likely throw an error, but that's okay.  It's just a patch.\n\n"
	{ # try
    drush dev:reinstall -y islandora
	} || { # catch
		echo -e "\nIgnore these errors. This will fail if any content is already created.\n\n"
	}

	# Clear caches
	/var/www/drupal/vendor/drupal/console/bin/drupal cache:rebuild
	/var/www/drupal/vendor/drupal/console/bin/drupal cr all
	/var/www/drupal/vendor/drupal/console/bin/drupal node:access:rebuild
	drush cron
fi
