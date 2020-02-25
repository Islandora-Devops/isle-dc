ARG php_version=7.2.27
ARG php_pkg_release=fpm-buster

FROM php:${php_version}-${php_pkg_release}

ARG nginx_version=1.17.8
ARG nginx_njs_version=0.3.8
ARG nginx_pkg_release=1~buster

ENV CONFD_VERSION=0.16.0 \
    CONFD_SHA256SUM="255d2559f3824dd64df059bdc533fd6b697c070db603c76aaf8d1d5e6b0cc334" \
    FILES_DIR="/mnt/files" \
    APP_ROOT="/var/www/app" \
    APP_DOCROOT="/var/www/app/web" \
    APP_RUNNER_USER=root

# Install apt dependencies
# @TODO use specific versions of some of these to avoid version conflict or breaking
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    # utilitities cmd
    dos2unix rsync wget findutils \
    # for imap
    libc-client2007e-dev libkrb5-dev \
    # for ssh client only
    openssh-client \
    # for git
    git \
    # for bz2
    bzip2 libbz2-dev \
    # for gd
    # libfreetype6 libfreetype6-dev libpng-tools libjpeg-dev libgmp-dev libwebp-dev \
    libfreetype6 libfreetype6-dev libpng-tools libgmp-dev libwebp-dev \
    # For image optimization
    jpegoptim optipng pngquant \
    # For imagick
    imagemagick libmagickwand-dev \
    # For nginx cgi-fcgi
    libfcgi0ldbl \
    # for intl
    libicu-dev \
    # for mcrypt
    libmcrypt-dev \
    # for ldap
    libldap2-dev \
    # for zip
    libzip-dev zip unzip \
    # for xslt
    libxslt1-dev \
    # for postgres
    libpq-dev \
    # for tidy
    libtidy-dev \
    # for yaml
    libyaml-dev \
    # for command like drush sqlc/sqlq which need a mysql client
    mariadb-client \
    # for supervsisor (http://supervisord.org/)
    supervisor; \
    # install confd
    wget -O /usr/local/bin/confd "https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-amd64"; \
    chmod +x /usr/local/bin/confd; \
    # verify confd signature
    sha256sum /usr/local/bin/confd | grep -q "${CONFD_SHA256SUM}"; \
    exit $?; \
    rm -r /var/lib/apt/lists/*

# Install and enable php extensions using the helper script provided by the base
# image
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure gd --with-gd --with-webp-dir \
       --with-freetype-dir=/usr/include/freetype2 \
       --with-jpeg-dir=/usr/include/ \
       --with-png-dir=/usr/include/ \
    && docker-php-ext-configure intl --enable-intl \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
    && docker-php-ext-configure zip --with-libzip \
    && docker-php-ext-install -j$(nproc) \
       bcmath \
       bz2 \
       calendar \
       exif \
       gd \
       gettext \
       gmp \
       imap \
       intl \
       ldap \
       mysqli \
       opcache \
       pcntl \
       pdo_mysql \
       pdo_pgsql \
       pgsql \
       soap \
       sockets \
       tidy \
       xmlrpc \
       xsl \
       zip \
    # pecl related extensions
    && pecl install \
       apcu-5.1.17 \
       imagick-3.4.4 \
       mcrypt-1.0.1 \
       yaml-2.0.4 \
    && docker-php-ext-enable \
       apcu \
       imagick \
       mcrypt \
       yaml

# install nginx (copied from official nginx Dockerfile https://github.com/nginxinc/docker-nginx/blob/c817e28dd68b6daa33265a8cb527b1c4cd723b59/mainline/buster/Dockerfile)
ENV NGINX_VERSION=${nginx_version} \
    NGINX_PKG_RELEASE=${nginx_pkg_release} \
    NJS_VERSION=${nginx_njs_version} \
    NGINX_USER=www-data \
    NGINX_USER_GROUP=www-data

RUN set -x \
    # Ensure nginx user/group first, to be consistent throughout docker variants
    && user_exists=$(id -u ${NGINX_USER} > /dev/null 2>&1; echo $?) \
    && if [ user_exists -eq 0 ]; then \
      addgroup --system --gid 101 ${NGINX_USER_GROUP}; \
      adduser --system --disabled-login \
              --ingroup ${NGINX_USER_GROUP} --no-create-home \
              --home /nonexistent --gecos "${NGINX_USER} user" \
              --shell /bin/false --uid 101 ${NGINX_USER}; \
    fi \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
      apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && nginxPackages=" \
      nginx=${NGINX_VERSION}-${NGINX_PKG_RELEASE} \
      nginx-module-xslt=${NGINX_VERSION}-${NGINX_PKG_RELEASE} \
      nginx-module-geoip=${NGINX_VERSION}-${NGINX_PKG_RELEASE} \
      nginx-module-image-filter=${NGINX_VERSION}-${NGINX_PKG_RELEASE} \
      nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-${NGINX_PKG_RELEASE} \
    " \
    # Arches officialy built by upstream
    && echo "deb https://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
       $nginxPackages \
       gettext-base \
    && apt-get remove --purge --auto-remove -y \
    && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    # Create default place to store files generated by the app
    && install -o ${NGINX_USER} -g ${NGINX_USER} -d "${FILES_DIR}/public" "${FILES_DIR}/private"; \
    chmod -R 775 "${FILES_DIR}"

EXPOSE 80 443

# Copy custom supervisord configuration file
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
