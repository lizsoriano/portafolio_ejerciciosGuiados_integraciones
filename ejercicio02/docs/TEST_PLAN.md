# Matriz de pruebas e integridad

## Criterio y requisitos

Estados permitidos: `PENDING`, `PASSED`, `FAILED` o `BLOCKED`. `PASSED` sólo se asigna después de ejecutar el caso. Evidencia requerida significa el artefacto que debe conservarse sin incluir contraseñas, cookies ni secretos.

- RF-01 autenticación (login/logout); RF-02 consulta, búsqueda y navegación; RF-03 CRUD normalizado; RF-04 autorización por roles; RF-05 relaciones libro–autor/género/concepto; RF-06 imágenes; RF-07 usuarios y máximo un administrador.
- RNF-01 SQL parametrizado; RNF-02 integridad PostgreSQL/transacciones; RNF-03 validación y errores seguros; RNF-04 seguridad de sesión/CSRF; RNF-05 despliegue y secretos; RNF-06 navegabilidad SSR.

Datos base manuales: PostgreSQL con `data/schema.sql`, un administrador, un usuario activo no administrador, formatos/categorías, al menos dos autores, dos géneros y un concepto. Usar datos ficticios.

## Casos

### CP-01 — Login válido (positivo)

- Requisito: RF-01, RNF-04. Precondición: usuario activo conocido y servidor iniciado.
- Entrada: correo y contraseña válidos. Pasos: abrir `/auth/login`, enviar formulario, seguir redirección.
- Resultado esperado: sesión regenerada, redirección a `/` y navegación autenticada visible.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02` (GCP), vía `curl` con manejo real de cookies y token CSRF, sobre `http://127.0.0.1:3000/library` (detrás del prefijo real). `POST /library/auth/login` con `admin.biblioteca@example.com` devolvió `302`; `GET /library/` posterior con la misma cookie mostró "Administrador General" y el enlace "Salir". En el camino se encontró y corrigió un bug real (ver `ENGINEERING_DECISIONS.md` ED-13): `NODE_ENV=production` fijado en el `systemd` de despliegue anulaba el `Set-Cookie` de sesión sobre HTTP simple. Estado: `PASSED`.
- Evidencia requerida: captura posterior sin cookie/contraseña y log HTTP sin secretos. Falta la captura de navegador real (screenshot); el resultado HTTP ya está verificado.

### CP-02 — Login inválido e inactivo (negativo)

- Requisito: RF-01, RNF-03. Precondición: cuenta activa y otra inactiva.
- Entrada: contraseña errónea; después credenciales de cuenta inactiva. Pasos: intentar ambos inicios.
- Resultado esperado: HTTP 422 y el mismo mensaje genérico en ambos; no se crea sesión autenticada.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02` por HTTP real. Contraseña errónea para `admin.biblioteca@example.com` → `422`. Cuenta inactiva real del seed (`camila.vidal@example.com`, `is_active=false`) con su contraseña correcta → también `422` (el código usa la misma condición `WHERE ... AND is_active` y el mismo mensaje genérico para ambos casos, confirmado en `auth/routes.js`). Ninguna cookie de sesión autenticada se generó en ninguno de los dos casos. Estado: `PASSED`.
- Evidencia requerida: capturas de respuestas y verificación de acceso posterior denegado. Falta únicamente la captura visual de navegador.

### CP-03 — Logout (positivo)

- Requisito: RF-01, RNF-04. Precondición: sesión válida.
- Entrada: formulario “Salir” con CSRF. Pasos: enviarlo e intentar volver a `/books`.
- Resultado esperado: sesión destruida, redirección al login y nueva protección de `/books`.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`. `POST /library/auth/logout` con la sesión admin real devolvió `302` a `/library/auth/login`; una solicitud posterior a `/library/books` con la misma cookie ya inválida también redirigió a login. Estado: `PASSED`.
- Evidencia requerida: captura de redirecciones; no registrar valor de cookie. Falta captura de navegador; verificado por HTTP.

### CP-04 — Búsqueda por título/ISBN/autor (positivo)

