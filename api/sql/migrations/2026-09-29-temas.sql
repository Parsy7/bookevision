-- Migración aditiva. Los temas de color viven en la base de datos, no en el
-- código: añadir uno nuevo es un INSERT en `temas`, sin tocar Dart ni
-- desplegar una versión nueva de la app.
--
-- Los derivados de siempre (onInk, onRed, onBlue, scrim, press) no se
-- guardan aquí: se calculan en Dart a partir de paper/white/ink.

CREATE TABLE IF NOT EXISTS temas (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  nombre  VARCHAR(100) NOT NULL,
  paper   CHAR(7) NOT NULL,
  sheet   CHAR(7) NOT NULL,
  white   CHAR(7) NOT NULL,
  ink     CHAR(7) NOT NULL,
  acento  CHAR(7) NOT NULL,
  blue    CHAR(7) NOT NULL,
  grey1   CHAR(7) NOT NULL,
  grey2   CHAR(7) NOT NULL,
  grey3   CHAR(7) NOT NULL,
  strike  CHAR(7) NOT NULL,
  orden   INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Clásico: los valores exactos que ya tenía GColors antes de este cambio.
INSERT INTO temas (nombre, paper, sheet, white, ink, acento, blue, grey1, grey2, grey3, strike, orden)
VALUES ('Clásico', '#F3F0E8', '#FBFAF6', '#FFFFFF', '#141414', '#E4401C', '#2449D8', '#5E594F', '#6B665E', '#8A847A', '#6D675D', 1);

-- Marino y dorado: paleta de la preview ya mostrada, a partir de los logos.
INSERT INTO temas (nombre, paper, sheet, white, ink, acento, blue, grey1, grey2, grey3, strike, orden)
VALUES ('Marino y dorado', '#FAF6EF', '#FFFDFA', '#FFFFFF', '#232A42', '#C9A06A', '#2449D8', '#5A5F72', '#6B7086', '#9598A6', '#6D7286', 2);

ALTER TABLE users ADD COLUMN tema_id INT NULL AFTER name;
ALTER TABLE users ADD CONSTRAINT fk_users_tema
  FOREIGN KEY (tema_id) REFERENCES temas(id) ON DELETE SET NULL;
