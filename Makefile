# Allows for customization of the behavior of the Makefile as well as Docker Compose.
# If it does not exist create it from sample.env.
ENV_FILE=$(shell \
	if [ ! -f .env ]; then \
		cp sample.env .env; \
	fi; \
	echo .env)

# Checks to see if the path includes a space character. Intended to be a temporary fix.
ifneq (1,$(words $(CURDIR)))
$(error Containing path cannot contain space characters: '$(CURDIR)')
endif

# Include the sample.env so new values can be added with defaults without requiring
# users to regenerate their .env files losing their changes.
include sample.env
include $(ENV_FILE)

# The site to operate on when using drush -l $(SITE) commands
SITE?=default

# Make sure all docker-compose commands use the given project
# name by setting the appropriate environment variables.
export

# Services that are not produced by isle-buildkit.
EXTERNAL_SERVICES := etcd watchtower traefik

# The minimal set of docker-compose files required to be able to run anything.
REQUIRED_SERVICES ?= activemq alpaca blazegraph cantaloupe crayfish crayfits drupal mariadb matomo solr

ifeq ($(USE_SECRETS), true)
	SECRETS := secrets
endif

# Watchtower is an optional dependency, by default it is included.
ifeq ($(INCLUDE_WATCHTOWER_SERVICE), true)
	WATCHTOWER_SERVICE := watchtower
endif

# The service traefik may be optional if we are sharing one from another project.
ifeq ($(INCLUDE_TRAEFIK_SERVICE), true)
	TRAEFIK_SERVICE := traefik
endif

# The service traefik may be optional if we are sharing one from another project.
ifeq ($(USE_ACME), true)
	ACME := acme
endif

# The service traefik may be optional if we are sharing one from another project.
ifeq ($(INCLUDE_CODE_SERVER_SERVICE), true)
	CODE_SERVER_SERVICE := code-server
endif

# etcd is an optional dependency, by default it is not included.
ifeq ($(INCLUDE_ETCD_SERVICE), true)
	ETCD_SERVICE := etcd
endif

# etcd is an optional dependency, by default it is not included.
ifeq ($(FEDORA_6), true)
	FCREPO_SERVICE := fcrepo6
else
	FCREPO_SERVICE := fcrepo
endif

# Some services can optionally depend on PostgreSQL.
# Either way their environment variables get customized
# depending on the database service they have choosen.
DATABASE_SERVICES ?= drupal.$(DRUPAL_DATABASE_SERVICE) $(FCREPO_SERVICE).$(FCREPO_DATABASE_SERVICE)

ifeq ($(DRUPAL_DATABASE_SERVICE), postgresql)
	DATABASE_SERVICES += postgresql
endif

ifeq ($(FCREPO_DATABASE_SERVICE), postgresql)
	DATABASE_SERVICES += postgresql
endif

# Sorts and removes duplicates.
DATABASE_SERVICES := $(sort $(DATABASE_SERVICES))

# The services to be run (order is important), as services can override one
# another. Traefik must be last if included as otherwise its network
# definition for `gateway` will be overriden.
SERVICES := $(REQUIRED_SERVICES) $(FCREPO_SERVICE) $(WATCHTOWER_SERVICE) $(ETCD_SERVICE) $(DATABASE_SERVICES) $(ENVIRONMENT) $(SECRETS) $(CODE_SERVER_SERVICE) $(TRAEFIK_SERVICE) $(ACME)

default: download-default-certs docker-compose.yml pull

.SILENT: docker-compose.yml
docker-compose.yml: $(SERVICES:%=docker-compose.%.yml) .env
	docker-compose $(SERVICES:%=-f docker-compose.%.yml) config > docker-compose.yml

.PHONY: pull
## Fetches the latest images from the registry.
pull: docker-compose.yml
ifeq ($(REPOSITORY), local)
	# Only need to pull external services if using local images.
	docker-compose pull $(filter $(EXTERNAL_SERVICES), $(SERVICES))
else
	docker-compose pull
endif

.PHONY: build
## Create Dockerfile from example if it does not exist.
build:
	if [ ! -f $(PROJECT_DRUPAL_DOCKERFILE) ]; then \
		cp "$(CURDIR)/sample.Dockerfile" $(PROJECT_DRUPAL_DOCKERFILE); \
	fi
	docker build -f $(PROJECT_DRUPAL_DOCKERFILE) -t $(COMPOSE_PROJECT_NAME)_drupal --build-arg REPOSITORY=$(REPOSITORY) --build-arg TAG=$(TAG) .


