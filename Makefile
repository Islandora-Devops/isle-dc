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
REQUIRED_SERIVCES ?= activemq alpaca blazegraph cantaloupe crayfish crayfits drupal mariadb matomo solr

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
SERVICES := $(REQUIRED_SERIVCES) $(FCREPO_SERVICE) $(WATCHTOWER_SERVICE) $(ETCD_SERVICE) $(DATABASE_SERVICES) $(ENVIRONMENT) $(TRAEFIK_SERVICE) $(SECRETS) $(CODE_SERVER_SERVICE)

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
.PHONY: set-files-owner
.SILENT: set-files-owner
set-files-owner: $(SRC)
ifndef SRC
	$(error SRC is not set)
endif
	sudo find $(SRC) -exec chown $(shell id -u):101 {} \;

# Creates required databases for drupal site(s) using environment variables.
.PHONY: drupal-database
.SILENT: drupal-database
drupal-database:
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
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_matomo_module"
	-docker-compose exec -T drupal with-contenv bash -lc "for_all_sites configure_openseadragon"

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

# Reconstitute the site from environment variables.
.PHONY: hydrate
.SILENT: hydrate
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

# Exports the sites configuration.
.PHONY: config-export
.SILENT: config-export
config-export:
	docker-compose exec -T drupal drush -l $(SITE) config:export -y

# Import the sites configuration.
# N.B You may need to run this multiple times in succession due to errors in the configurations dependencies.
.PHONY: config-import
.SILENT: config-import
config-import: set-site-uuid delete-shortcut-entities
	docker-compose exec -T drupal drush -l $(SITE) config:import -y

# Dump database.
drupal-database-dump: $(DEST)
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
	docker cp $(SRC) $$(docker-compose ps -q drupal):/tmp/dump.sql
	# Need to specify the root user to import the database otherwise it will fail due to permissions.
	docker-compose exec -T drupal with-contenv bash -lc 'chown root:root /tmp/dump.sql && mysql -u $${DRUPAL_DEFAULT_DB_ROOT_USER} -p$${DRUPAL_DEFAULT_DB_ROOT_PASSWORD} -h $${DRUPAL_DEFAULT_DB_HOST} $${DRUPAL_DEFAULT_DB_NAME} < /tmp/dump.sql'

drupal-public-files-dump: $(DEST)
ifndef DEST
	$(error DEST is not set)
endif
	docker-compose exec -T drupal with-contenv bash -lc 'tar zcvf /tmp/public-files.tgz /var/www/drupal/web/sites/default/files'
	docker cp $$(docker-compose ps -q drupal):/tmp/public-files.tgz $(DEST)

drupal-public-files-import: $(SRC)
ifndef SRC 
	$(error SRC is not set)
endif
	docker cp $(SRC) $$(docker-compose ps -q drupal):/tmp/public-files.tgz
	docker-compose exec -T drupal with-contenv bash -lc 'tar zxvf /tmp/public-files.tgz -C /var/www/drupal/web/sites/default/files && chown -R nginx:nginx /var/www/drupal/web/sites/default/files && rm /tmp/public-files.tgz'

# Dump fcrepo.
fcrepo-export: $(DEST)
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
	docker cp $(SRC) $$(docker-compose ps -q fcrepo):/tmp/fcrepo-export.tgz
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

.PHONY: demo
.SILENT: demo
demo:
	$(MAKE) download-default-certs ENVIROMENT=demo
	$(MAKE) -B docker-compose.yml ENVIROMENT=demo
	$(MAKE) pull ENVIROMENT=demo
	mkdir -p $(CURDIR)/codebase
	docker-compose up -d
	$(MAKE) update-settings-php ENVIROMENT=demo
	$(MAKE) drupal-public-files-import SRC=$(CURDIR)/demo-data/public-files.tgz ENVIROMENT=demo
	$(MAKE) drupal-database ENVIROMENT=demo
	$(MAKE) drupal-database-import SRC=$(CURDIR)/demo-data/drupal.sql ENVIROMENT=demo
	$(MAKE) hydrate ENVIROMENT=demo
	docker-compose exec -T drupal with-contenv bash -lc 'drush --root /var/www/drupal/web -l $${DRUPAL_DEFAULT_SITE_URL} upwd admin $${DRUPAL_DEFAULT_ACCOUNT_PASSWORD}'
	$(MAKE) fcrepo-import SRC=$(CURDIR)/demo-data/fcrepo-export.tgz ENVIROMENT=demo
	$(MAKE) reindex-fcrepo-metadata ENVIROMENT=demo
	$(MAKE) reindex-solr ENVIROMENT=demo
	$(MAKE) reindex-triplestore ENVIROMENT=demo
	

.PHONY: local
.SILENT: local
local:
	$(MAKE) download-default-certs ENVIROMENT=local
	$(MAKE) -B docker-compose.yml ENVIRONMENT=local
	$(MAKE) pull ENVIRONMENT=local
	mkdir -p $(CURDIR)/codebase
	if [ -z "$$(ls -A $(CURDIR)/codebase)" ]; then \
		docker container run --rm -v $(CURDIR)/codebase:/home/root $(REPOSITORY)/nginx:$(TAG) with-contenv bash -lc 'composer create-project drupal/recommended-project:^9.1 /tmp/codebase; mv /tmp/codebase/* /home/root; cd /home/root; composer config minimum-stability dev; composer require islandora/islandora:dev-8.x-1.x; composer require drush/drush:^10.3'; \
	fi
	docker-compose up -d
	docker-compose exec -T drupal with-contenv bash -lc 'composer install; chown -R nginx:nginx .'
	$(MAKE) remove_standard_profile_references_from_config ENVIROMENT=local
	$(MAKE) install ENVIRONMENT=local
	$(MAKE) hydrate ENVIRONMENT=local
	$(MAKE) set-files-owner SRC=$(CURDIR)/codebase ENVIROMENT=local

.PHONY: local-from-demo
.SILENT: local-from-demo
local-from-demo:
	$(MAKE) demo ENVIRONMENT=demo
	$(MAKE) extract-codebase
	$(MAKE) -B docker-compose.yml ENVIRONMENT=local
	docker-compose up -d

.PHONY: extract-codebase 
.SILENT: extract-codebase
extract-codebase:
	docker-compose exec drupal drush -y config:export
	# Need `default` folder to be writeable to copy it down to host.
	docker-compose exec drupal chmod 777 /var/www/drupal/web/sites/default
	sudo rm -rf codebase
	docker cp $$(docker-compose ps -q drupal):/var/www/drupal/ $(CURDIR)/codebase
	# Restore expected perms for `default`.
	docker-compose exec drupal chmod 555 /var/www/drupal/web/sites/default
	# Change ownership so the host user can work with the files.
	sudo chown -R $(shell id -u):101 $(CURDIR)/codebase
	# For newly added files/directories makesure they inherit the parent folders owner/group.
	find $(CURDIR)/codebase -type d -exec chmod u+s,g+s {} \;

# Destroys everything beware!
.PHONY: clean
.SILENT: clean
clean:
	-docker-compose down -v
	sudo rm -fr codebase certs
	git clean -xffd .