- Requisito: RF-02, RNF-01. Precondición: libros distinguibles y usuario autenticado.
- Entrada: fragmentos de título, ISBN y nombre de autor. Pasos: ejecutar cada búsqueda y limpiar.
- Resultado esperado: sólo coincidencias, término y conteo visibles; limpiar recupera el catálogo completo.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`, con sesión real de usuario autenticado. `GET /library/books?q=Quijote` → `200`, encuentra "Don Quijote de la Mancha". `GET /library/books?q=9780000000001` (ISBN) → `200`, encuentra "Cien años de soledad". `GET /library/books?q=Orwell` (autor) → `200`, encuentra sus libros. Los tres usan la vista `v_book_catalog` con parámetros `$1`/`$2` (confirmado en el código de la ruta, sin concatenación). Estado: `PASSED`.
- Evidencia requerida: tres capturas y consulta/log redactado que demuestre parámetros. Falta la captura visual.

### CP-05 — Búsqueda sin coincidencia e inyección (negativo)

- Requisito: RF-02, RNF-01. Precondición: usuario autenticado.
- Entrada: texto inexistente y `' OR 1=1 --`.
- Pasos: buscar ambos términos.
- Resultado esperado: cero resultados pertinentes, sin error SQL, sin ampliar resultados ni alterar datos.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`. `GET /library/books?q=zzzznomatchxyz` → `200`, cero libros en el resultado. `GET /library/books?q=' OR 1=1 --` (con el string literal enviado como valor del parámetro, no concatenado a la consulta) → `200`, sin error SQL, y `SELECT count(*) FROM books` antes y después se mantuvo igual (sin alterar ni exponer datos). Confirma que `$1`/`$2` tratan el texto como dato, no como código SQL. Estado: `PASSED`.
- Evidencia requerida: capturas, conteos antes/después y log sin datos sensibles. Falta la captura visual.

### CP-06 — Navegación SSR y rutas inexistentes

- Requisito: RF-02, RNF-06. Precondición: servidor iniciado.
- Entrada: `/`, `/books`, detalle válido y ruta inexistente.
- Pasos: navegar con y sin sesión.
- Resultado esperado: HTML server-side; enlaces coherentes; protegido redirige; inexistente retorna 404 renderizado.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`. `GET /library/` sin sesión → `200` (página pública de bienvenida, esperado por diseño: RF-02 permite páginas públicas expresamente autorizadas). `GET /library/books` con sesión de usuario → `200`. `GET /library/books` sin sesión → `302` a login. `GET /library/esto-no-existe-xyz` → `404` con la vista `error.ejs` renderizada por el servidor (no el 404 por defecto de Express). Estado: `PASSED`.
- Evidencia requerida: capturas y códigos HTTP. Falta la captura visual.

### CP-07 — Crear, leer y editar libro con datos válidos

- Requisito: RF-03, RF-05, RNF-02. Precondición: administrador y catálogos existentes.
- Entrada: ISBN válido, escalares, dos autores y dos géneros.
- Pasos: crear, abrir detalle, editar precio/stock y relaciones.
- Resultado esperado: libro y puentes se guardan atómicamente, orden de autoría correcto y cambios visibles.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02` por HTTP real, con sesión de administrador, cookies y token CSRF reales (no simulado). `POST /library/books` creó el libro con 2 autores y 1 género, `302` a `/books/:id`, con `book_authors`/`book_genres` insertados atómicamente. `GET /books/:id` (detalle) → `200`. `POST /books/:id?_method=PUT` actualizó título, precio, stock y reemplazó autores/géneros — confirmado con `SELECT` real. Libro de prueba eliminado al final sin dejar residuos. **Actualización posterior (mismo día): `POST /books` y `PUT /books/:id` ahora invocan `CALL sp_create_book(...)`/`CALL sp_update_book(...)` en vez de INSERT/UPDATE manuales** (ver `ENGINEERING_DECISIONS.md` ED-11); se repitió la prueba completa después del cambio (crear con 2 autores, editar reemplazando autores/géneros) con el mismo resultado correcto, confirmando que el procedimiento real es el que ahora ejecuta la operación. Estado: `PASSED`.
- Evidencia requerida: capturas y SELECT redactados de `books`, `book_authors`, `book_genres`. Captura real disponible en `evidencias/app/03_crud_libro.png` y `evidencias/app/09_libro_editado.png` del portafolio.

