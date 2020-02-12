FROM drupal:8.8.1-apache@sha256:f0f3f84004b3d8f27cd7dd6fd2af61998a809d51b1239e9220db90f1f05235fc

RUN rm -rf /var/www/html/modules && \
    rm -rf /var/www/html/profiles && \
    rm -rf /var/www/html/sites && \
    rm -rf /var/www/html/themes && \
    ln -s /mnt/assets/modules /var/www/html/modules && \
    ln -s /mnt/assets/profiles /var/www/html/profiles && \
    ln -s /mnt/assets/sites /var/www/html/sites && \
    ln -s /mnt/assets/themes /var/www/html/themes
