#!/bin/bash

# =============================================================================
# MAKEFILE ALTERNATIVO - Comandos útiles para Docker
# =============================================================================
# Este script proporciona comandos comunes para trabajar con Docker Compose.
# Es más portable que un Makefile ya que solo requiere bash.
#
# USO:
#   ./docker/commands.sh up       # Iniciar contenedores
#   ./docker/commands.sh down     # Detener contenedores
#   ./docker/commands.sh shell    # Acceder al contenedor
#   ./docker/commands.sh help     # Ver todos los comandos
#
# NOTA: Asegúrate de dar permisos de ejecución:
#   chmod +x docker/commands.sh
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# -----------------------------------------------------------------------------
# COMANDOS
# -----------------------------------------------------------------------------

# Iniciar todos los contenedores
cmd_up() {
    print_info "Iniciando contenedores..."
    docker compose up -d
    print_status "Contenedores iniciados"
    echo ""
    print_info "Servicios disponibles:"
    echo "  - App:      http://localhost:${APP_PORT:-8080}"
    echo "  - Mailpit:  http://localhost:${MAILPIT_UI_PORT:-8025}"
    echo "  - MySQL:    localhost:${DB_EXTERNAL_PORT:-3306}"
    echo "  - Redis:    localhost:${REDIS_EXTERNAL_PORT:-6379}"
}

# Detener todos los contenedores
cmd_down() {
    print_info "Deteniendo contenedores..."
    docker compose down
    print_status "Contenedores detenidos"
}

# Reconstruir contenedores
cmd_build() {
    print_info "Reconstruyendo contenedores..."
    docker compose build --no-cache
    print_status "Contenedores reconstruidos"
}

# Reiniciar contenedores
cmd_restart() {
    print_info "Reiniciando contenedores..."
    docker compose restart
    print_status "Contenedores reiniciados"
}

# Ver logs de todos los servicios
cmd_logs() {
    docker compose logs -f
}

# Ver logs de un servicio específico
cmd_logs_service() {
    local service=${1:-app}
    docker compose logs -f "$service"
}

# Acceder al shell del contenedor app
cmd_shell() {
    print_info "Accediendo al contenedor app..."
    docker compose exec app bash
}

# Ejecutar comando artisan
cmd_artisan() {
    docker compose exec app php artisan "$@"
}

# Ejecutar composer
cmd_composer() {
    docker compose exec app composer "$@"
}

# Ejecutar npm
cmd_npm() {
    docker compose exec node npm "$@"
}

# Ejecutar tests
cmd_test() {
    print_info "Ejecutando tests..."
    docker compose exec app php artisan test "$@"
}

# Ejecutar migraciones
cmd_migrate() {
    print_info "Ejecutando migraciones..."
    docker compose exec app php artisan migrate "$@"
    print_status "Migraciones completadas"
}

# Ejecutar migraciones fresh con seeders
cmd_fresh() {
    print_warning "Esto eliminará todos los datos de la base de datos."
    read -p "¿Continuar? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        print_info "Ejecutando migrate:fresh --seed..."
        docker compose exec app php artisan migrate:fresh --seed
        print_status "Base de datos reiniciada"
    else
        print_info "Operación cancelada"
    fi
}

# Generar datos de prueba masivos
cmd_stress() {
    local subscriptions=${1:-10000}
    local reports=${2:-100}
    print_info "Generando $subscriptions suscripciones con $reports reportes cada una..."
    docker compose exec app php artisan test:stress "$subscriptions" "$reports"
    print_status "Datos generados"
}

# Iniciar queue worker
cmd_queue() {
    print_info "Iniciando queue worker..."
    docker compose exec app php artisan queue:work redis --verbose
}

# Limpiar caches
cmd_clear() {
    print_info "Limpiando caches..."
    docker compose exec app php artisan cache:clear
    docker compose exec app php artisan config:clear
    docker compose exec app php artisan route:clear
    docker compose exec app php artisan view:clear
    print_status "Caches limpiados"
}

