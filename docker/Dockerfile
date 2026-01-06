# Multi-stage Dockerfile for Mautic 7.x with Apache and PHP 8.4
# Based on official mautic/docker-mautic repository structure

# ============================================
# Builder Stage
# ============================================
FROM php:8.4-apache-bookworm AS builder

# Set working directory
WORKDIR /opt

# Install build dependencies and PHP extensions
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        curl \
        git \
        graphicsmagick \
        imagemagick \
        libaprutil1-dev \
        libc-client-dev \
        libcurl4-gnutls-dev \
        libfreetype6-dev \
        libgif-dev \
        libicu-dev \
        libjpeg-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libmagickwand-dev \
        libmcrypt-dev \
        libonig-dev \
        libpng-dev \
        libpq-dev \
        librabbitmq-dev \
        libssl-dev \
        libtiff-dev \
        libwebp-dev \
        libxml2-dev \
        libxpm-dev \
        libz-dev \
        libzip-dev \
        nodejs \
        npm \
        unzip

# Build and install amqp PHP extension from source
RUN curl -L -o /tmp/amqp.tar.gz "https://github.com/php-amqp/php-amqp/archive/refs/tags/v2.1.2.tar.gz" \
    && mkdir -p /usr/src/php/ext/amqp \
    && tar -C /usr/src/php/ext/amqp -zxvf /tmp/amqp.tar.gz --strip 1 \
    && rm /tmp/amqp.tar.gz

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install intl mbstring mysqli curl pdo_mysql zip bcmath sockets exif amqp gd imap opcache \
    && docker-php-ext-enable intl mbstring mysqli curl pdo_mysql zip bcmath sockets exif amqp gd imap opcache

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Set PHP memory limit
RUN echo "memory_limit = -1" > /usr/local/etc/php/php.ini

# Define Mautic version (can be overridden at build time)
ARG MAUTIC_VERSION=7.x-dev

# Create Mautic project using Composer
RUN cd /opt \
    && COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_PROCESS_TIMEOUT=10000 \
        composer create-project mautic/recommended-project:${MAUTIC_VERSION} mautic --no-interaction \
    && rm -rf /opt/mautic/var/cache/js

# Clean up unnecessary node_modules (keep only jquery and vimeo-froogaloop2)
RUN find /opt/mautic/node_modules -mindepth 1 -maxdepth 1 \
        -not \( -name 'jquery' -or -name 'vimeo-froogaloop2' \) | xargs rm -rf

# ============================================
# Runtime Stage
# ============================================
FROM php:8.4-apache-bookworm

# Metadata
LABEL vendor="Mautic"
LABEL maintainer="Custom build for Coolify"
LABEL version="7.x-dev"

# Define Mautic volumes to persist data
VOLUME /var/www/html/config
VOLUME /var/www/html/var/logs
VOLUME /var/www/html/docroot/media/files
VOLUME /var/www/html/docroot/media/images

# Set PHP environment variables
ENV PHP_INI_VALUE_DATE_TIMEZONE='UTC' \
    PHP_INI_VALUE_MEMORY_LIMIT=512M \
    PHP_INI_VALUE_UPLOAD_MAX_FILESIZE=512M \
    PHP_INI_VALUE_POST_MAX_FILESIZE=512M \
    PHP_INI_VALUE_MAX_EXECUTION_TIME=300

# Set worker environment variables
ENV DOCKER_MAUTIC_WORKERS_CONSUME_EMAIL=2 \
    DOCKER_MAUTIC_WORKERS_CONSUME_HIT=2 \
    DOCKER_MAUTIC_WORKERS_CONSUME_FAILED=2

# Set Mautic role and defaults
ENV DOCKER_MAUTIC_ROLE=mautic_web \
    DOCKER_MAUTIC_RUN_MIGRATIONS=false \
    DOCKER_MAUTIC_LOAD_TEST_DATA=false \
    DEBUG=false

# Set Apache document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/docroot

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy php.ini from host
COPY common/templates/php.ini /usr/local/etc/php/php.ini

# Copy Mautic application
COPY --from=builder --chown=www-data:www-data /opt/mautic /var/www/html

# Copy entrypoint scripts and templates from host
COPY --chmod=755 common/startup/ /startup/
COPY --chown=www-data:www-data --chmod=755 common/templates/ /templates/
COPY --chmod=755 common/docker-entrypoint.sh /entrypoint.sh
COPY --chmod=755 common/entrypoint_mautic_web.sh /entrypoint_mautic_web.sh
COPY --chmod=755 common/entrypoint_mautic_cron.sh /entrypoint_mautic_cron.sh
COPY --chmod=755 common/entrypoint_mautic_worker.sh /entrypoint_mautic_worker.sh

# Copy supervisord configuration for workers
COPY common/templates/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install runtime dependencies
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y \
        cron \
        git \
        libc-client-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        librabbitmq4 \
        libwebp-dev \
        libzip-dev \
        mariadb-client \
        supervisor \
        unzip \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/cron.daily/*

# Install Node.js (LTS) for asset building
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

# Rebuild web assets
RUN cd /var/www/html \
    && npm install \
    && php bin/console mautic:assets:generate \
    && php bin/console cache:clear

# Configure Apache to use docroot
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && a2enmod rewrite

# Set correct ownership for Mautic var folder
RUN chown -R www-data:www-data /var/www/html/var/

# Set working directory
WORKDIR /var/www/html/docroot

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
