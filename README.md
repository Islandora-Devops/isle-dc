# ISLE: Islandora Enterprise 8 Prototype  <!-- omit in toc -->

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](./LICENSE)

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Configuring the Domain(s)](#configuring-the-domains)
  - [Configuring the Environment](#configuring-the-environment)
- [Demo Environment](#demo-environment)
- [Local Environment](#local-environment)
  - [Create Local Environment from islandora/demo Image](#create-local-environment-from-islandorademo-image)
    - [From existing Configuration](#from-existing-configuration)
    - [Manually](#manually)
  - [Create Local Environment from Existing Site](#create-local-environment-from-existing-site)
  - [Create Local Environment from Scratch](#create-local-environment-from-scratch)
- [Custom Environment](#custom-environment)
- [Services](#services)
  - [Watchtower](#watchtower)
  - [Traefik](#traefik)
  - [ETCD](#etcd)
- [Troubleshooting/Issues](#troubleshootingissues)
- [FAQ](#faq)
  - [Question: When doing an `drush config:import -y` I get one of the following errors](#question-when-doing-an-drush-configimport--y-i-get-one-of-the-following-errors)
  - [Question: When doing an `drush sql:dump` I get one of the following errors](#question-when-doing-an-drush-sqldump-i-get-one-of-the-following-errors)
- [Development](#development)
- [Maintainers/Sponsors](#maintainerssponsors)
  - [Architecture Team](#architecture-team)
- [Sponsors](#sponsors)
- [License](#license)

## Introduction

[Docker Compose] project facilitating creation and management of Islandora 8
Infrastructure under [Docker] using [Docker Compose].

This is a prototype of the `docker-compose` file, Docker service and image
configuration structure for the ISLE Phase III - ISLE / Islandora 8 Prototype
(isle-dc) project.

The workflow for this repository centers around using the provided
[Makefile](./Makefile) to generate an appropriate `docker-compose.yml` file.

There are **three** `ENVIRONMENT`s or ways of development that this repository
supports:

- **demo** *(Example site for testing the images)*
- **local** *(Local development using composer/drush in the codebase folder)*
- **custom** *(Use a custom built image or generate one from the codebase folder)*

To quickly get started, we recommend running the [demo](#-demo) environment
first after you have completed the [Installation](#-installation).

## Requirements

- Composer 1.10+
- Desktop / laptop / VM (*Must be able to support running GNU Make*)
- Docker-CE 19.x+ (If using Docker Desktop for Windows, any stable release
  *after* 2.2.0.4, or use a 2.2.0.4 with a [patch][Docker for Windows Patch] due
  to a [bug][Docker for Windows Bug])
- Docker-compose version 1.25.x+
- Drush 9.0+
- Git 2.0+
- GNU Make 4.0+
- PHP 7.2+ (*Also requires the same ext packages you intend to use in your site.*)

## Installation

- For stable working use the `master` branch
- For bleeding edge, potentially not working, use the `development` branch

### Configuring the Domain(s)

If you are not using Linux as your operating system you will need to modify your
`hosts` file such that you can access Islandora via its domain name.

| Operating System | Host File location                      |
| :--------------- | :-------------------------------------- |
| Windows          | `C:\Windows\System32\drivers\etc\hosts` |
| Linux / OSX      | `/etc/hosts`                            |

The domains used will depend on two things, the name of the composer project
`COMPOSE_PROJECT_NAME` which defaults to `isle-dc`.

Ensure the following lines are written to your respective `host` file. If you
have altered the value of `COMPOSE_PROJECT_NAME` in `.env` replace `isle-dc`
with the same value you have chosen for `COMPOSE_PROJECT_NAME`:

```bash
127.0.0.1 activemq.isle-dc.localhost
127.0.0.1 blazegraph.isle-dc.localhost
127.0.0.1 database.isle-dc.localhost
127.0.0.1 fcrepo.isle-dc.localhost
127.0.0.1 islandora.isle-dc.localhost
127.0.0.1 solr.isle-dc.localhost
```

Also if you intended to develop remotely using a server in AWS for example you
would change the IP address from `127.0.0.1` to a publicly accessible IP address
for your server.

### Configuring the Environment

To run the containers you must first generate a `docker-compose.yml` file. It is
the only orchestration mechanism provided to launch all the containers, and have
them work as a whole.

To get started generate the defaults with the following command:

```bash
make
```

This will create the following files which you can **customize**:

| File                     | Purpose                                                                                                                                                   |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.env`                   | Responsible for setting variables used in `docker-compose.*.yml` files </br> Determines which `docker-compose.*.yml` are included in `docker-compose.yml` |
| `docker-compose.env.yml` | Allows the user to set environment settings inside  of containers and override any services configuration                                                 |

You can set the environment in the `.env` file, using the `ENVIRONMENT`
variable.

Once you are happy with your changes to the above files you can regenerate the
`docker-compose.yml`, and pull the required images using the
[Makefile](./Makefile) like so:

```bash
make
```

After this point you can just interact with the `docker-compose.yml` file like
you would normally.

```bash
docker-compose up -d
```

With [Docker Compose] there are many features such as displaying logs among
other things for which you can find detailed descriptions in the
[Docker Composer CLI Documentation](https://docs.docker.com/compose/reference/overview/)

## Demo Environment

To quickly get started, we recommend running the [demo](#-demo) environment first.

This is the default environment if you do a clean checkout of this repository and run the following:

```bash
make
docker-compose up -d
```

This environment is just meant as a show case of the basic `islandora` site.

You should be able to reach it in your browser at `islandora.isle-dc.localhost`
if you followed the instructions under the [Installation](#-installation)
section.

## Local Environment

This environment is intended for local development. Users will create a `Drupal`
site in the folder [codebase](./codebase), which gets bind mounted into the
`drupal` service container. Allowing developers to use `composer` / `drush`
locally to work out of the [codebase](./codebase) folder.

There are a three ways in which you can create a local environment.

- From the `islandora/demo` image.
- From an existing site.
- From scratch.

**N.B:** Before attempting any of these methods make sure you have set `ENVIRONMENT` to
`local` in your `.env` file.

After you have setup your local site you can then work directly out of the
`codebase` folder, as if you had installed `Drupal` locally.

### Create Local Environment from islandora/demo Image

The following [Makefile](./Makefile) command is provided as method to quickly
get a site up using the `islandora/demo` image as base.

```bash
make create-codebase-from-demo
```

It will take a few minutes to spin up a the demo instance, export its
configuration and copy the site into the [codebase](./codebase) folder.

Once this is done you can bring up your local site using `docker-compose`.

```bash
docker-compose up -d
```

At this point the site will not be installed. There are **two** was to do an
installation, from an existing configuration or in a stepwise fashion.

**After** either of your chosen methods you will still need to update services
like `solr` and `blazegraph`, etc, these commands are combined into a single
target for convenience.

```bash
make hydrate
```

#### From existing Configuration

To be able to install from an existing configuration you must change the
following environment variables in `docker-compose.env.yml`:

| Environment Variable                   | Value                       |
| :------------------------------------- | :-------------------------- |
| DRUPAL_DEFAULT_CONFIGDIR               | /var/www/drupal/config/sync |
| DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG | "true"                      |
| DRUPAL_DEFAULT_PROFILE                 | minimal                     |

Regenerate your `docker-compose.yml` file, and restart the container.

```bash
make docker-compose.yml
docker-compose up -d
```

You also need to change the site configuration to use the minimal profile.

```bash
make remove_standard_profile_references_from_config
```

At this point you should be able to perform the installation

```bash
make install
```

Finally configure the rest of the site which depends on environment variables.

```bash
make hydrate
```

**N.B.:** There is a
[bug](https://www.drupal.org/project/drupal/issues/2914213) which affects
`islandora_fits`. For now you must manually set a value. Visit
<http://islandora.isle-dc.localhost/taxonomy/term/1/edit> and set the value
`URL` to <https://projects.iq.harvard.edu/fits>.

#### Manually

 you can install it by running the
following [Makefile](./Makefile) command:

```bash
make install
```

That will create the required database and install a bare bones site.

Now that the `drupal` service is running you can update the `settings.php` with
the appropriate settings from the environment variables defined in
`docker-compose.env.yml`, by running the following [Makefile](./Makefile)
command:

```bash
make update-settings-php
```

At this point the site is still bare-bones as we have not imported the site
configuration. Or you can manually setup the site as you see fit. To import an
existing configuration you can use the following command.

```bash
make config-import
```

*N.B:* You'll have to run this twice, due to bugs in the dependencies of configurations!

Finally configure the rest of the site which depends on environment variables.

```bash
make hydrate
```

**N.B.:** There is a
[bug](https://www.drupal.org/project/drupal/issues/2914213) which affects
`islandora_fits`. For now you must manually set a value. Visit
<http://islandora.isle-dc.localhost/taxonomy/term/1/edit> and set the value
`URL` to <https://projects.iq.harvard.edu/fits>.

### Create Local Environment from Existing Site

Copy or clone your existing site into the [codebase](./codebase) folder.

Then you have a number of options you can:

- Follow the same installation procedure as the demo [from an existing configuration](#from-existing-configuration)
- Follow the same installation procedure as the demo [manually](#manually)

Or you can import an existing database if you have it.

```bash
make database-import SRC=/tmp/dump.sql
```

Finally configure the rest of the site which depends on environment variables.

```bash
make hydrate
```

### Create Local Environment from Scratch

You can create a composer project for your drupal site from scratch.

Some popular examples:

- drupal/recommended-project
- drupal-composer/drupal-project:8.x-dev
- islandora/drupal-project:8.8.1
- born-digital/drupal-project:dev-isle8-dev

```bash
composer create-project --ignore-platform-reqs --no-interaction --no-install drupal/recommended-project ./codebase
composer require -- drush/drush
composer install
make
docker-compose up -d
make install
```

At this point you should have a functioning Drupal site that you can customize
as you see fit using `composer` / `drush` commands in the codebase folder.

## Custom Environment

This environment is used to run your custom `drupal` image which can be produced
outside of this repository. You can specify the image in your `.env` file using
the settings `PROJECT_DRUPAL_DOCKERFILE` if you want to build it in the context
of this repository.

For convenience a `sample.Dockerfile` is provided from which you can generate a
custom image from the [codebase](./codebase) folder. For example if you followed
the guide above to create the codebase folder from the `islandora/demo` image.

And then run it by changing `ENVIRONMENT` to be `custom` and regenerating the
`docker-compose.yml` file and building the image.

```bash
make docker-compose.yml
make build
```

At this point you could run it using `docker-compose`:

```bash
docker-compose up -d
```

To specify an image created outside of this repository, you can add the
following to `docker-compose.env.yml`:

```yaml
drupal:
  image: YOUR_CUSTOM_IMAGE
```

## Services

Islandora is composed of many different services, this project has split these
services up such that they have their own
[Container](https://www.docker.com/resources/what-container).

For in-depth documentation of the various `islandora` images see the
[isle-buildkit](https://github.com/Islandora-Devops/isle-buildkit) repository.

Other services will be documented below:

### Watchtower

The [watchtower](https://hub.docker.com/r/v2tec/watchtower/) container monitors
the running Docker containers and watches for changes to the images that those
containers were originally started from. If watchtower detects that an image has
changed, it will automatically restart the container using the new image. This
allows for automatic deployment, and overall faster development time.

Note however Watchtower will not restart stopped container or containers that
exited due to error. To ensure a container is always running, unless explicitly
stopped, add ``restart: unless-stopped`` property to the container in the
[docker-compose.yml] file. For example:

```yaml
database:
    image: islandora/mariadb:latest
    restart: unless-stopped
```

The watchtower can be disabled/enabled via the `INCLUDE_WATCHTOWER_SERVICE`
variable in your `.env` file.

```bash
# Includes `watchtower` as a service.
INCLUDE_WATCHTOWER_SERVICE=true
```

### Traefik

The [traefik](https://containo.us/traefik/) container acts as a reverse proxy,
and exposes some containers through port ``80``/``443``/``3306`` on the localhost via the
[loopback](https://www.tldp.org/LDP/nag/node66.html). This allows access to the
following urls.

- <http://activemq.isle-dc.localhost/admin>
- <http://blazegraph.isle-dc.localhost/bigdata>
- <mysql://database.isle-dc.localhost:3306>
- <http://islandora.isle-dc.localhost>
- <http://fcrepo.isle-dc.localhost/fcrepo/reset>
- <http://matomo.isle-dc.localhost>

Note if you cannot map ``traefik`` to the hosts port 80, you will need to
manually modify your ``/etc/hosts`` file and add entries for each of the urls
above like so, assuming the IP of ``traefik`` container is ``x.x.x.x`` on its
virtual network, and you can access that address from your machine.

```properties
x.x.x.x     activemq.isle-dc.localhost
x.x.x.x     blazegraph.isle-dc.localhost
x.x.x.x     islandora.isle-dc.localhost
x.x.x.x     fcrepo.isle-dc.localhost
x.x.x.x     matomo.isle-dc.localhost
```

Since Drupal passes its ``Base URL`` along to other services in AS2 as a means
of allowing them to find their way back. As well as having services like Fedora
exposed at the same URL they are accessed by the micro-services to end users. We
need to allow containers within the network to be accessible via the same URL,
though not by routing through ``traefik`` since it is and edge router.

So alias like the following are defined:

```yaml
drupal:
    image: islandora/demo:latest
    # ...
    networks:
      default:
        aliases:
          - islandora.isle-dc.localhost
```

These are set on the ``default`` network as that is the internal network (no
access to the outside) on which all containers reside.

The `traefik` service can be disabled/enabled via the `INCLUDE_TRAEFIK_SERVICE`
variable in your `.env` file.

```bash
# Includes `traefik` as a service.
INCLUDE_TRAEFIK_SERVICE=true
```

### ETCD

The [etcd](https://github.com/etcd-io/etcd) container is a distributed reliable
key-value store, which this project can use for configuration settings and secrets.

It is not enabled by default.

```bash
# Includes `etcd` as a service.
INCLUDE_ETCD_SERVICE=false
```

## Troubleshooting/Issues

Post your questions here and subscribe for updates, meeting announcements, and technical support

- [Islandora ISLE Interest Group](https://github.com/islandora-interest-groups/Islandora-ISLE-Interest-Group) - Meetings open to everybody!
  - [Schedule](https://github.com/islandora-interest-groups/Islandora-ISLE-Interest-Group/#how-to-join) is alternating Wednesdays, 3:00pm EDT
- [Islandora ISLE Google group](https://groups.google.com/forum/#!forum/islandora-isle)
- [Islandora ISLE Slack channel](https://islandora.slack.com) `#isle`
- [Islandora Group](https://groups.google.com/forum/?hl=en&fromgroups#!forum/islandora)
- [Islandora Dev Group](https://groups.google.com/forum/?hl=en&fromgroups#!forum/islandora-dev)

## FAQ

### Question: When doing an `drush config:import -y` I get one of the following errors

**Error:**

```html
Site UUID in source storage does not match the target Storage.
```

This occurs when your configuration has come from a site other than the one that
is currently installed. You can run the following command to override the site
`uuid` so that you can import your configuration:

```bash
make set-site-uuid
```

**Error:**

```html
Entities exist of type <em class="placeholder">Shortcut link</em> and <em class="placeholder">Shortcut set</em>
<em class="placeholder">Default</em>. These entities need to be deleted before importing
```

These are entities created by the `standard` installation profile, you can delete
them with the following command in the codebase folder:

```bash
make delete-shortcut-entities
```

**Error:**

```bash
Error: Call to a member function getConfigDependencyName() on null in ... Entity/EntityDisplayBase.php on line 325 #0 ... /codebase/web/core/lib/Drupal/Core/Config/Entity/ConfigEntityBase.php(318): Drupal\Core\Entity\EntityDisplayBase->calculateDependencies()
```

There is some bug in the dependencies of the various modules. Until those
dependencies issues are resolved just rerun the command until they go away.

```bash
drush config:import -y
```

### Question: When doing an `drush sql:dump` I get one of the following errors

**Error:**

This arises from our use of [MariaDB] for the database in Docker, not matching
the same client on your host system. Which probably uses the [MySQL] clients
`mysqldump` executable. You can specify the following command using drush to get
around it:

```bash
drush sql:dump --extra-dump="--column-statistics=0" > /tmp/dump.sql
```

Or you can use the provided method in the [Makefile](./Makefile) which should be
more portable.

```bash
make database-dump DEST=/tmp/dump.sql
```

## Development

If you would like to contribute to this project, please check out
[CONTRIBUTING.md](CONTRIBUTING.md). In addition, we have helpful
[Documentation for Developers](https://github.com/Islandora/islandora/wiki#wiki-documentation-for-developers)
info, as well as our [Developers](http://islandora.ca/developers) section on the
[Islandora.ca](http://islandora.ca) site.

drush --debug sql:dump --extra-dump="--column-statistics=0" > /tmp/dump.sql^C

## Maintainers/Sponsors

### Architecture Team

- [Jeffery Antoniuk](https://github.com/jefferya), Canadian Writing Research Collaboratory
- [Nia Kathoni](https://github.com/nikathone), Canadian Writing Research Collaboratory
- [Aaron Birkland](https://github.com/birkland), Johns Hopkins University
- [Jonathan Green](https://github.com/jonathangreen), LYRASIS
- [Danny Lamb](https://github.com/dannylamb), Islandora Foundation
- [Gavin Morris](https://github.com/g7morris) (Project Tech Lead), Born-Digital
- [Mark Sandford](https://github.com/marksandford) (Documentation Lead), Colgate University
- [Daniel Bernstein](https://github.com/dbernstein), LYRASIS

## Sponsors

This project has been sponsored by:

- Grinnell College
- Tri-College (Bryn Mawr College, Haverford College, Swarthmore College)
- Wesleyan University
- Williams College
- Colgate University
- Hamilton College
- Amherst College
- Mount Holyoke College
- Franklin and Marshall College
- Whitman College
- Smith College
- Arizona State University
- Canadian Writing Research Collaboratory (CWRC)
- Johns Hopkins University
- Tulane University
- LYRASIS
- Born-Digital

## License

[MIT](https://opensource.org/licenses/MIT)

[Docker Compose]: https://docs.docker.com/compose
[Docker for Windows Bug]: https://github.com/docker/for-win/issues/6016
[Docker for Windows Patch]: https://download-stage.docker.com/win/stable/43542/Docker%20Desktop%20Installer.exe
[Docker]: https://docs.docker.com
[MariaDB]: https://mariadb.org/
[MySQL]: https://www.mysql.com/
