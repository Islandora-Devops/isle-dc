############################################################
## Create / include any necessary files and configuration ##
############################################################

# Allows for customization of the behavior of the Makefile as well as Docker Compose.
# If it does not exist create it from sample.env.
ENV_FILE=$(shell \
	if [ ! -f .env ]; then \
		cp sample.env .env; \
	fi; \
	echo .env)

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
include $(ENV_FILE)
# The site to operate on when using drush -l $(SITE) commands
SITE?=default

# Make sure all docker compose commands use the given project
# name by setting the appropriate environment variables.
export

#############################################
## Add necessary variables                 ##
#############################################

PHP_MAJOR_VERSION?=8
PHP_MINOR_VERSION?=3

# Services that are not produced by isle-buildkit.
EXTERNAL_SERVICES := etcd watchtower traefik

# The minimal set of docker compose files required to be able to run anything.
REQUIRED_SERVICES ?= activemq alpaca blazegraph cantaloupe crayfish crayfits drupal mariadb solr

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

RESET=$(shell tput sgr0)
RED=$(shell tput setaf 9)
BLUE=$(shell tput setaf 6)
TARGET_MAX_CHAR_NUM=20

IS_DRUPAL_PSSWD_FILE_READABLE := $(shell test -r secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD -a -w secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD && echo 1 || echo 0)
CMD := $(shell [ $(IS_DRUPAL_PSSWD_FILE_READABLE) -eq 1 ] && echo 'tee' || echo 'sudo -k tee')

