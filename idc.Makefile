# Bootstrap a new instance without Fedora.  Assumes there is a Drupal site in ./codebase.
# Will do a clean Drupal install and initialization
#
# (TODO: generally make ISLE more robust to the choice to omit fedora.
# otherwise we could of simply done 'hydrate' instead of update-settings-php, update-config... etc)
.PHONY: bootstrap
.SILENT: bootstrap
bootstrap: default destroy-state composer-install install \
		update-settings-php update-config-from-environment solr-cores run-islandora-migrations \
		cache-rebuild snapshot-image

# Rebuilds the Drupal cache
.PHONY: cache-rebuild
.SILENT: cache-rebuild
cache-rebuild:
	echo "irebuilding Drupal cache..."
	docker-compose exec drupal drush cr -y

.PHONY: destroy-state
.SILENT: destroy-state
destroy-state:
	echo "Destroying docker-compose volume state"
	docker-compose down -v
	docker-compose up -d

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
	TAG=`git describe --tags`.`date +%s` && \
		docker build -f snapshot/snapshot.Dockerfile -t ${SNAPSHOT_IMAGE}:$$TAG ./snapshot && \
		sed -i s/SNAPSHOT_TAG=.*/SNAPSHOT_TAG=$$TAG/ .env
	rm docker-compose.yml
	$(MAKE) docker-compose.yml
	docker-compose up -d