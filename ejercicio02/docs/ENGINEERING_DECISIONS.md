# Registro de decisiones de ingeniería

Esquema usado en cada entrada: **Necesidad/problema → alternativas
consideradas → decisión tomada → justificación técnica → riesgo o
limitación → evidencia de validación.**

## ED-01. Macro-arquitectura monolítica

- **Necesidad/problema**: entregar un sistema de gestión de librería con
  SSR, CRUD normalizado, imágenes y control de acceso, para un equipo
  pequeño y un despliegue académico único.
- **Alternativas consideradas**: (a) monolito server-side; (b) frontend
  desacoplado (SPA) sobre un backend con API; (c) microservicios por
  dominio (catálogo, usuarios, imágenes).
- **Decisión tomada**: monolito server-side en Node.js/Express/EJS con
  acceso directo a PostgreSQL, organizado en módulos por dominio
  (`src/modules/{auth,books,catalogs,people,users}`).
- **Justificación técnica**: una sola unidad desplegable simplifica sesión,
  transacciones, seguridad y operación; el enunciado además prohíbe
  explícitamente API REST/GraphQL/SOAP y JSON/XML como contrato con el
  navegador, lo que descarta (b) y (c) por restricción, no sólo por
  preferencia.
- **Riesgo o limitación**: las rutas pueden acumular validación, SQL y
  control de flujo si no se disciplina la organización por módulos; un
  fallo de seguridad en el proceso afecta a toda la aplicación (una sola
  frontera de confianza).
- **Evidencia de validación**: ver `docs/ARCHITECTURE_MONOLITHIC.png` y el
  análisis completo de trade-offs en `docs/ARCHITECTURAL_EVALUATION.md`.

## ED-02. Acceso directo a PostgreSQL (sin ORM)

- **Necesidad/problema**: ejecutar CRUD normalizado y transacciones
  multi-tabla (libro + autores + géneros) de forma auditable y segura.
- **Alternativas consideradas**: (a) driver `pg` con SQL parametrizado
  explícito; (b) un ORM (Prisma, Sequelize, TypeORM); (c) un query builder
  (Knex).
- **Decisión tomada**: `pg` puro, con un módulo centralizado
  (`src/config/db.js`) que expone `pool` y un helper `transaction()`.
- **Justificación técnica**: el enunciado exige "acceso directo a
  PostgreSQL mediante el controlador pg y consultas SQL parametrizadas";
  un ORM añadiría una capa de abstracción y dependencias no requeridas
  para el alcance del ejercicio, y dificultaría demostrar que cada consulta
  está parametrizada explícitamente.
- **Riesgo o limitación**: sin un ORM, la disciplina de nunca concatenar
  SQL recae enteramente en cada ruta; no hay migraciones versionadas
  automáticas (se gestionan como scripts numerados en `db/`).
- **Evidencia de validación**: todas las consultas en
  `src/modules/**/routes.js` usan `$1…$n`; `docs/SECURITY_REVIEW.md` SR-04
  documenta el control y su riesgo residual.

## ED-03. Renderizado server-side con EJS

- **Necesidad/problema**: presentar la interfaz sin exponer una API ni usar
  JSON/XML como intercambio con el navegador.
- **Alternativas consideradas**: (a) EJS con HTML generado en el servidor;
  (b) un framework de frontend (React/Vue) consumiendo una API interna;
  (c) plantillas con un motor distinto (Pug, Handlebars).
- **Decisión tomada**: EJS, con vistas organizadas por módulo
  (`src/views/{books,catalogs,people,users,auth}`) y parciales comunes
  (`partials/header.ejs`, `partials/footer.ejs`).
- **Justificación técnica**: EJS permite HTML+JS mínimo, sin paso de
  compilación, y encaja de forma natural con Express; usar (b) violaría
  directamente la restricción arquitectónica del ejercicio (implicaría un
  contrato de datos tipo API).
- **Riesgo o limitación**: sin separación estricta de "lógica de
  presentación" hay riesgo de que una vista crezca con demasiada lógica
  condicional; se mitiga manteniendo las vistas sin SQL directo (las rutas
  ya resuelven los datos antes de renderizar).
- **Evidencia de validación**: `npm run check` compila y verifica sintaxis
  de rutas; inspección manual confirma que ninguna vista `.ejs` contiene
  una consulta SQL.

## ED-04. Claves primarias `GENERATED ALWAYS AS IDENTITY` (no UUID)

- **Necesidad/problema**: definir el tipo de clave primaria para las diez
  tablas del modelo normalizado.
- **Alternativas consideradas**: (a) `bigint GENERATED ALWAYS AS IDENTITY`;
  (b) `uuid` generado en la aplicación o con `gen_random_uuid()`.