# Updates codebase folder to be owned by the host user and nginx group.
.PHONY: set-files-owner
.SILENT: set-files-owner
set-files-owner: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	sudo find "$(SRC)" -exec chown $(shell id -u):101 {} \;

# Creates required databases for drupal site(s) using environment variables.
.PHONY: drupal-database
.SILENT: drupal-database
drupal-database:
	docker-compose exec -T drupal timeout 300 bash -c "while ! test -e /var/run/nginx/nginx.pid -a -e /var/run/php-fpm7/php-fpm7.pid; do sleep 1; done"
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_database"

# Installs drupal site(s) using environment variables.
.PHONY: install
.SILENT: install
install: drupal-database
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites install_site"

# Updates settings.php according to the environment variables.
.PHONY: update-settings-php
.SILENT: update-settings-php
update-settings-php:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites update_settings_php"
	# Make sure the host user can read the settings.php files after they have been updated.
	sudo find ./codebase -type f -name "settings.php" -exec chown $(shell id -u):101 {} \;

# Updates configuration from environment variables.
# Allow all commands to fail as the user may not have all the modules like matomo, etc.
.PHONY: update-config-from-environment
.SILENT: update-config-from-environment
update-config-from-environment:
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_jwt_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_search_api_solr_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_matomo_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_openseadragon"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"

# Runs migrations of islandora
.PHONY: run-islandora-migrations
.SILENT: run-islandora-migrations
run-islandora-migrations:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites import_islandora_migrations"

# Creates solr-cores according to the environment variables.
.PHONY: solr-cores
.SILENT: solr-cores
solr-cores:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_solr_core_with_default_config"

# Creates namespaces in Blazegraph according to the environment variables.
.PHONY: namespaces
.SILENT: namespaces
namespaces:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_blazegraph_namespace_with_default_properties"

.PHONY: hydrate
.SILENT: hydrate
## Reconstitute the site from environment variables.
hydrate: update-settings-php update-config-from-environment solr-cores namespaces run-islandora-migrations
	docker-compose exec -T drupal drush cr -y

# Created by the standard profile, need to be deleted to import a site that was
# created with the standard profile.
.PHONY: delete-shortcut-entities
.SILENT: delete-shortcut-entities
delete-shortcut-entities:
	docker-compose exec -T drupal drush -l $(SITE) entity:delete shortcut_set

# Forces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: set-site-uuid
.SILENT: set-site-uuid
set-site-uuid:
	docker-compose exec -T drupal with-contenv bash -lc "set_site_uuid"

# RemovesForces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: remove_standard_profile_references_from_config
.SILENT: remove_standard_profile_references_from_config
remove_standard_profile_references_from_config:
	docker-compose exec -T drupal with-contenv bash -lc "remove_standard_profile_references_from_config"

.PHONY: config-export
.SILENT: config-export
## Exports the sites configuration.
config-export:
	docker-compose exec -T drupal drush -l $(SITE) config:export -y


.PHONY: config-import
.SILENT: config-import
## Import the sites configuration. N.B You may need to run this multiple times in succession due to errors in the configurations dependencies.
config-import: set-site-uuid delete-shortcut-entities
	docker-compose exec -T drupal drush -l $(SITE) config:import -y

drupal-database-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T drupal with-contenv bash -lc 'mysqldump -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} > /tmp/dump.sql'
	docker cp $$(docker-compose ps -q drupal):/tmp/dump.sql $(DEST)

# Import database.
drupal-database-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker-compose ps -q drupal):/tmp/dump.sql
	# Need to specify the root user to import the database otherwise it will fail due to permissions.
	docker-compose exec -T drupal with-contenv bash -lc 'chown root:root /tmp/dump.sql && mysql -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} < /tmp/dump.sql'

drupal-public-files-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T drupal with-contenv bash -lc 'tar zcvf /tmp/public-files.tgz /var/www/drupal/web/sites/default/files'
	docker cp $$(docker-compose ps -q drupal):/tmp/public-files.tgz $(DEST)

