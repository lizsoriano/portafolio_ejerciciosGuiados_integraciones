# Prompt maestro de IA — Ejercicio 02

## Mejora autorizada

Trabaja únicamente sobre la aplicación existente en `apps/web-monolito`. Implementa una sola mejora pequeña y de bajo riesgo: agrega en `GET /books` una búsqueda server-side por título, ISBN o nombre completo del autor. Conserva Express, EJS, PostgreSQL y `pg`; no agregues API ni dependencias. Usa parámetros de PostgreSQL para todos los valores aportados por el usuario, conserva el listado completo cuando el término esté vacío, muestra el término y el número de resultados en la vista, y ofrece limpiar el filtro. Modifica sólo `apps/web-monolito/src/modules/books/routes.js` y `apps/web-monolito/src/views/books/index.ejs`. Verifica sintaxis y deja cualquier prueba que requiera PostgreSQL como pendiente si no hay conexión disponible.

## Control previo obligatorio

Antes de modificar código, registra:

1. Problema: el catálogo sólo lista todos los libros y no permite localizar registros por criterios funcionales.
2. Archivos previstos: exclusivamente las rutas de libros y su vista de índice.
3. Riesgo: bajo, limitado a una consulta de lectura y a la semántica de coincidencia de `ILIKE`.
4. Pruebas: sintaxis, compilación EJS, revisión de parámetros y pruebas funcionales con coincidencia, vacío, cero resultados e intento de SQL Injection.

## Restricciones

- No cambiar la arquitectura monolítica server-side.
- No crear REST, GraphQL, SOAP ni microservicios.
- No modificar el esquema PostgreSQL para esta mejora.
- No agregar dependencias.
- No publicar secretos ni marcar pruebas no ejecutadas como aprobadas.
