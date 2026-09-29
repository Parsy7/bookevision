<?php

/**
 * Validación e inserción de sugerencias, compartida entre la importación
 * normal (`ReviewController::import`) y las que genera la IA
 * (`AiController`) — un único sitio decide qué es una sugerencia válida, así
 * que ninguna de las dos rutas puede insertar algo mal formado.
 */
class SuggestionValidator {
    /** Devuelve `null` si son válidas, o un mensaje de error si no. */
    public static function validar(array $suggestions): ?string {
        // Un array vacío es válido: un .md importado a pelo no trae ninguna
        // sugerencia (es un "capítulo suelto"), y la IA puede legítimamente
        // no encontrar nada que proponer.
        foreach ($suggestions as $s) {
            if (!is_array($s)) {
                return 'Cada sugerencia debe ser un objeto';
            }
            $t = $s['type'] ?? null;
            if ($t !== 'replace' && $t !== 'insert') {
                return 'Cada sugerencia debe ser type replace o insert';
            }
        }
        return null;
    }

    /**
     * Inserta sugerencias (+ su respuesta vacía a juego) en una revisión,
     * continuando el `orden` donde lo dejara la revisión (0 si es nueva).
     * Llamar dentro de una transacción ya abierta.
     */
    public static function insertar(PDO $pdo, string $revisionId, array $suggestions): void {
        $stmt = $pdo->prepare(
            'SELECT COALESCE(MAX(orden), -1) FROM sugerencias WHERE revision_id = :id'
        );
        $stmt->execute(['id' => $revisionId]);
        $orden = (int)$stmt->fetchColumn() + 1;

        $insSug = $pdo->prepare(
            'INSERT INTO sugerencias
               (revision_id, orden, type, title, location, reason,
                original, proposed, anchor, insert_mode, previous, next)
             VALUES
               (:revision_id, :orden, :type, :title, :location, :reason,
                :original, :proposed, :anchor, :insert_mode, :previous, :next)'
        );
        $insAns = $pdo->prepare(
            'INSERT INTO respuestas (revision_id, orden, choice, custom, insert_position)
             VALUES (:revision_id, :orden, :choice, :custom, :insert_position)'
        );

        foreach ($suggestions as $s) {
            $type = $s['type'];
            $insSug->execute([
                'revision_id' => $revisionId,
                'orden'       => $orden,
                'type'        => $type,
                'title'       => $s['title'] ?? null,
                'location'    => $s['location'] ?? null,
                'reason'      => $s['reason'] ?? null,
                'original'    => $s['original'] ?? null,
                'proposed'    => $s['proposed'] ?? null,
                'anchor'      => $s['anchor'] ?? null,
                'insert_mode' => in_array($s['insert'] ?? null, ['before', 'after'], true)
                                    ? $s['insert'] : null,
                'previous'    => $s['previous'] ?? null,
                'next'        => $s['next'] ?? null,
            ]);
            // Respuesta inicial vacía (choice null; insert_position 'between' en inserciones).
            $insAns->execute([
                'revision_id'     => $revisionId,
                'orden'           => $orden,
                'choice'          => null,
                'custom'          => null,
                'insert_position' => $type === 'insert' ? 'between' : null,
            ]);
            $orden++;
        }
    }
}