- **Decisión tomada**: identidad numérica autoincremental (a) en todas las
  tablas.
- **Justificación técnica**: los identificadores numéricos son más
  legibles para depuración y pruebas manuales con `psql`, ocupan menos
  espacio en índices y FKs, y no requieren la extensión `pgcrypto`. El
  sistema no federa datos entre múltiples bases ni necesita generar IDs sin
  round-trip a la base.
- **Riesgo o limitación**: los IDs son predecibles/enumerables; no es un
  riesgo relevante aquí porque toda ruta de lectura ya exige autenticación
  (`requireUser`) y las de escritura exigen `requireAdmin`.
- **Evidencia de validación**: `db/01_schema.sql`; `db/02_seed_30_per_table.sql`
  resuelve todas sus relaciones por clave natural (isbn, nombre) en vez de
  asumir valores de identidad, precisamente para no depender de este detalle.

## ED-05. Regla "máximo un Administrador" en base de datos, no sólo en la app

- **Necesidad/problema**: el enunciado exige que exista como máximo un
  Administrador, de forma verificable y no evadible.
- **Alternativas consideradas**: (a) validarlo únicamente en la ruta de
  creación/edición de usuarios (capa de aplicación); (b) un índice único
  parcial `ON users ((is_admin)) WHERE is_admin`.
- **Decisión tomada**: (b), como defensa primaria, complementada por (a).
- **Justificación técnica**: un índice único parcial rechaza a nivel de
  PostgreSQL cualquier segundo `INSERT`/`UPDATE` con `is_admin = true`,
  sin importar qué proceso lo intente (aplicación, `psql`, un script). La
  validación en la aplicación sólo puede evitarlo si nadie la evade.
- **Riesgo o limitación**: el índice único evita un SEGUNDO administrador,
  pero no evita quedarse con CERO administradores activos. Esa regla
  simétrica se resolvió aparte (ver ED-06).
- **Evidencia de validación**: CP-14 en `docs/TEST_PLAN.md`; comentario y
  definición del índice en `db/01_schema.sql`.

## ED-06. Protección del último Administrador activo mediante trigger

- **Necesidad/problema**: `docs/SECURITY_REVIEW.md` (SR-10) documentó que
  nada impedía desactivar o degradar al único Administrador, dejando el
  sistema sin nadie con permisos administrativos.
- **Alternativas consideradas**: (a) validarlo sólo en la ruta de usuarios;
  (b) un procedimiento almacenado que la aplicación debería recordar
  llamar; (c) un trigger `BEFORE UPDATE OR DELETE` en `users` que bloquee
  la operación en la propia base de datos.
- **Decisión tomada**: (c) como defensa autoritativa
  (`trg_users_last_admin_guard`, `db/05_triggers.sql`), con (b) como
  procedimiento de conveniencia (`sp_set_user_role`, `db/04_stored_procedures.sql`)
  que ofrece el mismo chequeo con un mensaje más temprano.
- **Justificación técnica**: un trigger protege el invariante incluso ante
  un `UPDATE`/`DELETE` directo que no pase por la aplicación ni por el
  procedimiento; es la única opción que no depende de que cada punto de
  escritura recuerde aplicar la regla.
- **Riesgo o limitación**: el trigger añade una comprobación (`SELECT
  count(*)`) en cada `UPDATE`/`DELETE` sobre `users`, tabla de bajo volumen
  en este sistema, por lo que el costo es despreciable.
- **Evidencia de validación**: revisión estática de `db/05_triggers.sql`
  (sin PostgreSQL disponible en este entorno para ejecutarlo; queda como
  prueba pendiente marcada `PENDING` en `docs/TEST_PLAN.md`, CP-14 y CP-18).

## ED-07. Sesiones persistidas en PostgreSQL (`connect-pg-simple`)

- **Necesidad/problema**: mantener sesiones de usuario de forma segura y
  compatible con múltiples instancias del proceso Node si el despliegue
  llegara a replicarse.
- **Alternativas consideradas**: (a) sesión en memoria (`MemoryStore`); (b)
  `connect-pg-simple` sobre la misma base `library_db`; (c) un almacén
  externo como Redis.
- **Decisión tomada**: (b).
- **Justificación técnica**: evita introducir una dependencia de
  infraestructura adicional (Redis) para el alcance del ejercicio, reutiliza
  la misma base de datos ya disponible, y sobrevive a un reinicio del
  proceso Node (a diferencia de `MemoryStore`, que además no es apta para
  producción según la propia documentación de `express-session`).
