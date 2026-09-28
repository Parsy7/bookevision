-- Migración aditiva (no destructiva, a diferencia de sql/schema.sql).
-- Añade usuarios, tokens de sesión, libros (proyectos) y una columna
-- libro_id en revisiones. Aplícala tal cual; después registra tu cuenta
-- desde la app y ejecuta api/scripts/adopt_existing_book.php <email> para
-- migrar a ella el libro y las revisiones que ya existen.

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NULL,
  google_id VARCHAR(64) NULL UNIQUE,
  name VARCHAR(100) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS auth_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at DATETIME NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS libros (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Nullable a propósito: se rellena con adopt_existing_book.php. Una
-- migración futura puede endurecerla a NOT NULL una vez confirmado el
-- backfill de datos existentes.
ALTER TABLE revisiones ADD COLUMN libro_id INT NULL AFTER id;
ALTER TABLE revisiones ADD CONSTRAINT fk_revisiones_libro
  FOREIGN KEY (libro_id) REFERENCES libros(id) ON DELETE CASCADE;
