# ISLE: Islandora Enterprise 8 Prototype

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](./LICENSE)

## Introduction

Docker-Compose project facilitating creation and management of Islandora 8 Infrastructure under Docker.

## Developer Notes

This is a pseudo code draft of the `docker-compose` file, Docker service and image configuration structure for the ISLE Phase III - ISLE / Islandora 8 Prototype (isle-dc) project.

Due to the current **DRAFT** status, any software contained within this repo will **not work** and should not be used in any environment yet. Updates to follow when the project shifts to the build phase (Februrary 2020).

Currently there are blank `.keep` files in most of the `config/service` directories. They should be removed as services are defined and created. If a service doesn't require a config to bind mounted then please remove the appropriate service directory from the `config` directory as needed.

## Requirements

* Desktop / laptop / VM
* Docker-CE 19.x+
* Docker-compose version 1.25.x+
* Git 2.0+

## Installation

* For stable working use the `master` branch
* For bleeding edge, potentially not working, use the `development` branch

* use `docs/MVP3_README.md` for current installation steps.


## Configuration

* The `config` directory currently holds all settings and configurations for the Dockerized Islandora 8 stack services and is the `./config` path found within the `docker-compose.yml`.

## Documentation

* All documentation for this project can be found within the `docs` directory.

## Connect

* Coming soon

## Troubleshooting/Issues

Post your questions here and subscribe for updates, meeting announcements, and technical support

* [Islandora ISLE Interest Group](https://github.com/islandora-interest-groups/Islandora-ISLE-Interest-Group) - Meetings open to everybody! 
  * [Schedule](https://github.com/islandora-interest-groups/Islandora-ISLE-Interest-Group/#how-to-join) is alternating Wednesdays, 3:00pm EDT
* [Islandora ISLE Google group](https://groups.google.com/forum/#!forum/islandora-isle)
* [Islandora ISLE Slack channel](https://islandora.slack.com) `#isle`
* [Islandora Group](https://groups.google.com/forum/?hl=en&fromgroups#!forum/islandora)
* [Islandora Dev Group](https://groups.google.com/forum/?hl=en&fromgroups#!forum/islandora-dev)

## FAQ

* Coming soon

## Development

If you would like to contribute to this project, please check out [CONTRIBUTING.md](CONTRIBUTING.md). In addition, we have helpful [Documentation for Developers](https://github.com/Islandora/islandora/wiki#wiki-documentation-for-developers) info, as well as our [Developers](http://islandora.ca/developers) section on the [Islandora.ca](http://islandora.ca) site.

## Maintainers/Sponsors

### Architecture Team

* [Jeffery Antoniuk](https://github.com/jefferya), Canadian Writing Research Collaboratory
* [Nia Kathoni](https://github.com/nikathone), Canadian Writing Research Collaboratory
* [Aaron Birkland](https://github.com/birkland), Johns Hopkins University
* [Jonathan Green](https://github.com/jonathangreen), LYRASIS
* [Danny Lamb](https://github.com/dannylamb), Islandora Foundation
* [Gavin Morris](https://github.com/g7morris) (Project Tech Lead), Born-Digital
* [Mark Sandford](https://github.com/marksandford) (Documentation Lead), Colgate University
* [Daniel Bernstein](https://github.com/dbernstein), LYRASIS

## Sponsors

This project has been sponsored by:

Grinnell College
Tri-College (Bryn Mawr College, Haverford College, Swarthmore College)
Wesleyan University
Williams College
Colgate University
Hamilton College
Amherst College
Mount Holyoke College
Franklin and Marshall College
Whitman College
Smith College
Arizona State University
Canadian Writing Research Collaboratory (CWRC)
Johns Hopkins University
Tulane University
LYRASIS
Born-Digital

## License

[MIT](https://opensource.org/licenses/MIT)