# IDC development platform

Leverages ISLE to provide a local development environment for the IDC stack, with particular focus on development/testing of 
the Drupal site.

## Quick Start

Right now, this is in an incomplete state.  You can build an initial Drupal site from scratch via executing

    make bootstrap

## Contents

* Our Drupal site is in `codebase`.  
  * Use `composer` to add, remove, or update dependencies in `codebase/composer.json` and `codebase/composer.lock` when developing
  * Dependencies are not vendored, so you need to do a composer install.  This is included in `make bootstrap`
* IDC development-specific environment variables are in `.env` and `docker-compose.env.yml`
