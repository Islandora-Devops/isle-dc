.PHONY: lite-init
lite-init: generate-secrets
	$(MAKE) download-default-certs
	$(MAKE) -B docker-compose.yml
	$(MAKE) pull
	mkdir -p $(CURDIR)/codebase

.PHONY: run-lite-migrations
## Runs migrations of islandora
.SILENT: run-lite-migrations
run-lite-migrations:
	#docker-compose exec -T drupal with-contenv bash -lc "for_all_sites import_islandora_migrations"
	# this line can be reverted when https://github.com/Islandora-Devops/isle-buildkit/blob/fae704f065435438828c568def2a0cc926cc4b6b/drupal/rootfs/etc/islandora/utilities.sh#L557
	# has been updated to match
	docker-compose exec -T drupal with-contenv bash -lc 'drush -l $(SITE) migrate:import islandora_tags'

.PHONY: update-config-from-lite-environment
## Updates configuration from environment variables.
## Allow all commands to fail as the user may not have all the modules like matomo, etc.
.SILENT: update-config-from-lite-environment
update-config-from-lite-environment:
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_jwt_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_search_api_solr_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_matomo_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_openseadragon"

.PHONY: lite_hydrate
.SILENT: lite_hydrate
## Reconstitute the site from environment variables.
lite_hydrate: update-settings-php update-config-from-lite-environment solr-cores namespaces run-lite-migrations
	docker-compose exec -T drupal drush cr -y

.PHONY: lite_dev
## Make a local site with codebase directory bind mounted, using cloned starter site.
lite_dev: QUOTED_CURDIR = "$(CURDIR)"
lite_dev: generate-secrets
	$(MAKE) lite-init ENVIRONMENT=local
	if [ -z "$$(ls -A $(QUOTED_CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'git clone -b 2.x https://github.com/digitalutsc/islandora-lite-site.git /home/root;'; \
	fi
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIRONMENT=local
	$(MAKE) compose-up

	# install imagemagick plugin
	docker compose exec -T drupal with-contenv bash -lc 'apk --update add imagemagick'
	docker compose exec -T drupal with-contenv bash -lc 'apk add php83-pecl-imagick'

	# install ffmpeg needed to create TNs
	docker compose exec -T drupal with-contenv bash -lc 'apk --update add ffmpeg'
	docker-compose restart drupal

	# install the site
	$(MAKE) compose-up
	docker compose exec -T drupal with-contenv bash -lc 'chown -R nginx:nginx /var/www/drupal/ ; su nginx -s /bin/bash -c "composer install"'
	$(MAKE) lite-finalize ENVIRONMENT=local

	# Set config media_thumbnails_video
	docker compose exec -T drupal with-contenv bash -lc 'drush -y config:set media_thumbnails_video.settings ffmpeg /usr/bin/ffmpeg'
	docker compose exec -T drupal with-contenv bash -lc 'drush -y config:set media_thumbnails_video.settings ffprobe /usr/bin/ffprobe'

.PHONY: lite-finalize
lite-finalize:
	docker compose exec -T drupal with-contenv bash -lc 'chown -R nginx:nginx . ; echo "Chown Complete"'
	$(MAKE) drupal-database update-settings-php
	docker-compose exec -T drupal with-contenv bash -lc "drush si -y --existing-config minimal --account-pass '$(shell cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD)'"
	docker-compose exec -T drupal with-contenv bash -lc "drush -l $(SITE) user:role:add administrator admin"
	@echo "Checking if Solr's healthy"
	docker compose exec -T solr bash -c 'curl -s http://localhost:8983/solr/admin/info/system?wt=json' | jq -r .lucene || (echo "Solr is not healthy, waiting 10 seconds." && sleep 10)

	MIGRATE_IMPORT_USER_OPTION=--userid=1 $(MAKE) lite_hydrate
	$(MAKE) login
	$(MAKE) wait-for-drupal-locally

