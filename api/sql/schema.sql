-- Esquema base del Revisor de capítulos de «La jaula rota».
-- MariaDB / InnoDB / utf8mb4. Mismo criterio que Anotto: este schema.sql crea
-- las tablas base con DROP (aplicarlo BORRA los datos). Cambios posteriores de
-- esquema van SIEMPRE en sql/migrations/*.sql, nunca reaplicando este archivo.
--
-- Modelo: una «revisión» es un capítulo (texto completo) + N «sugerencias».
-- El estado de trabajo del usuario son sus «respuestas» (una por sugerencia,
-- indexada por posición) y sus «ediciones manuales» (bloques de prosa libre
-- editados a mano, con sus offsets de carácter en el capítulo original).

SET NAMES utf8mb4;

DROP TABLE IF EXISTS ediciones_manuales;
DROP TABLE IF EXISTS respuestas;
DROP TABLE IF EXISTS sugerencias;
DROP TABLE IF EXISTS revisiones;

CREATE TABLE revisiones (
  -- Id natural que viene en el JSON (p. ej. 'capitulo-x-la-promesa-revision-v4').
  id          VARCHAR(191) PRIMARY KEY,
  format      VARCHAR(64)  NOT NULL,
  title       VARCHAR(255) NOT NULL,
  source      VARCHAR(255) NULL,
  chapter     LONGTEXT     NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sugerencias (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  revision_id  VARCHAR(191) NOT NULL,
  -- Posición 0-based dentro del array `suggestions`. Es la clave real: las
  -- respuestas se referencian por este `orden`, igual que `answers[i]` en el HTML.
  orden        INT NOT NULL,
  type         ENUM('replace','insert') NOT NULL,
  title        VARCHAR(255) NULL,
  location     VARCHAR(255) NULL,
  reason       TEXT     NULL,
  original     LONGTEXT NULL,                 -- solo replace
  proposed     LONGTEXT NULL,
  anchor       LONGTEXT NULL,                 -- solo insert
  insert_mode  ENUM('before','after') NULL,   -- campo `insert` del JSON
  previous     LONGTEXT NULL,                 -- solo insert
  next         LONGTEXT NULL,                 -- solo insert
  UNIQUE KEY uq_sugerencia (revision_id, orden),
  KEY idx_sug_revision (revision_id),
  CONSTRAINT fk_sug_revision FOREIGN KEY (revision_id)
    REFERENCES revisiones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE respuestas (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  revision_id     VARCHAR(191) NOT NULL,
  -- Apunta a sugerencias.orden (misma revisión). Una respuesta por sugerencia.
  orden           INT NOT NULL,
  -- 'omit' = no responder y quitar del capítulo el fragmento original.
  choice          ENUM('original','proposed','custom','omit') NULL,
  custom          LONGTEXT NULL,
  -- Solo tiene sentido en inserciones; por defecto 'between'.
  insert_position ENUM('before','between','after') NULL,
  UNIQUE KEY uq_respuesta (revision_id, orden),
  KEY idx_resp_revision (revision_id),
  CONSTRAINT fk_resp_revision FOREIGN KEY (revision_id)
    REFERENCES revisiones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ediciones_manuales (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  revision_id  VARCHAR(191) NOT NULL,
  -- Clave estable del bloque: 'b_<start>_<end>' (offsets en el capítulo original).
  block_id     VARCHAR(64) NOT NULL,
  start_offset INT NOT NULL,
  end_offset   INT NOT NULL,
  original     LONGTEXT NOT NULL,
  value        LONGTEXT NOT NULL,
  UNIQUE KEY uq_edicion (revision_id, block_id),
  KEY idx_edit_revision (revision_id),
  CONSTRAINT fk_edit_revision FOREIGN KEY (revision_id)
    REFERENCES revisiones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
