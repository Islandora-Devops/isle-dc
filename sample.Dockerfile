# syntax=docker/dockerfile:experimental
ARG REPOSITORY=islandora
ARG TAG=latest
FROM ${REPOSITORY}/drupal:${TAG}

# Remove runtime configuration and data (files, settings.php, etc) these will
# either be mounted as volumes or generated on startup from environment variables.
RUN --mount=type=bind,source=codebase,target=/build \
    cp -r /build/* /var/www/drupal && \
    rm -fr /var/www/drupal/web/sites/default/files/* && \
    bash -lc "remove_standard_profile_references_from_config" && \
    find /var/www/drupal/web/sites -name "settings.php" -exec rm {} \; && \
    chown -R nginx:nginx /var/www/drupal && \
    chmod -R u+w /var/www/drupal && \
    chmod -R g+w /var/www/drupal

COPY rootfs /
