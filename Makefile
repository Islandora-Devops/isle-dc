# The variable used to determine which composer create project to use.
# Run make drupal_init_help for more information
isle_codebase ?= islandora

docker_compose_project ?= islandora

.PHONY: help drupal_init up build down down_rmi_all down_rmi_local drupal_clean clean_local clean

default: drupal_init up

help:
	./scripts/drupal/init.sh --help

drupal_init:
	./scripts/drupal/init.sh --codebase $(isle_codebase)

up:
	docker-compose -p $(docker_compose_project) up --remove-orphans --detach

build:
	docker-compose -p $(docker_compose_project) up \
		--build \
		--detach \
		--remove-orphans

down:
	docker-compose -p $(docker_compose_project) down --remove-orphans

down_rmi_all:
	docker-compose -p $(docker_compose_project) down \
		--rmi all \
		--volumes \
		--remove-orphans

down_rmi_local:
	docker-compose -p $(docker_compose_project) down \
		--rmi local \
		--volumes \
		--remove-orphans

# @todo we might chmod here since drupal set settings.php to readonly after
# install
drupal_clean:
	chmod u+w codebase/web/sites/default && rm -rf codebase data/drupal

clean_local: down_rmi_local drupal_clean

clean: down_rmi_all drupal_clean
