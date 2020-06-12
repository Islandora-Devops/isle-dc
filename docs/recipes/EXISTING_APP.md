# RECIPE: How to boot an existing Islandora 8 app for local development in ISLE-8

## Overview

_As of June 2020_, ISLE-8 uses images built by this maintainer repository https://github.com/Islandora-Devops/isle-buildkit and pushed to the "islandora" namespace on Dockerhub by https://hub.docker.com/u/islandora. 

This recipe contains instructions for using this repository to spin up a local ISLE-8 development environment for an existing Composer-based Islandora 8 application. NOTE that this does not facilitate creation of a new app, but merely brings up a dev environment. Other recipes exist in this same documentation folder addressing those alternate use cases.

## Instructions

Launch a terminal and follow these steps below:

* On your local, add the local domain/site to `/etc/hosts` if it isn't there already
  * `sudo nano /etc/hosts`
  * add `127.0.0.1   islandora.localdomain` as a seperate line underneath `127.0.0.1       localhost`
  * save and exit the hosts file

* Within the terminal, navigate to a directory of your choice that you can start working

* Clone the ISLE 8 project (isle-dc)
* `git clone https://github.com/Islandora-Devops/isle-dc.git`

* `cd isle-dc`

* Switch 

* Now you need a Drupal codebase in a 'codebase' folder. You can either
  * Generate a Drupal codebase via `COMPOSER_MEMORY_LIMIT=-1 make isle_codebase=islandora` which will go build out an appropriate codebase for you to start with
  * Or clone your existing Composer app into a new directory called 'codebase' in the root level of this project

* Pull down Docker images
  * `docker-compose pull`

* Start up the Docker containers
  * `docker-compose up -d`

* Run the Drupal site installation script
  * `docker-compose exec -T -u islandora php bash -c "sh /scripts/islandora/install-islandora.sh"`
  * This script will take at least 5-10 mins depending on the speed of your internet connection and/or local environment.

* Access site at: http://idcp.localhost:8000

* Test Houdini with by running `identify` on the Islandora logo:
  * `curl -H "Authorization: Bearer islandora" -H "Apix-Ldp-Resource: https://islandora.ca/sites/default/files/Islandora.png" idcp.localhost:8000/identify`

* The directory `/var/www/html` is bind mounted in both the Apache and PHP services / containers to the local directory `isle-dc/codebase`. This directory is in the .gitignore file to ignore the contents of this data directory.

* To shut down the containers but persist data
  * `docker-compose down`

* To **destroy** containers and data including the Drupal site and all content. This is essential when re-testing or re-installing.
  * `docker-compose down -v`
  * `sudo rm -rf codebase`
