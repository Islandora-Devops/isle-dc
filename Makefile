# Allows for customization of the behavior of the Makefile as well as Docker Compose.
# If it does not exist create it from sample.env.
ENV_FILE=$(shell \
	if [ ! -f .env ]; then \
		cp sample.env .env; \
	fi; \
	echo .env)

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
REQUIRED_SERIVCES ?= activemq alpaca blazegraph cantaloupe crayfish crayfits drupal fcrepo mariadb matomo solr

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

# etcd is an optional dependency, by default it is not included.
ifeq ($(INCLUDE_ETCD_SERVICE), true)
	ETCD_SERVICE := etcd
endif

# Some services can optionally depend on PostgreSQL.
# Either way their environment variables get customized
# depending on the database service they have choosen.
DATABASE_SERVICES ?= drupal.$(DRUPAL_DATABASE_SERVICE) fcrepo.$(FCREPO_DATABASE_SERVICE) crayfish.$(GEMINI_DATABASE_SERVICE)

ifeq ($(DRUPAL_DATABASE_SERVICE), postgresql)
	DATABASE_SERVICES += postgresql
endif

ifeq ($(FCREPO_DATABASE_SERVICE), postgresql)
	DATABASE_SERVICES += postgresql
endif

ifeq ($(GEMINI_DATABASE_SERVICE), postgresql)
	DATABASE_SERVICES += postgresql
endif

# Sorts and removes duplicates.
DATABASE_SERVICES := $(sort $(DATABASE_SERVICES))

# The services to be run (order is important), as services can override one
# another. Traefik must be last if included as otherwise its network 
# definition for `gateway` will be overriden.
SERVICES := $(REQUIRED_SERIVCES) $(WATCHTOWER_SERVICE) $(ETCD_SERVICE) $(DATABASE_SERVICES) $(ENVIRONMENT) $(TRAEFIK_SERVICE) $(SECRETS)

default: download-default-certs docker-compose.yml pull

.SILENT: docker-compose.yml
docker-compose.yml: $(SERVICES:%=docker-compose.%.yml) .env
	docker-compose $(SERVICES:%=-f docker-compose.%.yml) config > docker-compose.yml

.PHONY: pull
pull: docker-compose.yml
ifeq ($(REPOSITORY), local)
	# Only need to pull external services if using local images.
	docker-compose pull $(filter $(EXTERNAL_SERVICES), $(SERVICES))
else
	docker-compose pull
endif

.PHONY: build
build:
	# Create Dockerfile from example if it does not exist.
	if [ ! -f $(PROJECT_DRUPAL_DOCKERFILE) ]; then \
		cp $(CURDIR)/sample.Dockerfile $(PROJECT_DRUPAL_DOCKERFILE); \
	fi
	docker build -f $(PROJECT_DRUPAL_DOCKERFILE) -t $(COMPOSE_PROJECT_NAME)_drupal --build-arg REPOSITORY=$(REPOSITORY) --build-arg TAG=$(TAG) .


# Updates codebase folder to be owned by the host user and nginx group.
.PHONY: set-codebase-owner
.SILENT: set-codebase-owner
set-codebase-owner:
	sudo find ./codebase -exec chown $(shell id -u):101 {} \;

# Creates required databases for drupal site(s) using environment variables.
.PHONY: databases
.SILENT: databases
databases:
	docker-compose exec drupal with-contenv bash -lc "for_all_sites create_database"

# Installs drupal site(s) using environment variables.
.PHONY: install
.SILENT: install
install: databases
	docker-compose exec drupal with-contenv bash -lc "for_all_sites install_site"

# Updates settings.php according to the environment variables.
.PHONY: update-settings-php
.SILENT: update-settings-php
update-settings-php:
	docker-compose exec drupal with-contenv bash -lc "for_all_sites update_settings_php"
	# Make sure the host user can read the settings.php files after they have been updated.
	sudo find ./codebase -type f -name "settings.php" -exec chown $(shell id -u):101 {} \;

# Updates configuration from environment variables.
# Allow all commands to fail as the user may not have all the modules like matomo, etc.
.PHONY: update-config-from-environment
.SILENT: update-config-from-environment
update-config-from-environment:
	-docker-compose exec drupal with-contenv bash -lc "for_all_sites configure_islandora_module"
	-docker-compose exec drupal with-contenv bash -lc "for_all_sites configure_matomo_module"
	-docker-compose exec drupal with-contenv bash -lc "for_all_sites configure_openseadragon"
	-docker-compose exec drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"

