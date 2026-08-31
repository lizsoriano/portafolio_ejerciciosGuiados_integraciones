-- db/06_views.sql
-- Vistas ligadas a pantallas y reportes reales del sistema.
--
-- Ejecutar conectado a library_db, despues de db/01..db/05:
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/06_views.sql

-- =========================================================================
-- v_book_catalog: catalogo de libros con formato, categoria, autores y
-- portada. Misma forma que la consulta usada en GET /books (Q1 de
-- db/03_all_quieries_before_stored_procedures.sql), expuesta como vista
-- reutilizable para reportes y para la propia aplicacion.
-- =========================================================================
CREATE OR REPLACE VIEW v_book_catalog AS
SELECT
    b.book_id, b.isbn, b.title, b.publication_year, b.price, b.stock,
    f.name AS format, c.name AS category,
    string_agg(DISTINCT concat_ws(' ', a.first_name, a.last_name), ', ') AS authors,
    (SELECT image_url FROM book_images WHERE book_id = b.book_id AND is_cover LIMIT 1) AS cover_url
FROM books b
JOIN formats f USING (format_id)
JOIN categories c USING (category_id)
LEFT JOIN book_authors ba USING (book_id)
LEFT JOIN authors a USING (author_id)
GROUP BY b.book_id, f.name, c.name;

-- =========================================================================
-- v_book_authors_ordered: autores de cada libro en su orden de autoria.
-- Equivalente a la consulta de GET /books/:id para la lista de autores.
-- =========================================================================
CREATE OR REPLACE VIEW v_book_authors_ordered AS
SELECT
    b.book_id, b.title,
    ba.author_order,
    a.author_id,
    concat_ws(' ', a.first_name, a.last_name) AS author_name
FROM book_authors ba
JOIN books b USING (book_id)
JOIN authors a USING (author_id)
ORDER BY b.book_id, ba.author_order;

-- =========================================================================
-- v_book_concepts_detail: conceptos y definiciones por libro, con el
-- titulo del libro para lectura directa en reportes.
-- =========================================================================
CREATE OR REPLACE VIEW v_book_concepts_detail AS
SELECT
    b.book_id, b.title, cn.concept_id, cn.name AS concept, bc.definition, bc.updated_at
FROM book_concepts bc
JOIN books b USING (book_id)
JOIN concepts cn USING (concept_id);

-- =========================================================================
-- v_admin_users: administrador(es) activos del sistema. Por la regla de
-- negocio (uq_users_single_administrator + trg_users_last_admin_guard),
-- esta vista debe devolver siempre exactamente 1 fila en operacion normal.
-- =========================================================================
CREATE OR REPLACE VIEW v_admin_users AS
SELECT user_id, email, display_name, is_active, created_at
FROM users
WHERE is_admin;

-- =========================================================================
-- v_books_low_stock: libros con existencias bajas, para reabastecimiento.
-- =========================================================================
CREATE OR REPLACE VIEW v_books_low_stock AS
SELECT book_id, isbn, title, stock
FROM books
WHERE stock <= 5
ORDER BY stock ASC;

-- =========================================================================
-- v_catalog_inventory_value: valor de inventario (precio x existencias)
-- agrupado por categoria, para reportes administrativos.
-- =========================================================================
CREATE OR REPLACE VIEW v_catalog_inventory_value AS
SELECT
    c.category_id, c.name AS category,
    count(b.book_id) AS total_libros,
    sum(b.price * b.stock) AS valor_inventario
FROM books b
JOIN categories c USING (category_id)
GROUP BY c.category_id, c.name;
