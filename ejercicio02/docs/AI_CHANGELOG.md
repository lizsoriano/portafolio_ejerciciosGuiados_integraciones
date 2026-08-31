# Registro de cambios realizados con IA

## 2026-08-30 — Filtro de búsqueda del catálogo

- Alcance: una mejora funcional pequeña; no cambia arquitectura, esquema ni dependencias.
- Archivos de código modificados: `apps/web-monolito/src/modules/books/routes.js` y `apps/web-monolito/src/views/books/index.ejs`.
- Cambio: `GET /books?q=...` filtra por título, ISBN o autor mediante `ILIKE`; la vista conserva y muestra el término, cuenta resultados y permite limpiar.
- Seguridad: los valores se pasan como `$1` y `$2`; no se interpolan en el SQL.
- Riesgo: bajo. Un término con `%` o `_` conserva la semántica de comodín de `ILIKE`; no modifica datos.
- Pruebas ejecutadas: `npm.cmd run check`, `node --check` para todos los archivos JavaScript y compilación EJS de la vista modificada, todas con código 0. `git check-ignore` confirmó exclusión de `.env`, `node_modules` y uploads; `git ls-files` confirmó que no están versionados (salvo `.gitkeep`).
- Pruebas pendientes: comportamiento de búsqueda, login, roles, CRUD, uploads e integridad contra PostgreSQL/navegador. No había `.env` local y `psql` no estaba disponible en `PATH`; por ello no se asignó `PASSED` a esos casos.

## 2026-08-31 — Corrección CSP: `upgrade-insecure-requests` sin TLS disponible

- Alcance: corrección puntual de una directiva de seguridad; no cambia arquitectura, esquema ni dependencias.
- Archivo de código modificado: `apps/web-monolito/src/app.js` (una línea, dentro de la configuración de `helmet()`).
- Cambio: se agrega `"upgrade-insecure-requests": null` a `contentSecurityPolicy.directives` para que Helmet deje de enviar esa directiva.
- Seguridad: no se retira ninguna otra protección de Helmet; el resto de la CSP y de los encabezados (`X-Frame-Options`, `X-Content-Type-Options`, etc.) queda sin cambios.
- Riesgo: bajo. La directiva retirada no tenía efecto útil sobre un despliegue sin TLS y activamente rompía la carga de CSS/imágenes bajo `/library` en un navegador real.
- Pruebas ejecutadas: `curl -I` real contra `http://34.51.61.250/library` y `http://34.51.61.250/library/css/app.css`, antes y después del cambio, en la instancia GCP real (`maquina-02`), con `library-web.service` reiniciado.
- Resultado: `Content-Security-Policy` ya no incluye `upgrade-insecure-requests`; `GET .../css/app.css` sigue devolviendo `200`. `PASSED`.

## 2026-08-31 — Ejecución real de db/00–06, corrección de 3 bugs y conexión de stored procedures

Sesión con acceso real por primera vez a PostgreSQL/GCP (instancia `maquina-02`). Resumen de cambios de código con IA como herramienta, cada uno probado contra la base y la app reales antes de darlo por bueno (detalle completo, incluyendo el prompt/contexto de cada corrección, en `docs/ENGINEERING_DECISIONS.md` ED-11 a ED-17):

- `db/01_schema.sql` y `data/schema.sql`: `ck_books_price_nonnegative CHECK (price >= 0)` → `ck_books_price_positive CHECK (price > 0)`. Encontrado ejecutando la prueba negativa de precio inválido por primera vez contra PostgreSQL real; antes solo se había validado de forma estática.
- `apps/web-monolito/src/server.js`: se agrega `host=process.env.HOST||'127.0.0.1'` y se pasa a `app.listen(port,host,...)`. Antes Node escuchaba en todas las interfaces; se detectó revisando el firewall real del proyecto GCP, que además tenía una regla que exponía el puerto 3000 directo a Internet (eliminada).
- `library-web.service` (systemd, no versionado en git): se retira `Environment=NODE_ENV=production`, que anulaba las cookies de sesión sobre HTTP simple.
- `apps/web-monolito/src/modules/books/routes.js`: `GET /books` pasa a consultar la vista real `v_book_catalog`; `POST /books`, `PUT /books/:id`, `POST /books/:id/concepts` y la portada de imágenes en `PUT /books/:id/images/:imageId` pasan a invocar `CALL sp_create_book`, `CALL sp_update_book`, `CALL sp_upsert_book_concept` y `CALL sp_set_book_cover_image` respectivamente, en vez de sus `INSERT`/`UPDATE` manuales.
- Riesgo: medio en los cambios de `routes.js` (tocan el flujo de escritura de libros que ya funcionaba); mitigado probando cada ruta modificada de punta a punta por HTTP real (cookies + CSRF reales) inmediatamente después del cambio, antes de dar por cerrada la corrección.
- Pruebas ejecutadas: los 7 scripts de `db/` corridos en orden contra PostgreSQL real; 11 pruebas negativas de integridad con el error real de PostgreSQL; login/logout/autorización por HTTP real con las tres sesiones (administrador, usuario, visitante); creación/edición de libro, concepto y portada de imagen por HTTP real verificando con `SELECT` que cada procedimiento ejecutó la operación esperada; despliegue verificado desde fuera de la instancia (`curl` externo a `/library`).
- Resultado: `docs/TEST_PLAN.md` pasó de 2 a 22 de 22 casos en `PASSED`, todos con evidencia HTTP/SQL real. `PASSED`.