- **Riesgo o limitación**: acopla la disponibilidad de sesiones a la
  disponibilidad de PostgreSQL; a la escala de este ejercicio es aceptable.
- **Evidencia de validación**: `src/app.js`, configuración de `session()`
  con `store: new pgSession(...)`.

## ED-08. Hash de contraseñas con bcrypt (costo 12)

- **Necesidad/problema**: nunca almacenar contraseñas en texto plano.
- **Alternativas consideradas**: (a) `bcrypt` costo 10 (valor por defecto
  común); (b) `bcrypt` costo 12; (c) `argon2`.
- **Decisión tomada**: (b), aplicado de forma consistente en
  `auth/routes.js`, `users/routes.js` y `scripts/create-admin.js`.
- **Justificación técnica**: costo 12 balancea resistencia a fuerza bruta
  con tiempo de cómputo aceptable para un sistema de bajo volumen de
  logins; `bcrypt` tiene soporte maduro en Node y ya era la dependencia
  elegida en el proyecto, evitando introducir `argon2` sin necesidad
  demostrada.
- **Riesgo o limitación**: costo 12 es más lento que 10 bajo carga alta de
  logins concurrentes; irrelevante para el volumen esperado del ejercicio.
- **Evidencia de validación**: hashes reales generados y verificados para
  `db/02_seed_30_per_table.sql` (`bcrypt.hash` + `bcrypt.compare` = `true`
  antes de insertarlos en el seed).

## ED-09. Imágenes en disco local con metadatos en PostgreSQL

- **Necesidad/problema**: permitir varias imágenes por libro, con una
  marcada como portada, sin exponer rutas internas ni aceptar el nombre de
  archivo del usuario.
- **Alternativas consideradas**: (a) `multer` con `diskStorage` en
  `public/uploads` + nombre aleatorio, referencia en `book_images.image_url`;
  (b) almacenamiento de objetos (bucket) externo.
- **Decisión tomada**: (a) para este ejercicio; (b) queda documentado como
  evolución razonable si el sistema creciera (ver
  `docs/ARCHITECTURAL_EVALUATION.md`).
- **Justificación técnica**: el enunciado no exige integración con
  almacenamiento de objetos; disco local + Express estático es suficiente y
  más simple de operar en una sola instancia GCP.
- **Riesgo o limitación**: `docs/SECURITY_REVIEW.md` SR-06 documenta el
  riesgo residual **alto**: sólo se valida `file.mimetype`, no la firma
  real del archivo (magic bytes).
- **Evidencia de validación**: `book_images` con `uq_book_images_single_cover`
  (índice parcial) + `trg_book_images_single_cover` (trigger) como defensa
  en profundidad; ver `db/01_schema.sql` y `db/05_triggers.sql`.

## ED-11. Procedimientos y vistas de `db/04`–`db/06`: de capa SQL paralela a conexión real en `routes.js`

- **Necesidad/problema**: el enunciado pide que el CRUD esté respaldado por
  procedimientos almacenados, triggers y vistas, no solo por sentencias SQL
  sueltas (Parte 5, punto 14).
- **Alternativas consideradas**: (a) reescribir cada ruta de escritura en
  `src/modules/books/routes.js` (y catalogs/people/users) para invocar
  `CALL sp_*(...)` en vez de sus `INSERT`/`UPDATE`/`DELETE` parametrizados
  actuales; (b) crear los procedimientos, triggers y vistas como una capa
  SQL completa y correcta que representa las mismas operaciones reales
  (mismas columnas, mismas reglas), documentando explícitamente a qué ruta
  equivale cada uno, sin modificar las rutas que ya funcionan.
- **Decisión tomada**: (b).
- **Justificación técnica**: este entorno de trabajo no tiene acceso a un
  PostgreSQL en ejecución (no hay `psql`, `docker` ni servidor disponible),
  por lo que cualquier cambio a las transacciones reales de `routes.js`
  (que sí funcionan hoy, verificadas manualmente por el usuario según
  `docs/AI_CHANGELOG.md`) no podría probarse antes de entregarse. Cambiar
  código de escritura sin poder ejecutarlo contra una base real viola la
  instrucción explícita de no reemplazar funcionalidad que ya funciona.
- **Riesgo o limitación**: esta es una desviación de una lectura estricta
  del enunciado, que puede interpretarse como "el CRUD debe invocar
  literalmente los procedimientos". Si se requiere esa integración
  literal, el trabajo pendiente es mecánico y acotado: reemplazar, por
  ejemplo, las líneas de `POST /books` y `PUT /books/:id` en
  `books/routes.js` por `CALL sp_create_book(...)`/`CALL sp_update_book(...)`
  (ver ejemplos de invocación comentados en `db/04_stored_procedures.sql`),
  y `books/index.ejs`/su ruta por una consulta a `v_book_catalog`
  (`db/06_views.sql`) — y validarlo contra PostgreSQL real antes de
  publicarlo.
