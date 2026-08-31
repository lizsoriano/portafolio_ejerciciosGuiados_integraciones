-- db/02_seed_30_per_table.sql
-- Datos sinteticos para probar la solucion end-to-end.
--
-- Ejecutar despues de db/01_schema.sql, conectado a library_db:
--   PGPASSWORD=library666 psql -h localhost -U library_user -d library_db -f db/02_seed_30_per_table.sql
--
-- Criterio de cantidad: se apunta a ~30 filas por tabla. En catalogos donde
-- 30 valores distintos no serian realistas (formatos de un libro, por
-- ejemplo) se usa una cantidad menor y justificada; en las tablas puente
-- (book_authors, book_genres, book_concepts, book_images) el conteo supera
-- 30 porque escalan de forma natural con los 30 libros sembrados.
--
-- Estrategia de claves: como todos los PK son GENERATED ALWAYS AS IDENTITY,
-- este script nunca asume valores de id. Las tablas base se insertan con
-- INSERT ... VALUES; las tablas dependientes se insertan con
-- INSERT ... SELECT que resuelve los id reales mediante JOIN por clave
-- natural (isbn de books, name de catalogos, nombre de autores/conceptos).
-- Esto hace el script seguro de re-generar sobre una base vacia sin
-- importar el orden de asignacion de las secuencias.
--
-- Credenciales de la cuenta administradora y de las cuentas de prueba:
-- son EXCLUSIVAMENTE para desarrollo/pruebas locales, nunca para produccion.
-- Los hashes se generaron con bcrypt (costo 12, el mismo que usa
-- apps/web-monolito/src/modules/auth y scripts/create-admin.js) a partir de:
--   administrador -> AdminSeed2026!
--   resto de usuarios -> UsuarioSeed2026!

BEGIN;

-- =========================================================================
-- 1. Catalogos independientes: formats, categories, genres
-- =========================================================================

INSERT INTO formats (name, description) VALUES
    ('Tapa dura', 'Encuadernacion rigida, mayor durabilidad.'),
    ('Tapa blanda', 'Encuadernacion flexible de bajo costo.'),
    ('Bolsillo', 'Formato compacto y economico.'),
    ('Digital (eBook)', 'Archivo digital para lectores electronicos.'),
    ('Audiolibro', 'Version narrada en formato de audio.'),
    ('Espiral', 'Encuadernacion de espiral, comun en manuales.'),
    ('Pop-up', 'Libro ilustrado con elementos desplegables.'),
    ('Novela grafica (edicion)', 'Edicion en formato de comic o novela grafica.'),
    ('Edicion de lujo', 'Edicion coleccionable con acabados especiales.'),
    ('Edicion universitaria', 'Edicion academica con aparato critico.'),
    ('Folleto tecnico', 'Formato breve encuadernado en rustica.');

INSERT INTO categories (name, description) VALUES
    ('Ficcion', 'Obras narrativas de caracter imaginativo.'),
    ('No ficcion', 'Obras basadas en hechos y analisis reales.'),
    ('Infantil', 'Contenido dirigido a lectores infantiles.'),
    ('Juvenil', 'Contenido dirigido a lectores adolescentes.'),
    ('Academico', 'Material de apoyo para educacion superior.'),
    ('Tecnico', 'Manuales y referencias tecnicas especializadas.'),
    ('Autoayuda', 'Obras de desarrollo personal.'),
    ('Biografia', 'Relatos de vida de personas reales.'),
    ('Historia', 'Analisis y narracion de hechos historicos.'),
    ('Ciencia', 'Divulgacion y referencia cientifica.'),
    ('Filosofia', 'Obras de pensamiento y reflexion filosofica.'),
    ('Arte', 'Publicaciones sobre artes visuales y diseno.'),
    ('Referencia', 'Diccionarios, atlas y obras de consulta.'),
    ('Poesia', 'Obras en verso.'),
    ('Ensayo', 'Textos argumentativos y reflexivos.'),
    ('Negocios', 'Administracion, finanzas y emprendimiento.'),
    ('Salud', 'Bienestar fisico y mental.'),
    ('Viajes', 'Guias y cronicas de viaje.'),
    ('Cocina', 'Recetarios y gastronomia.'),
    ('Religion', 'Textos espirituales y religiosos.');

