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
	MSYS_NO_PATHCONV=1 docker-compose -p $(docker_compose_project) up --remove-orphans --detach

build:
	MSYS_NO_PATHCONV=1 docker-compose -p $(docker_compose_project) up \
		--build \
		--detach \
		--remove-orphans

jwt_keys:
	(cd scripts; ./generate_jwt_keys.sh)
	#copy keys to the appropriate location within the container

# use like this: make drupal_exec command="drush st"
drupal_exec:
	docker-compose exec -T -p islandora -w /var/www/html/web drupal bash -c "$(command)"

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

# use like this: make drupal_db_load dbfilepath=data/misc dbfilename=latest.sql
drupal_db_load:
	docker cp $(dbfilepath)/$(dbfilename) $(docker_compose_project)_database_1:/tmp/$(dbfilename) && \
	docker exec $(docker_compose_project)_database_1 bash -c "mysql -u root -ppassword drupal_default < /tmp/$(dbfilename)"

clean_local: down_rmi_local drupal_clean

clean: down_rmi_all drupal_clean