- **Evidencia de validación**: cada procedimiento/trigger/vista documenta
  en un comentario a qué ruta o consulta real equivale (ver
  `db/04_stored_procedures.sql`, `db/05_triggers.sql`, `db/06_views.sql`);
  esto cumple la exigencia de que "correspondan a funcionalidades reales
  del sistema, no ejemplos desconectados" aunque la invocación desde Node
  quede pendiente de conectar y probar con PostgreSQL disponible.

**Actualización 2026-08-31 (sesión con PostgreSQL/GCP real disponible):**
esta decisión se revisó con acceso real a PostgreSQL en la instancia
`maquina-02`. Se resolvió parcialmente en el tiempo disponible antes de
la entrega:

- **Vistas: conectadas.** `GET /books` (`apps/web-monolito/src/modules/books/routes.js`)
  ahora consulta `v_book_catalog` en vez de repetir el JOIN manual.
  Probado end-to-end vía HTTP real (sesión admin autenticada por curl,
  cookies + token CSRF reales) contra la base ya poblada: el listado
  devuelve las filas esperadas, incluyendo "Cloud Computing: Concepts,
  Technology & Architecture".
- **Procedimientos: ahora conectados a las rutas de escritura reales.**
  Con más tiempo disponible en una sesión posterior, se completó la
  integración literal que el riesgo residual de arriba dejaba pendiente:
  - `POST /books` (crear) invoca `CALL sp_create_book(...)`.
  - `PUT /books/:id` (editar) invoca `CALL sp_update_book(...)`.
  - `POST /books/:id/concepts` invoca `CALL sp_upsert_book_concept(...)`.
  - `PUT /books/:id/images/:imageId`, cuando se marca portada, invoca
    `CALL sp_set_book_cover_image(...)` (el resto de metadatos —
    `alt_text`/`display_order`— sigue con `UPDATE` parametrizado directo,
    ya que el procedimiento solo cubre la exclusividad de portada).
  Cada `CALL` usa casts explícitos por parámetro (`::varchar`,
  `::smallint`, `::bigint[]`, etc.) siguiendo el patrón que documenta
  ED-16 para que PostgreSQL resuelva la sobrecarga correctamente,
  incluyendo el placeholder `NULL::bigint` para el parámetro `OUT` de
  `sp_create_book`.
- **Triggers: conectados de facto**, sin cambios de código: se disparan
  automáticamente en cualquier INSERT/UPDATE/DELETE sobre las tablas
  reales.
- **Evidencia de validación de la conexión completa**: probado de punta
  a punta por HTTP real (sesión admin, cookies + CSRF reales) contra
  `maquina-02`: se creó un libro con 2 autores y 1 género vía
  `sp_create_book` (orden de autoría correcto en `book_authors`); se
  editó reemplazando autores/géneros vía `sp_update_book`; se agregó un
  concepto vía `sp_upsert_book_concept`; se subieron dos imágenes y se
  cambió la portada de una a otra vía `sp_set_book_cover_image`,
  confirmando con `SELECT` que la exclusividad de portada se mantuvo
  (una sola fila con `is_cover=true`). Se verificó además que la
  restricción `uq_book_images_order` sigue rechazando correctamente un
  orden duplicado con un mensaje seguro (sin stack trace), y que el
  registro de prueba se eliminó sin dejar residuos (conteo final: 30
  libros, sin huérfanos en `uploads/`).
- **Riesgo residual**: ninguno pendiente de esta decisión — las cuatro
  rutas de escritura de `books` mencionadas en el enunciado (Parte 5,
  punto 14) ya invocan sus procedimientos correspondientes. Las rutas de
  `catalogs`, `people` y `users` siguen con SQL parametrizado directo
  (no tienen procedimientos equivalentes en `db/04`, por diseño: son
  operaciones de una sola tabla sin lógica multi-paso que justifique un
  procedimiento).

## ED-12. Corrección: `books.price` aceptaba 0 (faltaba CHECK de precio positivo)

- **Necesidad/problema**: al ejecutar por primera vez la prueba negativa
  de integridad "precio inválido" (Parte 3, punto 8 del enunciado) contra
  PostgreSQL real, `INSERT INTO books (..., price, ...) VALUES (..., 0, ...)`
  se aceptó sin error.
