# syntax=docker/dockerfile:experimental
ARG REPOSITORY
ARG TAG
FROM ${REPOSITORY}/drupal:${TAG}

RUN --mount=type=bind,source=codebase,target=/build \
    cp -r /build/* /var/www/drupal && \
    bash /var/www/drupal/fix_permissions.sh /var/www/drupal/web nginx
