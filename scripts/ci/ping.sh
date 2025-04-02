#!/usr/bin/env bash

COUNTER=0
while true; do
  HTTP_STATUS=$(curl -w '%{http_code}' -o /dev/null -s https://islandora.dev/)
  echo "Ping returned http status ${HTTP_STATUS}, exit code $?"
  if [ "${HTTP_STATUS}" -eq 200 ]; then
    echo "We're live 🚀"
    break
  fi

  ((COUNTER++))
  if [ "${COUNTER}" -eq 50 ]; then
    echo "Failed to come online after 4m"
    exit 1
  fi
  sleep 5;
done

echo "Making sure containers trust the self-signed cert"
docker compose exec houdini curl -vf https://islandora.dev -o /dev/null
