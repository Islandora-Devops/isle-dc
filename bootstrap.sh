echo "Setting up docker-compose.yml file, if it doesn't exist already"
make
echo "Destroying old ISLE state"
docker-compose down -v
echo "[ISLE DC] Starting ISLE..."
docker-compose up -d
echo "[ISLE DC] Composer install..."
docker-compose exec drupal with-contenv bash -lc 'COMPOSER_MEMORY_LIMIT=-1 composer install'
echo "[ISLE DC] make install..."
make install
echo "[ISLE DC] updating/managing settings..."
make update-settings-php update-config-from-environment solr-cores run-islandora-migrations
echo "[ISLE DC] rebuilding Drupal cache..."
docker-compose exec drupal drush cr -y