INSERT INTO genres (name, description) VALUES
    ('Novela', 'Narrativa extensa en prosa.'),
    ('Cuento', 'Narrativa breve en prosa.'),
    ('Ciencia ficcion', 'Narrativa especulativa basada en ciencia y tecnologia.'),
    ('Fantasia', 'Narrativa con elementos magicos o sobrenaturales.'),
    ('Terror', 'Narrativa orientada a provocar miedo o inquietud.'),
    ('Misterio', 'Narrativa centrada en resolver un enigma.'),
    ('Policiaco', 'Narrativa centrada en la investigacion de un crimen.'),
    ('Romance', 'Narrativa centrada en relaciones amorosas.'),
    ('Distopia', 'Narrativa que retrata sociedades opresivas o fallidas.'),
    ('Realismo magico', 'Narrativa donde lo fantastico se integra a lo cotidiano.'),
    ('Aventura', 'Narrativa centrada en peripecias y viajes.'),
    ('Drama', 'Narrativa centrada en conflictos emocionales serios.'),
    ('Satira', 'Narrativa que critica mediante la ironia y el humor.'),
    ('Novela historica', 'Narrativa ambientada en un periodo historico real.'),
    ('Novela grafica', 'Narrativa contada mediante ilustraciones secuenciales.'),
    ('Poesia', 'Composicion literaria en verso.'),
    ('Epica', 'Narrativa de gran escala sobre hazanas heroicas.'),
    ('Tragedia', 'Narrativa centrada en un desenlace funesto inevitable.'),
    ('Comedia', 'Narrativa centrada en el humor y el desenlace favorable.'),
    ('Bildungsroman', 'Narrativa centrada en la formacion del protagonista.'),
    ('Ensayo filosofico', 'Reflexion argumentada sobre temas filosoficos.'),
    ('Divulgacion cientifica', 'Explicacion accesible de temas cientificos.'),
    ('Tecnologia', 'Contenido centrado en herramientas y sistemas tecnologicos.'),
    ('Computacion en la nube', 'Contenido centrado en servicios y arquitecturas cloud.'),
    ('Programacion', 'Contenido centrado en desarrollo de software.'),
    ('Economia', 'Contenido centrado en fenomenos economicos.'),
    ('Autoayuda', 'Narrativa o ensayo orientado al desarrollo personal.'),
    ('Memorias', 'Narrativa autobiografica basada en experiencias reales.'),
    ('Mitologia', 'Narrativa basada en relatos tradicionales y dioses.'),
    ('Existencialismo', 'Narrativa centrada en el sentido de la existencia.');

-- =========================================================================
-- 2. Personas y conceptos: authors, concepts
-- =========================================================================

INSERT INTO authors (first_name, last_name, biography) VALUES
    ('Gabriel', 'Garcia Marquez', 'Escritor colombiano, premio Nobel de Literatura 1982.'),
    ('Jorge Luis', 'Borges', 'Escritor argentino, referente del cuento y el ensayo del siglo XX.'),
    ('Miguel', 'de Cervantes Saavedra', 'Escritor espanol del Siglo de Oro.'),
    ('George', 'Orwell', 'Escritor britanico conocido por su critica al totalitarismo.'),
    ('Aldous', 'Huxley', 'Escritor britanico, autor de narrativa distopica y ensayo.'),
    ('Ray', 'Bradbury', 'Escritor estadounidense de ciencia ficcion.'),
    ('Franz', 'Kafka', 'Escritor checo en lengua alemana.'),
    ('Albert', 'Camus', 'Escritor y filosofo franco-argelino, premio Nobel de Literatura 1957.'),
    ('Jane', 'Austen', 'Escritora britanica de novela de costumbres.'),
    ('Mary', 'Shelley', 'Escritora britanica, pionera de la ciencia ficcion.'),
    ('Herman', 'Melville', 'Escritor estadounidense de narrativa marina.'),
    ('Fiodor', 'Dostoyevski', 'Escritor ruso, referente de la novela psicologica.'),
    ('Leon', 'Tolstoi', 'Escritor ruso, autor de narrativa realista de gran escala.'),
    ('Virginia', 'Woolf', 'Escritora britanica, pionera de la narrativa modernista.'),
    ('Ernest', 'Hemingway', 'Escritor estadounidense, premio Nobel de Literatura 1954.'),
    ('J.R.R.', 'Tolkien', 'Escritor y filologo britanico, autor de literatura fantastica.'),
    ('Isabel', 'Allende', 'Escritora chilena, referente del realismo magico contemporaneo.'),
    ('Julio', 'Cortazar', 'Escritor argentino, referente de la narrativa experimental.'),
    ('Mario', 'Vargas Llosa', 'Escritor peruano, premio Nobel de Literatura 2010.'),
    ('Pablo', 'Neruda', 'Poeta chileno, premio Nobel de Literatura 1971.'),
    ('William', 'Shakespeare', 'Dramaturgo y poeta ingles.'),
    ('Emily', 'Bronte', 'Escritora britanica del periodo victoriano.'),
    ('Charlotte', 'Bronte', 'Escritora britanica del periodo victoriano.'),
    ('Antoine', 'de Saint-Exupery', 'Escritor y aviador frances.'),
    ('Umberto', 'Eco', 'Escritor y semiologo italiano.'),
    ('Yuval Noah', 'Harari', 'Historiador israeli, autor de divulgacion sobre la humanidad.'),
    ('Thomas', 'Erl', 'Autor especializado en arquitectura de servicios y computacion en la nube.'),
    ('Zaigham', 'Mahmood', 'Investigador y autor en computacion en la nube.'),
    ('Ricardo', 'Puttini', 'Consultor y autor en infraestructura de nube.'),
    ('Chinua', 'Achebe', 'Escritor nigeriano, referente de la literatura africana moderna.'),
    ('Toni', 'Morrison', 'Escritora estadounidense, premio Nobel de Literatura 1993.'),
    ('Haruki', 'Murakami', 'Escritor japones de narrativa contemporanea.');

