<?php

/**
 * Estado de trabajo de una revisión: respuestas (por sugerencia) + ediciones
 * manuales (por bloque). Equivale a { answers, manualEdits } del HTML, pero
 * persistido en MariaDB para poder retomar desde cualquier dispositivo.
 *
 *   GET    /revisiones/{id}/estado   -> { answers:[...], manualEdits:{...} }
 *   PUT    /revisiones/{id}/estado   -> guarda el estado completo (autosave)
 *   DELETE /revisiones/{id}/estado   -> borra decisiones y ediciones (reset)
 */
class StateController {
    public function handle(string $method, ?string $id): void {
        $pdo = get_pdo();

        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta id de revisión']);
            return;
        }
        if (!$this->reviewExists($pdo, $id)) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }

        switch ($method) {
            case 'GET':    $this->getState($pdo, $id); break;
            case 'PUT':    $this->putState($pdo, $id); break;
            case 'DELETE': $this->reset($pdo, $id);    break;
            default:
                http_response_code(405);
                echo json_encode(['error' => 'Método no permitido']);
        }
    }

    private function getState(PDO $pdo, string $id): void {
        $stmt = $pdo->prepare(
            'SELECT orden, choice, custom, insert_position
               FROM respuestas WHERE revision_id = :id ORDER BY orden ASC'
        );
        $stmt->execute(['id' => $id]);
        $answers = array_map(function ($r) {
            return [
                'orden'          => (int)$r['orden'],
                'choice'         => $r['choice'],
                'custom'         => $r['custom'] ?? '',
                'insertPosition' => $r['insert_position'],
            ];
        }, $stmt->fetchAll());

        $stmt = $pdo->prepare(
            'SELECT block_id, start_offset, end_offset, original, value
               FROM ediciones_manuales WHERE revision_id = :id'
        );
        $stmt->execute(['id' => $id]);
        $manualEdits = [];
        foreach ($stmt->fetchAll() as $e) {
            $manualEdits[$e['block_id']] = [
                'start'    => (int)$e['start_offset'],
                'end'      => (int)$e['end_offset'],
                'original' => $e['original'],
                'value'    => $e['value'],
            ];
        }
        // (object) para que un mapa vacío se serialice como {} y no como [].
        echo json_encode(['answers' => $answers, 'manualEdits' => (object)$manualEdits]);
    }

    private function putState(PDO $pdo, string $id): void {
        $body    = json_body();
        $answers = is_array($body['answers'] ?? null) ? $body['answers'] : [];
        $edits   = is_array($body['manualEdits'] ?? null) ? $body['manualEdits'] : [];

        $pdo->beginTransaction();
        try {
            $upd = $pdo->prepare(
                'UPDATE respuestas
                    SET choice = :choice, custom = :custom, insert_position = :insert_position
                  WHERE revision_id = :revision_id AND orden = :orden'
            );
            foreach ($answers as $a) {
                if (!is_array($a) || !isset($a['orden'])) continue;
                $upd->execute([
                    'choice'          => in_array($a['choice'] ?? null, ['original','proposed','custom'], true)
                                            ? $a['choice'] : null,
                    'custom'          => $a['custom'] ?? null,
                    'insert_position' => in_array($a['insertPosition'] ?? null, ['before','between','after'], true)
                                            ? $a['insertPosition'] : null,
                    'revision_id'     => $id,
                    'orden'           => (int)$a['orden'],
                ]);
            }

            // Las ediciones manuales son un conjunto: se reemplazan por completo.
            $pdo->prepare('DELETE FROM ediciones_manuales WHERE revision_id = :id')
                ->execute(['id' => $id]);
            $insEdit = $pdo->prepare(
                'INSERT INTO ediciones_manuales
                    (revision_id, block_id, start_offset, end_offset, original, value)
                 VALUES (:revision_id, :block_id, :start_offset, :end_offset, :original, :value)'
            );
            foreach ($edits as $blockId => $e) {
                if (!is_array($e) || !isset($e['start'], $e['end'])) continue;
                $insEdit->execute([
                    'revision_id'  => $id,
                    'block_id'     => (string)$blockId,
                    'start_offset' => (int)$e['start'],
                    'end_offset'   => (int)$e['end'],
                    'original'     => (string)($e['original'] ?? ''),
                    'value'        => (string)($e['value'] ?? ''),
                ]);
            }

            $pdo->prepare('UPDATE revisiones SET updated_at = NOW() WHERE id = :id')
                ->execute(['id' => $id]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        echo json_encode(['ok' => true]);
    }

    /** Reset: deja las respuestas en blanco y borra las ediciones manuales. */
    private function reset(PDO $pdo, string $id): void {
        $pdo->beginTransaction();
        try {
            // insert_position vuelve a 'between' en inserciones, NULL en sustituciones.
            $pdo->prepare(
                "UPDATE respuestas r
                   JOIN sugerencias s
                     ON s.revision_id = r.revision_id AND s.orden = r.orden
                    SET r.choice = NULL,
                        r.custom = NULL,
                        r.insert_position = IF(s.type = 'insert', 'between', NULL)
                  WHERE r.revision_id = :id"
            )->execute(['id' => $id]);

            $pdo->prepare('DELETE FROM ediciones_manuales WHERE revision_id = :id')
                ->execute(['id' => $id]);

            $pdo->prepare('UPDATE revisiones SET updated_at = NOW() WHERE id = :id')
                ->execute(['id' => $id]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        echo json_encode(['ok' => true]);
    }

    private function reviewExists(PDO $pdo, string $id): bool {
        $stmt = $pdo->prepare('SELECT 1 FROM revisiones WHERE id = :id');
        $stmt->execute(['id' => $id]);
        return (bool)$stmt->fetch();
    }
}
