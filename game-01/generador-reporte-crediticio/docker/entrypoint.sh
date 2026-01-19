#!/bin/bash

# =============================================================================
# SCRIPT DE ENTRADA PARA CONTENEDOR DOCKER
# =============================================================================
# Este script se ejecuta cuando el contenedor inicia.
#
# FUNCIONES:
# 1. Esperar a que los servicios dependientes estén listos
# 2. Configurar permisos de archivos
# 3. Ejecutar migraciones si es necesario
# 4. Generar APP_KEY si no existe
# 5. Crear symbolic link de storage
# 6. Iniciar el proceso principal (PHP-FPM)
#
# USO:
#   Se ejecuta automáticamente al iniciar el contenedor
#   O manualmente: docker compose exec app ./docker/entrypoint.sh
# =============================================================================

set -e  # Salir si hay error

echo "🚀 Iniciando contenedor de Laravel..."

# -----------------------------------------------------------------------------
# FUNCIÓN: Esperar a que un servicio esté disponible
# -----------------------------------------------------------------------------
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=0

    echo "⏳ Esperando a que $service_name ($host:$port) esté disponible..."

    while ! nc -z "$host" "$port" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "❌ Error: $service_name no está disponible después de $max_attempts intentos"
            exit 1
        fi
        echo "   Intento $attempt/$max_attempts..."
        sleep 2
    done

    echo "✅ $service_name está disponible"
}

# -----------------------------------------------------------------------------
# ESPERAR SERVICIOS DEPENDIENTES
# -----------------------------------------------------------------------------
# Solo esperar si las variables de entorno están configuradas
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
    wait_for_service "$DB_HOST" "$DB_PORT" "MySQL"
fi

if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ]; then
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis"
fi

# -----------------------------------------------------------------------------
# CONFIGURAR PERMISOS DE STORAGE Y CACHE
# -----------------------------------------------------------------------------
echo "📁 Configurando permisos de directorios..."

# Crear directorios si no existen
mkdir -p storage/app/public/reports
mkdir -p storage/framework/{cache,sessions,views}
mkdir -p storage/logs
mkdir -p bootstrap/cache

# Establecer permisos (775 permite escritura al grupo)
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

echo "✅ Permisos configurados"

# -----------------------------------------------------------------------------
# GENERAR APP_KEY SI NO EXISTE
# -----------------------------------------------------------------------------
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "" ]; then
    if [ -f .env ]; then
        if ! grep -q "^APP_KEY=base64:" .env; then
            echo "🔑 Generando APP_KEY..."
            php artisan key:generate --force
        fi
    fi
fi

# -----------------------------------------------------------------------------
# CREAR SYMBOLIC LINK DE STORAGE
# -----------------------------------------------------------------------------
if [ ! -L public/storage ]; then
    echo "🔗 Creando symbolic link de storage..."
    php artisan storage:link 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# EJECUTAR MIGRACIONES (Solo si AUTO_MIGRATE=true)
# -----------------------------------------------------------------------------
if [ "$AUTO_MIGRATE" = "true" ]; then
    echo "📊 Ejecutando migraciones..."
    php artisan migrate --force
    echo "✅ Migraciones completadas"
fi

# -----------------------------------------------------------------------------
# LIMPIAR Y CACHEAR CONFIGURACIÓN (Producción)
# -----------------------------------------------------------------------------
if [ "$APP_ENV" = "production" ]; then
    echo "⚡ Optimizando para producción..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    echo "✅ Cachés generados"
fi

# -----------------------------------------------------------------------------
# MOSTRAR INFORMACIÓN DEL ENTORNO
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "🎉 Contenedor listo"
echo "=========================================="
echo "  Entorno: $APP_ENV"
echo "  PHP: $(php -v | head -n 1)"
echo "  Laravel: $(php artisan --version)"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# EJECUTAR COMANDO PRINCIPAL
# -----------------------------------------------------------------------------
# Si se pasan argumentos, ejecutarlos; si no, iniciar PHP-FPM
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec php-fpm
fi
