# Requisitos — Aplicación web monolítica para gestión de una librería

Alcance: sistema monolítico server-side (Node.js + Express + EJS) con acceso
directo a PostgreSQL, sin API REST/GraphQL/SOAP ni intercambio JSON/XML entre
frontend y backend (restricción explícita del enunciado del Ejercicio Guiado
02, Parte 1). Los códigos RF-xx/RNF-xx de este documento son los mismos que
usan `docs/TEST_PLAN.md` y `docs/SECURITY_REVIEW.md`; no se introduce una
numeración distinta.

## Supuestos

- PostgreSQL 13+ ya instalado y accesible; usuario `library_user`, base
  `library_db` (ver `db/00_create_database.sql` y `apps/web-monolito/README.md`).
- Node.js 20+ disponible en el entorno de despliegue.
- Existe como máximo un Administrador en todo momento (regla de negocio
  explícita del enunciado, no solo una convención de la interfaz).
- Las imágenes se almacenan en disco local (`public/uploads`); la base de
  datos guarda únicamente la referencia (`image_url`) y sus metadatos.

## Restricciones

- No se implementan APIs REST/GraphQL/SOAP ni microservicios.
- No se usa JSON ni XML como mecanismo de intercambio con el navegador; los
  formularios HTML envían los datos directamente al monolito.
- Todo acceso a datos usa consultas parametrizadas con `pg`; está prohibido
  concatenar valores de usuario dentro de una sentencia SQL.
- `package.json` existe únicamente porque npm lo requiere para administrar
  el proyecto (no implica exponer un paquete ni una API pública).

## Actores

| Actor | Puede | No puede |
|---|---|---|
| Visitante (sin sesión) | Ver `/`, acceder a `/auth/login` | Consultar el catálogo (`/books`), ejecutar cualquier CRUD, ver `/users`, `/catalogs`, `/manage/*` |
| Usuario registrado activo | Iniciar/cerrar sesión, consultar y buscar el catálogo, ver el detalle de un libro con sus conceptos | Crear/editar/eliminar libros, catálogos, personas, usuarios ni imágenes |
| Administrador | Todo lo del Usuario registrado, más CRUD completo de libros, autores, géneros, formatos, categorías, conceptos, imágenes y usuarios | Existir como un segundo administrador simultáneo (bloqueado también en base de datos) |

La distinción autenticación/autorización se implementa con dos middleware
independientes: `requireUser` (¿hay sesión?) y `requireAdmin` (¿el usuario de
la sesión tiene `is_admin = true`?) — ver
`apps/web-monolito/src/middleware/auth.js`.

## Riesgos iniciales identificados

1. Acceso no autorizado a rutas administrativas por un usuario regular o un
   visitante (mitigado por `requireAdmin`/`requireUser`; ver RF-04).
2. SQL Injection vía formularios (mitigado con consultas parametrizadas;
   ver RNF-01 y `docs/SECURITY_REVIEW.md` SR-04).
3. Subida de archivos peligrosos disfrazados de imagen (ver RF-06 y
   `docs/SECURITY_REVIEW.md` SR-06).
4. Exposición de credenciales (`.env`, contraseña de administrador) en el
   repositorio o en la publicación final (ver RNF-05 y SR-05).
5. Eliminación accidental de información referenciada (mitigado con
   `ON DELETE RESTRICT` en catálogos y autores/géneros; ver RNF-02).
6. Publicación de datos sensibles (hashes, tokens de sesión) en evidencia o
   capturas de pantalla (ver `docs/TEST_PLAN.md`, criterio de evidencia).
7. El sistema queda sin ningún Administrador activo tras una desactivación o
   degradación de rol (riesgo residual SR-10 en `docs/SECURITY_REVIEW.md`,
   mitigado por `trg_users_last_admin_guard` en `db/05_triggers.sql`).

## Requisitos funcionales

### RF-01 — Autenticación (registro implícito por Administrador, login, logout)

El sistema permite iniciar y cerrar sesión con correo y contraseña. Las
cuentas las crea el Administrador (no hay autorregistro público, dado que
"sólo podrán ingresar usuarios registrados"). Las contraseñas se almacenan
con `bcrypt` (costo 12), nunca en texto plano.

- Criterio de aceptación: credenciales válidas y cuenta activa regeneran la
  sesión y redirigen a `/`; credenciales inválidas o cuenta inactiva
  devuelven HTTP 422 con un mensaje genérico idéntico en ambos casos; cerrar
  sesión destruye la sesión y las rutas protegidas vuelven a exigir login.

### RF-02 — Consulta, búsqueda y navegación del catálogo

Un usuario autenticado puede listar el catálogo completo y buscar por
título, ISBN o nombre de autor. La navegación se sirve como HTML renderizado
en el servidor (SSR), sin fragmentos JSON.

- Criterio de aceptación: `GET /books` sin término lista todo el catálogo;
  con término, sólo las coincidencias por título/ISBN/autor (`ILIKE`,
  parametrizado); limpiar el filtro recupera el listado completo; una ruta
  inexistente responde 404 renderizado en HTML.

### RF-03 — CRUD completo sobre el modelo normalizado

