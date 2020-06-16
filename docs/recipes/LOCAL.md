# RECIPE: How to boot an Islandora 8 app for local development in ISLE-8

## Overview

_As of June 2020_, ISLE-8 uses images built by this maintainer repository https://github.com/Islandora-Devops/isle-buildkit and pushed to the "islandora" namespace on Dockerhub by https://hub.docker.com/u/islandora. 

This recipe contains instructions for using this repository to spin up a local ISLE-8 development environment for either a new or existing Composer-based Islandora 8 application. Other recipes exist in this same documentation folder addressing  alternate use cases.

## Instructions

Launch a terminal and follow these steps below:

* On your local, add the local domain/site to `/etc/hosts` if it isn't there already
  * `sudo nano /etc/hosts`
  * add `127.0.0.1   islandora.localhost` as a seperate line underneath `127.0.0.1       localhost`
  * save and exit the hosts file

* Within the terminal, navigate to a directory of your choice that you can start working

* Clone the ISLE 8 project (isle-dc)
* `git clone https://github.com/Islandora-Devops/isle-dc.git`

* `cd isle-dc`

* Copy the sample.env file to `.env` 
  * `cp sample.env .env`
  * Modify the appropriate line to read `ENVIRONMENT=local` so the project will assumue you want to build a full app inside a `codebase` folder. If you want to customize the Drupal image further, switch to `ENVIRONMENT=local_custom` to use the Dockerfile in the root of this project as your starting point.

* Pull down the Docker images
  * `make pull`

* Now you need a Drupal codebase in a 'codebase' folder. You can either
  * Generate a Drupal codebase via `COMPOSER_MEMORY_LIMIT=-1 make drupal_init isle_codebase=islandora` which will go build out an appropriate codebase for you to start with
    * Now boot up the system: `make up` and run `make install_islandora` to enable all the Islandora modules and config.
    * This script will take at least 5-10 mins depending on the speed of your internet connection and/or local environment.
  * Or clone your existing Composer app into a new directory called 'codebase' in the root level of this project. 
    * `mkdir codebase && git clone <url> codebase`
    * Now boot up the system: `make up`
    * And load your database --here's an example of how, using the makefile helper script:
      * `mkdir -p data/misc`
      * `mv latest.sql data/misc/`
      * `make drupal_db_load dbfilepath=data/misc dbfilename=latest.sql`
      * Run `make solr_init` to initalize your Solr core
  * Note you'll still need to create a database or import an existing one below. Then you'll need to run `make drupal_exec command="COMPOSER_MEMORY_LIMIT=-1 composer install"` to actually build your Composer app.

* Clear the drupal cache
  * `make drupal_exec command="drush cr"`
* reset/claim the admin user password
  * `make drupal_exec command="drush uli"` (edit the base domain to match the URL below before you try to use the one-time link this provides)

* Access site at: http://islandora.localhost

* To shut down the containers but persist data
  * `make down`

* To **destroy** containers and data including the Drupal site and all content. This is essential when re-testing or re-installing.
  * `make clean`
