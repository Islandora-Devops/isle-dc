# The variable used to determine which composer create project to use.
# Run make drupal_init_help for more information
isle_codebase ?= islandora

docker_compose_project ?= islandora

.PHONY: help drupal_init up build down down_rmi_all down_rmi_local drupal_clean clean_local clean solr_init

default: drupal_init generate_keys up solr_init

help:
	./scripts/drupal/init.sh --help

drupal_init:
	./scripts/drupal/init.sh --codebase $(isle_codebase)

generate_keys:
	./scripts/generate_jwt_keys.sh

solr_init:
	chown -Rv 8983:8983 config/solr/islandora_solr_conf

up:
	MSYS_NO_PATHCONV=1 docker-compose -p $(docker_compose_project) up --remove-orphans --detach

build:
	MSYS_NO_PATHCONV=1 docker-compose -p $(docker_compose_project) up \
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

drupal_clean:
	chmod u+w codebase/web/sites/default && rm -rf codebase data/drupal

clean_local: down_rmi_local drupal_clean

clean: down_rmi_all drupal_clean
