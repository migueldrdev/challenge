-- =============================================================================
-- SCRIPT DE INICIALIZACIÓN DE MYSQL
-- =============================================================================
-- Este script se ejecuta SOLO la primera vez que se crea el contenedor MySQL.
-- Si necesitas ejecutarlo de nuevo, debes eliminar el volumen:
--   docker compose down -v
--   docker compose up -d
--
-- PROPÓSITO:
-- - Configurar permisos del usuario de la aplicación
-- - Crear bases de datos adicionales si es necesario (ej: testing)
-- - Configurar parámetros de sesión
-- =============================================================================

-- Crear base de datos para testing (separada de la principal)
CREATE DATABASE IF NOT EXISTS creditreport_testing;

-- Dar permisos al usuario de la aplicación sobre la BD de testing
GRANT ALL PRIVILEGES ON creditreport_testing.* TO 'laravel'@'%';

-- Aplicar cambios de privilegios
FLUSH PRIVILEGES;

-- Mensaje de confirmación (visible en logs del contenedor)
SELECT 'Base de datos inicializada correctamente para Generador de Reportes Crediticios' AS mensaje;
