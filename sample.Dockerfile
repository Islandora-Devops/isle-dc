# syntax=docker/dockerfile:experimental
ARG REPOSITORY=islandora
ARG TAG=latest
FROM ${REPOSITORY}/drupal:${TAG} as step1

COPY codebase /build


# Remove runtime configuration and data (files, settings.php, etc) these will
# either be mounted as volumes or generated on startup from environment variables.
RUN cp -r /build/* /var/www/drupal && \
    rm -fr /var/www/drupal/web/sites/default/files/* && \
    bash -lc "remove_standard_profile_references_from_config" && \
    find /var/www/drupal/web/sites -name "settings.php" -exec rm {} \; && \
    chown -R nginx:nginx /var/www/drupal

FROM ${REPOSITORY}/drupal:${TAG} as application
COPY --from=step1 --chown=nginx:nginx /var/www/drupal /var/www/drupal

COPY build/rootfs /