- **Alternativas consideradas**: (a) dejarlo así, ya que `0` no es
  negativo y la restricción original (`ck_books_price_nonnegative CHECK
  (price >= 0)`) técnicamente se cumplía; (b) corregir la restricción a
  `price > 0`, ya que un libro con precio cero no es un dato de catálogo
  válido y el enunciado exige explícitamente poder demostrar el rechazo
  de "precio inválido".
- **Decisión tomada**: (b). Se renombró la restricción a
  `ck_books_price_positive CHECK (price > 0)` en `db/01_schema.sql` y en
  `data/schema.sql` (se mantienen sincronizados, ver sección 1 del
  handoff de la sesión anterior).
- **Justificación técnica**: el enunciado pide poder ejecutar y mostrar
  el rechazo real de un precio inválido; `price >= 0` no lo permitía
  demostrar porque `0` no viola esa condición.
- **Riesgo o limitación**: ninguno para los datos actuales — los 30
  libros del seed tienen precios entre $179 y $899, todos mayores a
  cero, así que el cambio no rompe el seed existente.
- **Evidencia de validación**: aplicado en vivo contra `library_db` en
  `maquina-02` con `ALTER TABLE books DROP CONSTRAINT
  ck_books_price_nonnegative, ADD CONSTRAINT ck_books_price_positive
  CHECK (price > 0);`. Reintento posterior de
  `INSERT ... VALUES (..., 0, ...)` produjo el error real:
  `ERROR: new row for relation "books" violates check constraint
  "ck_books_price_positive"`.

## ED-13. Corrección: `NODE_ENV=production` en `systemd` anulaba las cookies de sesión sobre HTTP simple

- **Necesidad/problema**: al probar el login por primera vez contra la
  aplicación real desplegada (vía `curl` con manejo de cookies y token
  CSRF), el servidor nunca enviaba el encabezado `Set-Cookie`, por lo que
  ninguna sesión persistía entre solicitudes — el login parecía
  "funcionar" (redirigía) pero ninguna ruta protegida reconocía al
  usuario después.
- **Alternativas consideradas**: (a) sospechar de un bug en
  `express-session`/Express 5 y reescribir el manejo de sesión; (b)
  aislar la causa con una serie de reproducciones mínimas (app real
  aislada en un puerto de prueba) antes de tocar código de aplicación.
- **Decisión tomada**: (b). Se probó el archivo real `src/app.js` fuera
  de `systemd`, en un puerto aparte, y el `Set-Cookie` SÍ aparecía. Eso
  aisló el problema al entorno de ejecución, no al código: el archivo de
  unidad `/etc/systemd/system/library-web.service` creado en esta misma
  sesión fijaba `Environment=NODE_ENV=production`, y como la app llama a
  `require('dotenv').config()` sin `{override:true}`, una variable de
  entorno ya presente en el proceso (la de `systemd`) tiene prioridad
  sobre el valor de `.env`. Con `NODE_ENV=production`, la cookie de
  sesión se configura con `secure:true`
  (`apps/web-monolito/src/app.js`), y `express-session` deliberadamente
  omite el `Set-Cookie` cuando la conexión no es HTTPS y la cookie pide
  `secure` — no hay TLS configurado en esta instancia y el enunciado
  publica la evidencia sobre `http://IP/library`, no HTTPS.
- **Justificación técnica**: el enunciado no exige HTTPS/TLS para este
  ejercicio (los ejemplos de URL de la Parte 8 son `http://`); forzar
  `secure:true` sin TLS rompe la sesión para cualquier usuario real, no
  solo para las pruebas.
- **Riesgo o limitación**: si en el futuro se agrega TLS real (por
  ejemplo, para la publicación en `ubiquitous.udem.edu`), esta decisión
  debe revisarse y `NODE_ENV=production` (o una variable dedicada) debe
  volver a poner `secure:true`.
- **Evidencia de validación**: se eliminó la línea
  `Environment=NODE_ENV=production` de `library-web.service`, se
  recargó `systemd` y se repitió la prueba: `Set-Cookie` aparece, y un
  flujo completo de login con `curl` (cookies + CSRF reales) contra
  `admin.biblioteca@example.com` devolvió una sesión que la ruta
  protegida `/library/` reconoció ("Administrador General", enlace
  "Salir").

## ED-14. Corrección: Node escuchaba en todas las interfaces, no solo en `127.0.0.1`

- **Necesidad/problema**: el enunciado exige explícitamente (Parte 8,
  punto 19) que Node "deberá escuchar en 127.0.0.1:3000 y no exponerse
  directamente a Internet". `apps/web-monolito/src/server.js` llamaba a
  `app.listen(port, callback)` sin especificar host, que en Node hace
  que Express escuche en `0.0.0.0` (todas las interfaces) por defecto.
  Además, ya existía una regla de firewall de GCP (`monolito-web`) que
  abría el puerto 3000 a `0.0.0.0/0`, es decir, la aplicación era
  alcanzable directamente desde Internet sin pasar por el reverse proxy.
