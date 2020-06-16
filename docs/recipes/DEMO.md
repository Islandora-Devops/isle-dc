# RECIPE: How to run a DEMO Islandora 8 site in ISLE-8

## Overview

_As of June 2020_, ISLE-8 uses images built by this maintainer repository https://github.com/Islandora-Devops/isle-buildkit and pushed to the "islandora" namespace on Dockerhub by https://hub.docker.com/u/islandora. 

This recipe contains instructions for using this repository to spin up a sample ISLE-8 demo/sandbox for testing. NOTE that this does not facilitate local development of a NEW or EXISTING Islandora 8 site, but merely brings up a demo environment. Other recipes exist in this same documentation folder addressing those alternate use cases.

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
  * The default `environment=demo` is correct for this tutorial. You'll switch this to "local" and rebuild if you want to do actual local development (see other related recipes).

* Pull down latest Docker images
  * `docker-compose pull`

* Start up the Docker containers:
  * `make up`
  * This will invoke the `docker-compose.demo.yml` override which will result in a suite which uses the premade 'sandbox' demo image.
  * You will note that this command detaches Docker from the terminal. If you want to see the logs, subsequently run `make logs`. `Control-c` will get you out of this mode when you're done.

* Wait for the site installation scripts to complete. 
  * Watch the logs scroll by - this script may take 5-20 mins depending on the speed of your internet connection and/or local environment.
  * Access site at: http://islandora.localhost. You can start checking this at any time. You will see "Bad Gateway" responses at first, but eventually it will load.

* When you're done playing around with the system, use `CTRL-c` in your terminal to shut things down (or run `make down` if you've decided to use the detached mode). You can then run `make clean` to wipe everything away if you're ready to start one of the other recipes (like running an actual local development environment from scratch or from an existing )
