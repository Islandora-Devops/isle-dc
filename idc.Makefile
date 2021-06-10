.DEFAULT_GOAL := default
GIT_TAG := $(shell git describe --tags --always)

# Bootstrap a new instance without Fedora.  Assumes there is a Drupal site in ./codebase.
# Will do a clean Drupal install and initialization
#
# (TODO: generally make ISLE more robust to the choice to omit fedora.
# otherwise we could of simply done 'hydrate' instead of update-settings-php, update-config... etc)
.PHONY: bootstrap
.SILENT: bootstrap
bootstrap: snapshot-empty default destroy-state up install \
		update-settings-php update-config-from-environment solr-cores run-islandora-migrations \
		cache-rebuild
		git checkout -- .env

# Rebuilds the Drupal cache
.PHONY: cache-rebuild
.SILENT: cache-rebuild
cache-rebuild:
	echo "rebuilding Drupal cache..."
	docker-compose exec -T drupal drush cr -y

.PHONY: destroy-state
.SILENT: destroy-state
destroy-state:
	echo "Destroying docker-compose volume state"
	docker-compose down -v

.PHONY: composer-install
.SILENT: composer-install
composer-install:
	echo "Installing via composer"
	docker-compose exec drupal with-contenv bash -lc 'COMPOSER_MEMORY_LIMIT=-1 composer install'

.PHONY: snapshot-image
.SILENT: snapshot-image
snapshot-image:
	${MAKE} db_dump
	docker-compose stop
	docker run --rm --volumes-from snapshot \
		-v ${PWD}/snapshot:/dump \
		alpine:latest \
		/bin/tar cvf /dump/data.tar /data
	TAG=${GIT_TAG}.`date +%s` && \
		docker build -t ${REPOSITORY}/snapshot:$$TAG ./snapshot && \
		cat .env | sed s/SNAPSHOT_TAG=.*/SNAPSHOT_TAG=$$TAG/ > /tmp/.env && \
	  cp /tmp/.env .env && \
	  rm /tmp/.env
	rm docker-compose.yml
	$(MAKE) docker-compose.yml
	docker-compose up -d

.PHONY: reset
.SILENT: reset
reset: warning-destroy-state destroy-state
	@echo "Removing vendored modules"
	-rm -rf codebase/vendor
	-rm -rf codebase/web/core
	-rm -rf codebase/web/modules/contrib
	-rm -rf codebase/web/themes/contrib
	@echo "Re-generating docker-compose.yml"
	-rm -rf docker-compose.yml
	$(MAKE) docker-compose.yml
	@echo "Starting ..."
	@echo "Invoke 'docker-compose logs -f drupal' in another terminal to monitor startup progress"
	$(MAKE) up

.PHONY: warning-destroy-state
.SILENT: warning-destroy-state
warning-destroy-state:
	@echo "WARNING: Resetting state to snapshot ${SNAPSHOT_TAG}.  This will:"
	@echo "1. Remove all modules and dependencies under:"
	@echo "  codebase/vendor"
	@echo "  codebase/web/core"
	@echo "  codebase/modules/contrib"
	@echo "  codebase/themes/contrib"
	@echo "2. Re-generate docker-compose.yml"
	@echo "3. Pull the latest images"
	@echo "4. Re-install modules from composer.json"
	@echo "WARNING: continue? [Y/n]"
	@read line; if [ $$line != "Y" ]; then echo aborting; exit 1 ; fi

.PHONY: snapshot-empty
.SILENT: snapshot-empty
snapshot-empty:
	-rm docker-compose.yml
	sed s/SNAPSHOT_TAG=.*/SNAPSHOT_TAG=empty/ .env > /tmp/.env && \
      cp /tmp/.env .env && \
	    rm /tmp/.env
	$(MAKE) docker-compose.yml
	docker build -f snapshot/empty.Dockerfile -t ${REPOSITORY}/snapshot:empty ./snapshot

.PHONY: snapshot-push
.SILENT: snapshot-push
snapshot-push:
	docker push ${REPOSITORY}/snapshot:${SNAPSHOT_TAG}

.PHONY: up
.SILENT: up
up:  download-default-certs docker-compose.yml start

.PHONY: dev-up
.SILENT: dev-up
dev-up:  download-default-certs
	-docker-compose stop drupal
	-docker-compose rm -f drupal
	sed s/ENVIRONMENT=.*/ENVIRONMENT=drupal-dev/ .env > /tmp/.env && \
		cp /tmp/.env .env && \
		rm /tmp/.env
	$(MAKE) -B docker-compose.yml start

.PHONY: dev-down
.SILENT: dev-down
dev-down:  download-default-certs
	sed s/ENVIRONMENT=.*/ENVIRONMENT=local/ .env > /tmp/.env && \
		cp /tmp/.env .env && \
		rm /tmp/.env
	$(MAKE) -B docker-compose.yml
	docker-compose stop drupal
	docker-compose rm -f drupal

