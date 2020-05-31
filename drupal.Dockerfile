# syntax=docker/dockerfile:experimental
FROM islandora/composer:latest as composer

WORKDIR /var/www/drupal

RUN apk-install.sh php7-fileinfo

RUN COMPOSER_MEMORY_LIMIT=-1 composer install 
