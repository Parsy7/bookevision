-- Migración aditiva. Capítulos: un libro tiene capítulos, y cada capítulo
-- agrupa sus revisiones (p. ej. una ronda de sugerencias y luego el .md
-- final). Además, una revisión sin sugerencias (capítulo suelto) se puede
-- marcar como finalizada a mano, ya que no tiene sugerencias que resolver.

CREATE TABLE IF NOT EXISTS capitulos (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  libro_id   INT NOT NULL,
  numero     INT NOT NULL,
  titulo     VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Solo para el relleno de abajo; se borra al final de esta migración.
  _origen    VARCHAR(191) NULL,
  INDEX idx_capitulos_libro (libro_id, numero),
  CONSTRAINT fk_capitulos_libro FOREIGN KEY (libro_id)
    REFERENCES libros(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE revisiones ADD COLUMN capitulo_id INT NULL AFTER libro_id;
ALTER TABLE revisiones ADD COLUMN finalizada TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE revisiones ADD CONSTRAINT fk_revisiones_capitulo
  FOREIGN KEY (capitulo_id) REFERENCES capitulos(id) ON DELETE CASCADE;

-- Relleno: hasta ahora cada revisión hacía de capítulo, así que cada una
-- pasa a tener el suyo, con su mismo título y numerados por orden de
-- importación dentro de su libro. Después se pueden agrupar moviendo
-- revisiones de un capítulo a otro desde la app.
INSERT INTO capitulos (libro_id, numero, titulo, _origen)
SELECT r.libro_id,
       (SELECT COUNT(*) FROM revisiones r2
         WHERE r2.libro_id = r.libro_id
           AND (r2.created_at < r.created_at
                OR (r2.created_at = r.created_at AND r2.id <= r.id))),
       r.title,
       r.id
  FROM revisiones r
 WHERE r.libro_id IS NOT NULL;

UPDATE revisiones r JOIN capitulos c ON c._origen = r.id SET r.capitulo_id = c.id;

ALTER TABLE capitulos DROP COLUMN _origen;
