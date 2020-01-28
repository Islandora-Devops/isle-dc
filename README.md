# ISLE: Islandora Enterprise 8 Prototype

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](./LICENSE)

## Introduction

This is a pseudo code draft of the `docker-compose` file, Docker service and image configuration structure for the ISLE Phase III - ISLE / Islandora 8 Prototype (isle-dc) project.

Due to the current **DRAFT** status, any software contained within this repo will **not work** and should not be used in any environment yet. Updates to follow when the project shifts to the build phase (Februrary 2020).

## Developer Notes

Currently there are blank `.keep` files in most of the `config/service` directories. They should be removed as services are defined and created. If a service doesn't require a config to bind mounted then please remove the appropriate service directory from the `config` directory as needed.

## Requirements

* Desktop / laptop / VM
* Docker-CE 19.x+
* Docker-compose version 1.25.x+
* Git 2.0+

## Installation

* `git clone git@github.com:Born-Digital-US/isle-dc.git`

* `cd isle-dc`

* `docker-compose up -d`

## Configuration

* The `config` directory currently holds all settings and configurations for the Dockerized Islandora 8 stack services and is the `./config` path found within the `docker-compose.yml`.

## Documentation

All documentation for this project can be found within the `docs` directory.

* To configure your environment to use ISLE, please follow this [guide](docs/install/host-hardware-requirements.md)

* To learn what software dependencies are needed to host / run ISLE, please follow this [guide](docs/install/host-software-dependencies.md)

## Connect

You can connect via a browser at [http://idcp.localdomain](http://idcp.localdomain).
