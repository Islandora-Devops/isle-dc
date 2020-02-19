# USE updated Feb 2020 README for wodby ported MVP

Prototype for ISLE using only wodby images e.g. Drupal, PHP, Solr and Mariadb

* `mkdir codebase` in this project root
  * _`.gitignored` currently_

* `cp -Rv composer/* codebase/`
  * _this will be the composer.json & .lock files_

* Add this to `/etc/hosts`
  * `127.0.0.1 idcp.localhost`

* `docker-compose -f docker-compose.mvp1.woodby.yml pull`

* `docker-compose -f docker-compose.mvp1.woodby.yml up -d`

* `docker exec -it isle-dc-php-idcp bash -c "composer install"`

* Access site at: http://idcp.localhost

* Follow instructions for Drupal 8 site setup
  * Choose language, click blue `Save and continue`button
  * Select `Standard` for the installation profile
  * Database type: `MySQL, MariaDB, Percona Server, or equivalnet`
    * Database name: `drupal`
    * Database user: `drupal_user`
    * Database user password: `drupal_user_pw`
    * Advanced options > Host: `mariadb` (_change from localhost_)
      * Port number: `3306`
      * Table name prefix: `leave blank`
    * Click the blue `Save and continue` button
* Configure site:
  * Site name: `ISLE 8 Local`
  * Enter the `Site email address, Username, password, email address, default country and default time zone` settings of your choice.
  * Click the blue `Save and continue` button

* `chmod +x scripts/install-solr-drupal-modules.sh && scripts/./install-solr-drupal-modules.sh`

* Navigate to `idcp.localhost:/admin/config/search/search-api`
  * Click Edit within the first line below (most likely red)
  * Change `Solr host` to `solr` and click save at bottom.

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