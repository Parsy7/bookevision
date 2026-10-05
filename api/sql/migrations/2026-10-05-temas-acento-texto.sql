-- Migración aditiva. Tres tokens nuevos por tema, para que un acento claro
-- (el dorado de Marino) funcione igual que el rojo de Clásico:
--
--   acento_texto  el acento como palabra destacada sobre papel. Un dorado
--                 rellena bien pero no se lee como letra: aquí va uno más hondo.
--   peligro       borrar y lo irreversible, separado del acento («pendiente»).
--   sobre_acento  texto e iconos sobre un relleno de acento.
--
-- Son opcionales: sin valor, la app usa el acento, el rojo del corrector y
-- el blanco, que es lo que pintaba antes.

ALTER TABLE temas
  ADD COLUMN acento_texto CHAR(7) NULL AFTER acento,
  ADD COLUMN peligro      CHAR(7) NULL AFTER acento_texto,
  ADD COLUMN sobre_acento CHAR(7) NULL AFTER peligro;

-- Clásico: los tres coinciden con lo de siempre.
UPDATE temas
SET acento_texto = '#E4401C', peligro = '#E4401C', sobre_acento = '#FFFFFF'
WHERE nombre = 'Clásico';

-- Marino y dorado: paleta revisada (diseño «Importar y Perfil»). El dorado
-- vuelve como relleno con café oscuro encima (≈5,9:1); las palabras
-- destacadas usan un dorado más hondo, borrar un bermellón propio y
-- «Escribir yo» un azul petróleo.
UPDATE temas
SET paper = '#F6F2EA', sheet = '#FCFAF5', white = '#FFFFFF',
    ink = '#1E2A3E', acento = '#C9A26B', blue = '#2F6F86',
    grey1 = '#4E566A', grey2 = '#5E6577', grey3 = '#8A8F9C', strike = '#646A7A',
    acento_texto = '#9C7536', peligro = '#B03A2E', sobre_acento = '#3D2B12'
WHERE nombre = 'Marino y dorado';
