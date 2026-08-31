# Revisión de seguridad

Alcance revisado: `data/schema.sql`, configuración, middleware, rutas, vistas, script de administrador, `.env.example`, `.gitignore` y README de `apps/web-monolito`. “Control actual” sólo describe controles visibles en esos archivos. La severidad residual es cualitativa y debe confirmarse en el entorno desplegado.

## SR-01. Contraseñas débiles o expuestas

- Amenaza e impacto: toma de cuentas y privilegios administrativos.
- Control actual: hashes bcrypt con costo 12; inputs nuevos exigen diez caracteres en HTML; `.env.example` usa valores demostrativos.
- Evidencia: `users/routes.js`, `auth/routes.js`, `scripts/create-admin.js`, `users/form.ejs`.
- Riesgo residual: **medio**. La longitud sólo se valida en navegador, no hay política server-side, rate limiting ni bloqueo; la contraseña demostrativa aparece también en documentación y podría copiarse.
- Recomendación: validar longitud y política en servidor, prohibir valores por defecto, añadir rate limiting y rotación/recuperación segura.

## SR-02. Secuestro o fijación de sesión

- Amenaza e impacto: suplantación de un usuario autenticado.
- Control actual: sesión en PostgreSQL, cookie `httpOnly`, `sameSite=lax`, `secure` en producción, expiración de ocho horas y regeneración al iniciar sesión.
- Evidencia: `app.js` y `auth/routes.js`.
- Riesgo residual: **medio**. Existe un secreto fallback conocido en desarrollo, no hay rotación explícita de CSRF después del login y `trust proxy=1` requiere proxy bien configurado.
- Recomendación: abortar el arranque sin `SESSION_SECRET` en todo entorno compartido, usar HTTPS, documentar proxy confiable y regenerar token CSRF con la sesión.

## SR-03. Evasión de autorización por rol

- Amenaza e impacto: un usuario común modifica catálogos, libros o usuarios.
- Control actual: las rutas de escritura usan `requireAdmin`; lectura de libros usa `requireUser`; EJS oculta acciones administrativas.
- Evidencia: `middleware/auth.js` y módulos `books`, `catalogs`, `people`, `users`.
- Riesgo residual: **medio**. El rol se conserva en la sesión y no se vuelve a consultar; una cuenta degradada puede mantener privilegios hasta expirar/cerrar sesión.
- Recomendación: invalidar sesiones al cambiar rol/estado o comprobar rol activo en base para operaciones sensibles.

## SR-04. SQL Injection

- Amenaza e impacto: lectura, alteración o borrado arbitrario de PostgreSQL.
- Control actual: valores de usuario se envían como `$1...$n`. Los identificadores dinámicos de catálogos/personas proceden de listas cerradas (`catalogs` y `entities`), no directamente del usuario. La nueva búsqueda también usa parámetros.
- Evidencia: todos los módulos de rutas y `create-admin.js`.
- Riesgo residual: **bajo**, sujeto a conservar las listas permitidas. No hay prueba automatizada que impida futuras interpolaciones inseguras.
- Recomendación: añadir revisión/lint de consultas y casos negativos con payloads de inyección.

## SR-05. Secretos y archivo `.env`

- Amenaza e impacto: filtración de credenciales de base, sesión o administrador.
- Control actual: `apps/web-monolito/.gitignore` excluye `.env`; sólo existe `.env.example` versionado.
- Evidencia: `.gitignore`, `.env.example`, resultado de `git check-ignore` registrado en el historial de cambios IA.
- Riesgo residual: **medio**. El ejemplo y README contienen la contraseña académica `library666`; no se verificaron gestores de secretos de GCP ni permisos reales del archivo desplegado.
- Recomendación: usar credenciales distintas por entorno, Secret Manager o archivo `0600`, y nunca almacenar la contraseña administrativa después de crearla.

## SR-06. Upload malicioso

