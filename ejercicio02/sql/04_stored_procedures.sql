-- db/04_stored_procedures.sql
-- Procedimientos almacenados que encapsulan operaciones reales de
-- apps/web-monolito. Cada uno corresponde a una transaccion que hoy la
-- aplicacion ya ejecuta en Node (ver config/db.js: transaction()); moverla
-- a un procedimiento centraliza la atomicidad en PostgreSQL.
--
-- Ejecutar conectado a library_db, despues de db/01..db/03:
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/04_stored_procedures.sql
--
-- Compatibilidad: CREATE PROCEDURE / CALL requieren PostgreSQL 11+.

-- =========================================================================
-- sp_create_book: crea un libro y sus relaciones libro-autor y libro-genero
-- en una sola operacion atomica. Equivalente a POST /books.
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_create_book(
    p_isbn varchar,
    p_title varchar,
    p_publication_year smallint,
    p_price numeric,
    p_stock integer,
    p_format_id bigint,
    p_category_id bigint,
    p_author_ids bigint[],
    p_genre_ids bigint[],
    OUT p_book_id bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_author_id bigint;
    v_genre_id bigint;
    v_order smallint := 1;
BEGIN
    INSERT INTO books (isbn, title, publication_year, price, stock, format_id, category_id)
    VALUES (p_isbn, p_title, p_publication_year, p_price, p_stock, p_format_id, p_category_id)
    RETURNING book_id INTO p_book_id;

    FOREACH v_author_id IN ARRAY p_author_ids LOOP
        INSERT INTO book_authors (book_id, author_id, author_order)
        VALUES (p_book_id, v_author_id, v_order);
        v_order := v_order + 1;
    END LOOP;

    FOREACH v_genre_id IN ARRAY p_genre_ids LOOP
        INSERT INTO book_genres (book_id, genre_id) VALUES (p_book_id, v_genre_id);
    END LOOP;
END;
$$;

-- Ejemplo de uso (requiere ids reales de db/02_seed_30_per_table.sql):
-- CALL sp_create_book('9789999999999','Libro de prueba',2024,199.90,5,
--     (SELECT format_id FROM formats WHERE name='Tapa blanda'),
--     (SELECT category_id FROM categories WHERE name='Ficcion'),
--     ARRAY[(SELECT author_id FROM authors WHERE first_name='Isabel')],
--     ARRAY[(SELECT genre_id FROM genres WHERE name='Novela')], NULL);

-- =========================================================================
-- sp_update_book: actualiza los datos escalares de un libro y reemplaza por
-- completo sus autores y generos. Equivalente a PUT /books/:id.
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_update_book(
    p_book_id bigint,
    p_isbn varchar,
    p_title varchar,
    p_publication_year smallint,
    p_price numeric,
    p_stock integer,
    p_format_id bigint,
    p_category_id bigint,
    p_author_ids bigint[],
    p_genre_ids bigint[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_author_id bigint;
    v_genre_id bigint;
    v_order smallint := 1;
BEGIN
    UPDATE books SET
        isbn = p_isbn,
        title = p_title,
        publication_year = p_publication_year,
        price = p_price,
        stock = p_stock,
        format_id = p_format_id,
        category_id = p_category_id
        -- updated_at la asigna trg_books_set_updated_at (db/05_triggers.sql).
    WHERE book_id = p_book_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sp_update_book: no existe el libro %', p_book_id;
    END IF;

    DELETE FROM book_authors WHERE book_id = p_book_id;
    FOREACH v_author_id IN ARRAY p_author_ids LOOP
        INSERT INTO book_authors (book_id, author_id, author_order)
        VALUES (p_book_id, v_author_id, v_order);
        v_order := v_order + 1;
    END LOOP;

    DELETE FROM book_genres WHERE book_id = p_book_id;
    FOREACH v_genre_id IN ARRAY p_genre_ids LOOP
        INSERT INTO book_genres (book_id, genre_id) VALUES (p_book_id, v_genre_id);
    END LOOP;
END;
$$;

-- =========================================================================
-- sp_upsert_book_concept: crea o actualiza la definicion de un concepto
-- para un libro especifico. Equivalente a POST /books/:id/concepts.
-- La definicion depende del par (book_id, concept_id), nunca solo del
-- concepto (ver docs/NORMALIZATION_4NF.md).
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_upsert_book_concept(
    p_book_id bigint,
    p_concept_id bigint,
    p_definition text
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO book_concepts (book_id, concept_id, definition)
    VALUES (p_book_id, p_concept_id, p_definition)
    ON CONFLICT (book_id, concept_id)
    DO UPDATE SET definition = EXCLUDED.definition, updated_at = now();
END;
$$;

-- =========================================================================
-- sp_set_book_cover_image: marca una imagen existente del libro como
-- portada y garantiza que ninguna otra imagen del mismo libro quede
-- marcada como portada. Equivalente a la logica de "is_cover" ejecutada
-- hoy en Node dentro de una transaccion (books/routes.js).
-- Reforzado ademas por trg_book_images_single_cover (db/05) y por el
-- indice parcial uq_book_images_single_cover (db/01), como defensa en
-- profundidad ante escrituras que no pasen por este procedimiento.
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_set_book_cover_image(
    p_book_id bigint,
    p_image_id bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM book_images WHERE image_id = p_image_id AND book_id = p_book_id
    ) THEN
        RAISE EXCEPTION 'sp_set_book_cover_image: la imagen % no pertenece al libro %',
            p_image_id, p_book_id;
    END IF;

    UPDATE book_images SET is_cover = false
    WHERE book_id = p_book_id AND image_id <> p_image_id AND is_cover;

    UPDATE book_images SET is_cover = true
    WHERE image_id = p_image_id;
END;
$$;

-- =========================================================================
-- sp_set_user_role: cambia el rol/estado de un usuario evitando dejar el
-- sistema sin administradores activos. Complementa la regla "como maximo
-- un Administrador" (indice uq_users_single_administrator, que impide un
-- SEGUNDO admin) con la regla simetrica "al menos un Administrador
-- activo", documentada como riesgo residual SR-10 en
-- docs/SECURITY_REVIEW.md. Tambien se aplica en cada UPDATE/DELETE crudo
-- mediante trg_users_last_admin_guard (db/05), que es la defensa
-- autoritativa; este procedimiento es la forma recomendada de invocarla
-- desde la aplicacion.
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_set_user_role(
    p_user_id bigint,
    p_is_admin boolean,
    p_is_active boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining_admins integer;
    v_was_active_admin boolean;
BEGIN
    SELECT is_admin AND is_active INTO v_was_active_admin
    FROM users WHERE user_id = p_user_id;

    IF v_was_active_admin AND NOT (p_is_admin AND p_is_active) THEN
        SELECT count(*) INTO v_remaining_admins
        FROM users WHERE is_admin AND is_active AND user_id <> p_user_id;

        IF v_remaining_admins = 0 THEN
            RAISE EXCEPTION 'sp_set_user_role: no puede quedar el sistema sin administradores activos';
        END IF;
    END IF;

    UPDATE users SET is_admin = p_is_admin, is_active = p_is_active
    WHERE user_id = p_user_id;
END;
$$;