# Runs migrations of islandora
.PHONY: run-islandora-migrations
.SILENT: run-islandora-migrations
run-islandora-migrations:
	docker-compose exec drupal with-contenv bash -lc "for_all_sites import_islandora_migrations"

# Creates solr-cores according to the environment variables.
.PHONY: solr-cores
.SILENT: solr-cores
solr-cores:
	docker-compose exec drupal with-contenv bash -lc "for_all_sites create_solr_core_with_default_config"

# Creates namespaces in Blazegraph according to the environment variables.
.PHONY: namespaces
.SILENT: namespaces
namespaces:
	docker-compose exec drupal with-contenv bash -lc "for_all_sites create_blazegraph_namespace_with_default_properties"

# Reconstitute the site from environment variables.
.PHONY: hydrate
.SILENT: hydrate
hydrate: update-settings-php update-config-from-environment solr-cores namespaces run-islandora-migrations
	docker-compose exec drupal drush cr -y

# Created by the standard profile, need to be deleted to import a site that was
# created with the standard profile.
.PHONY: delete-shortcut-entities
.SILENT: delete-shortcut-entities
delete-shortcut-entities:
	docker-compose exec drupal drush -l $(SITE) entity:delete shortcut_set

# Forces the site uuid to match that in the config_sync_directory so that 
# configuration can be imported.
.PHONY: set-site-uuid
.SILENT: set-site-uuid
set-site-uuid:
	docker-compose exec drupal with-contenv bash -lc "set_site_uuid"

# RemovesForces the site uuid to match that in the config_sync_directory so that 
# configuration can be imported.
.PHONY: remove_standard_profile_references_from_config
.SILENT: remove_standard_profile_references_from_config
remove_standard_profile_references_from_config:
	docker-compose exec drupal with-contenv bash -lc "remove_standard_profile_references_from_config"

# Exports the sites configuration.
.PHONY: config-export
.SILENT: config-export
config-export:
	docker-compose exec drupal drush -l $(SITE) config:export -y

# Import the sites configuration.
# N.B You may need to run this multiple times in succession due to errors in the configurations dependencies.
.PHONY: config-import
.SILENT: config-import
config-import: set-site-uuid delete-shortcut-entities
	docker-compose exec drupal drush -l $(SITE) config:import -y

# Dump database.
database-dump:
ifndef DEST
	$(error DEST is not set)
endif
ifeq ($(wildcard $(CURDIR)/codebase),)
	$(error codebase folder does not exists)
endif
	docker-compose exec drupal drush -l $(SITE) sql:dump > /tmp/dump.sql
	docker cp $$(docker-compose ps -q drupal):/tmp/dump.sql $(DEST)

# Import database.
database-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
ifeq ($(wildcard $(CURDIR)/codebase),)
	$(error codebase folder does not exists)
endif
	docker cp $(SRC) $$(docker-compose ps -q drupal):/tmp/dump.sql
	# Need to specify the root user to import the database otherwise it will fail due to permissions.
	docker-compose exec drupal with-contenv bash -lc '`drush -l $(SITE) sql:connect --extra="-u $${DRUPAL_DEFAULT_DB_ROOT_USER} --password=$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD}"` < /tmp/dump.sql'

# Creates the codebase folder from a running islandora/demo image.
.PHONY: create-codebase-from-demo
.SILENT: create-codebase-from-demo
create-codebase-from-demo:
ifneq ($(wildcard $(CURDIR)/codebase),)
	$(error codebase folder already exists)
