# ISLE: Islandora Enterprise 8 Prototype  <!-- omit in toc -->

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](./LICENSE)

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Local Development](#local-development)
- [Custom Environment](#custom-environment)
- [Secrets](#secrets)
- [Services](#services)
  - [Code Server](#code-server)
  - [Watchtower](#watchtower)
  - [Traefik](#traefik)
  - [ETCD](#etcd)
- [Troubleshooting/Issues](#troubleshootingissues)
- [Development](#development)
- [Maintainers/Sponsors](#maintainerssponsors)
  - [Architecture Team](#architecture-team)
- [Sponsors](#sponsors)
- [License](#license)

## Introduction

[Docker Compose] project for creating and managing an Islandora 8 instance
using [Docker] containers from [Docker Hub](https://hub.docker.com/u/islandora)
that were created by [isle-buildkit](https://github.com/Islandora-Devops/isle-buildkit).

In a nutshell, `isle-dc` generates a docker-compose.yml file for you based on configuration
that you supply in a `.env` file.  And there are three use cases we're trying to accomplish:

- **demo** *(Example site for kicking the tires and looking at Islandora)*
- **local** *(Local development using composer/drush in the codebase folder)*
- **custom** *(A custom Dockerfile to deploy created from local)*

On top of that, there's a lot of useful commands for managing an Islandora instance, such
as database import/export and reindexing.

## Requirements

- Desktop / laptop / VM (*Docker must have sufficient resources to run GNU Make*)
- Docker-CE 19.x+
- Docker-compose version 1.25.x+
- Git 2.0+
- GNU Make 4.0+
- At least 8GB of RAM (ideally 16GB)

before running any of the make commands below.


See release notes at https://docs.docker.com/compose/cli-command/.


## Getting Started

To get started with a **demo** environment, run:

```bash
make demo
```
⚠️ If prompted during `make up\demo\local\clean` for password, use your computer's password. The build process may need elevated privileges to write or remove files. For other password information see [Secrets](#secrets)

This will pull down images from Dockerhub and generate

| File                 | Purpose                                                                                                                                                                                                                                                                     |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.env`               | A configuration file that is yours to customize. This file controls how the docker-compose.yml file gets generated to meet your use case.</br>It also allows you to set variables that make their way into the final `docker-compose.yml` file, such as your site's domain. |
| `docker-compose.yml` | A ready to run `docker-compose.yml` file based on your `.env` file.  This file is considered disposable. When you change your `.env` file, you will generate a new one.                                                                                                     |

Your new Islandora instance will be available at
[https://islandora.traefik.me](https://islandora.traefik.me). Don't let the
funny url fool you, it's a dummy domain that resolves to `127.0.0.1`.

If you do not have [secrets enabled](#secrets), you can log into Drupal as
`admin` using the default password: `password`. Otherwise you can find the
password in the file
[./secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD](/secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD).

Enjoy your Islandora instance!  Check out the [Islandora documentation](https://islandora.github.io/documentation) to see all
the things you can do.  If you want to poke around, here's all the services that are available to visit:

| Service     | Url                                                                                            |
| :---------- | :--------------------------------------------------------------------------------------------- |
| Drupal      | [https://islandora.traefik.me](https://islandora.traefik.me)                                   |
| Traefik     | [http://islandora.traefik.me:8080](http://islandora.traefik.me:8080)                         |
| Fedora      | [http://islandora.traefik.me:8081/fcrepo/rest](http://islandora.traefik.me:8081/fcrepo/rest) |
| Blazegraph  | [http://islandora.traefik.me:8082/bigdata](http://islandora.traefik.me:8082/bigdata)         |
| Activemq    | [http://islandora.traefik.me:8161](http://islandora.traefik.me:8161)                         |
| Solr        | [http://islandora.traefik.me:8983](http://islandora.traefik.me:8983)                         |
| Cantaloupe  | [https://islandora.traefik.me/cantaloupe](https://islandora.traefik.me/cantaloupe)             |
| Matomo      | [https://islandora.traefik.me/matomo/](https://islandora.traefik.me/matomo/)                   |
| Code Server | [https://islandora.traefik.me:8443/](https://islandora.traefik.me:8443/)                       |

Expose all of the endpoints at once (for testing and demo purposes and NOT production) by running
```bash
make kitchen_sink
```
This will automatically stop the containers, modify the `.env` file, import the changes and restart the containers with the new configurations. See [#custom-environment](#custom-environment) for more information on building with custom environment settings.

When you're done with your demo environment, shut it down by running

```bash
docker-compose down
```

This will keep your data around until the next time you start your instance.  If you want to completely destroy the repository and
all ingested data, use

```
docker-compose down -v

# OR a better option because it removes these directories (codebase/ certs/ secrets/live/) and
# resets all files back to their original states. This takes it back to a clean slate.

make clean

```

## Local Development

When developing locally, your Drupal site resides in the `codebase` folder and is bind-mounted into your
Drupal container.  This lets you update code using the IDE of your choice on your host machine, and the
changes are automatically reflected on the Drupal container.  Simply place any exported Drupal site as
the `codebase` folder in `isle-dc` and you're good to go.

If you don't provide a codebase, you'll be given a basic setup from vanilla Drupal 9 instance with the Islandora module
installed and the bare minimum configured to run.  This is useful if you want to build your repository
from scratch and avoid `islandora_defaults`.

If you've included configuration in your exported site using `drush config:export`, then you'll need
to set two values in your .env file:

```
INSTALL_EXISTING_CONFIG=true
DRUPAL_INSTALL_PROFILE=minimal
```

In either case, run this command to make a local environment.

```bash
make local
```

If you already have a Drupal site but don't know how to export it,
log into your server, navigate to the Drupal root, and run the following commands:

- `drush config:export`
- `git init`
- `git add -A .`
- `git commit -m "First export of site"`

Then you can `git push` your site to Github and `git clone` it down whenever you want.

## Custom Environment

This environment is used to run your custom `drupal` image which can be produced
outside of this repository. You can specify the image in your `.env` file using
the settings `PROJECT_DRUPAL_DOCKERFILE` if you want to build it in the context
of this repository. You can also set the memory limits for each containers here as well.

For convenience a `sample.Dockerfile` is provided from which you can generate a
custom image from the [codebase](./codebase) folder. For example if you followed
the guide above to create the codebase folder from the `islandora/demo` image.

And then run it by changing `ENVIRONMENT` to be `custom` and regenerating the
`docker-compose.yml` file and building the image.

To pull in changes to the .env file run the following.
```bash
make docker-compose.yml
make build

# then either
docker-compose up -d
# OR
make up
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
## Shutting down and bring back up
To run a non-destructive shutdown and bring it back up without having to know the docker commands needed. This keeps all of the commands for basic operations within the make commands.
```shell
# Shut down isle-dc with losing work.
make down

# Bring isle-dc back up from where it left off
make up

# If make hasn't been run this will run make demo

```

## Secrets

When running Islandora in the wild, you'll want to use secrets to store sensitive
information such as credentials.  Secrets are communicated from the docker host
to the individual containers over an encrypted channel, making it much safer
to run in production.

Some `confd` backends, such as `etcd`, can be used to serve secrets directly.
Simply expose `etcd` over `https` and nothing else needs to be done.  But for
other backends, particularly environment variables, you must mount the secrets
into containers as files using docker-compose. During startup, the files'
contents are read into the container environment and made available to `confd`.

To enable using secrets, set `USE_SECRETS=true` in your .env file. When you run
`make docker-compose.yml`, a large block of `secrets` will be added at the top of
your `docker-compose.yml` file.

```yml
secrets:
  ACTIVEMQ_PASSWORD:
    file: "./secrets/live/ACTIVEMQ_PASSWORD"
  ACTIVEMQ_WEB_ADMIN_PASSWORD:
    file: "./secrets/live/ACTIVEMQ_WEB_ADMIN_PASSWORD"
  ...
```

Each secret references a file in the `secrets/live` directory. These files are
generated by `make`. Each secrets file is named the exact same as the
environment variable it intends to replace. The contents of each file will be
used as the value for the secret.

### Quick Drupal "admin" password reset
Run `make set_admin_password` and it will prompt the user to enter in a new password. Enter it in and the password for the "admin" user will be set to the new password.
```shell
$ make set_admin_password
Password: ***
Setting admin password now
 [success] Changed password for admin.

```

## Services

Islandora is composed of many different services, this project has split these
services up such that they have their own
[Container](https://www.docker.com/resources/what-container).

For in-depth documentation of the various `islandora` images see the
[isle-buildkit](https://github.com/Islandora-Devops/isle-buildkit) repository.

Other services will be documented below:

### Code Server

The [code-server](https://github.com/cdr/code-server) container allows a user to
edit / debug their Drupal site from their browser.

The code-server service can be disabled/enabled via the
`INCLUDE_CODE_SERVER_SERVICE` variable in your `.env` file.

```bash
# Includes `code-server` as a service.
INCLUDE_CODE_SERVER_SERVICE=true
```

* Run `make local`, `make up`, or `make demo` to build the containers and local file system(s).
* Then modify the `.env` file.
* Then `make pull` then `make up` to fetch the builds.
It will then report it created the **code-server** and recreated **traefik** and **drupal** containers.

By default this will accessible at
[https://islandora.traefik.me:8443/](https://islandora.traefik.me:8443/).

If you do not have [secrets enabled](#secrets), you can login with the default
password: `password`. Otherwise you can find the password in the file
[./secrets/live/CODE_SERVER_PASSWORD](./secrets/live/CODE_SERVER_PASSWORD).

**N.B:** Do not expose this service on the internet without setting a strong
password via the `./secrets/live/CODE_SERVER_PASSWORD`, or better yet do not
expose it at all, and instead use port forward to access it if you have the
need. Exposing this service in an insecure way will allow root access to your
server to the public.

To enable xdebug for your request, you must also send an `XDEBUG_SESSION` cookie
with your request, this can be toggled on and off via a browser plugin such as
the following.

- [Chrome](https://chrome.google.com/webstore/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc?hl=en)
- [Firefox](https://addons.mozilla.org/en-GB/firefox/addon/xdebug-helper-for-firefox/)

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
mariadb:
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
and exposes some containers through port ``80``/``443``/``3306``. 

Since Drupal passes links to itself in the messages it passes to the microservices,
and occasionally other urls need to be resolved on containers that do not have
external access, we define aliases for most services on the internal network.

Aliases like so are defined on most services to mimic their routing rules in
Traefik:

```yaml
drupal:
    image: islandora/demo:latest
    # ...
    networks:
      default:
        aliases:
          - islandora-isle-dc.traefik.me
```

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

For common errors, see `docs/troubleshooting.md`.

## Development

If you would like to contribute to this project, please check out
[CONTRIBUTING.md](CONTRIBUTING.md). In addition, we have helpful
[Documentation for Developers](https://github.com/Islandora/islandora/wiki#wiki-documentation-for-developers)
info, as well as our [Developers](http://islandora.ca/developers) section on the
[Islandora.ca](http://islandora.ca) site.

drush --debug sql:dump --extra-dump="--column-statistics=0" > /tmp/dump.sql^C

## Maintainers/Sponsors

### Architecture Team

- [Nigel Banks](https://github.com/nigelbanks)
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
