-- db/05_triggers.sql
-- Triggers que automatizan invariantes reales del modelo, complementando
-- los procedimientos de db/04_stored_procedures.sql como defensa en
-- profundidad: protegen el dato incluso ante un UPDATE/INSERT/DELETE
-- directo que no pase por la aplicacion ni por un procedimiento.
--
-- Ejecutar conectado a library_db, despues de db/01..db/04:
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/05_triggers.sql

-- =========================================================================
-- 1. Marca de tiempo automatica en updated_at.
--    apps/web-monolito NO siempre asigna updated_at manualmente (por
--    ejemplo, people/routes.js actualiza authors sin tocar esa columna);
--    este trigger lo garantiza para toda actualizacion, sin depender de
--    que cada ruta lo recuerde.
-- =========================================================================
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_authors_set_updated_at
    BEFORE UPDATE ON authors
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_books_set_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_book_concepts_set_updated_at
    BEFORE UPDATE ON book_concepts
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- =========================================================================
-- 2. Portada unica por libro.
--    Complementa el indice parcial uq_book_images_single_cover (db/01):
--    el indice RECHAZA una segunda portada; este trigger la EVITA,
--    desmarcando automaticamente cualquier portada previa del mismo
--    libro cuando se inserta o actualiza una imagen con is_cover = true.
-- =========================================================================
CREATE OR REPLACE FUNCTION trg_book_images_enforce_single_cover()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_cover THEN
        UPDATE book_images
        SET is_cover = false
        WHERE book_id = NEW.book_id
          AND image_id <> NEW.image_id
          AND is_cover;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_book_images_single_cover
    BEFORE INSERT OR UPDATE OF is_cover, book_id ON book_images
    FOR EACH ROW EXECUTE FUNCTION trg_book_images_enforce_single_cover();

-- =========================================================================
-- 3. Proteccion del ultimo Administrador activo.
--    El indice uq_users_single_administrator (db/01) impide tener DOS
--    administradores, pero no impide quedarse sin ninguno. Este trigger
--    cierra ese hueco documentado como riesgo residual SR-10 en
--    docs/SECURITY_REVIEW.md: bloquea el UPDATE que desactiva/degrada al
--    unico administrador activo y el DELETE que lo elimina.
-- =========================================================================
CREATE OR REPLACE FUNCTION trg_users_protect_last_admin()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining_admins integer;
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.is_admin AND OLD.is_active THEN
            SELECT count(*) INTO v_remaining_admins
            FROM users WHERE is_admin AND is_active AND user_id <> OLD.user_id;
            IF v_remaining_admins = 0 THEN
                RAISE EXCEPTION 'No puede eliminarse el unico administrador activo del sistema';
            END IF;
        END IF;
        RETURN OLD;
    END IF;

    -- TG_OP = 'UPDATE'
    IF OLD.is_admin AND OLD.is_active AND NOT (NEW.is_admin AND NEW.is_active) THEN
        SELECT count(*) INTO v_remaining_admins
        FROM users WHERE is_admin AND is_active AND user_id <> OLD.user_id;
        IF v_remaining_admins = 0 THEN
            RAISE EXCEPTION 'No puede desactivarse o degradarse al unico administrador activo del sistema';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_last_admin_guard
    BEFORE UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION trg_users_protect_last_admin();