- Amenaza e impacto: contenido activo, consumo de disco, sobrescritura o exposición pública.
- Control actual: Multer limita a 5 MB, acepta cuatro MIME declarados, genera nombre aleatorio y usa `basename` al borrar; el directorio ignora archivos subidos.
- Evidencia: `books/routes.js` y `.gitignore`.
- Riesgo residual: **alto**. Sólo se confía en `file.mimetype`; no se inspecciona firma real, dimensiones, contenido ni cuota. Los archivos se sirven desde el mismo origen y no hay antivirus.
- Recomendación: verificar magic bytes y decodificación, restringir dimensiones/cuotas, almacenar fuera del web root o en object storage con cabeceras seguras y analizar malware.

## SR-07. Validación server-side insuficiente

- Amenaza e impacto: datos inválidos, errores 500 y abuso de recursos.
- Control actual: PostgreSQL aplica `NOT NULL`, `CHECK`, FK y `UNIQUE`; Express limita formularios a 100 KB; algunos campos HTML tienen `required`, rangos y longitudes.
- Evidencia: `data/schema.sql`, `app.js` y vistas EJS.
- Riesgo residual: **alto**. Las rutas pasan numerosos campos al DB sin normalización ni mensajes por campo; no se exige al menos un autor/género y no hay límites server-side equivalentes para textos.
- Recomendación: validar tipos, longitudes, pertenencia de IDs y reglas de negocio antes de consultar, manteniendo restricciones DB como defensa final.

## SR-08. Divulgación mediante errores

- Amenaza e impacto: exposición de estructura interna o datos sensibles.
- Control actual: el cliente recibe mensajes genéricos y traducciones de códigos PostgreSQL; el detalle se escribe en consola.
- Evidencia: `middleware/errors.js`.
- Riesgo residual: **medio**. Los logs pueden contener consultas/datos y no hay política de redacción, correlación o retención; errores asíncronos deben confirmarse bajo Express 5.
- Recomendación: logging estructurado con redacción, ID de incidente y acceso restringido; no registrar secretos ni hashes.

## SR-09. Privilegios excesivos en PostgreSQL

- Amenaza e impacto: una inyección o cuenta comprometida controla esquema/base completa.
- Control actual: la aplicación usa el usuario configurado en `DATABASE_URL`.
- Evidencia: `config/db.js`, `.env.example`, README.
- Riesgo residual: **alto/desconocido**. No hay `GRANT`, `REVOKE`, roles separados ni evidencia de permisos efectivos en SQL.
- Recomendación: propietario separado para migraciones y rol runtime limitado a `SELECT/INSERT/UPDATE/DELETE` y secuencias necesarias; verificar con `information_schema`/`\dp`.

## SR-10. Regla de administrador único y disponibilidad

- Amenaza e impacto: escalamiento creando un segundo administrador o, en sentido contrario, bloqueo operativo si desaparece el único.
- Control actual: índice parcial único `uq_users_single_administrator`; UI impide borrar la propia cuenta activa.
- Evidencia: `data/schema.sql` y `users/routes.js`.
- Riesgo residual: **medio**. La base rechaza correctamente un segundo administrador, pero la aplicación no ofrece un mensaje específico; el administrador puede desactivarse o quitarse su rol, dejando cero administradores. `create-admin.js` puede restaurarlo sólo con acceso operativo y secretos.
- Recomendación: transacción y validación que eviten desactivar/degradar al último administrador, más procedimiento auditado de recuperación. Mantener “máximo uno” conforme al requisito.

## SR-11. CSRF y métodos mutables

- Amenaza e impacto: operaciones administrativas ejecutadas desde un sitio externo.
- Control actual: token aleatorio por sesión, comparación constante y verificación para POST/PUT/PATCH/DELETE; `sameSite=lax` complementa el control.
- Evidencia: `middleware/csrf.js` y formularios EJS.
- Riesgo residual: **bajo-medio**. El upload envía el token en query string, donde puede aparecer en logs.
- Recomendación: procesar multipart antes del control o usar cabecera/campo protegido para evitar tokens en URL; rotar tras autenticación.
