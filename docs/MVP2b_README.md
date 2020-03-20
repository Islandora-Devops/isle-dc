Running the containers
With this repo you can run drupal using drupal/recommended-project or islandora/drupal-project. I have added aMakefile to facilitate with the setup and running the needed commands. The steps below will download the codebase, setup data/drupal/ and run docker-compose.

Run make isle_codebase=drupal to create codebase with drupal/recommended-project
Or run make isle_codebase=islandora to create codebase with islandora/drupal-project
In case you have composer installed locally and run into the composer memory limit problem you might need to run COMPOSER_MEMORY_LIMIT=-1 make isle_codebase=islandora
You might need to run docker stats to check CPU usage for each container. Since AUTO_INSTALL is on it might take some time for the drupal container CPU usage to come down once it's done. So give the drupal container up to 5-10min to complete the site installation. Then visit islandora.localhost:8000 in chrome or if using any non chromium web browser add islandora.localhost in the /etc/hosts.

Bringing down the containers
Run make down to just bring down the container without cleaning up all the various docker assets related to the docker compose.
Or run make clean to delete everything from the codebase, data/drupal to all containers, images and volumes associated with docker-compose.yml
For a "light clean" you can also run make clean_local
For more make commands please check the Makefile.

Interacting with the container
docker-compose -p islandora exec drupal drush uli: to get a one time login url for admin.
docker-compose -p islandora exec drupal drush cr: to clear cache.
Notes
The drupal.Dockerfile still using registry.gitlab.com/nikathone/drupal-docker-good-defaults/php-nginx:latest for php and nginx base image but this will change once we have a CI to build images/nginx-php/Dockerfile.

I did disable the SOLR service.

Also it might be a good idea to move the traefik service setup in it's own docker-compose file cause ideally they should only be one traefik service per local host.

I might have missed something since I was trying to avoid to add to many changes at once.