INSERT INTO concepts (name) VALUES
    ('Distopia'), ('Realismo magico'), ('Existencialismo'), ('Antiheroe'),
    ('Satira politica'), ('Amor no correspondido'), ('Viaje del heroe'),
    ('Alienacion'), ('Locura'), ('Semiotica'), ('Ironia dramatica'),
    ('Simbolismo'), ('Flujo de conciencia'), ('Metaficcion'), ('Nostalgia'),
    ('Identidad'), ('Culpa y redencion'), ('Traicion'), ('Venganza'), ('Destino'),
    ('IaaS'), ('PaaS'), ('SaaS'), ('FaaS'), ('Bucket'),
    ('Public Cloud'), ('Private Cloud'), ('Hybrid Cloud'), ('Multicloud'), ('Serverless');

-- =========================================================================
-- 3. Usuarios (RF-07: como maximo un administrador)
-- =========================================================================

INSERT INTO users (email, password_hash, display_name, is_admin, is_active) VALUES
    ('admin.biblioteca@example.com', '$2b$12$OJ3xQaaBxrnGKQHaeNxOyutyJzITNyaoRNoYwrUSNVwcPJgO3mmQ.', 'Administrador General', true, true),
    ('ana.torres@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Ana Torres', false, true),
    ('luis.ramirez@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Luis Ramirez', false, true),
    ('sofia.mendoza@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Sofia Mendoza', false, true),
    ('carlos.herrera@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Carlos Herrera', false, true),
    ('valentina.rojas@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Valentina Rojas', false, true),
    ('diego.salazar@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Diego Salazar', false, true),
    ('camila.vidal@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Camila Vidal', false, false),
    ('andres.pena@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Andres Pena', false, true),
    ('fernanda.cabrera@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Fernanda Cabrera', false, true),
    ('javier.nunez@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Javier Nunez', false, true),
    ('paula.contreras@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Paula Contreras', false, true),
    ('ricardo.fuentes@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Ricardo Fuentes', false, true),
    ('daniela.espinoza@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Daniela Espinoza', false, true),
    ('sebastian.reyes@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Sebastian Reyes', false, false),
    ('mariana.castillo@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Mariana Castillo', false, true),
    ('emilio.vargas@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Emilio Vargas', false, true),
    ('renata.solis@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Renata Solis', false, true),
    ('gabriel.ortiz@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Gabriel Ortiz', false, true),
    ('isabel.bravo@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Isabel Bravo', false, true),
    ('tomas.guzman@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Tomas Guzman', false, true),
    ('lucia.paredes@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Lucia Paredes', false, false),
    ('mateo.silva@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Mateo Silva', false, true),
    ('antonia.rivas@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Antonia Rivas', false, true),
    ('nicolas.aranda@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Nicolas Aranda', false, true),
    ('josefina.lara@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Josefina Lara', false, true),
    ('ivan.cordero@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Ivan Cordero', false, true),
    ('regina.salgado@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Regina Salgado', false, true),
    ('bruno.escobar@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Bruno Escobar', false, false),
    ('catalina.mora@example.com', '$2b$12$yhTnonkpU.HhJlFazWGe9OZWbErQlC6HHL/BZv68QEceDm16NVIT6', 'Catalina Mora', false, true);

-- =========================================================================
-- 4. Libros (30), resolviendo format_id/category_id por nombre.
-- =========================================================================

