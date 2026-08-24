# Revisor de capítulos — «La jaula rota»

App para revisar capítulo a capítulo aplicando sugerencias de edición
(sustituciones e inserciones), con edición manual de cualquier bloque de prosa.
Réplica en **Flutter + PHP/MariaDB** del revisor HTML, siguiendo la misma
estructura y disciplina de diseño que Anotto (tokens, sin sombras, mobile-first,
widgets genéricos). **Sin login** (un solo usuario).

Estado del build por fases:

- [x] **Fase 1 — Backend**: esquema MariaDB + API PHP. ← *incluido aquí*
- [ ] Fase 2 — Tema Flutter (tokens `AppColors/AppText/AppSpacing/AppRadius`) + widgets genéricos.
- [ ] Fase 3 — Modelos + `ApiService` + `ReviewSession` (estado con Provider).
- [ ] Fase 4 — Pantallas: lista, lector con tarjetas, edición manual, preview, confirmación y export `.md`.

## Estructura

```
api/
  index.php                 Router por PATH_INFO (sin auth)
  db.example.php            Copiar a db.php (fuera de git) y rellenar
  .htaccess                 Protege db.php y los .sql
  controllers/
    ReviewController.php     Revisiones: listar, obtener, importar, borrar
    StateController.php      Estado: obtener, guardar (autosave), resetear
  sql/
    schema.sql              Esquema base (aplicar UNA vez; es destructivo)
    migrations/             Cambios posteriores de esquema (*.sql en orden)
  scripts/
    run_migrations.php      Aplica migraciones por URL (protegido por secreto)
```

## Instalación del backend

1. Crea una base de datos MariaDB (utf8mb4) y un usuario.
2. Aplica el esquema base una vez (phpMyAdmin → Importar, o CLI):
   ```
   mysql -u USUARIO -p NOMBRE_BD < api/sql/schema.sql
   ```
3. Copia `api/db.example.php` a `api/db.php` y rellena `DB_*` y un `SCRIPT_SECRET`
   largo al azar. `db.php` va **fuera de git**.
4. Sube `api/` al servidor. La base de la API será algo como
   `https://TU-DOMINIO/revisor/api/index.php`.
5. Para cambios de esquema futuros: añade un `.sql` en `sql/migrations/` y visita
   `…/api/scripts/run_migrations.php?secret=TU_SECRETO`.

## API

Todas las rutas cuelgan de `…/api/index.php`.

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/revisiones` | Lista revisiones con progreso (`total`, `resolved`, `manual`). |
| GET | `/revisiones/{id}` | Revisión completa: metadatos + `chapter` + `suggestions[]`. |
| POST | `/revisiones` | Importa un JSON de revisión (`la-jaula-rota-review-v4`) o de estado (`la-jaula-rota-state-v2`). 409 si el id ya existe. |
| DELETE | `/revisiones/{id}` | Borra la revisión (sugerencias, respuestas y ediciones en cascada). |
| GET | `/revisiones/{id}/estado` | Estado actual: `{ answers[], manualEdits{} }`. |
| PUT | `/revisiones/{id}/estado` | Guarda el estado completo (autosave). |
| DELETE | `/revisiones/{id}/estado` | Reset: borra decisiones y ediciones manuales. |

### Modelo de datos

- **`revisiones`** — `id` (el del JSON), `format`, `title`, `source`, `chapter` (LONGTEXT).
- **`sugerencias`** — `revision_id`, `orden` (índice 0-based), `type` (`replace`/`insert`),
  `title`, `location`, `reason`, `original`, `proposed`, `anchor`, `insert_mode`
  (`before`/`after`), `previous`, `next`.
- **`respuestas`** — una por sugerencia (`revision_id`+`orden`): `choice`
  (`original`/`proposed`/`custom`), `custom`, `insert_position` (`before`/`between`/`after`).
- **`ediciones_manuales`** — por bloque (`block_id = b_<inicio>_<fin>`): `start_offset`,
  `end_offset`, `original`, `value`.

El id de la sugerencia dentro de la revisión es su `orden`, igual que `answers[i]`
en el HTML original: así el estado se mapea 1:1 con el modelo del revisor.
