hocr_test:
.PHONY: hocr_test
## Make a local site with codebase directory bind mounted, using cloned starter site.
hocr_test: QUOTED_CURDIR = "$(CURDIR)"
hocr_test: generate-secrets

	$(MAKE) starter-init ENVIRONMENT=starter_dev
	if [ -z "$$(ls -A $(QUOTED_CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'git clone -b solr-hocr https://github.com/Islandora-Devops/islandora-starter-site /home/root;'; \
	fi
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIRONMENT=starter_dev
	docker compose up -d --remove-orphans
		@echo "Wait for the /var/www/drupal directory to be available"
	while ! docker compose exec -T drupal with-contenv bash -lc 'test -d /var/www/drupal'; do \
		echo "Waiting for /var/www/drupal directory to be available..."; \
		sleep 2; \
	done
	docker compose exec -T drupal with-contenv bash -lc 'chown -R nginx:nginx /var/www/drupal/ ; su nginx -s /bin/bash -c "composer install"'
	$(MAKE) starter-finalize ENVIRONMENT=starter_dev
docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} migrate:import islandora_hocr_media_uses'