drupal-public-files-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker-compose ps -q drupal):/tmp/public-files.tgz
	docker-compose exec -T drupal with-contenv bash -lc 'tar zxvf /tmp/public-files.tgz -C /var/www/drupal/web/sites/default/files && chown -R nginx:nginx /var/www/drupal/web/sites/default/files && rm /tmp/public-files.tgz'

# Composer Update
composer_update:
	docker-compose exec -T drupal with-contenv bash -lc 'composer update'

# Dump fcrepo.
fcrepo-export:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T fcrepo with-contenv bash -lc 'java -jar /opt/tomcat/fcrepo-import-export-1.0.1.jar --mode export -r http://$(DOMAIN):8081/fcrepo/rest -d /tmp/fcrepo-export -b -u $${FCREPO_TOMCAT_ADMIN_USER}:$${FCREPO_TOMCAT_ADMIN_PASSWORD}'
	docker-compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zcvf fcrepo-export.tgz fcrepo-export'
	docker cp $$(docker-compose ps -q fcrepo):/tmp/fcrepo-export.tgz $(DEST)

# Import fcrepo.
fcrepo-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	$(MAKE) -B docker-compose.yml DISABLE_SYN=true
	docker-compose up -d fcrepo
	docker cp "$(SRC)" $$(docker-compose ps -q fcrepo):/tmp/fcrepo-export.tgz
	docker-compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zxvf fcrepo-export.tgz && chown -R tomcat:tomcat fcrepo-export && rm fcrepo-export.tgz'
ifeq ($(FEDORA_6), true)
	docker-compose exec -T fcrepo with-contenv bash -lc 'java -jar fcrepo-upgrade-utils-6.0.0-beta-1.jar -i /tmp/fcrepo-export -o /data/home -s 5+ -t 6+ -u http://${DOMAIN}:8081/fcrepo/rest && chown -R tomcat:tomcat /data/home'
ifeq ($(FCREPO_DATABASE_SERVICE), postgresql)
	$(error Postgresql not implemented yet in fcrepo-import)
else
	docker-compose exec -T fcrepo with-contenv bash -lc 'mysql -u $${DB_ROOT_USER} -p$${DB_ROOT_PASSWORD} -h $${DB_MYSQL_HOST} -e "DROP DATABASE $${FCREPO_DB_NAME}"'
endif
else
	docker-compose exec -T fcrepo with-contenv bash -lc 'java -jar /opt/tomcat/fcrepo-import-export-1.0.1.jar --mode import -r http://$(DOMAIN):8081/fcrepo/rest --map http://islandora.traefik.me:8081/fcrepo/rest,http://$(DOMAIN):8081/fcrepo/rest -d /tmp/fcrepo-export -b -u $${TOMCAT_ADMIN_NAME}:$${TOMCAT_ADMIN_PASSWORD}'
endif
	$(MAKE) -B docker-compose.yml
	docker-compose up -d fcrepo

reindex-fcrepo-metadata:
	# Re-index RDF in Fedora
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec non_fedora_files emit_file_event --configuration="queue=islandora-indexing-fcrepo-file-external&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-fcrepo-media&event=Update"'

reindex-solr:
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-reindex'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-index'

reindex-triplestore:
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'

# Helper to generate secrets & passwords, like so:
# make generate-secrets
.PHONY: generate-secrets
.SILENT: generate-secrets
generate-secrets:
	docker run --rm -t \
		-v "$(CURDIR)/secrets":/secrets \
		-v "$(CURDIR)/scripts/generate-secrets.sh":/generate-secrets.sh \
		-w / \
		--entrypoint bash \
		$(REPOSITORY)/drupal:$(TAG) -c "/generate-secrets.sh && chown -R `id -u`:`id -g` /secrets"

# Helper function to generate keys for the user to use in their docker-compose.env.yml
.PHONY: download-default-certs
.SILENT: download-default-certs
download-default-certs:
	mkdir -p certs
	if [ ! -f certs/cert.pem ]; then \
		curl http://traefik.me/fullchain.pem -o certs/cert.pem; \
	fi
	if [ ! -f certs/privkey.pem ]; then \
		curl http://traefik.me/privkey.pem -o certs/privkey.pem; \
	fi

