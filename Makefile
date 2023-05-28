SHELL := bash

############################################################
## Create / include any necessary files and configuration ##
############################################################

# handle sed -i differences (see https://stackoverflow.com/a/4247319/3204023 for more context)
ifeq ($(shell uname -s),Darwin)
	SED_DASH_I=sed -i ''
else  # GNU/Linux
	SED_DASH_I=sed -i
endif


# If custom.makefile exists include it.
-include custom.Makefile

# Checks to see if the path includes a space character. Intended to be a temporary fix.
ifneq (1,$(words $(CURDIR)))
$(error Containing path cannot contain space characters: '$(CURDIR)')
endif

# Include the sample.env so new values can be added with defaults without requiring
# users to regenerate their .env files losing their changes.
include sample.env
-include .env

# The site to operate on when using drush -l $(SITE) commands
SITE?=default

# Make sure all docker-compose commands use the given project
# name by setting the appropriate environment variables.
export

#############################################
## Add necessary variables                 ##
#############################################

# Services that are not produced by isle-buildkit.
EXTERNAL_SERVICES := etcd watchtower traefik

# The minimal set of docker-compose files required to be able to run anything.
REQUIRED_SERVICES ?= activemq alpaca blazegraph cantaloupe crayfish crayfits drupal fcrepo mariadb matomo solr

# Check if we are requesting a target that doesn't match the current environment.
ENVIRONMENTS := demo local
$(foreach environment, $(ENVIRONMENTS), \
	$(if $(filter $(environment),$(MAKECMDGOALS)), \
	$(if $(filter-out $(environment),$(ENVIRONMENT)), \
		$(error "ENVIRONMENT in .env '$(ENVIRONMENT)' does not match the target '$(environment)'."))))

# Conditional targets shared by all environments (e.g. generate-secrets).
ENVIRONMENT_DEFAULT_TARGETS := \
	$(if $(filter true,$(USE_SECRETS)),generate-secrets) \
	$(if $(filter %.traefik.me,$(DOMAIN)),download-default-certs) \
	docker-compose.yml \
	codebase

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
	CODE_SERVER_SERVICE := code-server $(ENVIRONMENT).code-server
endif

# etcd is an optional dependency, by default it is not included.
ifeq ($(INCLUDE_ETCD_SERVICE), true)
	ETCD_SERVICE := etcd
endif

# Some services can optionally depend on PostgreSQL.
# Either way their environment variables get customized
# depending on the database service they have choosen.
DATABASE_SERVICES ?= drupal.$(DRUPAL_DATABASE_SERVICE) fcrepo.$(FCREPO_DATABASE_SERVICE)

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
SERVICES := $(REQUIRED_SERVICES) $(WATCHTOWER_SERVICE) $(ETCD_SERVICE) $(DATABASE_SERVICES) $(ENVIRONMENT) $(SECRETS) $(CODE_SERVER_SERVICE) $(TRAEFIK_SERVICE) $(ACME)

RESET=$(shell tput sgr0)
RED=$(shell tput setaf 9)
BLUE=$(shell tput setaf 6)
TARGET_MAX_CHAR_NUM=20

ROW_MESSAGE := ${RED}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${BLUE}%s${RESET}

IS_DRUPAL_PSSWD_FILE_READABLE := $(shell test -r secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD -a -w secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD && echo 1 || echo 0)
CMD := $(shell [ $(IS_DRUPAL_PSSWD_FILE_READABLE) -eq 1 ] && echo 'tee' || echo 'sudo -k tee')


#############################################
## Functions                               ##
#############################################

# Bash snippet to check for the existance an executable.
define wait-for-installation
	@printf "Waiting for installation...\n"
	@docker compose exec drupal timeout 600 bash -c "while ! test -f /installed; do sleep 5; done"
endef