endif
	# Create docker-compose.yml file for the demo environment.
	$(MAKE) -B docker-compose.yml ENVIRONMENT=demo
	# Ensure we have the latest images.
	$(MAKE) pull
	# Start the services
	docker-compose up -d
	# Give an extra few seconds for the containers to become responsive.
	sleep 5
	# Wait for Drupal to become responsive (up to 20 minutes - should be less than 5 except on Macs).
	docker-compose exec drupal timeout 1200 wait-for-open-port.sh localhost 80
	# Export the site configuration.
	docker-compose exec drupal drush config:export
	# Need `default` folder to be writeable to copy it down to host.
	docker-compose exec drupal chmod 777 /var/www/drupal/web/sites/default
	docker cp $$(docker-compose ps -q drupal):/var/www/drupal/ codebase
	# Restore expected perms for `default`.
	docker-compose exec drupal chmod 555 /var/www/drupal/web/sites/default
	# Take down the services
	docker-compose down -v
	# Change ownership so the host user can work with the files.
	sudo chown -R $(shell id -u):101 $(CURDIR)/codebase
	# For newly added files/directories makesure they inherit the parent folders owner/group.
	find $(CURDIR)/codebase -type d -exec chmod u+s,g+s {} \;
	# Restore the docker-compose.yml file to what the user had before.
	$(MAKE) -B docker-compose.yml

# Helper function to generate keys for the user to use in their docker-compose.env.yml
.PHONY: generate-jwt-keys
.SILENT: generate-jwt-keys
generate-jwt-keys:
	docker run --rm -ti \
		--entrypoint bash \
		$(REPOSITORY)/drupal:$(TAG) -c \
		"openssl genrsa -out /tmp/private.key 2048 &> /dev/null; \
		openssl rsa -pubout -in /tmp/private.key -out /tmp/public.key &> /dev/null; \
		echo $$'\nPrivate Key:\n'; \
		cat /tmp/private.key; \
		echo $$'\nPublic Key:\n'; \
		cat /tmp/public.key; \
		echo $$'\nCopy and paste these keys into your docker-compose.env.yml file where appropriate.'"

# Helper to generate Matomo password, like so:
# make generate-matomo-password MATOMO_USER_PASS=my_new_password
.PHONY: generate-matomo-password
.SILENT: generate-matomo-password
generate-matomo-password:
ifndef MATOMO_USER_PASS
	$(error MATOMO_USER_PASS is not set)
endif
	docker run --rm -ti \
		--entrypoint php \
		$(REPOSITORY)/drupal:$(TAG) -r \
		'echo password_hash(md5("$(MATOMO_USER_PASS)"), PASSWORD_DEFAULT) . "\n";'

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

.PHONY: dev
.SILENT: dev
dev:
	$(MAKE) download-default-certs
	$(MAKE) create-codebase-from-demo
	if grep -q DRUPAL_DEFAULT_CONFIGDIR docker-compose.env.yml; then \
		perl -i -pe's/DRUPAL_DEFAULT_CONFIGDIR:.*/DRUPAL_DEFAULT_CONFIGDIR: \/var\/www\/drupal\/config\/sync/g'  docker-compose.env.yml; \
	else \
		perl -i -pe's/DRUPAL_DEFAULT_SALT/DRUPAL_DEFAULT_CONFIGDIR: \/var\/www\/drupal\/config\/sync\n\ \ \ \ \ \ DRUPAL_DEFAULT_SALT/g' docker-compose.env.yml; \
	fi
	if grep -q  DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG docker-compose.env.yml; then \
		perl -i -pe's/DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG:.*/DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG: "true"/g' docker-compose.env.yml; \
	else \
		perl -i -pe's/DRUPAL_DEFAULT_SALT/DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG: "true"\n\ \ \ \ \ \ DRUPAL_DEFAULT_SALT/g' docker-compose.env.yml; \
	fi
	if grep -q  DRUPAL_DEFAULT_PROFILE docker-compose.env.yml; then \
		perl -i -pe's/DRUPAL_DEFAULT_PROFILE:.*/DRUPAL_DEFAULT_PROFILE: minimal/g' docker-compose.env.yml; \
	else \
	  perl -i -pe's/DRUPAL_DEFAULT_SALT/DRUPAL_DEFAULT_PROFILE: minimal\n\ \ \ \ \ \ DRUPAL_DEFAULT_SALT/g' docker-compose.env.yml; \
	fi
	$(MAKE) -B docker-compose.yml ENVIRONMENT=local
	docker-compose up -d
	$(MAKE) remove_standard_profile_references_from_config
	$(MAKE) install ENVIRONMENT=local
	$(MAKE) hydrate ENVIRONMENT=local

# Destroys everything beware!
.PHONY: clean
.SILENT: clean
clean:
	-docker-compose down -v
	sudo rm -fr codebase certs
	git clean -xffd .