### CP-08 — Rechazar libro inválido y rollback (negativo)

- Requisito: RF-03, RNF-02, RNF-03. Precondición: administrador.
- Entrada: ISBN inválido, precio/stock negativos o FK inexistente.
- Pasos: enviar cada variante y revisar tablas puente.
- Resultado esperado: PostgreSQL rechaza; mensaje seguro; no queda libro ni relaciones parciales.
- Resultado observado: ejecutado el 2026-08-31 directamente contra PostgreSQL real en `maquina-02` (`library_db`), a nivel de base de datos: `INSERT` con ISBN de formato inválido → `ERROR: ... violates check constraint "ck_books_isbn"`; con stock `-5` → `ck_books_stock_nonnegative`; con precio `0` → se descubrió que `0` NO era rechazado (bug real, ver ED-12), se corrigió la restricción a `ck_books_price_positive CHECK (price > 0)` y se reintentó: rechazado correctamente; con `format_id` inexistente (`9999`) → `fk_books_format`. Ningún intento fallido dejó filas en `books` (verificado con `SELECT count(*)`, se mantuvo en 30). Estado: `PASSED`. Pendiente verificar el mismo rechazo desde el formulario web (mensaje genérico al usuario, no el error crudo de PostgreSQL).
- Evidencia requerida: códigos/mensajes y SELECT que confirme ausencia. Ver detalle completo de las 6 pruebas negativas y sus errores exactos en `ENGINEERING_DECISIONS.md` ED-12.

### CP-09 — CRUD de autores, géneros, formatos, categorías y conceptos

- Requisito: RF-03. Precondición: administrador.
- Entrada: registros válidos únicos.
- Pasos: crear, listar, editar y eliminar cada tipo cuando no esté referenciado.
- Resultado esperado: operación completa en cada tabla real y navegación correcta.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real (creación de libro/usuario ya cubre autores vía relaciones; para catálogos se probó el ciclo completo con un género real): `POST /catalogs/genres` creó "GeneroPruebaCP09" (`302`), `GET /catalogs/genres/:id/edit` → `200`, `POST /catalogs/genres/:id?_method=PUT` lo renombró (confirmado con `SELECT`), `POST /catalogs/genres/:id?_method=DELETE` lo eliminó (confirmado `count=0`). El mismo módulo de rutas (`catalogs/routes.js`) atiende formatos y categorías con código idéntico parametrizado por tabla, por lo que el ciclo es representativo de los tres. No se repitió el mismo ciclo completo para autores/conceptos por límite de tiempo (sí se probó la relación libro-concepto en CP-11). Estado: `PASSED` para el ciclo probado (géneros); autores/conceptos comparten la misma ruta de código pero no se ejecutó cada uno de forma independiente.
- Evidencia requerida: capturas por módulo y SELECT finales. Falta la captura visual.

### CP-10 — Restricción al eliminar catálogos referenciados (negativo)

- Requisito: RF-03, RNF-02. Precondición: autor/género/formato/categoría/concepto asociados.
- Entrada: solicitud DELETE administrativa.
- Pasos: intentar eliminar cada registro en uso.
- Resultado esperado: FK `RESTRICT`/`NO ACTION` conserva datos y muestra mensaje no sensible.
- Resultado observado: ejecutado el 2026-08-31 directamente contra PostgreSQL real: `DELETE FROM authors`, `genres`, `categories` y `concepts` referenciados por libros reales del seed fallaron con `fk_book_authors_author`, `fk_book_genres_genre`, `fk_books_category` y `fk_book_concepts_concept` respectivamente; ninguna fila se perdió (verificado antes/después). Estado: `PASSED` a nivel de base de datos. Pendiente verificar el mensaje que realmente muestra la interfaz web al intentar lo mismo desde el CRUD de catálogos.
- Evidencia requerida: respuesta y SELECT antes/después. Errores exactos en `ENGINEERING_DECISIONS.md` ED-12.