- **Alternativas consideradas**: (a) dejarlo así y confiar solo en el
  firewall de GCP para bloquear el acceso directo; (b) corregir el
  binding de Node a nivel de aplicación (`127.0.0.1` explícito) además
  de ajustar el firewall, como defensa en profundidad.
- **Decisión tomada**: (b).
- **Justificación técnica**: depender solo del firewall de un proveedor
  cloud específico ata la seguridad de la aplicación a la configuración
  de infraestructura de un entorno particular; el enunciado pide que la
  propia aplicación no se exponga, no solo que el firewall la oculte.
- **Riesgo o limitación**: ninguno — el desarrollo local sigue
  funcionando igual (`127.0.0.1` es el comportamiento esperado también
  para pruebas locales).
- **Evidencia de validación**: se agregó `const host=process.env.HOST||'127.0.0.1'`
  y se pasó a `app.listen(port,host,...)` en `server.js`. Verificado con
  `sudo ss -tlnp | grep 3000` en `maquina-02`, que muestra
  `LISTEN 127.0.0.1:3000` (antes mostraba `0.0.0.0:3000`). Se creó
  además la regla de firewall `allow-library-http` (tcp:80, para NGINX)
  y se eliminó la regla vieja `monolito-web`: con Node ligado a
  `127.0.0.1`, `curl` externo al puerto 3000 ya no conectaba
  (`curl: (7) Failed to connect`), confirmado desde fuera de la VM antes
  de borrar la regla, y `gcloud compute firewall-rules list` confirma que
  ya no existe. El firewall del proyecto solo permite 80 (HTTP/NGINX),
  443, 22, RDP e ICMP por defecto — ningún acceso directo a Node.

## ED-15. Despliegue real: `systemd` + NGINX como reverse proxy en `/library`

- **Necesidad/problema**: publicar la aplicación bajo `/library` detrás
  de un reverse proxy real (Parte 8), con Node corriendo de forma
  persistente (no un proceso manual que muera al cerrar la terminal).
- **Alternativas consideradas**: (a) ejecutar `node src/server.js` en
  segundo plano con `nohup`/`&`; (b) crear un servicio `systemd`
  administrado (arranque automático, reinicio ante fallos, logs vía
  `journalctl`); para el proxy, (c) Apache httpd o (d) NGINX.
- **Decisión tomada**: (b) para el proceso Node, (d) NGINX para el
  proxy — ya que CentOS Stream 10 no traía ninguno de los dos
  instalado y NGINX tiene menos piezas móviles para un solo
  `location /library`.
- **Justificación técnica**: `systemd` da reinicio automático
  (`Restart=on-failure`) y arranque en boot (`enable`), sin necesitar
  intervención manual tras un reinicio de la instancia — más cercano a
  un despliegue real que un proceso en primer plano.
- **Riesgo o limitación**: NGINX necesitó habilitar el booleano SELinux
  `httpd_can_network_connect` (estaba en `off`), sin el cual devolvía
  `502 Bad Gateway` al intentar conectar con el backend Node incluso
  con la configuración de proxy correcta. Es el booleano estándar para
  cualquier reverse proxy NGINX en un sistema con SELinux en modo
  `Enforcing` (confirmado con `getenforce`), no una relajación de
  seguridad fuera de lo normal para este caso de uso.
