# 🐳 Guía de Dockerización - Generador de Reportes Crediticios

## 📋 Índice

1. [Estructura de Archivos](#estructura-de-archivos)
2. [Inicio Rápido](#inicio-rápido)
3. [Arquitectura de Contenedores](#arquitectura-de-contenedores)
4. [Configuración Detallada](#configuración-detallada)
5. [Comandos Útiles](#comandos-útiles)
6. [Consideraciones para Producción](#consideraciones-para-producción)
7. [Troubleshooting](#troubleshooting)

---

## 📁 Estructura de Archivos

```
docker/
├── Dockerfile              # Imagen principal PHP-FPM multi-stage
├── entrypoint.sh           # Script de inicialización del contenedor
├── commands.sh             # Comandos helper (como Makefile)
├── nginx/
│   ├── default.conf        # Config Nginx para desarrollo
│   └── default.prod.conf   # Config Nginx para producción
├── mysql/
│   ├── my.cnf              # Config MySQL para desarrollo
│   ├── my.prod.cnf         # Config MySQL para producción
│   └── init.sql            # Script de inicialización de BD
└── php/
    ├── php-dev.ini         # Config PHP para desarrollo
    └── php-prod.ini        # Config PHP para producción

docker-compose.yml          # Orquestación para DESARROLLO
docker-compose.prod.yml     # Orquestación para PRODUCCIÓN
.dockerignore               # Archivos excluidos del build
.env.docker                 # Variables de entorno para Docker
```

---

## 🚀 Inicio Rápido

### Prerrequisitos

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

### Pasos de Instalación

```bash
# 1. Clonar el repositorio
git clone <url-repositorio>
cd generador-reporte-crediticio

# 2. Copiar archivo de entorno
cp .env.docker .env

# 3. Obtener tu USER_ID y GROUP_ID (evita problemas de permisos)
echo "USER_ID=$(id -u)" >> .env
echo "GROUP_ID=$(id -g)" >> .env

# 4. Dar permisos al script de comandos
chmod +x docker/commands.sh

# 5. Ejecutar setup completo
./docker/commands.sh setup

# 6. La aplicación estará disponible en:
#    - App: http://localhost:8080
#    - Mailpit: http://localhost:8025
```

### Setup Manual (Alternativa)

```bash
# Iniciar contenedores
docker compose up -d

# Esperar a que MySQL esté listo (30 segundos aprox.)
sleep 30

# Instalar dependencias
docker compose exec app composer install

# Generar key y configurar storage
docker compose exec app php artisan key:generate
docker compose exec app php artisan storage:link

# Ejecutar migraciones
docker compose exec app php artisan migrate

# (Opcional) Generar datos de prueba
docker compose exec app php artisan db:seed
```

---

## 🏗️ Arquitectura de Contenedores

### Diagrama de Servicios

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Docker Network                                │
│                       (creditreport_network)                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐      │
│   │  Nginx   │────▶│   App    │────▶│   MySQL  │     │  Redis   │      │
│   │  :8080   │     │ PHP-FPM  │     │  :3306   │     │  :6379   │      │
│   └──────────┘     └──────────┘     └──────────┘     └──────────┘      │
│        │                │                 │                │            │
│        │                │                 │                │            │
│        ▼                ▼                 │                ▼            │
│   ┌──────────┐     ┌──────────┐          │          ┌──────────┐       │
│   │  Node    │     │  Queue   │──────────┴─────────▶│  Queue   │       │
│   │  :5173   │     │  Worker  │                     │  Jobs    │       │
│   └──────────┘     └──────────┘                     └──────────┘       │
│                          │                                              │
│                          ▼                                              │
│                    ┌──────────┐                                         │
│                    │Scheduler │                                         │
│                    │  (cron)  │                                         │
│                    └──────────┘                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Descripción de Servicios

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| **nginx** | 8080 | Servidor web, sirve archivos estáticos y proxy a PHP-FPM |
| **app** | 9000 (interno) | PHP-FPM ejecutando Laravel |
| **db** | 3306 | MySQL 8.0 para almacenamiento de datos |
| **redis** | 6379 | Cache y sistema de colas para jobs |
| **queue** | - | Worker dedicado para procesar `GenerateCreditReportJob` |
| **scheduler** | - | Ejecuta tareas programadas de Laravel |
| **node** | 5173 | Vite para compilación de assets (solo desarrollo) |
| **mailpit** | 8025 | Captura emails en desarrollo |

---

## ⚙️ Configuración Detallada

### Variables de Entorno Importantes

```bash
# === Aplicación ===
APP_PORT=8080              # Puerto de la aplicación web
APP_ENV=local              # Entorno (local/production)
APP_DEBUG=true             # Mostrar errores (false en prod)

# === Base de Datos ===
DB_HOST=db                 # Nombre del servicio Docker
DB_DATABASE=creditreport   # Nombre de la BD
DB_USERNAME=laravel        # Usuario de la BD
DB_PASSWORD=secret         # Contraseña (CAMBIAR en prod)
DB_EXTERNAL_PORT=3306      # Puerto para conectar desde host

# === Redis ===
REDIS_HOST=redis           # Nombre del servicio Docker
QUEUE_CONNECTION=redis     # Usar Redis para colas (recomendado)
CACHE_STORE=redis          # Usar Redis para cache

# === Permisos de Archivos ===
USER_ID=1000               # Tu usuario local (id -u)
GROUP_ID=1000              # Tu grupo local (id -g)
```

### Configuración Específica para Reportes Masivos

El proyecto está optimizado para generar reportes de millones de registros. Configuraciones importantes:

```ini
# docker/php/php-dev.ini
memory_limit = 512M        # Suficiente para streaming
max_execution_time = 0     # Sin límite para jobs

# docker/mysql/my.cnf
innodb_buffer_pool_size = 256M  # Cache de queries
max_allowed_packet = 64M        # Para exports grandes
```

---

## 🛠️ Comandos Útiles

### Usando el Script Helper

```bash
# Dar permisos (solo una vez)
chmod +x docker/commands.sh

# Ver todos los comandos disponibles
./docker/commands.sh help

# Comandos comunes
./docker/commands.sh up          # Iniciar contenedores
./docker/commands.sh down        # Detener contenedores
./docker/commands.sh shell       # Acceder al contenedor
./docker/commands.sh logs        # Ver logs
./docker/commands.sh test        # Ejecutar tests
./docker/commands.sh migrate     # Ejecutar migraciones
./docker/commands.sh fresh       # Reset de BD con seeders
./docker/commands.sh clear       # Limpiar caches
```

### Comandos Docker Compose Directos

```bash
# Iniciar en segundo plano
docker compose up -d

# Ver logs en tiempo real
docker compose logs -f app
docker compose logs -f queue

# Acceder al contenedor
docker compose exec app bash

# Ejecutar artisan
docker compose exec app php artisan migrate
docker compose exec app php artisan queue:work

# Ejecutar tests
docker compose exec app php artisan test

# Reconstruir imágenes
docker compose build --no-cache

# Detener y eliminar volúmenes
docker compose down -v
```

### Probar la API

```bash
# Generar un reporte crediticio
curl -X POST http://localhost:8080/api/reports/export \
  -H "Content-Type: application/json" \
  -d '{"from": "2025-07-15", "to": "2026-01-13"}'

# Verificar jobs en cola
docker compose exec app php artisan queue:monitor

# Ver logs del queue worker
docker compose logs -f queue
```

### Generar Datos de Prueba (Stress Test)

```bash
# Generar 10,000 suscripciones con 100 reportes cada una
./docker/commands.sh stress 10000 100

# O directamente
docker compose exec app php artisan test:stress 10000 100
```

---

## 🏭 Consideraciones para Producción

### ⚠️ Cambios Críticos

| Aspecto | Desarrollo | Producción |
|---------|------------|------------|
| **APP_DEBUG** | `true` | `false` |
| **APP_ENV** | `local` | `production` |
| **Contraseñas** | Simples | Seguras y únicas |
| **OPcache** | Deshabilitado | Habilitado |
| **Logs** | Debug | Warning/Error |
| **SSL** | No | Sí (obligatorio) |
| **Puertos BD** | Expuestos | No expuestos |
| **Volúmenes código** | Montados | En imagen |

### 🔐 Seguridad

1. **Contraseñas**: Usar secrets manager (AWS Secrets, Vault)
2. **SSL/TLS**: Configurar certificados (Let's Encrypt)
3. **Firewall**: Solo exponer puertos 80/443
4. **Updates**: Mantener imágenes actualizadas
5. **Backups**: Configurar backups de MySQL y Redis

### 📦 Despliegue con CI/CD

```yaml
# Ejemplo para GitHub Actions
name: Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and push
        run: |
          docker build -t ghcr.io/${{ github.repository }}/app:${{ github.sha }} \
            --target production \
            -f docker/Dockerfile .
          docker push ghcr.io/${{ github.repository }}/app:${{ github.sha }}
      
      - name: Deploy
        run: |
          docker compose -f docker-compose.prod.yml pull
          docker compose -f docker-compose.prod.yml up -d
```

### 🔄 Escalar Queue Workers

Para aumentar la capacidad de procesamiento de reportes:

```bash
# Escalar a 5 workers
docker compose -f docker-compose.prod.yml up -d --scale queue=5
```

### 💾 Backups

```bash
# Backup de MySQL
docker compose exec db mysqldump -u root -p creditreport > backup.sql

# Backup de volúmenes
docker run --rm -v creditreport_mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql-backup.tar.gz /data
```

---

## 🔧 Troubleshooting

### Problemas Comunes

#### 1. Permisos de archivos

```bash
# Error: Permission denied en storage/
# Solución: Verificar USER_ID y GROUP_ID
echo "USER_ID=$(id -u)" >> .env
echo "GROUP_ID=$(id -g)" >> .env
docker compose down && docker compose up -d --build
```

#### 2. MySQL no inicia

```bash
# Ver logs de MySQL
docker compose logs db

# Si hay error de permisos en data
docker compose down -v  # CUIDADO: elimina datos
docker compose up -d
```

#### 3. Queue worker no procesa jobs

```bash
# Verificar conexión a Redis
docker compose exec app php artisan tinker
>>> Redis::ping()  # Debe retornar "PONG"

# Reiniciar queue worker
docker compose restart queue
```

#### 4. Composer/npm fallan

```bash
# Limpiar cache de Composer
docker compose exec app composer clear-cache

# Limpiar node_modules
docker compose down
docker volume rm creditreport_node_modules
docker compose up -d
```

#### 5. Aplicación lenta

```bash
# Limpiar caches de Laravel
./docker/commands.sh clear

# En desarrollo, verificar que OPcache esté deshabilitado
# En producción, verificar que esté HABILITADO
```

---

## 📚 Referencias

- [Documentación oficial de Docker](https://docs.docker.com/)
- [Laravel Deployment](https://laravel.com/docs/deployment)
- [PHP-FPM Configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [MySQL Docker Image](https://hub.docker.com/_/mysql)
- [Redis Docker Image](https://hub.docker.com/_/redis)
