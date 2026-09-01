-- Añade 'omit' a respuestas.choice: dejar una tarjeta en blanco y quitar del
-- capítulo el fragmento original, en vez de sustituirlo por algo.
--
-- Sin esto, MariaDB guarda '' (o NULL en modo estricto) al recibir un valor
-- fuera del ENUM y la decisión se pierde en el siguiente autosave.
ALTER TABLE respuestas
  MODIFY choice ENUM('original','proposed','custom','omit') NULL;
