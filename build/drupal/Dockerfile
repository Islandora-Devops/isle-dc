FROM drupal:8.8.2-apache

ENV DRUSH_VERSION=9.7.2 \
    COMPOSER_MEMORY_LIMIT=-1

RUN apt-get update &&  apt-get install -y mysql-client && \
    curl -sS https://getcomposer.org/installer | php && \
    ln -s /var/www/html/composer.phar /usr/local/bin/composer && \
    composer require drush/drush:${DRUSH_VERSION} && \
    curl -L https://github.com/drush-ops/drush-launcher/releases/download/0.6.0/drush.phar > /usr/local/bin/drush && \
    chmod +x /usr/local/bin/drush && \
    rm -rf /var/www/html/modules && \
    rm -rf /var/www/html/profiles && \
    rm -rf /var/www/html/sites && \
    rm -rf /var/www/html/themes && \
    ln -s /mnt/assets/modules /var/www/html/modules && \
    ln -s /mnt/assets/profiles /var/www/html/profiles && \
    ln -s /mnt/assets/sites /var/www/html/sites && \
    ln -s /mnt/assets/themes /var/www/html/themes
