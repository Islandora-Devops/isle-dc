#!/bin/bash
set -euo pipefail

# Log file for tracking script operations
LOG_FILE="/tmp/drupal_troubleshoot_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Verify required commands exist
check_dependencies() {
    local deps=("drush" "composer" "awk" "grep")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "Error: $cmd is not installed"
            exit 1
        fi
    done
}

# Check Drush installation
ensure_drush() {
    if ! composer show 'drush/drush' &>/dev/null; then
        log "Installing Drush..."
        composer require drush/drush
    else
        log "Drush is already installed"
    fi
}

# Main troubleshooting function
troubleshoot_drupal() {
    local ERROR_MESSAGE
    ERROR_MESSAGE=$(drush watchdog:show --severity=Error --filter="InvalidArgumentException: A valid cache entry key is required" | awk '{print $6}')
    log "Detected Error Message: '$ERROR_MESSAGE'"

    # Retrieve enabled views
    local VIEWS_FILE="/tmp/enabled_views.txt"
    drush views:list --status=enabled --format=csv | grep -v "Machine name" | awk -F',' '{print $1}' > "$VIEWS_FILE"

    log "Views file contents:"
    log "$VIEWS_FILE"
    echo "---------------------"

    # Always process views, regardless of error message
    while IFS= read -r dis_view; do
         log "Processing view: $dis_view"
         drush views:disable "$dis_view" || log "Error disabling view: $dis_view"
         sleep 1
         drush views:enable "$dis_view" || log "Error enabling view: $dis_view"
    done < "$VIEWS_FILE"

    # Ensure Devel module
    DEVEL_INITIALLY_ENABLED=$(drush pm:list | grep devel | grep -F 'Devel (devel)' | grep -q "Enabled" && echo "Enabled" || echo "Disabled")
    log "Devel module initial state: $DEVEL_INITIALLY_ENABLED"

    if ! composer show 'drupal/devel' &>/dev/null; then
        log "Installing Devel module..."
        composer require 'drupal/devel' -W || log "Error: Devel module installation failed"
    fi

    # If it wasn't initially enabled, enable it.
    if [[ "$DEVEL_INITIALLY_ENABLED" == "Disabled" ]]; then
        drush pm:enable -y devel || log "Error: Devel module enabling failed"
    fi

    # Attempt to reinstall Islandora (with error suppression). For new installs only.
    # log "Attempting Islandora module uninstallation..."
    # drush devel:reinstall -y islandora || log "Islandora uninstall may have partial failure. This can be ignored."

    # Clear caches
    log "Rebuilding caches..."
    drush cache:rebuild
    drush cron

    log "Troubleshooting complete."
}

# Main script execution
main() {
    check_dependencies
    ensure_drush
    troubleshoot_drupal
}

# Execute main function with error trapping
if main; then
    log "Script completed successfully"
else
    log "Script encountered errors"
    exit 1
fi

# If it wasn't initially enabled, disable it at the end
if [[ "$DEVEL_INITIALLY_ENABLED" == "Disabled" ]]; then
    drush pm:uninstall -y devel
fi

echo "Check LOG at $LOG_FILE"
