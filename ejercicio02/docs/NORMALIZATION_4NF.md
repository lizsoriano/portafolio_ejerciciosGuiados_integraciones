# Reporte de normalización hasta cuarta forma normal (4FN)

## Alcance y modelo comprobado

Este reporte describe exclusivamente `data/schema.sql`, esquema canónico usado por `apps/web-monolito`. El modelo real contiene `formats`, `categories`, `genres`, `authors`, `users`, `books`, `book_authors`, `book_genres`, `concepts`, `book_concepts` y `book_images`. No se proponen tablas adicionales.

La relación no normalizada de partida puede expresarse conceptualmente como `LIBRO(ISBN, título, año, precio, stock, formato, categoría, {autores}, {géneros}, {concepto, definición}, {imágenes})`. Las llaves entre llaves son grupos repetidos independientes; no representan una tabla existente.

## Dependencias identificadas

Dependencias funcionales relevantes:

- `ISBN → título, publication_year, price, stock, format_id, category_id`; `book_id` determina los mismos atributos por ser la clave sustituta y `isbn` es clave candidata (`UNIQUE`).
- `format_id → name, description`; `category_id → name, description`; `genre_id → name, description`.
- `author_id → first_name, last_name, biography, created_at, updated_at`.
- `concept_id → name`.
- `(book_id, author_id) → author_order` y `(book_id, author_order) → author_id` por las restricciones de `book_authors`.
- `(book_id, concept_id) → definition, created_at, updated_at`. La definición no depende sólo de `concept_id`, porque el mismo término puede definirse de forma diferente por libro.
- `image_id → book_id, image_url, alt_text, display_order, is_cover, created_at`; también `(book_id, image_url)` y `(book_id, display_order)` son claves candidatas.
- `user_id → email, password_hash, display_name, is_admin, is_active, created_at, updated_at`; `email` es clave candidata.

Dependencias multivaluadas del enunciado y del esquema:

- `book_id ↠ author_id`, independiente de géneros e imágenes.
- `book_id ↠ genre_id`, independiente de autores e imágenes.
- `book_id ↠ image` (cada imagen posee atributos propios).
- `book_id ↠ concept_id`, con el matiz de que `definition` depende funcionalmente del par libro–concepto.

## Evolución de la normalización

### Primera forma normal (1FN)

Para cumplir 1FN se eliminan listas como “autor1, autor2” y columnas repetidas como `imagen_1`, `imagen_2`. Cada celda conserva un valor atómico y cada registro se identifica mediante una clave. Los datos escalares del libro quedan en `books`; autores, géneros, conceptos e imágenes se representan en filas separadas.

### Segunda forma normal (2FN)

Las relaciones con clave simple ya satisfacen 2FN si todos sus atributos dependen de esa clave. En las relaciones compuestas, ningún atributo no clave debe depender sólo de una parte: `book_concepts.definition` necesita el par `(book_id, concept_id)`, y `book_authors.author_order` describe la participación del autor en ese libro. Los nombres del autor, género o concepto no se duplican en esas relaciones, sino que permanecen en sus tablas maestras.

### Tercera forma normal y BCNF

Se eliminan dependencias transitivas de `books`: los textos de formato y categoría no dependen directamente del libro, sino de `format_id` y `category_id`, por lo que viven en catálogos independientes. Lo mismo aplica a los datos de autores, géneros y conceptos. Las determinantes significativas son claves o claves candidatas respaldadas por PK/`UNIQUE`; por ello el diseño queda en BCNF para las dependencias funcionales descritas. `users` también separa autenticación del libro. El índice parcial `uq_users_single_administrator` expresa la regla global de como máximo un administrador, no una nueva dependencia del catálogo.

### Cuarta forma normal (4FN)

Guardar autores, géneros, conceptos e imágenes juntos produciría un producto cartesiano: dos autores por tres géneros por cuatro imágenes generarían 24 combinaciones y anomalías de inserción/borrado. Las dependencias multivaluadas independientes se descomponen sin pérdida:

- `book_authors` es la tabla puente muchos-a-muchos entre libros y autores; además conserva `author_order`.
- `book_genres` es la tabla puente muchos-a-muchos entre libros y géneros.
- `book_concepts` es la tabla puente muchos-a-muchos entre libros y conceptos y almacena `definition`, atributo propio de la asociación.
- `book_images` no es una puente entre dos entidades maestras: es una entidad dependiente uno-a-muchos del libro, necesaria porque cada imagen tiene URL, texto alternativo, orden y condición de portada. La FK con `ON DELETE CASCADE` refleja su dependencia de existencia.

Así, cada relación contiene una sola multivaluación relevante y el esquema satisface 4FN conforme a las dependencias conocidas. Las PK, FK, `CHECK`, `UNIQUE`, índices parciales y acciones `RESTRICT`/`CASCADE` de `data/schema.sql` preservan la integridad de esa descomposición.
