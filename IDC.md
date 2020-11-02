# IDC development platform

Leverages ISLE to provide a local development environment for the IDC stack, with particular focus on development/testing of
the Drupal site.

## Contents

* Our Drupal site is in `codebase`.
  * Use `composer` to add, remove, or update dependencies in `codebase/composer.json` and `codebase/composer.lock` when developing
  * Dependencies are not vendored, so you need to do a composer install.  This is included in `make bootstrap`
* IDC development-specific environment variables are in `.env` and `docker-compose.env.yml`
* An idc-specific Makefile `idc.Makefile` defines additional make targets available for `make

## Quick Start

To start the IDC development environment, run

    make up

This will build a `docker-compose` file, run `composer install` to locally install all dependencies for our site (which will
take a few minutes when done the first time, but will be much quicker subsequent times), and start the stack.  The stack will
start from a known snapshot state, which currently is an entirely empty (but initialized) Drupal.

To reset to a known Drupal state, run

    docker-compose down -v
    docker-compose up -d

This will remove all content from volumes that you may have added, launch using the snapshot as its initial state.

To dump the site's configuration so that it can be committed to `git`, do

    make config-export

To take a snapshot of Drupal's current content, do

    make snapshot

See [snapshots](#snapshots) for more information on how to make and publish snapshots

## Make targets

There are several Make targets in the `Makefile`, and its idc-specific companion `idc.Makefile` (which are included by default,
so no need to do anything special other than `make` to invoke them).  A few useful targets are as follows:

* **make bootstrap** Burn everything down and create a fresh installation from scratch, deleting any pre-existing data, and starting from a completely empty state.  Only the list of modules in `composer.json` (and dependencies in `composer.lock`) survives the process.
* **make reset** Burn everything down and create a fresh installation _from the snapshot image_.  Unlike `make bootstrap`, modules and dependencies **do not** survive; they will be installed when the drupal container starts.  Does not pull in configuration from config/sync, will use the active configuration present in the snapshot.
* **make composer-install**  Use the Drupal container to run a `composer install`.  This avoids having to install composer on your local system.
* **make cache-rebuild** Uses Drush inside the Drupal container to rebuild Drupal's cache.
* **make config-export** Exports all current active Drupal config to the `codebase/config/sync` directory, so that it can be committed to git.
* **make snapshot** Create a snapshot of the current Drupal state (db, content files, etc), so that you can reset to this state at will, or push it so that others can.
* **make up** Brings up the development environment, including running `composer install`.

## Snapshots

Snapshots are Docker images that contain Drupal state (content files, database, SOLR indexes, Fedora files, etc).  When Docker starts,
all Docker volumes will be populated with files from the snapshot image.  The net result is that an environment will start quickly,
from a known state, with pre-populated content.

After Docker starts from a snapshot, data subsequent in Docker's volumes is ephemeral.  It will persist across `stop` and `down`, but can be wiped out by

    docker-compose down -v

When docker subsequently starts, it will start from the known snapshot state.  You are free to [take a snapshot](#taking-and-publishing-snapshots)
whenever you want a checkpoint you can reliably reset Drupal to.

### Images

The image used for the snapshot is specified via environment variables in `.env`.  For example:

    # Docker image and tag for snapshot image
    SNAPSHOT_IMAGE=birkland/snapshot
    SNAPSHOT_TAG=upstream-20201007-739693ae-12-ga409e4d8.1602146397

When the `docker-compose.yml` make target is run, that image and tag will be specified in the docker-compose file.  The images contain data that are
copied to Docker volumes upon initial startup of the stack (i.e. snapshots are deployed only once, until all volumes are wiped out via `docker-compose down -v`).  Because they are just regular docker images, they can be pushed and puled from container registry as usual.

### Taking and publishing snapshots

To take a snapshot, run

    make snapshot

This will do the following:

* stop the docker-compose stack
* dump the contents of the volumes
* create a new image from the contents of the volume
* give the image a unique tag based on the current git commit, and the date
* update the `.env` file to specify the just-taken `SNAPSHOT_TAG`
* rebuild the `docker-compose.yml` file to specify that tag
* start docker-compose

If you want to commit that snapshot so that others can use it, you need to commit `.env` (which contains the tag of the snapshot image),
and publish the snapshot image to a Docker registry via

    docker-compose push snapshot

Make sure you do both steps!  You need to push the image (so others can pull it), and push `.env` (so others can check out and run it).