.PHONY: demo
.SILENT: demo
## Make a demo site.
demo: generate-secrets
	$(MAKE) download-default-certs ENVIROMENT=demo
	$(MAKE) -B docker-compose.yml ENVIROMENT=demo
	$(MAKE) pull ENVIROMENT=demo
	mkdir -p "$(CURDIR)/codebase"
	docker-compose up -d
	$(MAKE) update-settings-php ENVIROMENT=demo
	$(MAKE) drupal-public-files-import SRC="$(CURDIR)/demo-data/public-files.tgz" ENVIROMENT=demo
	$(MAKE) drupal-database ENVIROMENT=demo
	$(MAKE) drupal-database-import SRC="$(CURDIR)/demo-data/drupal.sql" ENVIROMENT=demo
	$(MAKE) hydrate ENVIROMENT=demo
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} upwd admin $${DRUPAL_DEFAULT_ACCOUNT_PASSWORD}'
	$(MAKE) fcrepo-import SRC="$(CURDIR)/demo-data/fcrepo-export.tgz" ENVIROMENT=demo
	$(MAKE) reindex-fcrepo-metadata ENVIROMENT=demo
	$(MAKE) reindex-solr ENVIROMENT=demo
	$(MAKE) reindex-triplestore ENVIROMENT=demo

.PHONY: local
.SILENT: local
## Make a local site with codebase directory bind mounted.
local: QUOTED_CURDIR = "$(CURDIR)"
local: generate-secrets
	$(MAKE) download-default-certs ENVIROMENT=local
	$(MAKE) -B docker-compose.yml ENVIRONMENT=local
	$(MAKE) pull ENVIRONMENT=local
	mkdir -p "$(CURDIR)/codebase"
	if [ -z "$$(ls -A $(QUOTED_CURDIR)/codebase)" ]; then \
		docker container run --rm -v "$(CURDIR)/codebase":/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'composer create-project drupal/recommended-project:^9.1 /tmp/codebase; mv /tmp/codebase/* /home/root; cd /home/root; composer config minimum-stability dev; composer require islandora/islandora:dev-8.x-1.x; composer require drush/drush:^10.3'; \
	fi
	docker-compose up -d
	docker-compose exec -T drupal with-contenv bash -lc 'composer install; chown -R nginx:nginx .'
	$(MAKE) remove_standard_profile_references_from_config ENVIROMENT=local
	$(MAKE) install ENVIRONMENT=local
	$(MAKE) hydrate ENVIRONMENT=local
	$(MAKE) set-files-owner SRC="$(CURDIR)/codebase" ENVIROMENT=local

.PHONY: demo-install-profile
.SILENT: demo-instal-profile
demo-install-profile: generate-secrets
	$(MAKE) download-default-certs ENVIROMENT=demo
	$(MAKE) -B docker-compose.yml ENVIROMENT=demo
	$(MAKE) pull ENVIROMENT=demo
	mkdir -p $(CURDIR)/codebase
	docker-compose up -d --remove-orphans
	@echo "\n Sleeping for 10 seconds to wait for Drupal to finish initializing.\n"
	sleep 10
	$(MAKE) install
	$(MAKE) update-settings-php ENVIROMENT=demo
	$(MAKE) hydrate ENVIROMENT=demo
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} upwd admin $${DRUPAL_DEFAULT_ACCOUNT_PASSWORD}'
	docker-compose exec -T drupal with-contenv bash -lc 'drush migrate:rollback islandora_defaults_tags,islandora_tags'
	$(MAKE) initial_content
	$(MAKE) login

