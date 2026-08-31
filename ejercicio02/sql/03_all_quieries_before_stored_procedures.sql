-- db/03_all_quieries_before_stored_procedures.sql
-- Consultas de referencia sobre el modelo ya poblado, previas a introducir
-- procedimientos almacenados (db/04), triggers (db/05) y vistas (db/06).
-- El nombre del archivo conserva la grafia usada en el enunciado del
-- ejercicio ("quieries").
--
-- Ejecutar conectado a library_db, con db/01_schema.sql y
-- db/02_seed_30_per_table.sql ya aplicados:
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/03_all_quieries_before_stored_procedures.sql
--
-- Cada consulta corresponde a una necesidad real de apps/web-monolito o de
-- administracion del catalogo; no son ejemplos desconectados del sistema.

-- =========================================================================
-- Q1. Catalogo completo de libros (equivalente a GET /books sin filtro,
--     ver apps/web-monolito/src/modules/books/routes.js).
-- =========================================================================
SELECT
    b.book_id, b.isbn, b.title, b.publication_year, b.price, b.stock,
    f.name AS format, c.name AS category,
    string_agg(DISTINCT concat_ws(' ', a.first_name, a.last_name), ', ') AS authors,
    (SELECT image_url FROM book_images WHERE book_id = b.book_id AND is_cover LIMIT 1) AS cover
FROM books b
JOIN formats f USING (format_id)
JOIN categories c USING (category_id)
LEFT JOIN book_authors ba USING (book_id)
LEFT JOIN authors a USING (author_id)
GROUP BY b.book_id, f.name, c.name
ORDER BY b.title;

-- =========================================================================
-- Q2. Busqueda por titulo, ISBN o autor (equivalente a GET /books?q=...).
--     En la aplicacion, "termino" viaja como parametro $1/$2 de pg, nunca
--     concatenado; aqui se fija un valor literal solo para poder ejecutar
--     la consulta de forma independiente.
-- =========================================================================
SELECT b.book_id, b.title, b.isbn,
       string_agg(DISTINCT concat_ws(' ', a.first_name, a.last_name), ', ') AS authors
FROM books b
LEFT JOIN book_authors ba USING (book_id)
LEFT JOIN authors a USING (author_id)
WHERE b.title ILIKE '%cien%'
   OR b.isbn ILIKE '%cien%'
   OR concat_ws(' ', a.first_name, a.last_name) ILIKE '%cien%'
GROUP BY b.book_id
ORDER BY b.title;

-- =========================================================================
-- Q3. Detalle de un libro: datos, autores, generos, conceptos e imagenes
--     (equivalente a GET /books/:id).
-- =========================================================================
SELECT b.*, f.name AS format, c.name AS category
FROM books b
JOIN formats f USING (format_id)
JOIN categories c USING (category_id)
WHERE b.isbn = '9780000000030';

SELECT a.*
FROM authors a
JOIN book_authors ba USING (author_id)
JOIN books b USING (book_id)
WHERE b.isbn = '9780000000030'
ORDER BY ba.author_order;

SELECT g.*
FROM genres g
JOIN book_genres bg USING (genre_id)
JOIN books b USING (book_id)
WHERE b.isbn = '9780000000030'
ORDER BY g.name;

SELECT cn.name AS concept, bc.definition
FROM concepts cn
JOIN book_concepts bc USING (concept_id)
JOIN books b USING (book_id)
WHERE b.isbn = '9780000000030'
ORDER BY cn.name;

SELECT image_url, alt_text, display_order, is_cover
FROM book_images bi
JOIN books b USING (book_id)
WHERE b.isbn = '9780000000030'
ORDER BY display_order;

-- =========================================================================
-- Q4. Libros con existencias bajas (umbral de reabastecimiento).
-- =========================================================================
SELECT title, isbn, stock
FROM books
WHERE stock <= 5
ORDER BY stock ASC;

-- =========================================================================
-- Q5. Autores con mas titulos publicados en el catalogo.
-- =========================================================================
SELECT concat_ws(' ', a.first_name, a.last_name) AS author, count(*) AS total_libros
FROM authors a
JOIN book_authors ba USING (author_id)
GROUP BY a.author_id
ORDER BY total_libros DESC, author;

-- =========================================================================
-- Q6. Conceptos que se repiten en mas de un libro con definicion propia
--     por libro (evidencia funcional de la 4FN: book_id,concept_id ->
--     definition, no concept_id -> definition).
-- =========================================================================
SELECT cn.name AS concept, b.title, bc.definition
FROM book_concepts bc
JOIN concepts cn USING (concept_id)
JOIN books b USING (book_id)
WHERE cn.concept_id IN (
    SELECT concept_id FROM book_concepts GROUP BY concept_id HAVING count(*) > 1
)
ORDER BY cn.name, b.title;

-- =========================================================================
-- Q7. Libros sin genero asignado (control de calidad de datos).
-- =========================================================================
SELECT b.book_id, b.title
FROM books b
LEFT JOIN book_genres bg USING (book_id)
WHERE bg.genre_id IS NULL;

-- =========================================================================
-- Q8. Usuarios por rol y estado (equivalente a GET /users).
-- =========================================================================
SELECT
    CASE WHEN is_admin THEN 'Administrador' ELSE 'Usuario' END AS rol,
    is_active,
    count(*) AS total
FROM users
GROUP BY is_admin, is_active
ORDER BY rol, is_active DESC;

-- =========================================================================
-- Q9. Verificacion de la regla "como maximo un Administrador"
--     (debe devolver siempre 0 o 1).
-- =========================================================================
SELECT count(*) AS administradores_activos
FROM users
WHERE is_admin;

-- =========================================================================
-- Q10. Valor de inventario (precio x existencias) agrupado por categoria.
-- =========================================================================
SELECT c.name AS category, count(b.book_id) AS libros, sum(b.price * b.stock) AS valor_inventario
FROM books b
JOIN categories c USING (category_id)
GROUP BY c.name
ORDER BY valor_inventario DESC;
