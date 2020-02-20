# USE updated Feb 2020 README for wodby ported MVP

Prototype for ISLE using only wodby images e.g. Drupal, PHP, Solr and Mariadb

* Add this to `/etc/hosts`
  * `127.0.0.1 idcp.localhost`

* `docker-compose -f docker-compose.mvp1.woodby.yml pull`

* `docker-compose -f docker-compose.mvp1.woodby.yml up -d`

* `docker exec -it isle_dc_proto_php bash -c "sh /scripts/drupal/install-solr-drupal-modules.sh"`

* Access site at: http://idcp.localhost

* To shut down the containers but persist data
  * `docker-compose -f docker-compose.mvp1.woodby.yml down`

* To **destroy** containers and data
  * `docker-compose -f docker-compose.mvp1.woodby.yml down -v`
  * `rm -rf codebase`

## TO DO - Test if Solr is indexing? What is content / search setup aka block? (MVP 2?)

## Settings

* MySQL root password: `root_pw`
* Drupal 8 installation profile: `Standard`
* Language: English `en`
* Database type: `MySQL, MariaDB, Percona Server, or equivalnet`
* Database name: `drupal`
* Database user: `drupal_user`
* Database user password: `drupal_user_pw`
* Database host: `mariadb`
* Database Port number: `3306`
* Table name prefix: `left empty / blank`
* Drupal site name: `ISLE 8 Local`
* Drupal site email address: `admin@example.com`
* Drupal user: `islandora`
* Drupal user password: `islandora`
* Drupal user email address: `islandora@example.com`
* Drupal Locale: `US`

---

## Previous Instructions for docker-compose.yml

* TO DO: Review again and/or port. Traefik labels may need changes.

From https://github.com/Islandora-Devops/isle-dc/pull/1

First step: basic http port 80 Traefik route to the Drupal container

* fix docker-compose startup problem
* add entry points for 80 and 443
* add traefik labels for drupal

To test:

* clone repo
* `docker-compose -f docker-compose.mvp1.woodby.yml pull`
* `docker-compose -f docker-compose.mvp1.yml up -d`
* on linux, add `idcp.localdomain` to `/etc/hosts` as an alias for localhost
* `lynx http://idcp.localdomain:80/`
* if this works, one should see a Drupal 8.8.1 Installation tasks
  * Where `idcp.localdomain` is the .env DOMAIN property