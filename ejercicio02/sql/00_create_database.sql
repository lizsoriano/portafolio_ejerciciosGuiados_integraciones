-- db/00_create_database.sql
-- Creacion del rol de aplicacion y de la base de datos.
--
-- Ejecutar UNA sola vez, conectado como superusuario a la base de
-- mantenimiento "postgres" (no dentro de la base library_db, que aun no
-- existe):
--
--   psql -h localhost -U postgres -d postgres -f db/00_create_database.sql
--
-- CREATE DATABASE no puede ejecutarse dentro de un bloque de transaccion,
-- por lo que este script NO usa BEGIN/COMMIT y cada sentencia se confirma
-- de forma independiente.
--
-- Credenciales: se usa el usuario "library_user" / base "library_db" ya
-- documentados en apps/web-monolito/README.md y .env.example (enunciado
-- del ejercicio). Cambie la contrasena de ejemplo antes de usarla fuera de
-- un entorno academico local.
--
-- Principio de minimo privilegio (Parte 4, punto 10 del enunciado):
-- library_user NO es superusuario, NO puede crear otros roles ni otras
-- bases de datos. Es dueno de library_db y por lo tanto tiene control
-- total solo sobre sus propios objetos (tablas, secuencias, vistas,
-- funciones y procedimientos creados dentro de esa base).

CREATE ROLE library_user
    LOGIN
    PASSWORD 'library666'
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION;

CREATE DATABASE library_db
    OWNER library_user
    ENCODING 'UTF8'
    TEMPLATE template0;

-- A partir de aqui, todos los scripts siguientes (db/01 en adelante) se
-- ejecutan conectados a library_db, normalmente con el propio library_user:
--
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/01_schema.sql
