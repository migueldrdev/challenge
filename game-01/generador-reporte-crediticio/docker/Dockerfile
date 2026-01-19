# =============================================================================
# DOCKERFILE - Contenedor Principal de Laravel
# =============================================================================
# Este Dockerfile construye la imagen PHP necesaria para ejecutar Laravel.
# Utiliza un enfoque multi-stage para optimizar el tamaño de la imagen final.
#
# PROPÓSITO:
# - Proporciona un entorno PHP 8.2 con FPM para ejecutar Laravel
# - Incluye todas las extensiones PHP necesarias para el proyecto
# - Configura Composer para gestión de dependencias
# - Optimizado para tanto desarrollo como producción
#
# EXTENSIONES INCLUIDAS:
# - pdo_mysql: Conexión a MySQL
# - zip: Manejo de archivos comprimidos (requerido por FastExcel/Maatwebsite)
# - gd: Procesamiento de imágenes
# - bcmath: Cálculos financieros de precisión (importante para reportes crediticios)
# - pcntl: Control de procesos (requerido para queue workers)
# - redis: Cliente Redis para colas y caché en producción
# =============================================================================

# -----------------------------------------------------------------------------
# STAGE 1: Base - Imagen base con extensiones PHP
# -----------------------------------------------------------------------------
FROM php:8.2-fpm-alpine AS base

# Etiquetas de metadatos del contenedor
LABEL maintainer="TuEquipo <dev@tuempresa.com>"
LABEL description="Generador de Reportes Crediticios - Laravel Application"
LABEL version="1.0"

# Argumentos de construcción para configuración flexible
ARG APP_ENV=local
ARG USER_ID=1000
ARG GROUP_ID=1000

# Variables de entorno base
ENV APP_ENV=${APP_ENV}

# Instalación de dependencias del sistema operativo
# - libpng-dev, libjpeg-turbo-dev, freetype-dev: Para extensión GD (imágenes)
# - libzip-dev: Para extensión ZIP (Excel export)
# - icu-dev: Para extensión intl (internacionalización)
# - linux-headers: Headers necesarios para compilación de extensiones
# - $PHPIZE_DEPS: Herramientas para compilar extensiones PHP
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    linux-headers \
    oniguruma-dev \
    $PHPIZE_DEPS

# Configuración e instalación de extensiones PHP
# GD: Configurado con soporte JPEG y Freetype para procesamiento de imágenes
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        zip \
        gd \
        bcmath \
        pcntl \
        intl \
        opcache \
        mbstring

# Instalación de Redis PHP extension
# Importante: Redis es más eficiente que database para colas en producción
RUN pecl install redis \
    && docker-php-ext-enable redis

# Limpieza de archivos temporales para reducir tamaño de imagen
RUN apk del $PHPIZE_DEPS \
    && rm -rf /var/cache/apk/* /tmp/*

# -----------------------------------------------------------------------------
# STAGE 2: Composer - Instalación de Composer
# -----------------------------------------------------------------------------
FROM base AS composer

# Copiar Composer desde imagen oficial (más seguro y actualizado)
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# -----------------------------------------------------------------------------
# STAGE 3: Development - Configuración para desarrollo local
# -----------------------------------------------------------------------------
FROM composer AS development

# Crear usuario no-root para desarrollo (evita problemas de permisos)
# El USER_ID y GROUP_ID deben coincidir con tu usuario local
RUN addgroup -g ${GROUP_ID} laravel \
    && adduser -D -u ${USER_ID} -G laravel laravel

# Instalación de herramientas adicionales para desarrollo
RUN apk add --no-cache \
    git \
    bash \
    nodejs \
    npm \
    # MySQL client para debugging directo a BD
    mysql-client

# Configuración de PHP para desarrollo
# - Más memoria para debugging
# - Errores visibles
# - Sin límite de tiempo para debugging
COPY docker/php/php-dev.ini /usr/local/etc/php/conf.d/custom.ini

# Directorio de trabajo de la aplicación
WORKDIR /var/www/html

# Cambiar a usuario no-root por seguridad
USER laravel

# Puerto expuesto (FPM)
EXPOSE 9000

# Comando por defecto
CMD ["php-fpm"]

# -----------------------------------------------------------------------------
# STAGE 4: Production - Imagen optimizada para producción
# -----------------------------------------------------------------------------
FROM composer AS production

# Crear usuario no-root para producción
RUN addgroup -g 1000 laravel \
    && adduser -D -u 1000 -G laravel laravel

# Configuración de PHP para producción
# - OPcache habilitado y optimizado
# - Menos memoria (más eficiente)
# - Errores ocultos
COPY docker/php/php-prod.ini /usr/local/etc/php/conf.d/custom.ini

# Directorio de trabajo
WORKDIR /var/www/html

# Copiar código de la aplicación
COPY --chown=laravel:laravel . .

# Instalar dependencias de producción (sin dev dependencies)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# Optimizaciones de Laravel para producción
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Permisos correctos para storage y cache
RUN chmod -R 775 storage bootstrap/cache \
    && chown -R laravel:laravel storage bootstrap/cache

# Cambiar a usuario no-root
USER laravel

EXPOSE 9000

CMD ["php-fpm"]
