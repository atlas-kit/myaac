# MyAAC Dockerfile
FROM php:8.1-fpm-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    && docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli \
    && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    && docker-php-ext-enable \
    pdo \
    pdo_mysql \
    mysqli \
    && apk del .build-deps

# Install optional PHP extensions for better functionality
RUN apk add --no-cache \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    zip \
    gd

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create www-data user directories
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html

# Copy application files
COPY . /var/www/html/
WORKDIR /var/www/html

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Copy nginx configuration
COPY nginx-sample.conf /etc/nginx/http.d/default.conf

# Update nginx configuration for PHP 8.1
RUN sed -i 's/php7.4-fpm.sock/php8-fpm.sock/g' /etc/nginx/http.d/default.conf

# Create supervisor configuration
RUN echo $'[supervisord]\n\
nodaemon=true\n\
user=root\n\
\n\
[program:nginx]\n\
command=nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
\n\
[program:php-fpm]\n\
command=php-fpm -F\n\
autostart=true\n\
autorestart=true' > /etc/supervisor/conf.d/supervisord.conf

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod 660 /var/www/html/config.local.php 2>/dev/null || true

# Create required directories
RUN mkdir -p /run/nginx \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/log/supervisor

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]