- **Evidencia de validación**: `curl http://127.0.0.1/library` (vía
  NGINX) y `curl http://34.51.61.250/library` (IP pública, sin
  navegador) devuelven HTTP 301/200 con el HTML real renderizado por
  Express, incluyendo el catálogo con libros reales
  (`/library/uploads/seed/...`, "Cloud Computing: Concepts, Technology
  & Architecture", etc.). El puerto 3000 no es alcanzable externamente
  (ver ED-14). El servicio sobrevive a `systemctl restart` y está
  habilitado (`systemctl enable`) para sobrevivir a un reinicio de la
  instancia.

## ED-16. Sintaxis correcta para invocar procedimientos con parámetro `OUT` desde `psql`

- **Necesidad/problema**: al validar `sp_create_book` (que declara
  `OUT p_book_id bigint`) directamente por `psql`, `CALL
  sp_create_book(...)` fallaba repetidamente con "procedure ... does not
  exist" pese a que los tipos de los argumentos de entrada eran
  correctos.
- **Decisión/hallazgo**: PostgreSQL exige que la posición del parámetro
  `OUT` se incluya explícitamente en la lista de argumentos del `CALL`
  (como un valor cualquiera, típicamente `NULL`, con cast explícito al
  tipo declarado) para que la resolución de sobrecarga encuentre el
  procedimiento; los parámetros posicionales anteriores también deben
  llevar cast explícito cuando el tipo inferido del literal no coincide
  exactamente (`integer` vs. `bigint`, `integer` vs. `smallint`).
- **Evidencia de validación**: la llamada que finalmente funcionó fue
  `CALL sp_create_book('9780000000000'::varchar,'...'::varchar,
  2020::smallint,50.00::numeric,3::integer,1::bigint,1::bigint,
  ARRAY[1]::bigint[],ARRAY[1]::bigint[],NULL::bigint);`, que devolvió el
  `book_id` real generado. Documentado aquí para que una futura conexión
  de `routes.js` a los procedimientos (ED-11) no repita la misma
  investigación.

## ED-10. Prefijo `/library` mediante `BASE_PATH`, no reescritura de HTML

- **Necesidad/problema**: el enunciado exige publicar la aplicación bajo
  `http://IP/library` mediante un reverse proxy (Apache/NGINX), pero todas
  las rutas, formularios y recursos estáticos de las vistas EJS usan rutas
  absolutas (`/books`, `/css/app.css`, etc.), que se rompen bajo un
  prefijo si el proxy sólo reenvía la petición.
- **Alternativas consideradas**: (a) que NGINX reescriba el HTML de salida
  (`sub_filter`) para insertar el prefijo; (b) variable de entorno
  `BASE_PATH` que la aplicación usa para montar el router y para construir
  toda URL en las vistas; (c) no dar soporte al prefijo y desplegar en la
  raíz del dominio.
- **Decisión tomada**: (b). `BASE_PATH` vacío por defecto (comportamiento
  actual sin cambios); en producción se define `BASE_PATH=/library`.
- **Justificación técnica**: (a) es frágil (depende de que el HTML no
  cambie de forma que rompa el filtro, y no cubre cabeceras de
  redirección); (c) incumple un requisito explícito del enunciado. (b) es
  la única opción que cubre rutas, formularios, estáticos y
  redirecciones (`res.redirect`) de forma consistente.
- **Riesgo o limitación**: cada vista que construye una URL absoluta debe
  usar la variable `basePath` inyectada en `res.locals`; un olvido futuro
  rompería un enlace bajo `/library` sin romper nada en desarrollo local
  (`BASE_PATH` vacío), lo que puede ocultar el error hasta el despliegue.
- **Evidencia de validación**: ver CP-22 en `docs/TEST_PLAN.md` (pendiente,
  requiere una instancia real con reverse proxy) y el detalle de la
  implementación en `apps/web-monolito/README.md`.

## ED-17. Corrección: CSP enviaba `upgrade-insecure-requests` sin tener HTTPS disponible

- **Necesidad/problema**: verificación externa post-despliegue (usuario,
  2026-08-31) detectó que `https://34.51.61.250/library/css/app.css` no
  conecta (`curl: (7) Failed to connect`, puerto 443 cerrado — no hay TLS
  configurado en esta instancia), mientras que `http://` sí responde
  `200`. La configuración por defecto de Helmet agrega la directiva CSP
  `upgrade-insecure-requests`, que le indica al navegador que reescriba
  toda solicitud HTTP del sitio a HTTPS automáticamente. Con esa
  directiva activa, un navegador real visitando `http://34.51.61.250/library`
  intentaría cargar CSS, imágenes y demás recursos por HTTPS y fallaría,
  incluso aunque el HTML principal cargó por HTTP.
- **Alternativas consideradas**: (a) desactivar Helmet o todo el CSP
  para evitar el problema; (b) desactivar únicamente la directiva
  `upgrade-insecure-requests`, dejando el resto de CSP y todas las demás
  protecciones de Helmet intactas.
- **Decisión tomada**: (b).
- **Justificación técnica**: apagar Helmet completo eliminaría
  protecciones reales (X-Frame-Options, nosniff, etc.) por un problema
  que solo afecta a una directiva específica y solo mientras no haya
  TLS. `upgrade-insecure-requests` no tiene efecto útil en un despliegue
  que el propio enunciado publica sobre `http://IP/library` (Parte 8),
  y aquí activamente rompía la carga de assets.
- **Riesgo o limitación**: si en el futuro se agrega TLS real a esta
  instancia (por ejemplo para la publicación en `ubiquitous.udem.edu`,
  si esa infraestructura sí tiene HTTPS), esta directiva debería
  reactivarse quitando el `null` explícito, de forma simétrica a como
  ED-13 documenta revisar `NODE_ENV`/cookies `secure` en ese mismo
  escenario.
- **Evidencia de validación**: se cambió
  `helmet({contentSecurityPolicy:{directives:{"img-src":[...]}}})` a
  `helmet({contentSecurityPolicy:{directives:{"img-src":[...],
  "upgrade-insecure-requests":null}}})` en
  `apps/web-monolito/src/app.js`. Verificado con `curl -I` real, antes y
  después, contra `http://34.51.61.250/library` y
  `http://34.51.61.250/library/css/app.css`: el encabezado
  `Content-Security-Policy` de la respuesta ya no contiene
  `upgrade-insecure-requests`, mientras que el resto de las directivas
  (`default-src 'self'`, `script-src 'self'`, `object-src 'none'`, etc.)
  y el resto de encabezados de Helmet (`X-Frame-Options`,
  `X-Content-Type-Options`, `Cross-Origin-Opener-Policy`, etc.) siguen
  presentes sin cambios. `GET /library/css/app.css` sigue devolviendo
  `200` con el CSS real.
- **Nota relacionada, no aplicada todavía**: la misma verificación mostró
  que Helmet también envía `Strict-Transport-Security` (HSTS) sobre este
  despliegue HTTP-only. Un navegador real debería ignorar ese encabezado
  llegar por una conexión no segura (la especificación HSTS exige HTTPS
  para que el encabezado tenga efecto), pero es una
  inconsistencia similar a la de `upgrade-insecure-requests`; queda
  fuera del alcance de esta corrección puntual porque no se reportó
  como bloqueante y no se pidió explícitamente desactivarla.

## ED-18. Corrección: la subida de imágenes rechazaba siempre el CSRF (403)

- **Necesidad/problema**: al ejecutar por primera vez una prueba real de
  subida de imagen (CP-16 del `TEST_PLAN.md`), `POST /books/:id/images`
  con un formulario `multipart/form-data` real (archivo + token CSRF
  válido) devolvía `403 "El formulario expiró o no es válido"` siempre,
  sin importar que el token fuera correcto.
- **Causa raíz**: el middleware global `csrf` (`router.use(csrf)` en
  `app.js`) corre para todas las rutas, incluida `/books/:id/images`,
  **antes** de que Multer (`upload.single('image')`, registrado solo en
  esa ruta específica) parsee el cuerpo `multipart/form-data`. En ese
  momento, `req.body` está vacío (`express.urlencoded` no entiende
  multipart), así que `req.body._csrf` es `undefined` y la validación
  siempre falla, sin importar el token real enviado por el formulario.
- **Alternativas consideradas**: (a) mover Multer a nivel de router
  global antes del CSRF, para que todas las rutas tengan `req.body`
  parseado uniformemente; (b) omitir la validación de CSRF en el
  middleware global cuando la solicitud es `multipart/form-data`, y
  validar el token manualmente dentro de la propia ruta de subida,
  después de que Multer ya corrió.
- **Decisión tomada**: (b).
- **Justificación técnica**: (a) aplicaría Multer a rutas que no lo
  necesitan (costo y superficie de cambio innecesarios); (b) es un
  cambio mínimo y localizado que preserva la protección CSRF completa
  (nunca se deja de validar, solo se mueve el punto de validación al
  momento en que el dato ya existe).
- **Riesgo o limitación**: cualquier ruta futura que reciba
  `multipart/form-data` debe recordar llamar a `csrf.isValid(req)`
  manualmente después de su middleware de Multer; si se agrega una ruta
  así sin ese paso, quedaría sin protección CSRF. Se documenta aquí
  explícitamente para que no se repita el olvido.
- **Evidencia de validación**: `csrf.js` ahora expone `csrf.isValid(req)`
  y se salta la validación automática solo cuando `req.is('multipart/form-data')`.
  `books/routes.js` llama a `csrf.isValid(req)` explícitamente al inicio
  del handler de `POST /:id/images`, después de que `upload.single('image')`
  ya corrió, y limpia el archivo temporal si el token es inválido.
  Verificado con `curl` real contra `maquina-02`: antes del fix,
  `upload_valido=403` con token correcto; después del fix,
  `upload_valido=302` con la fila real insertada en `book_images`. Se
  repitió también la prueba con CSRF ausente/alterado sobre rutas no
  multipart (`POST /books` sin token y con token alterado) para
  confirmar que la protección normal sigue intacta: ambas `403`, cero
  filas creadas (ver CP-19 en `TEST_PLAN.md`).