.PHONY: start
.SILENT: start
start:
	docker-compose up -d mariadb snapshot;
	# Try connecting to mariadb, and get a valid (a number, greater than zero) count of the number of databases.
	# Then, once we're "confident" that mariadb is up and validly query able, see if the Drupal db is in place.
	# This is a tricky process, as the mariadb client can succeed once, then fail on a subsequent invocation.
	# Once we've finally determined if mariadb is running, and have found a valid answer for whether the Drupal DB is present,
	# then we can proceed.  If the Drupal DB is not present, then load it from snapshot before starting the stack.
	# Otherwise, if the Drupal db is already present, just start.
	for i in $$(seq 5) ; do \
		echo "waiting for mysql to start..."; \
		sleep 5; \
		BASIC_DBS_PRESENT=$$(docker-compose exec -T mariadb mysql mysql -N -e "SELECT count(*) from information_schema.SCHEMATA;"); \
		if [  "$$?" -gt "0" ]; then continue; fi; \
		if [ ! -n "$$BASIC_DBS_PRESENT" ]; then continue; fi; \
		if [ ! "$$BASIC_DBS_PRESENT" -gt "0" ]; then continue; fi; \
		DRUPAL_STATE_EXISTS=$$(docker-compose exec -T mariadb mysql mysql -N -e "SELECT count(*) from information_schema.SCHEMATA WHERE schema_name = 'drupal_default';"); \
		if [ "$$?" -eq "0" -a -n "$${DRUPAL_STATE_EXISTS}" ]; then break; fi; \
	done; \
	if [ "$${DRUPAL_STATE_EXISTS}" != "1" ] ; then \
		echo "No Drupal state found.  Loading from snapshot, and importing config from config/sync"; \
		${MAKE} db_restore; \
		${MAKE} _docker-up-and-wait; \
		${MAKE} config-import; \
	else echo "Pre-existing Drupal state found, not loading db from snapshot"; \
		${MAKE} _docker-up-and-wait; \
	fi;

.PHONY: _docker-up-and-wait
.SILENT: _docker-up-and-wait
_docker-up-and-wait:
	docker-compose up -d
	sleep 5
	docker-compose exec -T drupal /bin/sh -c "while true ; do echo \"Waiting for Drupal to start ...\" ; if [ -d \"/var/run/s6/services/nginx\" ] ; then s6-svwait -u /var/run/s6/services/nginx && exit 0 ; else sleep 5 ; fi done"


# Static drupal image, with codebase baked in.  This image
# is tagged based on the current git hash/tag.  If the image is not present
# locally, nor pullable, then this is built locally.  Ultimately, this image is
# intended be published to cloud instances of the stack
.PHONY: static-drupal-image
.SILENT: static-drupal-image
static-drupal-image:
	IMAGE=${REPOSITORY}/drupal-static:${GIT_TAG} ; \
	EXISTING=`docker images -q $$IMAGE` ; \
	if test -z "$$EXISTING" ; then \
	    docker pull $${IMAGE} 2>/dev/null || \
	    docker build --build-arg REPOSITORY=$${REPOSITORY} --build-arg TAG=$${TAG} -t $${IMAGE} .; \
	else \
	    echo "Using existing Drupal image $${EXISTING}" ; \
	fi


# Build a docker-compose file that will run the whole stack, except with
# the static drupal image rather than the dev drupal image + codebase bind mount.
.SILENT: static-docker-compose.yml
.PHONY: static-docker-compose.yml
static-docker-compose.yml: static-drupal-image
	-rm -f docker-compose.yml
	echo '' > .env_static && \
	    while read line; do \
		if echo $$line | grep -q "ENVIRONMENT" ; then \
			echo "ENVIRONMENT=static" >> .env_static ; \
		else \
			echo $$line >> .env_static ; \
		fi \
	    done < .env && \
	    echo DRUPAL_STATIC_TAG=${GIT_TAG} >> .env_static
	mv .env .env.bak
	mv .env_static .env
	$(MAKE) docker-compose.yml || mv .env.bak .env
	if [ -f .env.bak ] ; then mv .env.bak .env ; fi

.SILENT: test
.PHONY: test
test:
	./run-tests.sh $(test)

.PHONY: db_dump
.SILENT: db_dump
db_dump:
	docker-compose exec -T mariadb bash -c "mysqldump drupal_default --add-drop-database > /mariadb-dump/drupal_default.sql"

.PHONY: db_restore
.SILENT: db_restore
db_restore:
	if [ -z "${DRUPAL_DEFAULT_DB_USER}" ] ; then \
		DRUPAL_DEFAULT_DB_USER=drupal_default; \
	fi; \
	echo "Creating mysql user $${DRUPAL_DEFAULT_DB_USER}"
	docker-compose exec -T mariadb mysql mysql -e "CREATE USER IF NOT EXISTS '$${DRUPAL_DEFAULT_DB_USER}'@'%' IDENTIFIED BY '${DRUPAL_DEFAULT_DB_PASSWORD}'; FLUSH PRIVILEGES"; \
	docker-compose exec -T mariadb bash -c 'mysql mysql -e "DROP DATABASE IF EXISTS drupal_default"'; \
	docker-compose exec -T mariadb bash -c 'mysql mysql -e "CREATE DATABASE drupal_default DEFAULT CHARACTER SET utf8"'; \
	echo "Loading mysql dump"; \
	docker-compose exec -T mariadb bash -c 'mysql drupal_default < /mariadb-dump/drupal_default.sql'; \
	docker-compose exec -T mariadb mysql mysql -e "GRANT ALL PRIVILEGES ON drupal_default.* to '$${DRUPAL_DEFAULT_DB_USER}'@'%';";

.phony: minio-bucket
.silent: minio-bucket
minio-bucket:
	docker run --rm --env-file .env -v $$(pwd)/minio-init.sh:/minio-init.sh --network idc_default --entrypoint=/minio-init.sh minio/mc
