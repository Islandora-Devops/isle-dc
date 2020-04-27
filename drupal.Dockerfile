ARG build_environment=prod
ARG code_dir=./codebase
ARG base_image_tag=7.2.28-1.17.8-0ceedc1b
ARG composer_version=1.9.3

#
# Stage 1: PHP Dependencies
#
# @TODO handle scafolded files
FROM composer:${composer_version} as composer-build
ARG code_dir
ARG build_environment
ENV COMPOSER_INSTALL_FLAGS \
  --ansi \
  --no-suggest \
  --prefer-dist \
  --no-interaction \
  --ignore-platform-reqs

ENV DRUPAL_COMPOSER_DIRECTORIES \
  web/core \
  web/modules/contrib \
  web/profiles/contrib \
  web/themes/contrib \
  web/libraries \
  drush/contrib

WORKDIR /root/.ssh
RUN chmod 0600 /root/.ssh \
  && ssh-keyscan -t rsa bitbucket.org >> known_hosts \
  && ssh-keyscan -t rsa github.com >> known_hosts \
  # To speed up download.
  && composer global require hirak/prestissimo "${COMPOSER_INSTALL_FLAGS}"

WORKDIR /app

COPY ${code_dir}/composer.json ${code_dir}/composer.lock ./
# This only work when the codebase is islandora. It should probably be commented out if installing
# the drupal/recommended-project.
COPY ${code_dir}/scripts/composer/ScriptHandler.php ./scripts/composer/ScriptHandler.php

RUN set -eux; \
  flags="${COMPOSER_INSTALL_FLAGS}"; \
  if [ "$build_environment" == "prod" ]; then \
  flags="${COMPOSER_INSTALL_FLAGS} --no-dev"; \
  fi; \
  composer install $flags \
  # make dummy directory just in case no drupal contrib related dependencies was created.
  && for dir in $DRUPAL_COMPOSER_DIRECTORIES; do \
  if [ ! -d $dir ]; then \
  mkdir -p $dir; \
  fi; \
  done;

#
# Stage 2: Any node related dependencies can be build here. e.g. compile scss to css
#

#
# Stage 3: The base app/drupal
#
FROM registry.gitlab.com/nikathone/drupal-docker-good-defaults/php-nginx:${base_image_tag} as base
ARG code_dir
ARG app_runner_user=drupal
ARG app_runner_user_id=1000
ARG app_runner_group=drupal
ARG app_runner_group_id=1000
ARG NGINX_LISTEN_PORT=8080
ARG NGINX_SERVER_ROOT

ENV PATH=${PATH}:${APP_ROOT}/vendor/bin \
  PHP_EXPOSE_PHP=Off \
  PHP_FPM_USER=${app_runner_user} \
  PHP_FPM_GROUP=${app_runner_group} \
  NGINX_LISTEN_PORT=${NGINX_LISTEN_PORT} \
  DEFAULT_USER=${app_runner_user} \
  APP_NAME=drupal \
  AUTO_INSTALL=${AUTO_INSTALL:-false} \
  APP_RUNNER_USER=${app_runner_user} \
  APP_RUNNER_USER_ID=${app_runner_user_id:-1000} \
  APP_RUNNER_GROUP=${app_runner_group} \
  APP_RUNNER_GROUP_ID=${app_runner_group_id:-1000}