El Administrador puede crear, leer, actualizar y eliminar registros de
`books`, `authors`, `genres`, `formats`, `categories`, `concepts` y `users`.
Cada operación de escritura pasa por validación server-side y por las
restricciones de PostgreSQL (`NOT NULL`, `CHECK`, `UNIQUE`, `FK`) como última
línea de defensa.

- Criterio de aceptación: cada tabla administrable tiene formulario de alta,
  edición y baja; una operación inválida (por ejemplo ISBN duplicado o FK
  inexistente) es rechazada por PostgreSQL y el usuario recibe un mensaje
  seguro, sin detalle interno.

### RF-04 — Autorización por rol

Toda ruta de escritura exige `requireAdmin`; la lectura del catálogo exige
`requireUser`; un usuario sin los permisos suficientes recibe una respuesta
controlada de acceso denegado (redirección con mensaje), nunca un error sin
manejar.

- Criterio de aceptación: un usuario regular que solicite una URL o envíe un
  POST/PUT/DELETE administrativo es redirigido sin que el dato cambie; un
  visitante sin sesión que solicite `/books` es redirigido a `/auth/login`.

### RF-05 — Relaciones libro–autor, libro–género y libro–concepto

Un libro puede tener varios autores (con orden de autoría) y varios géneros;
un mismo concepto puede aparecer en distintos libros con una definición
propia de cada par (libro, concepto).

- Criterio de aceptación: crear o editar un libro permite seleccionar varios
  autores y géneros a la vez; agregar una definición de concepto a un libro
  no afecta la definición del mismo concepto en otro libro (ver
  `db/02_seed_30_per_table.sql`, conceptos como "Distopía" o "Destino"
  reutilizados con texto distinto por libro).

### RF-06 — Gestión de imágenes

Un libro puede tener varias imágenes; como máximo una puede marcarse como
portada. Se validan extensión/MIME, tamaño máximo (5 MB) y el nombre de
archivo lo genera el sistema, nunca el valor enviado por el usuario.

- Criterio de aceptación: subir una imagen válida (JPEG/PNG/WebP/GIF, ≤5 MB)
  la asocia al libro; marcarla como portada desmarca cualquier portada
  previa del mismo libro (reforzado en `db/05_triggers.sql` y por el índice
  parcial `uq_book_images_single_cover` en `db/01_schema.sql`); un archivo
  con MIME no permitido o de mayor tamaño se rechaza sin dejar fila ni
  archivo huérfano.

### RF-07 — Usuarios y máximo un Administrador

El Administrador puede administrar cuentas de usuario (crear, editar,
activar/desactivar, eliminar). El sistema nunca permite un segundo
Administrador, y —regla simétrica documentada como riesgo SR-10— tampoco
debería quedar sin ningún Administrador activo.

- Criterio de aceptación: crear o promover un segundo usuario con
  `is_admin = true` falla por `uq_users_single_administrator`
  (SQLSTATE 23505); desactivar, degradar o eliminar al único administrador
  activo falla por `trg_users_last_admin_guard` (`db/05_triggers.sql`).

## Requisitos no funcionales

### RNF-01 — SQL parametrizado

Todo valor proporcionado por el usuario viaja como parámetro (`$1…$n`) del
driver `pg`; los únicos identificadores dinámicos (nombre de tabla/columna
en `catalogs`/`manage`) provienen de listas cerradas en el propio código,
nunca directamente del usuario.

### RNF-02 — Integridad y transacciones en PostgreSQL

Las operaciones que tocan varias tablas relacionadas (crear/editar un libro
con sus autores y géneros) se ejecutan dentro de una transacción
(`config/db.js: transaction()`), con `ROLLBACK` automático ante error. Las
restricciones de PostgreSQL (`PK`, `FK`, `UNIQUE`, `CHECK`) son la defensa
final incluso si la validación de la aplicación fallara.

### RNF-03 — Validación y manejo seguro de errores

Los formularios validan en el cliente (HTML5) y en el servidor; los errores
de PostgreSQL (`23505`, `23503`, `23514`, `22P02`) se traducen a mensajes
genéricos (`middleware/errors.js`) sin exponer SQL ni estructura interna.

### RNF-04 — Seguridad de sesión y CSRF

Sesión almacenada en PostgreSQL (`connect-pg-simple`), cookie `httpOnly`,
`sameSite=lax`, `secure` en producción, expiración de 8 horas y
regeneración al iniciar sesión. Todo POST/PUT/DELETE exige un token CSRF
por sesión.

### RNF-05 — Despliegue y manejo de secretos

`SESSION_SECRET`, credenciales de base de datos y credenciales del
Administrador viven únicamente en variables de entorno (`.env`, excluido de
git); sólo se versiona `.env.example` con nombres de variable, sin valores
reales. El usuario de PostgreSQL de la aplicación no es superusuario
(ver `db/00_create_database.sql`).

### RNF-06 — Navegabilidad SSR

Toda respuesta al navegador es HTML generado en el servidor (EJS); no existe
ningún endpoint que devuelva JSON/XML como contrato de datos con el cliente.
La aplicación debe seguir siendo navegable cuando se publica detrás de un
reverse proxy con prefijo `/library` (ver Parte 8 del enunciado).
