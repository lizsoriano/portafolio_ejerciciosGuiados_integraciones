# Historial de prompts de IA

## 2026-08-30 — Búsqueda parametrizada de libros

`docs/PROMPT_MAESTRO_IA.md` no existía al comenzar. El prompt exacto utilizado para la mejora fue el siguiente y posteriormente se conservó, sin cambiar su alcance, en `docs/PROMPT_MAESTRO_IA.md`:

> Trabaja únicamente sobre la aplicación existente en `apps/web-monolito`. Implementa una sola mejora pequeña y de bajo riesgo: agrega en `GET /books` una búsqueda server-side por título, ISBN o nombre completo del autor. Conserva Express, EJS, PostgreSQL y `pg`; no agregues API ni dependencias. Usa parámetros de PostgreSQL para todos los valores aportados por el usuario, conserva el listado completo cuando el término esté vacío, muestra el término y el número de resultados en la vista, y ofrece limpiar el filtro. Modifica sólo `apps/web-monolito/src/modules/books/routes.js` y `apps/web-monolito/src/views/books/index.ejs`. Verifica sintaxis y deja cualquier prueba que requiera PostgreSQL como pendiente si no hay conexión disponible.

Problema: el catálogo existente sólo ofrecía listado completo y el Trabajo en Casa exige cubrir búsqueda. Archivos previstos: los dos indicados. Riesgo: cambio limitado a lectura; coincidencias dependen de `ILIKE` y la configuración lingüística de PostgreSQL. Prueba prevista: sintaxis, inspección de parámetros y pruebas manuales con coincidencia, vacío, cero resultados e intento de SQL Injection.

Limitación de trazabilidad: como el archivo maestro no existía, no pudo leerse desde disco antes del cambio. Este historial conserva el prompt que sí se comunicó antes de modificar código; la creación posterior del archivo no se presenta como evidencia de un orden que no ocurrió.

## 2026-08-31 — Sesión con PostgreSQL/GCP real: ejecución, hallazgo y corrección de bugs reales

Esta sesión tuvo, por primera vez, acceso real a la instancia GCP (`maquina-02`) y a PostgreSQL en ejecución. El trabajo no fue una sola mejora aislada sino una secuencia de verificaciones reales que revelaron y corrigieron varios defectos concretos. Se documenta aquí como conjunto, con el prompt exacto que originó la corrección más acotada y verificable (la que mejor ejemplifica el ciclo completo de Tarea 2e), y un resumen trazable del resto.

### Mejora pequeña y verificable (ejemplo completo del ciclo Tarea 2e): CSP `upgrade-insecure-requests`

Prompt exacto recibido del usuario, después de verificar por su cuenta que `https://IP/library` no conectaba mientras `http://IP/library` sí:

> Confirmé que HTTPS NO está habilitado: [...] Revisa inmediatamente el CSP/Helmet. La aplicación está enviando `upgrade-insecure-requests`, pero el servidor actualmente solo está publicado por HTTP. Eso puede provocar que el navegador intente cargar CSS/assets por HTTPS y falle. Deshabilita únicamente la directiva `upgrade-insecure-requests` mientras este entorno opere por HTTP. No deshabilites Helmet ni todo CSP. Después reinicia el servicio y confirma [...] Finalmente verifica desde navegador externo que `/library` cargue CSS, imágenes y demás assets, y haz commit + push del fix.

- Problema: Helmet agrega `upgrade-insecure-requests` a la CSP por defecto; sin TLS configurado, esa directiva induciría a un navegador real a intentar recargar CSS/imágenes por HTTPS (puerto 443 cerrado) y fallar, aunque el HTML principal cargue bien por HTTP.
- Archivo modificado: únicamente `apps/web-monolito/src/app.js` (una línea: se agregó `"upgrade-insecure-requests":null` a las `directives` de `helmet()`).
- Riesgo introducido: ninguno nuevo — se retira una única directiva CSP que no tiene efecto útil en un despliegue sin TLS; el resto de Helmet (X-Frame-Options, nosniff, CSP restante) queda intacto.
- Pruebas ejecutadas: `curl -I` real, antes y después del cambio, contra `http://34.51.61.250/library` y `http://34.51.61.250/library/css/app.css`. Antes: la CSP incluía `upgrade-insecure-requests`. Después: ya no aparece, y el resto de encabezados de seguridad sigue idéntico; `GET .../css/app.css` sigue devolviendo `200` con el CSS real.
- Resultado: corregido, verificado, documentado en `docs/ENGINEERING_DECISIONS.md` ED-17, con commit y push reales a `origin/main`.

### Resto de correcciones reales de la sesión (resumen trazable)

Cada una siguió el mismo patrón real (problema detectado ejecutando algo de verdad → cambio mínimo → reejecución → verificación con `curl`/`psql` reales → commit). Detalle completo, con el prompt/contexto que originó cada una y la evidencia exacta, en `docs/ENGINEERING_DECISIONS.md` (ED-12 a ED-17) y `docs/PROGRESS.md`:

- **ED-12**: `books.price` aceptaba `0` (faltaba `CHECK`) — detectado al ejecutar por primera vez las pruebas negativas de integridad reales contra PostgreSQL.
- **ED-13**: las cookies de sesión no llegaban al cliente porque `NODE_ENV=production` en el `systemd` de despliegue forzaba `secure:true` sin TLS — detectado al intentar el primer login real por HTTP.
- **ED-14**: Node escuchaba en `0.0.0.0` en vez de `127.0.0.1` (incumplía la Parte 8 del enunciado) — detectado al revisar el firewall real del proyecto GCP.
- **ED-11 (actualización final)**: a petición explícita del usuario ("realiza el 1 y 2 para ya subirlo y lo de los stored procedures corrígelo"), se conectaron `POST /books`, `PUT /books/:id`, `POST /books/:id/concepts` y la portada de imágenes a sus procedimientos reales (`sp_create_book`, `sp_update_book`, `sp_upsert_book_concept`, `sp_set_book_cover_image`), probado de punta a punta por HTTP real contra `maquina-02`.
