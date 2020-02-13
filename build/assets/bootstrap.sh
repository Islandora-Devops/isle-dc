#!/bin/sh

MYSQL_HOST=isle-dc-mysql-$CONTAINER_SHORT_ID
DRUPAL_HOST=isle-dc-drupal-$CONTAINER_SHORT_ID

# First, create the Drupal user
echo "Creating Drupal db and user in mysql"
docker exec -i $MYSQL_HOST bash <<EOF
mysql -uroot -p${MYSQL_ROOT_PASSWORD} <<SQL_EOF
CREATE USER IF NOT EXISTS '${DRUPAL_MYSQL_USER}'@'%' IDENTIFIED BY '${DRUPAL_MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${DRUPAL_MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL_EOF
EOF

# Install Drupal site
echo "Installing basic Drupal site"
docker exec -i $DRUPAL_HOST bash <<EOF
  drush site-install standard -y --root=/var/www/html/drupal/web --site-name="Islandora 8" --account-name=admin --account-pass=islandora --db-url=mysql://${DRUPAL_MYSQL_USER}:${DRUPAL_MYSQL_PASSWORD}@${MYSQL_HOST}/${DRUPAL_MYSQL_DATABASE} --debug -vvv
EOF

# Configure the Drupal site.  I think this is where the bulk of
# The Islandora install action would occur
echo "Configuring Drupal site"
docker exec -i $DRUPAL_HOST bash <<EOF
  composer require drupal/bootstrap
  drush theme:enable bootstrap
  drush config:set system.theme default bootstrap
  composer require drupal/search_api_solr
  drush en -y search_api_solr
EOF