#!/bin/bash

echo "Changing to /var/www/drupal/"
cd /var/www/drupal/ || exit

drush -y solr-gsc default_solr_server /tmp/solr_config.zip 7.1

mkdir -p /opt/solr/server/solr/islandora/conf || true

mkdir -p /opt/solr/server/solr/islandora/data || true

unzip -o /tmp/solr_config.zip -d /opt/solr/server/solr/islandora/conf

# The uid:gid "100:1000" is "solr:solr" inside of the solr container.

chown -R 100:1000 /opt/solr/server/solr/islandora

curl -s "http://solr:8983/solr/admin/cores?action=CREATE&name=islandora&instanceDir=islandora&config=solrconfig.xml&dataDir=data" &> /dev/null
