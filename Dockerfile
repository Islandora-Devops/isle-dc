# syntax=docker/dockerfile:experimental
ARG REPOSITORY
ARG TAG
FROM ${REPOSITORY}/drupal:${TAG}

RUN --mount=type=bind,source=codebase,target=/build \
    cp -r /build/* /var/www/drupal && \
    cd /var/www/drupal && COMPOSER_MEMORY_LIMIT=-1 composer install && \
    chown -R nginx:nginx /var/www/drupal