#/bin/bash
echo ""
docker exec -it my_drupal8_project_php bash -c "chmod u+w web/sites/default && composer install"

echo ""
docker exec -it my_drupal8_project_php bash -c "drush en -y search_api search_api_solr"

echo ""
docker exec -it my_drupal8_project_php bash -c "drush pm-uninstall -y search"

echo ""
docker exec -it my_drupal8_project_php bash -c "drush en -y search_api_solr_defaults search_api_solr_admin"

# docker exec -it my_drupal8_project_php bash -c "chmod u+w web/sites/default && composer update"