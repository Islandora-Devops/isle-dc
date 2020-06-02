# syntax=docker/dockerfile:experimental
FROM islandora/composer:latest as composer

WORKDIR /var/www/drupal

# RUN apk-install.sh php7-fileinfo

RUN sed -i 's/default_socket_timeout\ =\ 60/default_socket_timeout\ =\ 120/g' /etc/php7/php.ini 

RUN COMPOSER_MEMORY_LIMIT=-1 composer install 