INSERT INTO books (isbn, title, publication_year, price, stock, format_id, category_id)
SELECT v.isbn, v.title, v.pub_year, v.price, v.stock, f.format_id, c.category_id
FROM (VALUES
    ('9780000000001', 'Cien anos de soledad', 1967, 349.00, 12, 'Tapa dura', 'Ficcion'),
    ('9780000000002', 'El amor en los tiempos del colera', 1985, 329.00, 10, 'Tapa blanda', 'Ficcion'),
    ('9780000000003', 'Ficciones', 1944, 259.00, 8, 'Tapa blanda', 'Ficcion'),
    ('9780000000004', 'El Aleph', 1949, 259.00, 8, 'Tapa blanda', 'Ficcion'),
    ('9780000000005', 'Don Quijote de la Mancha', 1605, 459.00, 6, 'Edicion de lujo', 'Ficcion'),
    ('9780000000006', '1984', 1949, 219.00, 20, 'Bolsillo', 'Ficcion'),
    ('9780000000007', 'Rebelion en la granja', 1945, 199.00, 18, 'Bolsillo', 'Ficcion'),
    ('9780000000008', 'Un mundo feliz', 1932, 229.00, 15, 'Tapa blanda', 'Ficcion'),
    ('9780000000009', 'Fahrenheit 451', 1953, 219.00, 14, 'Tapa blanda', 'Ficcion'),
    ('9780000000010', 'La metamorfosis', 1915, 189.00, 16, 'Tapa blanda', 'Ficcion'),
    ('9780000000011', 'El extranjero', 1942, 209.00, 12, 'Bolsillo', 'Ficcion'),
    ('9780000000012', 'Orgullo y prejuicio', 1813, 279.00, 11, 'Tapa dura', 'Ficcion'),
    ('9780000000013', 'Frankenstein', 1818, 239.00, 13, 'Tapa blanda', 'Ficcion'),
    ('9780000000014', 'Moby Dick', 1851, 299.00, 9, 'Tapa dura', 'Ficcion'),
    ('9780000000015', 'Crimen y castigo', 1866, 309.00, 10, 'Tapa dura', 'Ficcion'),
    ('9780000000016', 'Ana Karenina', 1877, 319.00, 8, 'Tapa dura', 'Ficcion'),
    ('9780000000017', 'Mrs. Dalloway', 1925, 249.00, 7, 'Tapa blanda', 'Ficcion'),
    ('9780000000018', 'El viejo y el mar', 1952, 189.00, 15, 'Bolsillo', 'Ficcion'),
    ('9780000000019', 'El senor de los anillos: La comunidad del anillo', 1954, 399.00, 10, 'Tapa dura', 'Ficcion'),
    ('9780000000020', 'La casa de los espiritus', 1982, 289.00, 9, 'Tapa blanda', 'Ficcion'),
    ('9780000000021', 'Rayuela', 1963, 269.00, 8, 'Tapa blanda', 'Ficcion'),
    ('9780000000022', 'La ciudad y los perros', 1963, 259.00, 9, 'Tapa blanda', 'Ficcion'),
    ('9780000000023', 'Veinte poemas de amor y una cancion desesperada', 1924, 179.00, 20, 'Tapa blanda', 'Poesia'),
    ('9780000000024', 'Hamlet', 1603, 199.00, 14, 'Tapa blanda', 'Ficcion'),
    ('9780000000025', 'Cumbres borrascosas', 1847, 239.00, 10, 'Tapa blanda', 'Ficcion'),
    ('9780000000026', 'Jane Eyre', 1847, 249.00, 11, 'Tapa blanda', 'Ficcion'),
    ('9780000000027', 'El principito', 1943, 259.00, 25, 'Tapa dura', 'Infantil'),
    ('9780000000028', 'El nombre de la rosa', 1980, 329.00, 9, 'Tapa blanda', 'Ficcion'),
    ('9780000000029', 'Sapiens: De animales a dioses', 2011, 399.00, 16, 'Tapa blanda', 'No ficcion'),
    ('9780000000030', 'Cloud Computing: Concepts, Technology & Architecture', 2013, 899.00, 5, 'Digital (eBook)', 'Tecnico')
) AS v(isbn, title, pub_year, price, stock, format_name, category_name)
JOIN formats f ON f.name = v.format_name
JOIN categories c ON c.name = v.category_name;

-- =========================================================================
-- 5. book_authors: libro <<->> autor (con orden de autoria)
-- =========================================================================

INSERT INTO book_authors (book_id, author_id, author_order)
SELECT b.book_id, a.author_id, v.author_order
FROM (VALUES
    ('9780000000001', 'Gabriel', 'Garcia Marquez', 1),
    ('9780000000002', 'Gabriel', 'Garcia Marquez', 1),
    ('9780000000003', 'Jorge Luis', 'Borges', 1),
    ('9780000000004', 'Jorge Luis', 'Borges', 1),
    ('9780000000005', 'Miguel', 'de Cervantes Saavedra', 1),
    ('9780000000006', 'George', 'Orwell', 1),
    ('9780000000007', 'George', 'Orwell', 1),
    ('9780000000008', 'Aldous', 'Huxley', 1),
    ('9780000000009', 'Ray', 'Bradbury', 1),
    ('9780000000010', 'Franz', 'Kafka', 1),
    ('9780000000011', 'Albert', 'Camus', 1),
    ('9780000000012', 'Jane', 'Austen', 1),
    ('9780000000013', 'Mary', 'Shelley', 1),
    ('9780000000014', 'Herman', 'Melville', 1),
    ('9780000000015', 'Fiodor', 'Dostoyevski', 1),
    ('9780000000016', 'Leon', 'Tolstoi', 1),
    ('9780000000017', 'Virginia', 'Woolf', 1),
    ('9780000000018', 'Ernest', 'Hemingway', 1),
    ('9780000000019', 'J.R.R.', 'Tolkien', 1),
    ('9780000000020', 'Isabel', 'Allende', 1),
    ('9780000000021', 'Julio', 'Cortazar', 1),
    ('9780000000022', 'Mario', 'Vargas Llosa', 1),
    ('9780000000023', 'Pablo', 'Neruda', 1),
    ('9780000000024', 'William', 'Shakespeare', 1),
    ('9780000000025', 'Emily', 'Bronte', 1),
    ('9780000000026', 'Charlotte', 'Bronte', 1),
    ('9780000000027', 'Antoine', 'de Saint-Exupery', 1),
    ('9780000000028', 'Umberto', 'Eco', 1),
    ('9780000000029', 'Yuval Noah', 'Harari', 1),
    -- Libro con multiples autores: demuestra la dependencia multivaluada libro ->> autor.
    ('9780000000030', 'Thomas', 'Erl', 1),
    ('9780000000030', 'Ricardo', 'Puttini', 2),
    ('9780000000030', 'Zaigham', 'Mahmood', 3)
) AS v(isbn, first_name, last_name, author_order)
JOIN books b ON b.isbn = v.isbn
JOIN authors a ON a.first_name = v.first_name AND a.last_name = v.last_name;

