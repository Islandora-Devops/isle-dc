# USE updated March 2020 README for wodby ported MVP 2

Prototype for ISLE using only wodby images e.g. Drupal, PHP, Solr and Mariadb

* Add this to `/etc/hosts`
  * `127.0.0.1 idcp.localhost`

* `docker-compose pull`

* `docker-compose up -d`

* Create a new Solr core called "islandora"
  * `docker exec -it isle_dc_proto_solr bash -c "solr create_core -c islandora"`

**TO DO:** Fix in MVP2 the `improper schema.xml` complaint that is fixed in these steps http://idcp.localhost/modules/contrib/search_api_solr/INSTALL.md

* Run the Drupal site installation script
  * `docker exec -it isle_dc_proto_php bash -c "sh /scripts/islandora/install-islandora.sh"`
  * This script will take at least 5-10 mins depending on the speed of your internet connection and/or local environment.

* Access site at: http://idcp.localhost

* The directory `/var/www/html` is bind mounted in both the Apache and PHP services / containers to the local directory `isle-dc/codebase`. This directory is in the .gitignore file to ignore the contents of this data directory.

* To shut down the containers but persist data
  * `docker-compose down`

* To **destroy** containers and data
  * `docker-compose down -v`
  * `sudo rm -rf codebase`

**TO DO** - Test if Solr is indexing? (MVP 2)
**TO DO** - Sample items with metadata (MVP 2)
**TO DO** - What is content / search setup aka block? (MVP 2)

### Database settings

Change settings in the `php.env` and/or `.env` files

* MySQL root password: `root_pw`
* Database name: `drupal`
* Database user: `drupal_user`
* Database user password: `drupal_user_pw`
* Database host: `mariadb`
* Database Port number: `3306`
* Table name prefix: `left empty / blank`
* Database type: `MySQL, MariaDB, Percona Server, or equivalent`

### Drupal settings

Change settings in the `php.env` and/or `.env` files

* Site url: http://idcp.localhost
* Drupal site name: `ISLE 8 Local`
* Drupal user: `islandora`
* Drupal user password: `islandora`
* Drupal site email address: `admin@example.com`
* Drupal user email address: `islandora@example.com`
* Drupal 8 installation profile: `Standard`
* Drupal Language: English `en`
* Drupal Locale: `US`

---

# MVP 2 - Alpaca connectors and activemq

* Aaron Birkland's https://github.com/Islandora-Devops/isle-dc/pull/7

Adds a single Karaf instance containing all connectors, config to run them, and an activemq instance

## To Test

* `docker-compose up -d`
  * This should pull in all images, if not do a `docker-compose pull` first
* Go to http://localhost:8161, which is the ActiveMQ admin console.
  * Click on "Manage ActiveMQ broker"
  * Enter in username `admin`, pass `admin`
* Click on the `queues` tab. You should see all the queues the connectors listen to.
* Now, pick a service (maybe fits) and remember it.
  * Shut everything down `docker-compose down -v`
* Within the `.env` file, comment out the env vars for that service. This will disable it.
* Start up again `docker-compose up -d`
* Log into ActiveMQ.
  * Look at the queues, and observe the one that corresponds to your service doesn't exist. 
  * This proves you can shut them off at will

There isn't much more to test, since services aren't connected.

This PR just verifies that camel routes start successfully, connect to the messaging bus and eagerly await messages that never come.

---

## Previous Instructions for MVP 1 docker-compose.yml (_this might get pulled out soon_)

* TO DO: Review again and/or port. Traefik labels may need changes.

From https://github.com/Islandora-Devops/isle-dc/pull/1

First step: basic http port 80 Traefik route to the Drupal container

* fix docker-compose startup problem
* add entry points for 80 and 443
* add traefik labels for drupal

To test:

* clone repo
* `docker-compose pull`
* `docker-compose -f docker-compose.mvp1.yml up -d`
* on linux, add `idcp.localdomain` to `/etc/hosts` as an alias for localhost
* `lynx http://idcp.localdomain:80/`
* if this works, one should see a Drupal 8.8.1 Installation tasks
  * Where `idcp.localdomain` is the .env DOMAIN property