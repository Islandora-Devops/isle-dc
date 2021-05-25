#!/usr/bin/with-contenv bash
set -e

source /etc/islandora/utilities.sh

function main {
    local site="default"
    # Creates database if does not already exist.
    create_database "${site}"
    # Needs to be set to do an install from existing configuration.
    drush islandora:settings:create-settings-if-missing
    drush islandora:settings:set-config-sync-directory "${DRUPAL_DEFAULT_CONFIGDIR}"
    install_site "${site}"
    # Settings like the hash / flystem can be affected by environment variables at runtime.
    update_settings_php "${site}"
    # Ensure that settings which depend on environment variables like service urls are set dynamically on startup.
    configure_islandora_module "${site}"
    configure_matomo_module "${site}"
    configure_openseadragon "${site}"
    configure_islandora_default_module "${site}"
    # The following commands require several services
    # to be up and running before they can complete.
    wait_for_required_services "${site}"
    # Create missing solr cores.
    create_solr_core_with_default_config "${site}"
    # Create namespace assumed one per site.
    create_blazegraph_namespace_with_default_properties "${site}"
    # Need to run migration to get expected default content, now that our required services are running.
    import_islandora_migrations "${site}"
    # Rebuild the cache.
    drush cr
}
main
