# syntax=docker/dockerfile:experimental
ARG REPOSITORY
ARG TAG
FROM ${REPOSITORY}/drupal:${TAG}

RUN --mount=type=bind,source=codebase,target=/build \
    cp -r /build/* /var/www/drupal && \
    cd /var/www/drupal && COMPOSER_MEMORY_LIMIT=-1 COMPOSER_DISCARD_CHANGES=true composer install --no-interaction && \
    bash /var/www/drupal/fix_permissions.sh /var/www/drupal/web nginx