-- =========================================================================
-- 6. book_genres: libro <<->> genero
-- =========================================================================

INSERT INTO book_genres (book_id, genre_id)
SELECT b.book_id, g.genre_id
FROM (VALUES
    ('9780000000001', 'Novela'), ('9780000000001', 'Realismo magico'),
    ('9780000000002', 'Novela'), ('9780000000002', 'Romance'),
    ('9780000000003', 'Cuento'),
    ('9780000000004', 'Cuento'),
    ('9780000000005', 'Novela historica'), ('9780000000005', 'Comedia'),
    ('9780000000006', 'Distopia'),
    ('9780000000007', 'Satira'),
    ('9780000000008', 'Distopia'), ('9780000000008', 'Ciencia ficcion'),
    ('9780000000009', 'Distopia'), ('9780000000009', 'Ciencia ficcion'),
    ('9780000000010', 'Drama'), ('9780000000010', 'Existencialismo'),
    ('9780000000011', 'Existencialismo'),
    ('9780000000012', 'Romance'),
    ('9780000000013', 'Terror'), ('9780000000013', 'Ciencia ficcion'),
    ('9780000000014', 'Aventura'),
    ('9780000000015', 'Drama'), ('9780000000015', 'Novela'),
    ('9780000000016', 'Drama'), ('9780000000016', 'Romance'),
    ('9780000000017', 'Drama'),
    ('9780000000018', 'Aventura'),
    ('9780000000019', 'Fantasia'), ('9780000000019', 'Aventura'),
    ('9780000000020', 'Realismo magico'), ('9780000000020', 'Novela'),
    ('9780000000021', 'Novela'),
    ('9780000000022', 'Novela'),
    ('9780000000023', 'Poesia'),
    ('9780000000024', 'Tragedia'),
    ('9780000000025', 'Drama'), ('9780000000025', 'Tragedia'),
    ('9780000000026', 'Bildungsroman'), ('9780000000026', 'Romance'),
    ('9780000000027', 'Fantasia'),
    ('9780000000028', 'Misterio'), ('9780000000028', 'Novela historica'),
    ('9780000000029', 'Divulgacion cientifica'), ('9780000000029', 'Ensayo filosofico'),
    ('9780000000030', 'Computacion en la nube'), ('9780000000030', 'Tecnologia')
) AS v(isbn, genre_name)
JOIN books b ON b.isbn = v.isbn
JOIN genres g ON g.name = v.genre_name;

-- =========================================================================
-- 7. book_concepts: libro <<->> concepto, con definicion propia del par
--    (mismo concepto, definicion distinta segun el libro -> 4FN).
-- =========================================================================

