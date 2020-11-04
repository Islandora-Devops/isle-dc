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
	docker-compose exec drupal drush cr -y

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
	$(MAKE) start

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

.PHONY: up
.SILENT: up
up:  download-default-certs docker-compose.yml start


.PHONY: start
.SILENT: start
start:
	docker-compose up -d
	$(MAKE) wait-for-drupal

.PHONY: wait-for-drupal
.SILENT: wait-for-drupal
wait-for-drupal:
	while test -z `docker-compose ps -q drupal` ; do echo "Waiting for Drupal container to start"; sleep 5; done
	docker-compose exec -T drupal /bin/sh -c "while true ; do echo \"Waiting for Drupal to load ...\" ; if [ -d \"/var/run/s6/services/nginx\" ] ; then s6-svwait -u /var/run/s6/services/nginx && exit 0 ; else sleep 5 ; fi done"

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
	    docker build --build-arg REPOSITORY=${REPOSITORY} \
	        --build-arg TAG=${TAG} \
	        -t ${REPOSITORY}/drupal-static:${GIT_TAG} . ; \
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
