FROM php:5.6-fpm

# Update sources.list to use the Debian archive
RUN echo "deb http://archive.debian.org/debian/ stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security/ stretch/updates main" >> /etc/apt/sources.list

# 1. Update and install keyring
RUN apt-get update && apt-get install -y --allow-unauthenticated debian-archive-keyring

# 2. Update again with the new keyring and install dependencies
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libmcrypt-dev \
    libicu-dev \
    libxml2-dev \
    libxslt1-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libgmp-dev

# 3. Create symlink for gmp.h
RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

# 4. Install PHP extensions
RUN docker-php-ext-install gmp
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install mcrypt
RUN docker-php-ext-install gd
RUN docker-php-ext-install soap
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install intl
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install dom
RUN docker-php-ext-install iconv
RUN docker-php-ext-install curl
RUN docker-php-ext-install simplexml
RUN docker-php-ext-install xsl
RUN docker-php-ext-install zip

# 5. Install Redis extension
RUN pecl install redis-2.2.8 \
    && docker-php-ext-enable redis

# 6. Cleanup
RUN rm -rf /var/lib/apt/lists/*

# Configurar PHP-FPM
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker/php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www
