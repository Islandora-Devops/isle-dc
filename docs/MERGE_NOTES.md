## How to run your own app

* make folder 'codebase`
* git clone your site into it
* `mkdir -p data/misc`
  * `mv latest.sql data/misc/`
* boot the system up with `make build` (to force a rebuild of the drupal image), and don't care that drupal keeps crashing. when we have the database in place it will stop. Notice that the "drupal" container is baked by the drupal.Dockerfile in this project, so you can edit that if you need to install other dependencies/etc. If this build keeps crashing, you can switch to using the prebuilt 'islandora/composer' image without customization.
* Do you already have a database from another app?
  * YES - then we need to load it. Here's an example of how, using the makefile helper script:
    * `mkdir -p data/misc`
    * `mv latest.sql data/misc/`
    * `make drupal_db_load dbfilepath=data/misc dbfilename=latest.sql`
    * Composer probably needs to compile your Drupal app. Run `make drupal_exec command="COMPOSER_MEMORY_LIMIT=-1 composer install"` to run Composer
    * `make solr_init` - this will create a Solr core and tell the Drupal db where to find it
* NO - Install and configure Islandora if you didn't already load a database
  * `make install_islandora`  
  * Composer probably needs to compile your Drupal app. Run `make drupal_exec command="COMPOSER_MEMORY_LIMIT=-1 composer install"` to run Composer
* Clear the drupal cache
  * `make drupal_exec command="drush cr"`
* reset/claim the admin user password
  * `make drupal_exec command="drush uli"` (edit the base domain to match the URL below before you try to use the one-time link this provides)
* The site will now be available to you on http://drupal.localhost
* `make down` will shut things off. `make clean` will clean it all up. If you want to run dc commands manually, just remember to use `-p islandora` (see Makefile for examples).