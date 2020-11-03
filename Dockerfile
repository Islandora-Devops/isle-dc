# syntax=docker/dockerfile:experimental
ARG REPOSITORY
ARG TAG
FROM ${REPOSITORY}/drupal:${TAG}

COPY --chown=nginx:nginx codebase/* /var/www/drupal