.PHONY: local-install-profile
.SILENT: local-install-profile
local-install-profile: generate-secrets
	$(MAKE) download-default-certs ENVIROMENT=local
	$(MAKE) -B docker-compose.yml ENVIRONMENT=local
	$(MAKE) pull ENVIRONMENT=local
	mkdir -p $(CURDIR)/codebase
	if [ -z "$$(ls -A $(CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'git clone https://github.com/islandora-devops/islandora-sandbox /tmp/codebase; mv /tmp/codebase/* /home/root;'; \
	fi
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIROMENT=local
	docker-compose up -d --remove-orphans
	docker-compose exec -T drupal with-contenv bash -lc 'composer install; chown -R nginx:nginx .'
	$(MAKE) remove_standard_profile_references_from_config ENVIROMENT=local
	$(MAKE) install ENVIRONMENT=local
	$(MAKE) hydrate ENVIRONMENT=local
	# The - at the beginning is not a typo, it will allow this process to failing the make command.
	-docker-compose exec -T drupal with-contenv bash -lc 'mkdir -p /var/www/drupal/config/sync && chmod -R 775 /var/www/drupal/config/sync'
	docker-compose exec -T drupal with-contenv bash -lc 'chown -R `id -u`:101 /var/www/drupal'
	docker-compose exec -T drupal with-contenv bash -lc 'drush migrate:rollback islandora_defaults_tags,islandora_tags'
	$(MAKE) initial_content
	$(MAKE) login

.PHONY: initial_content
initial_content:
	curl -u admin:$(shell cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD) -H "Content-Type: application/json" -d "@demo-data/homepage.json" https://${DOMAIN}/node?_format=json
	curl -u admin:$(shell cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD) -H "Content-Type: application/json" -d "@demo-data/browse-collections.json" https://${DOMAIN}/node?_format=json

# Destroys everything beware!
.PHONY: clean
.SILENT: clean
## Destroys everything beware!
clean:
	echo "**DANGER** About to rm your SERVER data subdirs, your docker volumes and your codebase/web"
	$(MAKE) confirm
	-docker-compose down -v
	sudo rm -fr codebase certs secrets/live/*
	git clean -xffd .

.PHONY: up
.SILENT: up
## Brings up the containers or builds demo if no containers were found.
up:
	test -f docker-compose.yml && docker-compose up -d --remove-orphans || $(MAKE) demo
	@echo "\n Sleeping for 10 seconds to wait for Drupal to finish building.\n"
	sleep 10
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites update_settings_php"

.PHONY: down
.SILENT: down
down:
	-docker-compose down --remove-orphans

.PHONY: login
.SILENT: login
login:
	echo "\n\n=========== LOGIN ==========="
	docker-compose exec -T drupal with-contenv bash -lc "drush uli --uri=$(DOMAIN)"
	echo "=============================\n"

.phony: confirm
confirm:
	@echo -n "Are you sure you want to continue and drop your data? [y/N] " && read ans && [ $${ans:-N} = y ]

.PHONY: help
.SILENT: help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	# @grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1 \2/'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = $$1; sub(/:$$/, "", helpCommand); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{lastLine = $$0}' $(MAKEFILE_LIST)

IS_DRUPAL_PSSWD_FILE_READABLE := $(shell test -r secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD -a -w secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD && echo 1 || echo 0)
CMD := $(shell [ $(IS_DRUPAL_PSSWD_FILE_READABLE) -eq 1 ] && echo 'tee' || echo 'sudo -k tee')

.PHONY: set_admin_password
.SILENT: set_admin_password
## Sets the admin password and accomodates for permissions restrictions to the secrets directory. Only runs sudo when needed.
set_admin_password:
	@$(eval PASSWORD ?= $(shell bash -c 'read -s -p "New Password: " pwd; echo $$pwd'))
	@echo "\n\nSetting admin password now"
	docker-compose exec -T drupal with-contenv bash -lc 'drush user:password admin "$(PASSWORD)"'
	echo "$(PASSWORD)" | $(CMD) secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD >> /dev/null
	@echo "\ndone."

LATEST_VERSION := $(shell curl -s https://api.github.com/repos/desandro/masonry/releases/latest | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\1/')

.PHONY: fix-masonry
.SILENT: fix-masonry
## Fix missing masonry library.
fix-masonry:
	@echo "Latest version of masonry library is ${LATEST_VERSION}"
	docker-compose exec drupal bash -lc "[ -d '/var/www/drupal/web/libraries' ] && exit ; mkdir -p /var/www/drupal/web/libraries ; chmod 755 /var/www/drupal/web/libraries ; chown 1000:nginx /var/www/drupal/web/libraries"
	docker-compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ ! -d '/var/www/drupal/web/libraries/masonry' ] && git clone --quiet --branch ${LATEST_VERSION} https://github.com/desandro/masonry.git || echo Ready"
	docker-compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ -d '/var/www/drupal/web/libraries/masonry' ] && chmod -R 755 /var/www/drupal/web/libraries/masonry ; chown -R 1000:nginx /var/www/drupal/web/libraries/masonry"