INSERT INTO book_concepts (book_id, concept_id, definition)
SELECT b.book_id, cn.concept_id, v.definition
FROM (VALUES
    ('9780000000001', 'Realismo magico', 'En esta novela, el realismo magico entreteje lo sobrenatural con la vida cotidiana de Macondo sin que los personajes lo perciban como extraordinario.'),
    ('9780000000001', 'Destino', 'El destino de la familia Buendia esta marcado por la repeticion ciclica de nombres y tragedias a lo largo de siete generaciones.'),
    ('9780000000002', 'Amor no correspondido', 'Florentino Ariza espera mas de cincuenta anos el amor de Fermina Daza, sostenido por la esperanza pese al rechazo inicial.'),
    ('9780000000002', 'Nostalgia', 'La novela evoca la nostalgia de una epoca y un amor de juventud postergado por decadas.'),
    ('9780000000003', 'Metaficcion', 'Los cuentos de Ficciones cuestionan los limites entre autor, narrador y lector mediante bibliotecas y libros imaginarios.'),
    ('9780000000003', 'Identidad', 'Relatos como Pierre Menard exploran como la identidad de un texto cambia segun quien y cuando lo escribe.'),
    ('9780000000004', 'Simbolismo', 'El Aleph funciona como simbolo de un punto que contiene todos los puntos del universo simultaneamente.'),
    ('9780000000005', 'Locura', 'La locura de Alonso Quijano, que se cree caballero andante, es el motor comico y tragico de toda la novela.'),
    ('9780000000005', 'Viaje del heroe', 'Don Quijote y Sancho recorren Castilla en una parodia del viaje heroico caballeresco.'),
    ('9780000000006', 'Distopia', 'Oceania representa una distopia totalitaria donde el Estado controla incluso el pensamiento mediante el Gran Hermano.'),
    ('9780000000006', 'Satira politica', 'La novela satiriza los regimenes totalitarios del siglo XX mediante el Partido y la neolengua.'),
    ('9780000000007', 'Satira politica', 'La granja gobernada por los cerdos satiriza la traicion de los ideales revolucionarios sovieticos.'),
    ('9780000000007', 'Traicion', 'Los cerdos traicionan gradualmente los siete mandamientos originales de la revolucion animal.'),
    ('9780000000008', 'Distopia', 'El Estado Mundial de Huxley controla a la poblacion mediante el condicionamiento genetico y el soma, no solo el miedo.'),
    ('9780000000008', 'Identidad', 'La identidad de cada individuo se predetermina desde la incubadora segun su casta social.'),
    ('9780000000009', 'Distopia', 'Una sociedad que quema libros para evitar el pensamiento critico y el conflicto que genera la lectura.'),
    ('9780000000009', 'Simbolismo', 'El fuego simboliza tanto la destruccion del conocimiento como, al final, la purificacion y el renacer.'),
    ('9780000000010', 'Alienacion', 'Gregorio Samsa se convierte en insecto y queda progresivamente aislado de su propia familia.'),
    ('9780000000010', 'Existencialismo', 'La transformacion absurda de Gregorio plantea preguntas sobre el sentido del trabajo y la identidad personal.'),
    ('9780000000011', 'Existencialismo', 'Meursault vive con indiferencia radical ante la muerte de su madre y su propio juicio, encarnando el absurdo.'),
    ('9780000000011', 'Alienacion', 'Meursault se muestra emocionalmente distante de las convenciones sociales que se esperan de el.'),
    ('9780000000012', 'Ironia dramatica', 'El lector percibe antes que los personajes los prejuicios de Darcy y Elizabeth el uno hacia el otro.'),
    ('9780000000013', 'Culpa y redencion', 'Victor Frankenstein carga con la culpa de abandonar a su criatura, sin alcanzar una redencion plena.'),
    ('9780000000013', 'Identidad', 'La criatura busca una identidad y un lugar en el mundo que su creador le niega.'),
    ('9780000000014', 'Venganza', 'La obsesion del capitan Ahab por la ballena blanca lo consume hasta destruir a toda su tripulacion.'),
    ('9780000000014', 'Destino', 'La travesia del Pequod se presenta como un destino inevitable que ningun tripulante puede evitar.'),
    ('9780000000015', 'Culpa y redencion', 'Raskolnikov comete un asesinato que justifica racionalmente, pero la culpa lo consume hasta buscar redencion.'),
    ('9780000000015', 'Antiheroe', 'Raskolnikov actua como antiheroe: sus motivos son intelectualmente justificados pero moralmente cuestionables.'),
    ('9780000000016', 'Amor no correspondido', 'Konstantin Lievin ama en silencio a Kitty antes de que ella corresponda sus sentimientos.'),
    ('9780000000016', 'Traicion', 'La infidelidad de Ana hacia su esposo Karenin desencadena su aislamiento social progresivo.'),
    ('9780000000017', 'Flujo de conciencia', 'La novela transcurre en un solo dia narrado mediante el flujo de conciencia de Clarissa Dalloway.'),
    ('9780000000017', 'Identidad', 'Clarissa reflexiona sobre las decisiones de vida que definieron quien llego a ser.'),
    ('9780000000018', 'Destino', 'Santiago enfrenta su lucha con el marlin como una prueba final de dignidad frente a un destino adverso.'),
    ('9780000000018', 'Antiheroe', 'Santiago es un pescador anciano y vencido que, sin embargo, sostiene una lucha heroica y silenciosa.'),
    ('9780000000019', 'Viaje del heroe', 'Frodo abandona la Comarca para iniciar un viaje que sigue el arquetipo clasico del heroe llamado a la aventura.'),
    ('9780000000019', 'Destino', 'El anillo determina el destino de la Tierra Media incluso antes de que la Comunidad se forme.'),
    ('9780000000020', 'Realismo magico', 'Clara del Valle predice el futuro y se comunica con espiritus como parte natural de la vida familiar.'),
    ('9780000000020', 'Destino', 'La saga familiar de los Trueba esta marcada por un destino politico y personal que se repite entre generaciones.'),
    ('9780000000021', 'Metaficcion', 'Rayuela propone un orden de lectura alternativo que convierte al lector en coautor de la estructura del libro.'),
    ('9780000000021', 'Identidad', 'Horacio Oliveira busca su identidad entre Paris y Buenos Aires sin encontrar pertenencia plena en ninguna.'),
    ('9780000000022', 'Traicion', 'Los cadetes del Leoncio Prado se traicionan entre si bajo el codigo de silencio impuesto por la vida militar.'),
    ('9780000000022', 'Identidad', 'Los personajes construyen su identidad a traves de apodos y jerarquias dentro del colegio militar.'),
    ('9780000000023', 'Nostalgia', 'Los poemas evocan la nostalgia de amores juveniles ya perdidos.'),
    ('9780000000023', 'Amor no correspondido', 'Varios poemas expresan el dolor de un amor que no fue correspondido de la misma manera.'),
    ('9780000000024', 'Venganza', 'Hamlet posterga y finalmente ejecuta su venganza contra Claudio por el asesinato de su padre.'),
    ('9780000000024', 'Locura', 'Hamlet finge y, en ciertos momentos, bordea una locura real como estrategia y como consecuencia de su duelo.'),
    ('9780000000025', 'Venganza', 'Heathcliff dedica su vida adulta a vengarse de quienes lo humillaron en su juventud.'),
    ('9780000000025', 'Amor no correspondido', 'El amor entre Heathcliff y Catherine nunca se concreta plenamente y se transforma en obsesion.'),
    ('9780000000026', 'Identidad', 'Jane construye su identidad y su independencia moral pese a la orfandad y la pobreza.'),
    ('9780000000026', 'Culpa y redencion', 'Rochester busca redimirse de haber ocultado la verdad sobre su primer matrimonio.'),
    ('9780000000027', 'Nostalgia', 'El aviador narra con nostalgia su encuentro con el principito anos despues de haberlo vivido.'),
    ('9780000000027', 'Simbolismo', 'La rosa y el zorro simbolizan el valor de los vinculos que se cultivan con tiempo y cuidado.'),
    ('9780000000028', 'Semiotica', 'Guillermo de Baskerville interpreta signos y simbolos en la abadia como pistas de un sistema semiotico completo.'),
    ('9780000000028', 'Culpa y redencion', 'Jorge de Burgos oculta un libro por temor a sus consecuencias, cargando con una culpa que termina destruyendo la biblioteca.'),
    ('9780000000029', 'Identidad', 'Harari examina como los mitos compartidos, como las naciones y el dinero, moldean la identidad colectiva humana.'),
    ('9780000000029', 'Destino', 'El libro plantea si la trayectoria tecnologica de la humanidad es un destino inevitable o una serie de decisiones evitables.'),
    -- Libro de Cloud Computing: conceptos pedidos explicitamente en el enunciado (Parte 5, punto 15).
    ('9780000000030', 'IaaS', 'Infrastructure as a Service: el proveedor entrega maquinas virtuales, redes y almacenamiento, y el cliente administra sistema operativo y aplicaciones.'),
    ('9780000000030', 'PaaS', 'Platform as a Service: el proveedor entrega un entorno de ejecucion y herramientas de desarrollo, y el cliente solo administra sus aplicaciones y datos.'),
    ('9780000000030', 'SaaS', 'Software as a Service: el proveedor entrega una aplicacion completa lista para usarse a traves de internet, sin que el cliente administre infraestructura.'),
    ('9780000000030', 'FaaS', 'Function as a Service: el proveedor ejecuta funciones individuales en respuesta a eventos, sin que el cliente administre servidores.'),
    ('9780000000030', 'Bucket', 'Contenedor logico de almacenamiento de objetos en la nube usado para guardar archivos con metadatos y control de acceso.'),
    ('9780000000030', 'Public Cloud', 'Infraestructura de nube operada por un proveedor externo y compartida entre multiples clientes mediante internet.'),
    ('9780000000030', 'Private Cloud', 'Infraestructura de nube dedicada exclusivamente a una organizacion, operada internamente o por un tercero.'),
    ('9780000000030', 'Hybrid Cloud', 'Combinacion de nube publica y privada que permite mover cargas de trabajo entre ambas segun costo, seguridad o rendimiento.'),
    ('9780000000030', 'Multicloud', 'Uso simultaneo de servicios de mas de un proveedor de nube publica para evitar dependencia de un solo proveedor.'),
    ('9780000000030', 'Serverless', 'Modelo de ejecucion donde el proveedor administra por completo el aprovisionamiento de servidores, escalando automaticamente segun la demanda.')
) AS v(isbn, concept_name, definition)
JOIN books b ON b.isbn = v.isbn
JOIN concepts cn ON cn.name = v.concept_name;

