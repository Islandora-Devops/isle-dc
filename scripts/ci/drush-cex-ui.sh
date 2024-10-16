#!/usr/bin/env bash

set -eou pipefail

ULI=$(make login | grep traefik)
echo "getting cookie from $ULI"
COOKIE=$(curl -L -s -c - "${ULI}")

# try exporting the config through the UI
STATUS=$(curl -s \
    --cookie <(echo "$COOKIE") \
    -w '%{http_code}' \
    -o /dev/null \
    https://islandora.traefik.me/admin/config/development/configuration/full/export-download)

# make sure the config export worked
if [ ${STATUS} -ne 200 ]; then
    echo "Could not export config through Drupal UI"
    echo ${STATUS}
    exit 1
fi