# Setup inicial del proyecto
cmd_setup() {
    print_info "Configurando proyecto..."

    # Copiar .env si no existe
    if [ ! -f .env ]; then
        cp .env.docker .env
        print_status "Archivo .env creado desde .env.docker"
    fi

    # Iniciar contenedores
    docker compose up -d

    # Esperar a que MySQL esté listo
    print_info "Esperando a que MySQL esté listo..."
    sleep 10

    # Instalar dependencias
    docker compose exec app composer install

    # Generar key
    docker compose exec app php artisan key:generate

    # Crear link de storage
    docker compose exec app php artisan storage:link

    # Ejecutar migraciones
    docker compose exec app php artisan migrate

    print_status "¡Proyecto configurado!"
    echo ""
    print_info "Accede a la aplicación en: http://localhost:${APP_PORT:-8080}"
}

# Eliminar todo (contenedores, volúmenes, imágenes)
cmd_destroy() {
    print_warning "Esto eliminará TODOS los contenedores, volúmenes y datos."
    read -p "¿Estás seguro? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        print_info "Eliminando todo..."
        docker compose down -v --rmi local
        print_status "Todo eliminado"
    else
        print_info "Operación cancelada"
    fi
}

# Ver estado de los contenedores
cmd_status() {
    docker compose ps
}

# Mostrar ayuda
cmd_help() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║       🐳 Comandos Docker para Reportes Crediticios              ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "USO: ./docker/commands.sh [comando] [argumentos]"
    echo ""
    echo "COMANDOS DE CONTENEDORES:"
    echo "  up          Iniciar todos los contenedores"
    echo "  down        Detener todos los contenedores"
    echo "  build       Reconstruir contenedores (--no-cache)"
    echo "  restart     Reiniciar contenedores"
    echo "  status      Ver estado de contenedores"
    echo "  destroy     Eliminar todo (contenedores, volúmenes, datos)"
    echo ""
    echo "COMANDOS DE DESARROLLO:"
    echo "  shell       Acceder al shell del contenedor app"
    echo "  logs        Ver logs de todos los servicios"
    echo "  logs-app    Ver logs solo del servicio app"
    echo "  logs-queue  Ver logs solo del queue worker"
    echo ""
    echo "COMANDOS DE LARAVEL:"
    echo "  artisan     Ejecutar comando artisan (ej: artisan migrate)"
    echo "  composer    Ejecutar comando composer (ej: composer require)"
    echo "  npm         Ejecutar comando npm (ej: npm install)"
    echo "  test        Ejecutar tests de PHPUnit"
    echo "  migrate     Ejecutar migraciones"
    echo "  fresh       Ejecutar migrate:fresh --seed"
    echo "  clear       Limpiar todos los caches"
    echo "  queue       Iniciar queue worker manualmente"
    echo ""
    echo "COMANDOS DE SETUP:"
    echo "  setup       Configuración inicial completa del proyecto"
    echo "  stress N M  Generar N suscripciones con M reportes cada una"
    echo ""
    echo "EJEMPLOS:"
    echo "  ./docker/commands.sh setup"
    echo "  ./docker/commands.sh artisan migrate:status"
    echo "  ./docker/commands.sh stress 1000 50"
    echo "  ./docker/commands.sh logs-app"
    echo ""
}

# -----------------------------------------------------------------------------
# MAIN - Procesar comando
# -----------------------------------------------------------------------------
case "${1:-help}" in
    up)         cmd_up ;;
    down)       cmd_down ;;
    build)      cmd_build ;;
    restart)    cmd_restart ;;
    logs)       cmd_logs ;;
    logs-app)   cmd_logs_service app ;;
    logs-queue) cmd_logs_service queue ;;
    logs-*)     cmd_logs_service "${1#logs-}" ;;
    shell)      cmd_shell ;;
    artisan)    shift; cmd_artisan "$@" ;;
    composer)   shift; cmd_composer "$@" ;;
    npm)        shift; cmd_npm "$@" ;;
    test)       shift; cmd_test "$@" ;;
    migrate)    shift; cmd_migrate "$@" ;;
    fresh)      cmd_fresh ;;
    stress)     cmd_stress "$2" "$3" ;;
    queue)      cmd_queue ;;
    clear)      cmd_clear ;;
    setup)      cmd_setup ;;
    destroy)    cmd_destroy ;;
    status)     cmd_status ;;
    help|--help|-h) cmd_help ;;
    *)
        print_error "Comando desconocido: $1"
        echo "Usa './docker/commands.sh help' para ver los comandos disponibles"
        exit 1
        ;;
esac