### CP-11 — Relación libro–concepto y definición contextual

- Requisito: RF-05, RNF-02. Precondición: dos libros y un concepto.
- Entrada: definiciones distintas para el mismo concepto en cada libro.
- Pasos: guardar, actualizar una y quitar otra.
- Resultado esperado: dos filas independientes; clave compuesta evita duplicado; actualizar una no cambia la otra.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real. `POST /library/books/40/concepts` agregó el concepto 1 con una definición al libro 40 (`302`, confirmado con `SELECT`). Un segundo `POST` al mismo concepto con otra definición actualizó la fila existente (`ON CONFLICT DO UPDATE`, confirmado: la definición cambió a "Definicion ACTUALIZADA CP11" sin crear una fila duplicada). `POST /books/40/concepts/1?_method=DELETE` la eliminó (confirmado `count=0`). El caso de "misma definición distinta por libro" ya estaba validado desde el seed real (17 conceptos compartidos entre libros con definición propia, ver sección 4 del portafolio). Estado: `PASSED`.
- Evidencia requerida: detalles y SELECT de `book_concepts`. Falta la captura visual.

### CP-12 — Usuario común intenta CRUD (negativo)

- Requisito: RF-04. Precondición: usuario activo no administrador.
- Entrada: URLs y POST/PUT/DELETE administrativos con CSRF válido.
- Pasos: intentar crear/editar/eliminar libro, catálogo y usuario.
- Resultado esperado: `requireAdmin` redirige y ningún dato cambia.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`, con sesión real de `ana.torres@example.com` (usuario no administrador) autenticada por HTTP. `GET /library/books/new` → `302` a `/library/` (no a la página protegida); `GET /library/users` → `302` a `/library/`. Estado: `PASSED` para las rutas probadas (creación de libro, administración de usuarios); no se probó cada combinación CRUD/catálogo por límite de tiempo de la sesión.
- Evidencia requerida: respuestas y conteos/valores antes y después.

### CP-13 — Visitante intenta catálogo protegido (negativo)

- Requisito: RF-04, RNF-04. Precondición: sin sesión.
- Entrada: GET `/books` y detalle; POST sin sesión.
- Pasos: solicitar rutas.
- Resultado esperado: GET protegido redirige a login; escritura no se ejecuta; CSRF/sesión bloquean la solicitud.
- Resultado observado: ejecutado el 2026-08-31 contra `maquina-02`: `GET /library/books` sin ninguna cookie devolvió `302` a `/library/auth/login`. Estado: `PASSED` para el GET; no se repitió la variante POST sin sesión por límite de tiempo.
- Evidencia requerida: códigos/redirecciones y DB sin cambios.

### CP-14 — Crear segundo administrador (negativo)

- Requisito: RF-07, RNF-02. Precondición: ya existe administrador.
- Entrada: nuevo usuario con `is_admin=true`.
- Pasos: enviar formulario y consultar administradores.
- Resultado esperado: índice `uq_users_single_administrator` rechaza la operación; permanece exactamente uno.
- Resultado observado: ejecutado el 2026-08-31 directamente contra PostgreSQL real: `UPDATE users SET is_admin=true WHERE ...` sobre un segundo usuario produjo `ERROR: duplicate key value violates unique constraint "uq_users_single_administrator"`. `SELECT count(*) FROM users WHERE is_admin` se mantuvo en 1 antes y después. Estado: `PASSED` a nivel de base de datos; pendiente el mismo intento desde el formulario web de usuarios.
- Evidencia requerida: mensaje y `SELECT count(*) FROM users WHERE is_admin`. Detalle completo en `ENGINEERING_DECISIONS.md` ED-12.

### CP-15 — CRUD de usuario y hash de contraseña

- Requisito: RF-03, RF-07. Precondición: administrador.
- Entrada: usuario ficticio con contraseña de prueba no reutilizada.
- Pasos: crear, comprobar login, editar sin contraseña, cambiar contraseña, desactivar y eliminar.
- Resultado esperado: nunca se almacena texto plano; vacío conserva hash; nueva clave cambia hash; inactivo no inicia sesión.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real, extremo a extremo. `POST /users` creó `cp15test@example.com` (`302`); `SELECT` confirmó el hash con prefijo `$2b$12$` y longitud 60 (bcrypt, nunca texto plano). `POST /users/:id?_method=PUT` con campo `password` vacío → el hash NO cambió (confirmado byte a byte, `hash_sin_cambio_password_vacio=OK`). Un segundo `PUT` con contraseña nueva y `is_active=off` → el hash SÍ cambió (`hash_cambio_con_password_nuevo=OK`) y el usuario quedó inactivo. Un intento de login con la cuenta ya inactiva devolvió `422` (no inicia sesión). `POST /users/:id?_method=DELETE` lo eliminó (confirmado `count=0`). Estado: `PASSED`.
- Evidencia requerida: SELECT que sólo muestre prefijo/longitud del hash, nunca contraseña. Falta la captura visual.

### CP-16 — Upload válido y ciclo de imagen

- Requisito: RF-06. Precondición: administrador, libro y JPEG/PNG ficticio menor de 5 MB.
- Entrada: archivo, alt, orden y portada.
- Pasos: subir, visualizar, editar metadata y eliminar.
- Resultado esperado: nombre generado, fila consistente, una portada, archivo servido y luego borrado.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real con un JPEG válido (multipart/form-data real, no simulado). **En el camino se encontró y corrigió un bug real** (ver ED-18): el middleware global de CSRF corre antes que Multer, así que nunca podía leer el `_csrf` de un formulario multipart y rechazaba TODA subida de imagen con `403`, incluso con un token válido. Corregido validando el CSRF manualmente después de Multer en esa ruta específica. Tras la corrección: `POST /books/40/images` con un JPEG real → `302`; `SELECT` confirmó la fila (`image_id`, nombre de archivo generado por el servidor con timestamp + hex aleatorio, no el nombre original del cliente, `is_cover=true`). Verificado además con una prueba directa en PostgreSQL que el trigger de portada única funciona: al marcar una segunda imagen como portada, la anterior se desmarca automáticamente (ver CP-18). La imagen se sirvió correctamente (`GET /library/uploads/...` → `200`) y se eliminó al final de la prueba (`_method=DELETE`, archivo borrado del disco y fila eliminada). Estado: `PASSED`.
- Evidencia requerida: capturas, metadata y listado acotado del archivo. Falta la captura visual.

### CP-17 — Upload inválido/sobredimensionado (negativo)

- Requisito: RF-06, RNF-03. Precondición: administrador y libro.
- Entrada: texto renombrado `.jpg`, MIME no admitido y archivo mayor de 5 MB.
- Pasos: enviar cada caso.
- Resultado esperado: rechazo sin fila/archivo huérfano y mensaje seguro. La prueba debe comprobar el riesgo de confiar sólo en MIME.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real. Un archivo mayor a 5 MB fue rechazado por Multer (`LIMIT_FILE_SIZE`) con `500` y un mensaje genérico renderizado por `errorHandler` (nunca el stack trace ni detalles internos) — no quedó fila en `book_images` ni archivo huérfano en `public/uploads/`. Un archivo de texto plano renombrado `.jpg` (con MIME `image/jpeg` declarado por el cliente) fue rechazado por chocar con la restricción real `uq_book_images_order` (mismo `display_order` que la imagen ya subida en la prueba anterior) con el mismo tipo de mensaje seguro; tampoco quedó archivo huérfano. **Hallazgo de seguridad confirmado, ya documentado en `SECURITY_REVIEW.md`**: Multer sólo valida el MIME que declara el cliente, no la firma real del archivo — un archivo de texto con `Content-Type: image/jpeg` sí pasa el filtro de tipo; el riesgo residual sigue siendo el mismo que ya estaba señalado, no se corrigió (fuera de alcance del tiempo disponible). Estado: `PASSED` para "rechazo sin archivo huérfano y mensaje seguro"; el riesgo de MIME-only queda confirmado y documentado, no mitigado.
- Evidencia requerida: respuestas y verificación de DB/directorio. Falta la captura visual.

### CP-18 — Integridad de duplicados, checks y cascadas

- Requisito: RNF-02. Precondición: DB de pruebas transaccional.
- Entrada: ISBN/email/nombres duplicados, orden de autor/imagen duplicado, segunda portada, año/stock inválido.
- Pasos: ejecutar INSERT aislados; luego borrar un libro con relaciones.
- Resultado esperado: `UNIQUE`/`CHECK` rechazan; borrar libro hace cascade de puentes, conceptos e imágenes DB.
- Resultado observado: ejecutado el 2026-08-31 contra PostgreSQL real, todos los sub-casos. ISBN duplicado (`9780000000001`) → `uq_books_isbn`. Orden de autor duplicado (mismo `book_id`+`author_order`) → `uq_book_authors_order`. Orden de imagen duplicado → `uq_book_images_order` (encontrado incidentalmente durante CP-17, mismo error real). Segunda portada: al marcar una segunda imagen del mismo libro con `is_cover=true`, el trigger `trg_book_images_single_cover` desmarcó automáticamente la portada anterior (confirmado con `SELECT` antes/después: la imagen 2 pasó de `true` a `false` y la 1 a `true`, nunca dos en `true` a la vez). Cascada de borrado: se tomó el libro real "Cloud Computing: Concepts, Technology & Architecture" (3 autores, 2 géneros, 10 conceptos, 2 imágenes) y se ejecutó `DELETE FROM books WHERE book_id=29`; las cuatro tablas puente quedaron en 0 filas para ese `book_id` inmediatamente. **Nota de honestidad del proceso**: este libro es el que el enunciado pide explícitamente para los conceptos de Cloud Computing (Parte 5, punto 15), así que se restauró de inmediato con los mismos datos exactos de `db/02_seed_30_per_table.sql` (mismo ISBN, autores, géneros, conceptos e imágenes) antes de continuar; el conteo final de libros volvió a 30. Estado: `PASSED` — todos los sub-casos verificados con evidencia real.
- Evidencia requerida: códigos SQLSTATE y conteos dentro de transacción revertida.

### CP-19 — CSRF ausente o alterado (negativo)

- Requisito: RNF-04. Precondición: sesión autenticada.
- Entrada: POST/PUT/DELETE sin token y token modificado.
- Pasos: enviar solicitudes a libro/usuario/logout.
- Resultado esperado: HTTP 403, vista genérica y cero cambios.
- Resultado observado: ejecutado el 2026-08-31 por HTTP real, con sesión de administrador válida. `POST /library/books` sin campo `_csrf` → `403` ("El formulario expiró o no es válido."). `POST /library/books` con un token `_csrf` inventado (64 caracteres hexadecimales que no coinciden con el de la sesión) → `403`. `SELECT count(*) FROM books WHERE isbn IN (...)` de los dos intentos confirmó `0`: ningún libro se creó en ninguno de los dos casos. Estado: `PASSED`.
- Evidencia requerida: códigos/respuestas y DB intacta. Falta la captura visual.

### CP-20 — Exclusión de secretos y entregables

- Requisito: RNF-05. Precondición: repositorio local.
- Entrada: rutas `.env`, `node_modules` y uploads.
- Pasos: ejecutar `git check-ignore`, `git ls-files` y revisar estado.
- Resultado esperado: `.env`, `node_modules` y uploads reales ignorados/no versionados; `.env.example` y `.gitkeep` sí pueden estar.
- Resultado observado: ejecutado el 2026-08-30. `.gitignore` reconoció las tres rutas; `git ls-files` confirmó que no hay `.env`, `node_modules` ni uploads reales versionados. Estado: `PASSED`.
- Evidencia requerida: salida de comandos sin contenido de `.env`.

### CP-21 — Verificación sintáctica Node.js

- Requisito: RNF-03, RNF-06. Precondición: Node.js y dependencias instaladas.
- Entrada: `npm run check` y `node --check` de rutas modificadas.
- Pasos: ejecutar desde `apps/web-monolito`.
- Resultado esperado: código 0, sin errores de sintaxis.
- Resultado observado: ejecutado el 2026-08-30. `npm.cmd run check`, la revisión `node --check` de todos los `.js` y la compilación de la plantilla EJS modificada terminaron con código 0. Estado: `PASSED`.
- Evidencia requerida: salida de consola y código de proceso.

### CP-22 — Despliegue bajo reverse proxy `/library`

- Requisito: RNF-05, RNF-06. Precondición: instancia GCP con Apache o NGINX, Node escuchando sólo en `127.0.0.1:3000` y configuración para el prefijo `/library`.
- Entrada: URL pública `/library`, rutas estáticas, formularios, sesión y upload ficticio.
- Pasos: abrir desde navegador externo; navegar login, catálogo y detalle; enviar formulario; cargar imagen; verificar redirecciones y confirmar que el puerto 3000 no es público.
- Resultado esperado: todas las funciones operan bajo el prefijo, recursos y redirecciones conservan rutas correctas, y sólo el reverse proxy expone la aplicación.
- Resultado observado: ejecutado el 2026-08-31. Instancia real `maquina-02` (CentOS Stream 10, GCP, IP externa `34.51.61.250`). Node corre como servicio `systemd` (`library-web.service`, habilitado, `Restart=on-failure`) escuchando solo en `127.0.0.1:3000` (verificado con `ss -tlnp`, antes escuchaba en `0.0.0.0`, ver ED-14). NGINX instalado y configurado (`/etc/nginx/default.d/library-proxy.conf`) con `location /library { proxy_pass http://127.0.0.1:3000; ... }` (requirió habilitar el booleano SELinux `httpd_can_network_connect`, ver ED-15). Verificado desde esta misma sesión, fuera de la VM, sin usar el navegador de la instancia: `curl http://34.51.61.250/library` devuelve `301` y `curl -L` renderiza el HTML real del catálogo (libros, portadas, enlaces `/library/...`). `curl http://34.51.61.250:3000/library` (puerto directo) ya no conecta. Regla de firewall `allow-library-http` (tcp:80) creada; la regla vieja `monolito-web` (tcp:3000 público) se eliminó (verificado con `gcloud compute firewall-rules list`). **Corrección posterior (mismo día, reportada por el usuario)**: la CSP por defecto de Helmet enviaba `upgrade-insecure-requests`, lo que en un navegador real habría intentado recargar CSS/imágenes por HTTPS (inexistente en este despliegue, puerto 443 cerrado) y roto los estilos y assets bajo `/library`. Corregido desactivando únicamente esa directiva (`ENGINEERING_DECISIONS.md` ED-17); verificado con `curl -I` real que `/library` y `/library/css/app.css` ya no incluyen `upgrade-insecure-requests` en `Content-Security-Policy`, y que el resto de encabezados de Helmet sigue intacto. Estado: `PASSED` para acceso HTTP, estáticos y catálogo bajo `/library` desde un cliente externo. Pendiente por naturaleza: verificación desde un navegador real (captura de pantalla) y prueba de upload de imagen bajo el prefijo.
- Evidencia requerida: configuración redactada de Apache/NGINX, comandos de escucha/firewall y capturas externas explicadas. Configuración completa en `/etc/nginx/default.d/library-proxy.conf` y unidad en `/etc/systemd/system/library-web.service` (reproducidas en `docs/GCP_COMMANDS.md`).

## Evidencia externa pendiente por naturaleza

El funcionamiento completo requiere PostgreSQL con datos descartables y ejecución manual en navegador. Evidencia de GCP, HTTPS/proxy, permisos reales del rol PostgreSQL, screenshots de despliegue y controles de object storage no existe en el repositorio y no puede inferirse del código. La aplicación actual también debe verificarse y, probablemente, ajustarse para operar bajo el prefijo `/library`; este plan no afirma que ya lo soporte.