LATEST_VERSION := $(shell curl -s https://api.github.com/repos/desandro/masonry/releases/latest | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\1/')

PHP_FPM_PID=/var/run/php-fpm7/php-fpm7.pid
ifeq ($(shell expr $(TAG) \>= 3.2), 1)
	PHP_FPM_PID=/var/run/php-fpm83/php-fpm83.pid
else ifeq ($(shell expr $(TAG) \>= 3.0), 1)
	PHP_FPM_PID=/var/run/php-fpm82/php-fpm82.pid
else ifeq ($(shell expr $(TAG) \>= 2.0), 1)
	PHP_FPM_PID=/var/run/php-fpm81/php-fpm81.pid
endif

#############################################
## Default Rule                            ##
#############################################

default: download-default-certs docker-compose.yml pull


#############################################
## Rules for installing Islandora          ##
#############################################

.PHONY: demo
.SILENT: demo
demo:
	echo "make demo has been removed. To create a demo site, please follow the instructions at https://islandora.github.io/documentation/installation/docker-local/"


.PHONY: local
.SILENT: local
local:
	echo "make local has been removed. To create a development site, please follow the instructions at https://islandora.github.io/documentation/installation/docker-local/"


.PHONY: starter
## Make a local site with codebase directory bind mounted, using starter site unless other package specified in .env or present already.
starter: QUOTED_CURDIR = "$(CURDIR)"
starter: generate-secrets
	$(MAKE) starter-init ENVIRONMENT=starter
	if [ -z "$$(ls -A $(QUOTED_CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'composer create-project $(CODEBASE_PACKAGE) /tmp/codebase; mv /tmp/codebase/* /home/root;'; \
	else \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'cd /home/root; composer install'; \
	fi
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIRONMENT=starter
	$(MAKE) compose-up
	$(MAKE) starter-finalize ENVIRONMENT=starter


.PHONY: starter_dev
## Make a local site with codebase directory bind mounted, using cloned starter site.
starter_dev: QUOTED_CURDIR = "$(CURDIR)"
starter_dev: generate-secrets
	$(MAKE) starter-init ENVIRONMENT=starter_dev
	if [ -z "$$(ls -A $(QUOTED_CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'git clone -b main https://github.com/Islandora-Devops/islandora-starter-site /home/root;'; \
	fi
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIRONMENT=starter_dev
	$(MAKE) compose-up
	docker compose exec -T drupal with-contenv bash -lc 'chown -R nginx:nginx /var/www/drupal/ ; su nginx -s /bin/bash -c "composer install"'
	$(MAKE) starter-finalize ENVIRONMENT=starter_dev


.PHONY: production
production: init
	$(MAKE) compose-up
	docker compose exec -T drupal with-contenv bash -lc 'composer install; chown -R nginx:nginx .'
	$(MAKE) starter-finalize ENVIRONMENT=starter


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
			if (helpCommand == "up") { \
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
			if (helpCommand != "up") { \
				printf "  ${RED}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${BLUE}%s${RESET}\n", helpCommand, helpMessage ; \
			} \
		} \
	} \
	{lastLine = $$0}' $(MAKEFILE_LIST)
	@echo ''


.PHONY: pull
## Fetches the latest images from the registry.
pull: docker-compose.yml
	docker compose pull


.PHONY: build
## Create Dockerfile from example if it does not exist.
build:
	if [ ! -f $(PROJECT_DRUPAL_DOCKERFILE) ]; then \
		cp "$(CURDIR)/sample.Dockerfile" $(PROJECT_DRUPAL_DOCKERFILE); \
	fi
	docker build -f $(PROJECT_DRUPAL_DOCKERFILE) -t $(CUSTOM_IMAGE_NAMESPACE)/$(CUSTOM_IMAGE_NAME):${CUSTOM_IMAGE_TAG} --build-arg REPOSITORY=$(REPOSITORY) --build-arg TAG=$(TAG) --platform linux/amd64 .


.PHONY: push-image
## Push your custom drupal image to dockerhub or a container registry
push-image:
	docker push "$(CUSTOM_IMAGE_NAMESPACE)/$(CUSTOM_IMAGE_NAME):${CUSTOM_IMAGE_TAG}"


.SILENT: docker-compose.yml
# Create or regenrate docker-compose.yml based on variables in your .env
docker-compose.yml: $(SERVICES:%=build/docker-compose/docker-compose.%.yml) .env
	docker compose $(SERVICES:%=-f build/docker-compose/docker-compose.%.yml) config > docker-compose.yml


.PHONY: up
.SILENT: up
## Brings up the containers or builds starter if no containers were found.
up:
	test -f docker-compose.yml && docker compose up -d --remove-orphans || $(MAKE) starter
	@echo "\n Sleeping for 10 seconds to wait for Drupal to finish building.\n"
	sleep 10
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites update_settings_php"
	$(MAKE) secrets_warning


.PHONY: down
.SILENT: down
## Brings down the containers. Same as docker compose down --remove-orphans
down:
	-docker compose down --remove-orphans


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
		docker compose exec -T drupal with-contenv bash -lc "cp /var/www/drupal/web/sites/default/settings.php /var/www/drupal/web/sites/default/settings.php.bak" ; \
		docker compose exec -T drupal with-contenv bash -lc "cp /var/www/drupal/web/sites/default/default.settings.php /var/www/drupal/web/sites/default/settings.php" ; \
		docker compose exec -T drupal with-contenv bash -lc "chown nginx:nginx /var/www/drupal/web/sites/default/settings.php" ; \
		docker compose exec -T drupal with-contenv bash -lc "chmod 644 /var/www/drupal/web/sites/default/settings.php" ; \
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
	docker compose exec -T drupal with-contenv bash -lc su nginx -s /bin/bash -c "composer update"


reindex-fcrepo-metadata:
	# Re-index RDF in Fedora
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec non_fedora_files emit_file_event --configuration="queue=islandora-indexing-fcrepo-file-external&event=Update"'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-fcrepo-content&event=Update"'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-fcrepo-media&event=Update"'


# rebuild Solr search index for your repository
reindex-solr:
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-reindex'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} search-api-index'


# reindex RDF metadata from Drupal into Blazegraph
reindex-triplestore:
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec all_taxonomy_terms emit_term_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec content emit_node_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'
	docker compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} vbo-exec media emit_media_event --configuration="queue=islandora-indexing-triplestore-index&event=Update"'


.PHONY: set_admin_password
.SILENT: set_admin_password
## Sets the Drupal admin password and accomodates for permissions restrictions to the secrets directory. Only runs sudo when needed.
set_admin_password:
	@$(eval PASSWORD ?= $(shell bash -c 'read -s -p "New Password: " pwd; echo $$pwd'))
	@echo "\n\nSetting admin password now"
	docker compose exec -T drupal with-contenv bash -lc 'drush user:password admin "$(PASSWORD)"'
	echo "$(PASSWORD)" | $(CMD) secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD >> /dev/null
	@echo "\ndone."


.PHONY: clean
.SILENT: clean
## Destroys everything beware!
clean:
	echo "**DANGER** About to rm your SERVER data subdirs, your docker volumes, codebase, islandora_workbench, certs, secrets, and all untracked/ignored files (including .env)."
	$(MAKE) confirm
	-docker compose down -v
	sudo rm -fr codebase islandora_workbench certs secrets/live/*
	git clean -xffd .

#############################################
## Rules for backing up and restoring      ##
#############################################

# Export Drupal database
drupal-database-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker compose exec -T drupal with-contenv bash -lc 'mysqldump -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} > /tmp/dump.sql'
	docker cp $$(docker compose ps -q drupal):/tmp/dump.sql $(DEST)


# Import Drupal database.
drupal-database-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker compose ps -q drupal):/tmp/dump.sql
	# Need to specify the root user to import the database otherwise it will fail due to permissions.
	docker compose exec -T drupal with-contenv bash -lc 'chown root:root /tmp/dump.sql && mysql -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} < /tmp/dump.sql'
	docker compose exec -T drupal with-contenv bash -lc 'drush cache-rebuild'


.PHONY: config-export
.SILENT: config-export
## Exports the sites configuration.
config-export:
	docker compose exec -T drupal drush -l $(SITE) config:export -y


.PHONY: config-import
.SILENT: config-import
## Import the sites configuration. N.B You may need to run this multiple times in succession due to errors in the configurations dependencies.
config-import: set-site-uuid delete-shortcut-entities
	docker compose exec -T drupal drush -l $(SITE) config:import -y


# dump Drupal's public files as zipped tarball
drupal-public-files-dump:
ifndef DEST
	$(error DEST is not set)
endif
	docker compose exec -T drupal with-contenv bash -lc 'tar zcvf /tmp/public-files.tgz -C /var/www/drupal/web/sites/default/files ${PUBLIC_FILES_TAR_DUMP_PATH}'
	docker cp $$(docker compose ps -q drupal):/tmp/public-files.tgz $(DEST)


# import Drupal's public files from zipped tarball
drupal-public-files-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker compose ps -q drupal):/tmp/public-files.tgz
	docker compose exec -T drupal with-contenv bash -lc 'tar zxvf /tmp/public-files.tgz -C /var/www/drupal/web/sites/default/files && chown -R nginx:nginx /var/www/drupal/web/sites/default/files && rm /tmp/public-files.tgz'


# Dump fcrepo as zipped tarball
fcrepo-export:
ifndef DEST
	$(error DEST is not set)
endif
	docker compose exec -T fcrepo with-contenv bash -lc 'tar zcvf fcrepo-export.tgz -C /data/home/data/ocfl-root/ .'
	docker compose exec -T fcrepo with-contenv bash -lc 'mv fcrepo-export.tgz /tmp'
	docker cp $$(docker compose ps -q fcrepo):/tmp/fcrepo-export.tgz $(DEST)


# Import fcrepo from zipped tarball
fcrepo-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	docker cp "$(SRC)" $$(docker compose ps -q fcrepo):/tmp/fcrepo-export.tgz
	docker compose exec -T fcrepo with-contenv bash -lc 'rm -r /data/home/data/ocfl-root/*'
	docker compose exec -T fcrepo with-contenv bash -lc 'tar zxvf /tmp/fcrepo-export.tgz -C /data/home/data/ocfl-root/ && chown -R tomcat:tomcat /data/home/data/ocfl-root/ && rm /tmp/fcrepo-export.tgz'
	docker compose exec -T mariadb with-contenv bash -lc 'mysql -e "drop database fcrepo;"'
	docker compose restart fcrepo


# Dump fcrepo as zipped tarball
fcrepo5-export:
ifndef DEST
	$(error DEST is not set)
endif
	docker compose exec -T fcrepo with-contenv bash -lc 'java -jar /opt/tomcat/fcrepo-import-export-1.0.1.jar --mode export -r http://$(DOMAIN):8081/fcrepo/rest -d /tmp/fcrepo-export -b -u $${FCREPO_TOMCAT_ADMIN_USER}:$${FCREPO_TOMCAT_ADMIN_PASSWORD}'
	docker compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zcvf fcrepo-export.tgz fcrepo-export'
	docker cp $$(docker compose ps -q fcrepo):/tmp/fcrepo-export.tgz $(DEST)


# Import fcrepo from zipped tarball
fcrepo5-import: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	$(MAKE) -B docker-compose.yml DISABLE_SYN=true
	docker compose up -d fcrepo
	docker cp "$(SRC)" $$(docker compose ps -q fcrepo):/tmp/fcrepo-export.tgz
	docker compose exec -T fcrepo with-contenv bash -lc 'cd /tmp && tar zxvf fcrepo-export.tgz && chown -R tomcat:tomcat fcrepo-export && rm fcrepo-export.tgz'
ifeq ($(FEDORA_6), true)
	docker compose exec -T fcrepo with-contenv bash -lc 'java -jar fcrepo-upgrade-utils-6.0.0-beta-1.jar -i /tmp/fcrepo-export -o /data/home -s 5+ -t 6+ -u http://${DOMAIN}:8081/fcrepo/rest && chown -R tomcat:tomcat /data/home'
ifeq ($(FCREPO_DATABASE_SERVICE), postgresql)
	$(error Postgresql not implemented yet in fcrepo-import)
else
	docker compose exec -T fcrepo with-contenv bash -lc 'mysql -u $${DB_ROOT_USER} -p$${DB_ROOT_PASSWORD} -h $${DB_MYSQL_HOST} -e "DROP DATABASE $${FCREPO_DB_NAME}"'
endif
else
	docker compose exec -T fcrepo with-contenv bash -lc 'java -jar /opt/tomcat/fcrepo-import-export-1.0.1.jar --mode import -r http://$(DOMAIN):8081/fcrepo/rest --map http://islandora.traefik.me:8081/fcrepo/rest,http://$(DOMAIN):8081/fcrepo/rest -d /tmp/fcrepo-export -b -u $${TOMCAT_ADMIN_NAME}:$${TOMCAT_ADMIN_PASSWORD}'
endif
	$(MAKE) -B docker-compose.yml
	docker compose up -d fcrepo


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
	@echo "Changing ownership of $(SRC) to $(shell id -u):101"
	@if sudo chown -R $(shell id -u):101 $(SRC); then \
		echo "Ownership changed successfully."; \
	else \
		echo "Error: Failed to change ownership."; \
	fi


# RemovesForces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: remove_standard_profile_references_from_config
.SILENT: remove_standard_profile_references_from_config
remove_standard_profile_references_from_config:
	docker compose exec -T drupal with-contenv bash -lc "remove_standard_profile_references_from_config"


.PHONY: drupal-database
## Creates required databases for drupal site(s) using environment variables.
.SILENT: drupal-database
drupal-database:
	docker compose exec -T drupal timeout 300 bash -c "while ! test -e /var/run/nginx/nginx.pid -a -e $(PHP_FPM_PID); do echo 'Waiting for nginx and php-fpm'; sleep 1; done"
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites create_database"


.PHONY: update-settings-php
## Updates settings.php according to the environment variables.
.SILENT: update-settings-php
update-settings-php:
	docker compose exec -T drupal with-contenv bash -lc "if [ ! -f /var/www/drupal/web/sites/default/settings.php ]; then cp /var/www/drupal/web/sites/default/default.settings.php  /var/www/drupal/web/sites/default/settings.php; fi"
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites update_settings_php"
	# Make sure the host user can read the settings.php files after they have been updated.
	if [ -d ./codebase ]; then sudo find ./codebase -type f -name "settings.php" -exec chown $(shell id -u):101 {} \;; fi


# Created by the standard profile, need to be deleted to import a site that was
# created with the standard profile.
.PHONY: delete-shortcut-entities
.SILENT: delete-shortcut-entities
delete-shortcut-entities:
	docker compose exec -T drupal drush -l $(SITE) entity:delete shortcut_set


.PHONY: hydrate
.SILENT: hydrate
## Reconstitute the site from environment variables.
hydrate: update-settings-php update-config-from-environment solr-cores namespaces run-islandora-migrations
	docker compose exec -T drupal drush cr -y


.PHONY: login
.SILENT: login
## Runs "drush uli" to provide a direct login link for user 1
login:
	echo "\n\n=========== LOGIN ==========="
	docker compose exec -T drupal with-contenv bash -lc "drush uli --uri=$(DOMAIN)"
	echo "=============================\n"

.PHONY: init
init: generate-secrets
	$(MAKE) download-default-certs
	$(MAKE) -B docker-compose.yml
	$(MAKE) pull

.PHONY: starter-init
starter-init: init
	mkdir -p $(CURDIR)/codebase

.PHONY: starter-finalize
starter-finalize:
	docker compose exec -T drupal with-contenv bash -lc 'chown -R nginx:nginx . ; echo "Chown Complete"'
	$(MAKE) drupal-database update-settings-php
	docker compose exec -T drupal with-contenv bash -lc "drush si -y --existing-config minimal --account-pass '$(shell cat secrets/live/DRUPAL_DEFAULT_ACCOUNT_PASSWORD)'"
	docker compose exec -T drupal with-contenv bash -lc "drush cr"
	docker compose exec -T drupal with-contenv bash -lc "drush -l $(SITE) user:role:add fedoraadmin admin"
	@echo "Checking if Solr's healthy"
	docker compose exec -T solr bash -c 'curl -s http://localhost:8983/solr/admin/info/system?wt=json' | jq -r .lucene || (echo "Solr is not healthy, waiting 10 seconds." && sleep 10)
	MIGRATE_IMPORT_USER_OPTION=--userid=1 $(MAKE) hydrate
	docker compose exec -T drupal with-contenv bash -lc 'drush -l $(SITE) migrate:import --userid=1 --tag=islandora'
	$(MAKE) login
	$(MAKE) wait-for-drupal-locally

.PHONY: install
## Installs drupal site(s) using environment variables.
.SILENT: install
install: drupal-database
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites install_site"


.PHONY: update-config-from-environment
## Updates configuration from environment variables.
## Allow all commands to fail as the user may not have all the modules.
.SILENT: update-config-from-environment
update-config-from-environment:
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_jwt_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_search_api_solr_module"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_openseadragon"
	-docker compose exec -T drupal with-contenv bash -lc "for_all_sites configure_islandora_default_module"


.PHONY: run-islandora-migrations
## Runs migrations of islandora
.SILENT: run-islandora-migrations
run-islandora-migrations:
	#docker compose exec -T drupal with-contenv bash -lc "for_all_sites import_islandora_migrations"
	# this line can be reverted when https://github.com/Islandora-Devops/isle-buildkit/blob/fae704f065435438828c568def2a0cc926cc4b6b/drupal/rootfs/etc/islandora/utilities.sh#L557
	# has been updated to match
	docker compose exec -T drupal with-contenv bash -lc 'drush -l $(SITE) migrate:import $(MIGRATE_IMPORT_USER_OPTION) islandora_defaults_tags,islandora_tags'


.PHONY: solr-cores
## Creates solr-cores according to the environment variables.
.SILENT: solr-cores
solr-cores:
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites create_solr_core_with_default_config"


.PHONY: namespaces
## Creates namespaces in Blazegraph according to the environment variables.
.SILENT: namespaces
namespaces:
	docker compose exec -T drupal with-contenv bash -lc "for_all_sites create_blazegraph_namespace_with_default_properties"


# Forces the site uuid to match that in the config_sync_directory so that
# configuration can be imported.
.PHONY: set-site-uuid
.SILENT: set-site-uuid
set-site-uuid:
	docker compose exec -T drupal with-contenv bash -lc "set_site_uuid"


.phony: confirm
confirm:
	@echo -n "Are you sure you want to continue and drop your data? [y/N] " && read ans && [ $${ans:-N} = y ]


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
fix_masonry:
	@echo "Latest version of masonry library is ${LATEST_VERSION}"
	docker compose exec drupal bash -lc "[ -d '/var/www/drupal/web/libraries' ] && exit ; mkdir -p /var/www/drupal/web/libraries ; chmod 755 /var/www/drupal/web/libraries ; chown 1000:nginx /var/www/drupal/web/libraries"
	docker compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ ! -d '/var/www/drupal/web/libraries/masonry' ] && git clone --quiet --branch ${LATEST_VERSION} https://github.com/desandro/masonry.git || echo Ready"
	docker compose exec drupal bash -lc "cd /var/www/drupal/web/libraries/ ; [ -d '/var/www/drupal/web/libraries/masonry' ] && chmod -R 755 /var/www/drupal/web/libraries/masonry ; chown -R 1000:nginx /var/www/drupal/web/libraries/masonry"

.PHONY: fix_views
.SILENT: fix_views
## This fixes a know issues with views when using the make local build. The error must be triggered before this will work.
fix_views:
	docker cp scripts/patch_views.sh $$(docker ps --format "{{.Names}}" | grep drupal):/var/www/drupal/patch_views.sh
	docker compose exec -T drupal with-contenv bash -lc "bash /var/www/drupal/patch_views.sh ; rm /var/www/drupal/patch_views.sh ; drush cr"

.PHONY: compose-up
.SILENT: compose-up
compose-up:
	docker compose up -d --remove-orphans
	while ! docker compose exec -T drupal with-contenv bash -lc 'test -d /var/www/drupal'; do \
		echo "Waiting for /var/www/drupal directory to be available..."; \
		sleep 1; \
	done

.PHONY: wait-for-drupal-locally
.SILENT: wait-for-drupal-locally
wait-for-drupal-locally:
	while ! curl -s -o /dev/null -m 5 https://$(DOMAIN)/ ; do \
		echo "Waiting for https://$(DOMAIN) to be available..."; \
		sleep 1; \
	done

.PHONY: xdebug
## Turn on xdebug.
xdebug: TIMEOUT_VALUE=3600
xdebug:

	$(MAKE) set-timeout TIMEOUT_VALUE=3600
	sleep 10
	docker compose exec -T drupal with-contenv bash -lc "apk add php${PHP_MAJOR_VERSION}${PHP_MINOR_VERSION}-pecl-xdebug"
	docker cp scripts/extra/xdebug.ini $$(docker compose ps -q drupal):/etc/php${PHP_MAJOR_VERSION}${PHP_MINOR_VERSION}/conf.d/xdebug.ini
	-docker compose exec -T drupal with-contenv bash -lc "chown root:root /etc/php${PHP_MAJOR_VERSION}${PHP_MINOR_VERSION}/conf.d/xdebug.ini"
	$(XDEBUG_HOST_COMMAND)

	docker compose restart drupal
	sleep 6
	docker compose exec -T drupal with-contenv bash -lc "php -i | grep xdebug"

.phony: set-timeout
## Update all PHP and NGinx timeouts to TIMEOUT_VALUE
set-timeout:
	$(SED_DASH_I) 's/NGINX_FASTCGI_READ_TIMEOUT: .*s/NGINX_FASTCGI_READ_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_FASTCGI_CONNECT_TIMEOUT: .*s/NGINX_FASTCGI_CONNECT_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_FASTCGI_SEND_TIMEOUT: .*s/NGINX_FASTCGI_SEND_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_KEEPALIVE_TIMEOUT: .*s/NGINX_KEEPALIVE_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_PROXY_CONNECT_TIMEOUT: .*s/NGINX_PROXY_CONNECT_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_PROXY_READ_TIMEOUT: .*s/NGINX_PROXY_READ_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_PROXY_SEND_TIMEOUT: .*s/NGINX_PROXY_SEND_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/NGINX_SEND_TIMEOUT: .*s/NGINX_SEND_TIMEOUT: $(TIMEOUT_VALUE)s/g' docker-compose.yml
	$(SED_DASH_I) 's/PHP_DEFAULT_SOCKET_TIMEOUT: ".*"/PHP_DEFAULT_SOCKET_TIMEOUT: "$(TIMEOUT_VALUE)"/g' docker-compose.yml
	$(SED_DASH_I) 's/PHP_MAX_EXECUTION_TIME: ".*"/PHP_MAX_EXECUTION_TIME: "$(TIMEOUT_VALUE)"/g' docker-compose.yml
	$(SED_DASH_I) 's/PHP_MAX_INPUT_TIME: ".*"/PHP_MAX_INPUT_TIME: "$(TIMEOUT_VALUE)"/g' docker-compose.yml
	$(SED_DASH_I) 's/PHP_PROCESS_CONTROL_TIMEOUT: ".*"/PHP_PROCESS_CONTROL_TIMEOUT: "$(TIMEOUT_VALUE)"/g' docker-compose.yml
	$(SED_DASH_I) 's/PHP_REQUEST_TERMINATE_TIMEOUT: ".*"/PHP_REQUEST_TERMINATE_TIMEOUT: "$(TIMEOUT_VALUE)"/g' docker-compose.yml
	docker compose up -d --force-recreate --remove-orphans