# Bash snippet to check for the existance an executable.
define access-message
	@printf "  Credentials:\n"
	@printf "  $(ROW_MESSAGE)\n" "Username" "admin"
	@if [ "$(USE_SECRETS)" = "true" ]; then \
		PASSWORD=$$(cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD); \
		printf "  $(ROW_MESSAGE)\n" "Password" "$${PASSWORD}"; \
	else \
		printf "  $(ROW_MESSAGE)\n" "Password" "password"; \
	fi
	@printf "\n  Services Available:\n"
	@if [ "$(EXPOSE_DRUPAL)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Drupal" "https://$(DOMAIN)"; fi
	@if [ "$(EXPOSE_CODE_SERVER)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "IDE" "https://$(DOMAIN):$(CODE_SERVER_PORT)"; fi
	@if [ "$(EXPOSE_ACTIVEMQ)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "ActiveMQ" "http://$(DOMAIN):$(ACTIVEMQ_PORT)"; fi
	@if [ "$(EXPOSE_BLAZEGRAPH)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Blazegraph" "http://$(DOMAIN):$(BLAZEGRAPH_PORT)/bigdata"; fi
	@if [ "$(EXPOSE_FEDORA)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Fedora" "http://$(DOMAIN):$(FEDORA_PORT)/fcrepo/rest"; fi
	@if [ "$(EXPOSE_MATOMO)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Matomo" "https://$(DOMAIN)/matomo/index.php"; fi
	@if [ "$(EXPOSE_CANTALOUPE)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Cantaloupe" "https://$(DOMAIN)/cantaloupe"; fi
	@if [ "$(EXPOSE_SOLR)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Solr" "http://$(DOMAIN):$(SOLR_PORT)/solr/#/"; fi
	@if [ "$(EXPOSE_TRAEFIK_DASHBOARD)" = "true" ]; then printf "  $(ROW_MESSAGE)\n" "Traefik" "http://$(DOMAIN):$(TRAEFIK_DASHBOARD_PORT)"; fi
endef

#############################################
## Default Rule                            ##
#############################################
default: help .env

#############################################
## Actual Targets                          ##
#############################################
codebase:
	mkdir -p $(CURDIR)/codebase

.env:
	cp sample.env .env

# Although not actually phony we need to force it to run every time, as environment variables can change the output.
.PHONY: docker-compose.yml
# Create or regenrate docker-compose.yml based on variables in your .env
docker-compose.yml: $(SERVICES:%=build/docker-compose/docker-compose.%.yml) .env
	HOST_UID=$(shell id -u) docker-compose $(SERVICES:%=-f build/docker-compose/docker-compose.%.yml) config > docker-compose.yml

Dockerfile:
	cp sample.Dockerfile Dockerfile

build/custom:
	cp -r build/local build/custom

#############################################
## Rules for installing Islandora          ##
#############################################
.PHONY: demo
.SILENT: demo
## Make a demo site
demo: $(ENVIRONMENT_DEFAULT_TARGETS)
	docker-compose up -d --remove-orphans
	$(call wait-for-installation)
	$(call access-message)

.PHONY: local
.SILENT: local
## Make a site with codebase directory bind mounted, (using starter site if no codebase provided).
local: $(ENVIRONMENT_DEFAULT_TARGETS)
	if [ -z "$$(ls -A '$(CURDIR)/codebase')" ]; then \
		if [ "$(STARTER_DEV)" = "true" ]; then \
			git clone -b main https://github.com/Islandora/islandora-starter-site '$(CURDIR)/codebase'; \
		else \
			docker container run --rm \
				-v $(CURDIR):/work \
				-u $(shell id -u):101 \
				--entrypoint composer $(REPOSITORY)/nginx:$(TAG) \
				--no-cache create-project $(CODEBASE_PACKAGE) /work/codebase; \
		fi; \
		docker container run --rm \
			-v $(CURDIR)/codebase:/var/www/drupal \
			-v $(CURDIR)/build/local/rootfs/var/www/drupal/assets/patches/default_settings.txt:/var/www/drupal/assets/patches/default_settings.txt \
			--entrypoint composer $(REPOSITORY)/nginx:$(TAG) install -d /var/www/drupal \
	fi
	docker compose build drupal
	docker compose up -d --remove-orphans
	$(call wait-for-installation)
	$(call access-message)

#############################################
## Helper Rules for managing your install  ##
#############################################
.PHONY: help
.SILENT: help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${RED}make${RESET} ${BLUE}<function>${RESET}'
	@echo ''
	@echo 'Functions to build:'
	# @grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1 \2/'
	@awk '/^[a-zA-Z\-_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = $$1; sub(/:$$/, "", helpCommand); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			if (helpCommand == "up" || helpCommand == "local" || helpCommand == "demo") { \
				printf "  ${RED}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${BLUE}%s${RESET}\n", helpCommand, helpMessage; \
			} \
		} \
	} \
	{lastLine = $$0}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Other functions:'
	@awk '/^[a-zA-Z\-_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = $$1; sub(/:$$/, "", helpCommand); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			if (helpCommand != "up" && helpCommand != "local" && helpCommand != "demo") { \
				printf "  ${RED}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${BLUE}%s${RESET}\n", helpCommand, helpMessage ; \
			} \
		} \
	} \
	{lastLine = $$0}' $(MAKEFILE_LIST)
	@echo ''

.PHONY: pull
## Fetches the latest images from the registry.
pull: docker-compose.yml
	docker-compose pull --ignore-pull-failures

.PHONY: push
## Push images (See README.md for more information on pushing images)
push: docker-compose.yml
	docker compose push

.PHONY: build
## Build images (See README.md for more information on building images)
build: docker-compose.yml
	docker compose build


.PHONY: up
.SILENT: up
## Brings up the containers or builds $(ENVIRONMENT) if no containers were found.
ifeq ($(wildcard docker-compose.yml),)
up: $(ENVIRONMENT)
else
up: pull build docker-compose.yml
	docker-compose up -d --remove-orphans
	$(call wait-for-installation)
	$(call access-message)
endif

.PHONY: down
.SILENT: down
## Brings down the containers. Same as docker-compose down --remove-orphans
down:
	-docker-compose down --remove-orphans


.PHONY: env
.SILENT: env
## Pull in changes to the .env file.
env:
	if [ -f .env ]; then \
		$(MAKE) down ; \
		$(MAKE) -B docker-compose.yml ; \
		$(MAKE) pull ; \
		$(MAKE) up ; \
		echo -e '\n\n${BLUE}Fixing the error message: ${RESET} ${RED}In Filesystem.php line 203${RESET}\n\n' ; \
		docker-compose exec -T drupal with-contenv bash -lc "cp /var/www/drupal/web/sites/default/settings.php /var/www/drupal/web/sites/default/settings.php.bak" ; \
		docker-compose exec -T drupal with-contenv bash -lc "cp /var/www/drupal/web/sites/default/default.settings.php /var/www/drupal/web/sites/default/settings.php" ; \
		docker-compose exec -T drupal with-contenv bash -lc "chown nginx:nginx /var/www/drupal/web/sites/default/settings.php" ; \
		docker-compose exec -T drupal with-contenv bash -lc "chmod 644 /var/www/drupal/web/sites/default/settings.php" ; \
		$(MAKE) update-settings-php ; \
	fi
	if [ ! -f .env ]; then \
		echo "No .env file found." ; \
	fi


.PHONY: download-default-certs
## Helper function to generate keys for the user to use in their docker-compose.env.yml
.SILENT: download-default-certs
download-default-certs:
	mkdir -p certs
	if [ ! -f certs/cert.pem ]; then \
		curl http://traefik.me/fullchain.pem -o certs/cert.pem; \
	fi
	if [ ! -f certs/privkey.pem ]; then \
		curl http://traefik.me/privkey.pem -o certs/privkey.pem; \
	fi


# Run Composer Update in your Drupal container
composer_update:
	docker-compose exec -T drupal with-contenv bash -lc 'composer update'


reindex-fcrepo-metadata:
	# Re-index RDF in Fedora
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec non_fedora_files emit_file_event --configuration="queue=islandora-indexing-fcrepo-file-external&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-fcrepo-media&event=Update"'


# rebuild Solr search index for your repository
reindex-solr:
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-reindex'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-index'


# reindex RDF metadata from Drupal into Blazegraph
reindex-triplestore:
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'


.PHONY: set_admin_password
.SILENT: set_admin_password
## Sets the Drupal admin password and accomodates for permissions restrictions to the secrets directory. Only runs sudo when needed.
set_admin_password:
	$(eval PASSWORD ?= $(shell bash -c 'read -s -p "New Password: " pwd; echo $$pwd'))
	echo "\n\nSetting admin password now"
	docker-compose exec -T drupal with-contenv bash -lc 'drush user:password admin "$(PASSWORD)"'
	echo -n "$(PASSWORD)" > secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD
	echo "\ndone."


.PHONY: clean
.SILENT: clean
## Destroys everything beware!
clean:
	echo "**DANGER** About to rm your SERVER data subdirs, your docker volumes, codebase, islandora_workbench, certs, secrets, and all untracked/ignored files (including .env)."
	@echo -n "Are you sure you want to continue and drop your data? [y/N] " && read ans && [ $${ans:-N} = y ]
	-docker-compose down -v
	-chmod -R a+w codebase/web/sites/default
	git clean -xfd .

#############################################
## Rules for backing up and restoring      ##
#############################################

# Export Drupal database
drupal-database-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T drupal with-contenv bash -lc 'mysqldump -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} > /tmp/dump.sql'
	docker cp $$(docker-compose ps -q drupal):/tmp/dump.sql $(DEST)


# Import Drupal database.
drupal-database-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker-compose ps -q drupal):/tmp/dump.sql
  # Need to specify the root user to import the database otherwise it will fail due to permissions.
	docker-compose exec -T drupal with-contenv bash -lc 'chown root:root /tmp/dump.sql && mysql -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} < /tmp/dump.sql'
	docker-compose exec -T drupal with-contenv bash -lc 'drush cache-rebuild'


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


# dump Drupal's public files as zipped tarball
drupal-public-files-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T drupal with-contenv bash -lc 'tar zcvf /tmp/public-files.tgz /var/www/drupal/web/sites/default/files'
	docker cp $$(docker-compose ps -q drupal):/tmp/public-files.tgz $(DEST)


# import Drupal's public files from zipped tarball
drupal-public-files-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker-compose ps -q drupal):/tmp/public-files.tgz
	docker-compose exec -T drupal with-contenv bash -lc 'tar zxvf /tmp/public-files.tgz -C /var/www/drupal/web/sites/default/files && chown -R nginx:nginx /var/www/drupal/web/sites/default/files && rm /tmp/public-files.tgz'


# Dump fcrepo as zipped tarball
fcrepo-export:
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T fcrepo with-contenv bash -lc 'java -jar /opt/tomcat/fcrepo-import-export-1.0.1.jar --mode export -r http://$(DOMAIN):8081/fcrepo/rest -d /tmp/fcrepo-export -b -u $${FCREPO_TOMCAT_ADMIN_USER}:$${FCREPO_TOMCAT_ADMIN_PASSWORD}'
	docker-compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zcvf fcrepo-export.tgz fcrepo-export'
	docker cp $$(docker-compose ps -q fcrepo):/tmp/fcrepo-export.tgz $(DEST)


# Import fcrepo from zipped tarball
fcrepo-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	$(MAKE) -B docker-compose.yml DISABLE_SYN=true
	docker-compose up -d fcrepo
	docker cp "$(SRC)" $$(docker-compose ps -q fcrepo):/tmp/fcrepo-export.tgz
	docker-compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zxvf fcrepo-export.tgz && chown -R tomcat:tomcat fcrepo-export && rm fcrepo-export.tgz'
	docker-compose exec -T fcrepo with-contenv bash -lc 'java -jar fcrepo-upgrade-utils-6.0.0-beta-1.jar -i /tmp/fcrepo-export -o /data/home -s 5+ -t 6+ -u http://${DOMAIN}:8081/fcrepo/rest && chown -R tomcat:tomcat /data/home'
ifeq ($(FCREPO_DATABASE_SERVICE), postgresql)
	$(error Postgresql not implemented yet in fcrepo-import)
else
	docker-compose exec -T fcrepo with-contenv bash -lc 'mysql -u $${DB_ROOT_USER} -p$${DB_ROOT_PASSWORD} -h $${DB_MYSQL_HOST} -e "DROP DATABASE $${FCREPO_DB_NAME}"'
endif
	$(MAKE) -B docker-compose.yml
	docker-compose up -d fcrepo


##############################################
## Rules that are run by other Rules        ##
## You shouldn't need to run these directly ##
##############################################

.PHONY: generate-secrets
## Helper to generate secrets & passwords, like so: make generate-secrets
.SILENT: generate-secrets
generate-secrets:
ifeq ($(USE_SECRETS), false)
	docker run --rm -t \
		-v "$(CURDIR)/secrets":/secrets \
		-v "$(CURDIR)/build/scripts/generate-secrets.sh":/generate-secrets.sh \
		-w / \
		--entrypoint bash \
		$(REPOSITORY)/drupal:$(TAG) -c "/generate-secrets.sh && chown -R `id -u`:`id -g` /secrets"
else
	@echo "'Uses Secrets' is set to 'true'."
	$(MAKE) secrets_warning
endif


.PHONY: demo_content
#.SILENT: demo_content
## Helper function for demo sites: do a workbench import of sample objects
demo_content: QUOTED_CURDIR = "$(CURDIR)"
demo_content:
	# fetch repo that has csv and binaries to data/samples
	# if prod do this by default
	[ -d "islandora_workbench" ] || (git clone https://github.com/mjordan/islandora_workbench)
	cd islandora_workbench ; cd islandora_workbench_demo_content || git clone https://github.com/DonRichards/islandora_workbench_demo_content
	$(SED_DASH_I) 's#^host.*#host: $(SITE)/#g' islandora_workbench/islandora_workbench_demo_content/example_content.yml
	$(SED_DASH_I) 's/^password.*/password: "$(shell cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD | sed s#/#\\\\\\\\/#g)"/g' islandora_workbench/islandora_workbench_demo_content/example_content.yml
	cd islandora_workbench && docker build -t workbench-docker .
	cd islandora_workbench && docker run -it --rm --network="host" -v $(QUOTED_CURDIR)/islandora_workbench:/workbench --name my-running-workbench workbench-docker bash -lc "./workbench --config /workbench/islandora_workbench_demo_content/example_content.yml"
	$(MAKE) reindex-solr


.PHONY: set-files-owner
## Updates codebase folder to be owned by the host user and nginx group.
.SILENT: set-files-owner
set-files-owner: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	sudo chown -R $(shell id -u):101 $(SRC)


# RemovesForces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: remove_standard_profile_references_from_config
.SILENT: remove_standard_profile_references_from_config
remove_standard_profile_references_from_config:
	docker-compose exec -T drupal with-contenv bash -lc "remove_standard_profile_references_from_config"


.PHONY: drupal-database
## Creates required databases for drupal site(s) using environment variables.
.SILENT: drupal-database
drupal-database:
	docker-compose exec -T drupal timeout 300 bash -c "while ! test -e /var/run/nginx/nginx.pid -a -e /var/run/php-fpm7/php-fpm7.pid; do sleep 1; done"
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_database"


.PHONY: update-settings-php
## Updates settings.php according to the environment variables.
.SILENT: update-settings-php
update-settings-php:
	docker-compose exec -T drupal with-contenv bash -lc "if [ ! -f /var/www/drupal/web/sites/default/settings.php ]; then cp /var/www/drupal/web/sites/default/default.settings.php  /var/www/drupal/web/sites/default/settings.php; fi"
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites update_settings_php"
	# Make sure the host user can read the settings.php files after they have been updated.
	sudo find ./codebase -type f -name "settings.php" -exec chown $(shell id -u):101 {} \;


# Created by the standard profile, need to be deleted to import a site that was
# created with the standard profile.
.PHONY: delete-shortcut-entities
.SILENT: delete-shortcut-entities
delete-shortcut-entities:
	docker-compose exec -T drupal drush -l $(SITE) entity:delete shortcut_set


.PHONY: hydrate
.SILENT: hydrate
## Reconstitute the site from environment variables.
hydrate: update-settings-php update-config-from-environment solr-cores namespaces run-islandora-migrations
	docker-compose exec -T drupal drush cr -y


.PHONY: login
.SILENT: login
## Runs "drush uli" to provide a direct login link for user 1
login:
	echo "\n\n=========== LOGIN ==========="
	docker-compose exec -T drupal with-contenv bash -lc "drush uli --uri=$(DOMAIN)"
	echo "=============================\n"


.PHONY: install
## Installs drupal site(s) using environment variables.
.SILENT: install
install: drupal-database
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites install_site"


.PHONY: update-config-from-environment
## Updates configuration from environment variables.
## Allow all commands to fail as the user may not have all the modules like matomo, etc.
.SILENT: update-config-from-environment
update-config-from-environment:
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_jwt_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_search_api_solr_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_matomo_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_openseadragon"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"


.PHONY: run-islandora-migrations
## Runs migrations of islandora
.SILENT: run-islandora-migrations
run-islandora-migrations:
	#docker-compose exec -T drupal with-contenv bash -lc "for_all_sites import_islandora_migrations"
	# this line can be reverted when https://github.com/Islandora-Devops/isle-buildkit/blob/fae704f065435438828c568def2a0cc926cc4b6b/drupal/rootfs/etc/islandora/utilities.sh#L557
	# has been updated to match
	docker-compose exec -T drupal with-contenv bash -lc 'drush -l $(SITE) migrate:import $(MIGRATE_IMPORT_USER_OPTION) islandora_defaults_tags,islandora_tags'


.PHONY: solr-cores
## Creates solr-cores according to the environment variables.
.SILENT: solr-cores
solr-cores:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_solr_core_with_default_config"


.PHONY: namespaces
## Creates namespaces in Blazegraph according to the environment variables.
.SILENT: namespaces
namespaces:
	docker-compose exec -T drupal with-contenv bash -lc "for_all_sites create_blazegraph_namespace_with_default_properties"


# Forces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: set-site-uuid
.SILENT: set-site-uuid
set-site-uuid:
	docker-compose exec -T drupal with-contenv bash -lc "set_site_uuid"

.PHONY: secrets_warning
.SILENT: secrets_warning
## Check to see if the secrets directory contains default secrets.
secrets_warning:
	@echo 'Starting build/scripts/check-secrets.sh'
	@bash build/scripts/check-secrets.sh || (echo "check-secrets exited $$?"; exit 1)


##################################################
## Hot fixes. These are not meant to be run     ##
## normally but are meant to be run when needed ##
##################################################

.PHONY: fix_masonry
.SILENT: fix_masonry
## Fix missing masonry library.
fix_masonry: LATEST_VERSION := $(shell curl -s https://api.github.com/repos/desandro/masonry/releases/latest | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\1/')
fix_masonry:
	@echo "Latest version of masonry library is ${LATEST_VERSION}"
	docker-compose exec drupal bash -lc "[ -d '/var/www/drupal/web/libraries' ] && exit ; mkdir -p /var/www/drupal/web/libraries ; chmod 755 /var/www/drupal/web/libraries ; chown 1000:nginx /var/www/drupal/web/libraries"
	docker-compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ ! -d '/var/www/drupal/web/libraries/masonry' ] && git clone --quiet --branch ${LATEST_VERSION} https://github.com/desandro/masonry.git || echo Ready"
	docker-compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ -d '/var/www/drupal/web/libraries/masonry' ] && chmod -R 755 /var/www/drupal/web/libraries/masonry ; chown -R 1000:nginx /var/www/drupal/web/libraries/masonry"

.PHONY: fix_views
.SILENT: fix_views
## This fixes a know issues with views when using the make local build. The error must be triggered before this will work.
fix_views:
	docker cp scripts/patch_views.sh $$(docker ps --format "{{.Names}}" | grep drupal):/var/www/drupal/patch_views.sh
	docker-compose exec -T drupal with-contenv bash -lc "bash /var/www/drupal/patch_views.sh ; rm /var/www/drupal/patch_views.sh ; drush cr"
