## How to run your own app

* make folder 'codebase`
* git clone your site into it
* `mkdir -p data/misc`
  * `mv latest.sql data/misc/`
* boot the system up with `make up`, and don't care that drupal keeps crashing. when we have the database in place it will stop. Notice that the "drupal" container is baked by the drupal.Dockerfile in this project, so you can edit that if you need to install other dependencies/etc.
* `make drupal_db_load dbfilepath=data/misc dbfilename=latest.sql`
* Hopefully composer will do a good job on your build. If not, run `COMPOSER_MEMORY_LIMIT=-1 composer install` on the drupal service.
  * `docker exec -it islandora_drupal_1 bash -c "cd /var/www/drupal/ && COMPOSER_MEMORY_LIMIT=-1 composer install"`
* Create the Solr core
  * `make solr_init`
* Clear the drupal cache
  * `docker exec -it islandora_drupal_1 bash -c "drush cr"`
* reset the admin user password
  * `docker exec -it islandora_drupal_1 bash -c "drush uli"`
* `make down` will shut things off. `make clean` will clean it all up. If you want to run dc commands manually, just remember to use `-p islandora` (see Makefile for examples).

### To clear cache

* `docker exec -it islandora_drupal_1 bash -c "drush cr"`


curl "http://solr:8983/solr/select?indent=on&q=*:*"