#!/bin/bash
set -e

# To be precise on the error message that matches the error this should address.
ERROR_MESSAGE=$(drush watchdog:show --severity=Error --filter="InvalidArgumentException: A valid cache entry key is required" | awk '{print $6}')

# If error message equals to "InvalidArgumentException", then exit.
if [[ $ERROR_MESSAGE == *'InvalidArgumentException'* ]]; then

    Check if drush is installed (Drupal Console replacement).
    drush_installed() {
        composer show 'drush/drush' | grep -q '/var/www/drupal/vendor/drush/drush'
    }
    if drush_installed; then
        echo 'Drush installed'
    else
        composer require drush/drush
    fi

    # Retrieve the list of enabled views by isolating the first column (view names) where the status is "Enabled"
    VIEWS_FILE="enabled_views.txt"

    # Get the list of enabled views and store it in the file without truncation
    # Force drush to output in CSV format to avoid terminal width truncation issues
    drush views:list --status=enabled --format=csv | grep -v "Machine name" | awk -F',' '{print $1}' > "$VIEWS_FILE"

    # Check if the file exists and is not empty
    if [[ ! -s "$VIEWS_FILE" ]]; then
        printf "Error: No enabled views found or unable to retrieve views list.\n" >&2
        exit 1
    fi

    # Read the file line by line to process each view
    while IFS= read -r dis_view; do
        printf "Reloading view: %s\n" "$dis_view"
        drush views:disable "$dis_view"
        sleep 1
        drush views:enable "$dis_view"
    done < "$VIEWS_FILE"

    # Install devel.
    devel_installed() {
        composer show 'drupal/devel' | grep -q '/var/www/drupal/web/modules/contrib/devel'
    }
    if devel_installed; then
        echo 'Devel module installed'
    else
        composer require 'drupal/devel' -W
    fi
    drush pm:enable -y devel

    echo -e "nnThis will likely throw an error, but that's okay.  It's just a patch.nn"
    { # try
        drush pm:uninstall -y islandora
    } || { # catch
        echo -e "nIgnore these errors. This will fail if any content is already created.nn"
    }

    # Clear caches
    drush cache:rebuild
    drush cr
    drush cron
# fi
