# The variable used to determine which composer create project to use.
# Run make drupal_init_help for more information
include .env

isle_codebase ?= islandora

docker_compose_project ?= ${COMPOSE_PROJECT_NAME}
environment ?= demo
dc_flags ?= -f docker-compose.yml -f docker-compose.$(environment).yml -p $(docker_compose_project)

.PHONY: help drupal_init up build down down_rmi_all down_rmi_local drupal_clean clean_local clean

default: drupal_init up solr_init

help:
	./scripts/drupal/init.sh --help && echo "\nCURRENT DC FLAGS: "$(dc_flags)

drupal_init:
	./scripts/drupal/init.sh --codebase $(isle_codebase)

solr_init:
	docker cp scripts/solr/create-core.sh $(docker_compose_project)_drupal_1:/tmp/create-core.sh && \
	docker-compose $(dc_flags) exec -T -w /tmp/ drupal bash -c "chmod 755 create-core.sh && ./create-core.sh" && \
	docker-compose $(dc_flags) exec -T drupal bash -c "drush cset -y search_api.server.default_solr_server backend_config.connector_config.host solr" && \
	docker-compose $(dc_flags) exec -T drupal bash -c "drush cset -y search_api.server.default_solr_server backend_config.connector_config.core ISLANDORA"

up:
	MSYS_NO_PATHCONV=1 docker-compose $(dc_flags) up --remove-orphans --detach

build:
	MSYS_NO_PATHCONV=1 docker-compose $(dc_flags) up \
		--build \
		--detach \
		--remove-orphans

logs:
	MSYS_NO_PATHCONV=1 docker-compose $(dc_flags) logs -f

install_islandora:
	docker-compose $(dc_flags) exec -T drupal bash -c "chmod +x /opt/scripts/islandora/*.sh && /opt/scripts/islandora/simplified_islandora_install.sh"

jwt_keys:
	(cd scripts; ./generate_jwt_keys.sh)
	#copy keys to the appropriate location within the container

# use like this: make drupal_exec command="drush st"
drupal_exec:
	docker-compose $(dc_flags) exec -T -w /var/www/drupal drupal bash -c "$(command)"

# use like this: make drupal_db_load dbfilepath=data/misc dbfilename=latest.sql
drupal_db_load:
	docker cp $(dbfilepath)/$(dbfilename) $(docker_compose_project)_database_1:/tmp/$(dbfilename) && \
	docker-compose $(dc_flags) exec -T database bash -c "mysql -u root -ppassword drupal_default < /tmp/$(dbfilename)"

down:
	docker-compose $(dc_flags) down --remove-orphans

down_rmi_all:
	docker-compose $(dc_flags) down \
		--rmi all \
		--volumes \
		--remove-orphans

down_rmi_local:
	docker-compose $(dc_flags) down \
		--rmi local \
		--volumes \
		--remove-orphans

drupal_clean:
	chmod u+w codebase/web/sites/default && rm -rf codebase data/drupal

clean_local: down_rmi_local drupal_clean

clean: down_rmi_all drupal_clean