-- =========================================================================
-- 8. book_images: libro ->> imagen (una portada por libro como maximo).
--    Las rutas son referencias de siembra bajo /uploads/seed/; no
--    corresponden a archivos binarios reales incluidos en el repositorio.
-- =========================================================================

INSERT INTO book_images (book_id, image_url, alt_text, display_order, is_cover)
SELECT b.book_id, v.image_url, v.alt_text, v.display_order, v.is_cover
FROM (VALUES
    ('9780000000001', '/uploads/seed/9780000000001-1.jpg', 'Portada de Cien anos de soledad', 1, true),
    ('9780000000001', '/uploads/seed/9780000000001-2.jpg', 'Contraportada de Cien anos de soledad', 2, false),
    ('9780000000002', '/uploads/seed/9780000000002-1.jpg', 'Portada de El amor en los tiempos del colera', 1, true),
    ('9780000000003', '/uploads/seed/9780000000003-1.jpg', 'Portada de Ficciones', 1, true),
    ('9780000000004', '/uploads/seed/9780000000004-1.jpg', 'Portada de El Aleph', 1, true),
    ('9780000000005', '/uploads/seed/9780000000005-1.jpg', 'Portada de Don Quijote de la Mancha', 1, true),
    ('9780000000005', '/uploads/seed/9780000000005-2.jpg', 'Contraportada de Don Quijote de la Mancha', 2, false),
    ('9780000000006', '/uploads/seed/9780000000006-1.jpg', 'Portada de 1984', 1, true),
    ('9780000000006', '/uploads/seed/9780000000006-2.jpg', 'Contraportada de 1984', 2, false),
    ('9780000000007', '/uploads/seed/9780000000007-1.jpg', 'Portada de Rebelion en la granja', 1, true),
    ('9780000000008', '/uploads/seed/9780000000008-1.jpg', 'Portada de Un mundo feliz', 1, true),
    ('9780000000009', '/uploads/seed/9780000000009-1.jpg', 'Portada de Fahrenheit 451', 1, true),
    ('9780000000009', '/uploads/seed/9780000000009-2.jpg', 'Contraportada de Fahrenheit 451', 2, false),
    ('9780000000010', '/uploads/seed/9780000000010-1.jpg', 'Portada de La metamorfosis', 1, true),
    ('9780000000011', '/uploads/seed/9780000000011-1.jpg', 'Portada de El extranjero', 1, true),
    ('9780000000012', '/uploads/seed/9780000000012-1.jpg', 'Portada de Orgullo y prejuicio', 1, true),
    ('9780000000013', '/uploads/seed/9780000000013-1.jpg', 'Portada de Frankenstein', 1, true),
    ('9780000000014', '/uploads/seed/9780000000014-1.jpg', 'Portada de Moby Dick', 1, true),
    ('9780000000015', '/uploads/seed/9780000000015-1.jpg', 'Portada de Crimen y castigo', 1, true),
    ('9780000000015', '/uploads/seed/9780000000015-2.jpg', 'Contraportada de Crimen y castigo', 2, false),
    ('9780000000016', '/uploads/seed/9780000000016-1.jpg', 'Portada de Ana Karenina', 1, true),
    ('9780000000017', '/uploads/seed/9780000000017-1.jpg', 'Portada de Mrs. Dalloway', 1, true),
    ('9780000000018', '/uploads/seed/9780000000018-1.jpg', 'Portada de El viejo y el mar', 1, true),
    ('9780000000019', '/uploads/seed/9780000000019-1.jpg', 'Portada de El senor de los anillos', 1, true),
    ('9780000000019', '/uploads/seed/9780000000019-2.jpg', 'Contraportada de El senor de los anillos', 2, false),
    ('9780000000020', '/uploads/seed/9780000000020-1.jpg', 'Portada de La casa de los espiritus', 1, true),
    ('9780000000020', '/uploads/seed/9780000000020-2.jpg', 'Contraportada de La casa de los espiritus', 2, false),
    ('9780000000021', '/uploads/seed/9780000000021-1.jpg', 'Portada de Rayuela', 1, true),
    ('9780000000022', '/uploads/seed/9780000000022-1.jpg', 'Portada de La ciudad y los perros', 1, true),
    ('9780000000023', '/uploads/seed/9780000000023-1.jpg', 'Portada de Veinte poemas de amor', 1, true),
    ('9780000000024', '/uploads/seed/9780000000024-1.jpg', 'Portada de Hamlet', 1, true),
    ('9780000000025', '/uploads/seed/9780000000025-1.jpg', 'Portada de Cumbres borrascosas', 1, true),
    ('9780000000026', '/uploads/seed/9780000000026-1.jpg', 'Portada de Jane Eyre', 1, true),
    ('9780000000027', '/uploads/seed/9780000000027-1.jpg', 'Portada de El principito', 1, true),
    ('9780000000027', '/uploads/seed/9780000000027-2.jpg', 'Contraportada de El principito', 2, false),
    ('9780000000028', '/uploads/seed/9780000000028-1.jpg', 'Portada de El nombre de la rosa', 1, true),
    ('9780000000028', '/uploads/seed/9780000000028-2.jpg', 'Contraportada de El nombre de la rosa', 2, false),
    ('9780000000029', '/uploads/seed/9780000000029-1.jpg', 'Portada de Sapiens', 1, true),
    ('9780000000030', '/uploads/seed/9780000000030-1.jpg', 'Portada de Cloud Computing: Concepts, Technology and Architecture', 1, true),
    ('9780000000030', '/uploads/seed/9780000000030-2.jpg', 'Contraportada de Cloud Computing: Concepts, Technology and Architecture', 2, false)
) AS v(isbn, image_url, alt_text, display_order, is_cover)
JOIN books b ON b.isbn = v.isbn;

COMMIT;

-- =========================================================================
-- Verificacion rapida de conteos (ejecutar manualmente si se desea revisar):
--
--   SELECT 'formats' t, count(*) FROM formats
--   UNION ALL SELECT 'categories', count(*) FROM categories
--   UNION ALL SELECT 'genres', count(*) FROM genres
--   UNION ALL SELECT 'authors', count(*) FROM authors
--   UNION ALL SELECT 'concepts', count(*) FROM concepts
--   UNION ALL SELECT 'users', count(*) FROM users
--   UNION ALL SELECT 'books', count(*) FROM books
--   UNION ALL SELECT 'book_authors', count(*) FROM book_authors
--   UNION ALL SELECT 'book_genres', count(*) FROM book_genres
--   UNION ALL SELECT 'book_concepts', count(*) FROM book_concepts
--   UNION ALL SELECT 'book_images', count(*) FROM book_images
--   ORDER BY 1;
-- =========================================================================