# Copy custom configuration template files for PHP and NGINX
RUN mkdir -p /etc/confd && cp -R /confd_templates/* /etc/confd/; \
  # Copy custom excutable scripts for drupal including the default entrypoint.
  mv /drupal/bin/* /usr/local/bin/; \
  # Make sure docker-webserver-entrypoint and other scripts are executable
  chmod -R +x /usr/local/bin/; \
  # apply custom configurations based on confd templates
  /usr/local/bin/confd -onetime -backend env \
  # clean the content of confd so that the app can add it's templates later in the process
  && rm -rf /etc/confd/* \
  # Move the .env template file for the drupal app. We then run confd in the docker
  # entrypoint to place it under <codebase>/.env.
  && cp -R /drupal/confd/* /etc/confd/ && rm -rf /drupal/confd

# Add and configure app runner user
RUN set -xe; \
  # Delete existing user/group if uid/gid occupied.
  existing_group=$(getent group "${APP_RUNNER_GROUP_ID}" | cut -d: -f1); \
  if [ -n "${existing_group}" ]; then delgroup "${existing_group}"; fi; \
  existing_user=$(getent passwd "${APP_RUNNER_USER_ID}" | cut -d: -f1); \
  if [ -n "${existing_user}" ]; then deluser "${existing_user}"; fi; \
  \
  # Ensure app runner user/group exists
  addgroup --system --gid ${APP_RUNNER_GROUP_ID} ${APP_RUNNER_GROUP}; \
  adduser --system --disabled-password --ingroup ${APP_RUNNER_GROUP} --shell /bin/bash --uid ${APP_RUNNER_USER_ID} ${APP_RUNNER_USER}; \
  usermod --append --groups ${NGINX_USER_GROUP} ${APP_RUNNER_USER} \
  # Other app runner user related configurations. See bin/config_app_runner_user
  && config_app_runner_user \
  \
  # Make sure that files dir have proper permissions.
  && mkdir -p ${FILES_DIR}/public; \
  mkdir -p ${FILES_DIR}/private; \
  # Ensure the files dir is owned by nginx user
  chown -R ${NGINX_USER}:${NGINX_USER_GROUP} ${FILES_DIR}

EXPOSE $NGINX_LISTEN_PORT
ENTRYPOINT [ "docker-webserver-entrypoint" ]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

WORKDIR ${APP_ROOT}

# Copy entire code files. The .dockerignore file ensures that ignored paths are
# not copied from the host machine into the image.
COPY --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} ${code_dir} ./
# Copy code and composer generated files and directories
# @TODO Copy scalfolded files.
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/vendor ./vendor
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/web/core ./web/core
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/web/modules/contrib ./web/modules/contrib
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/web/themes/contrib ./web/themes/contrib
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/web/profiles/contrib ./web/profiles/contrib
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/web/libraries ./web/libraries
COPY --from=composer-build --chown=${APP_RUNNER_USER}:${APP_RUNNER_GROUP} /app/drush/contrib ./drush/contrib
# If stage 2 available and generated js and css artifacts files, they can also be copied inside this folder.

WORKDIR ${APP_DOCROOT}
#
# Stage 4: The production setup
#
FROM base AS prod
ENV APP_ENV=prod

# Using the production php.ini
RUN mv ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini; \
  # Remove the confd templates altogether.
  rm -rf /confd_templates

USER ${APP_RUNNER_USER}

#
# Stage 5: The dev setup
#
FROM base AS dev
ARG composer_version
ARG PHP_XDEBUG
ARG PHP_XDEBUG_DEFAULT_ENABLE
ARG PHP_XDEBUG_REMOTE_CONNECT_BACK
ARG PHP_XDEBUG_REMOTE_HOST
ARG PHP_IDE_CONFIG

ENV APP_ENV=dev \
  DEBUG=true

# Install development tools.
RUN pecl install xdebug-2.7.1; \
  docker-php-ext-enable xdebug; \
  # Adding the dev php.ini
  mv ${PHP_INI_DIR}/php.ini-development ${PHP_INI_DIR}/php.ini; \
  # Copy xdebug configurations templates.
  cp /confd_templates/conf.d/docker-php-ext-xdebug.ini.toml /etc/confd/conf.d/docker-php-ext-xdebug.ini.toml; \
  cp /confd_templates/templates/docker-php-ext-xdebug.ini.tmpl /etc/confd/templates/docker-php-ext-xdebug.ini.tmpl; \
  # Apply xdebug configurations.
  /usr/local/bin/confd -onetime -backend env \
  # Delete xdebug configuration template files.
  && rm /etc/confd/conf.d/docker-php-ext-xdebug.ini.toml /etc/confd/templates/docker-php-ext-xdebug.ini.tmpl \
  # Remove the confd templates altogether.
  && rm -rf /confd_templates

# Copy composer binary from official Composer image. Notice we didn't need composer for prod stage.
# @TODO try to use composer_version here
COPY --from=composer:1.9.3 /usr/bin/composer /usr/bin/composer

EXPOSE 9000

USER ${APP_RUNNER_USER}
