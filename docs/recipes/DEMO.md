# RECIPE: How to run a DEMO Islandora 8 site in ISLE-8

## Overview

_As of June 2020_, ISLE-8 uses images built by this maintainer repository https://github.com/Islandora-Devops/isle-buildkit and pushed to the "islandora" namespace on Dockerhub by https://hub.docker.com/u/islandora. 

This recipe contains instructions for using this repository to spin up a sample ISLE-8 demo/sandbox for testing. NOTE that this does not facilitate local development of a NEW or EXISTING Islandora 8 site, but merely brings up a demo environment. Other recipes exist in this same documentation folder addressing those alternate use cases.

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

* Pull down latest Docker images
  * `docker-compose pull`

* Start up the Docker containers utilizing the `docker-compose.demo.yml` override file:
  * `make demo_up`
  * This will result in a suite which uses the premade 'sandbox' demo image.
  * You will note that this command does not detach Docker from the terminal - this is so you can see the logs in real time as the boot-up process builds out your Islandora 8 sandbox. If you want to run a demo in detached mode, you can run `make demo_up_detach`.

* Wait for the site installation scripts to complete. 
  * Watch the logs scroll by - this script may take 5-10 mins depending on the speed of your internet connection and/or local environment.
  * Access site at: http://islandora.localhost. You can start checking this at any time. You will see "Bad Gateway" responses at first, but eventually it will load.

* When you're done playing around with the system, use `CTRL-c` in your terminal to shut things down (or run `make down` if you've decided to use the detached mode). You can then run `make clean` to wipe everything away if you're ready to start one of the other recipes (like running an actual local development environment from scratch or from an existing )
