<?php

/**
 * Revisiones: capítulo + sugerencias. La importación acepta tanto el formato
 * de revisión ('la-jaula-rota-review-v4') como el de estado guardado
 * ('la-jaula-rota-state-v2'), replicando loadReview/loadState del HTML.
 */
class ReviewController {
    public function handle(string $method, ?string $id): void {
        $pdo = get_pdo();

        switch ($method) {
            case 'GET':
                if ($id) { $this->getOne($pdo, $id); }
                else     { $this->getList($pdo); }
                break;
            case 'POST':
                $this->import($pdo);
                break;
            case 'DELETE':
                $this->delete($pdo, $id);
                break;
            default:
                http_response_code(405);
                echo json_encode(['error' => 'Método no permitido']);
        }
    }

    /** Lista para la pantalla inicial: metadatos + progreso de cada revisión. */
    private function getList(PDO $pdo): void {
        $stmt = $pdo->query(
            "SELECT
                r.id, r.format, r.title, r.source, r.created_at, r.updated_at,
                (SELECT COUNT(*) FROM sugerencias s WHERE s.revision_id = r.id) AS total,
                (SELECT COUNT(*) FROM respuestas a
                   WHERE a.revision_id = r.id
                     AND (a.choice IN ('original','proposed')
                          OR (a.choice = 'custom' AND a.custom IS NOT NULL AND a.custom <> ''))
                ) AS resolved,
                (SELECT COUNT(*) FROM ediciones_manuales e WHERE e.revision_id = r.id) AS manual
             FROM revisiones r
             ORDER BY r.updated_at DESC"
        );
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['total']    = (int)$row['total'];
            $row['resolved'] = (int)$row['resolved'];
            $row['manual']   = (int)$row['manual'];
        }
        echo json_encode($rows);
    }

    /** Revisión completa: metadatos + capítulo + sugerencias ordenadas. */
    private function getOne(PDO $pdo, string $id): void {
        $stmt = $pdo->prepare('SELECT * FROM revisiones WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $review = $stmt->fetch();
        if (!$review) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }

        $stmt = $pdo->prepare(
            'SELECT * FROM sugerencias WHERE revision_id = :id ORDER BY orden ASC'
        );
        $stmt->execute(['id' => $id]);
        $review['suggestions'] = array_map(
            [$this, 'suggestionToJson'], $stmt->fetchAll()
        );

        echo json_encode($review);
    }

    /**
     * Importa una revisión. El cuerpo puede ser:
     *   - un objeto de revisión (chapter + suggestions), o
     *   - un estado 'la-jaula-rota-state-v2' (review + answers + manualEdits).
     * Si el id ya existe se responde 409 (bórrala antes de reimportar).
     */
    private function import(PDO $pdo): void {
        $body = json_body();

        $isState = ($body['format'] ?? null) === 'la-jaula-rota-state-v2'
                   && isset($body['review']);
        $review = $isState ? $body['review'] : $body;

        if (!is_array($review)
            || !isset($review['chapter']) || !is_string($review['chapter'])
            || !isset($review['suggestions']) || !is_array($review['suggestions'])) {
            http_response_code(400);
            echo json_encode(['error' => 'JSON no válido: falta chapter o suggestions']);
            return;
        }
        foreach ($review['suggestions'] as $s) {
            $t = $s['type'] ?? null;
            if ($t !== 'replace' && $t !== 'insert') {
                http_response_code(400);
                echo json_encode(['error' => 'Cada sugerencia debe ser type replace o insert']);
                return;
            }
        }

        $id = (string)($review['id'] ?? '');
        if ($id === '') {
            // Si el JSON no trae id, derivamos uno del título.
            $id = $this->slugify($review['title'] ?? 'revision') . '-' . date('YmdHis');
        }

        $exists = $pdo->prepare('SELECT 1 FROM revisiones WHERE id = :id');
        $exists->execute(['id' => $id]);
        if ($exists->fetch()) {
            http_response_code(409);
            echo json_encode(['error' => 'Ya existe una revisión con ese id', 'id' => $id]);
            return;
        }

        $pdo->beginTransaction();
        try {
            $pdo->prepare(
                'INSERT INTO revisiones (id, format, title, source, chapter)
                 VALUES (:id, :format, :title, :source, :chapter)'
            )->execute([
                'id'      => $id,
                'format'  => $review['format'] ?? 'la-jaula-rota-review-v4',
                'title'   => $review['title'] ?? 'Capítulo',
                'source'  => $review['source'] ?? null,
                'chapter' => $review['chapter'],
            ]);

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

            foreach ($review['suggestions'] as $i => $s) {
                $type = $s['type'];
                $insSug->execute([
                    'revision_id' => $id,
                    'orden'       => $i,
                    'type'        => $type,
                    'title'       => $s['title'] ?? null,
                    'location'    => $s['location'] ?? null,
                    'reason'      => $s['reason'] ?? null,
                    'original'    => $s['original'] ?? null,
                    'proposed'    => $s['proposed'] ?? null,
                    'anchor'      => $s['anchor'] ?? null,
                    'insert_mode' => in_array($s['insert'] ?? null, ['before','after'], true)
                                        ? $s['insert'] : null,
                    'previous'    => $s['previous'] ?? null,
                    'next'        => $s['next'] ?? null,
                ]);
                // Respuesta inicial vacía (choice null; insert_position 'between' en inserciones).
                $insAns->execute([
                    'revision_id'     => $id,
                    'orden'           => $i,
                    'choice'          => null,
                    'custom'          => null,
                    'insert_position' => $type === 'insert' ? 'between' : null,
                ]);
            }

            // Si venía un estado guardado, lo aplicamos encima.
            if ($isState) {
                $this->applyImportedState($pdo, $id, $body);
            }

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        $this->getOne($pdo, $id);
    }

    /** Vuelca answers[] y manualEdits{} de un estado 'state-v2' recién importado. */
    private function applyImportedState(PDO $pdo, string $id, array $state): void {
        $answers = is_array($state['answers'] ?? null) ? $state['answers'] : [];
        $upd = $pdo->prepare(
            'UPDATE respuestas
                SET choice = :choice, custom = :custom, insert_position = :insert_position
              WHERE revision_id = :revision_id AND orden = :orden'
        );
        foreach ($answers as $i => $a) {
            if (!is_array($a)) continue;
            $upd->execute([
                'choice'          => in_array($a['choice'] ?? null, ['original','proposed','custom'], true)
                                        ? $a['choice'] : null,
                'custom'          => $a['custom'] ?? null,
                'insert_position' => in_array($a['insertPosition'] ?? null, ['before','between','after'], true)
                                        ? $a['insertPosition'] : null,
                'revision_id'     => $id,
                'orden'           => $i,
            ]);
        }

        $edits = is_array($state['manualEdits'] ?? null) ? $state['manualEdits'] : [];
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
    }

    private function delete(PDO $pdo, ?string $id): void {
        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta id']);
            return;
        }
        // respuestas, sugerencias y ediciones caen en cascada por FK.
        $stmt = $pdo->prepare('DELETE FROM revisiones WHERE id = :id');
        $stmt->execute(['id' => $id]);
        if ($stmt->rowCount() === 0) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }
        echo json_encode(['ok' => true]);
    }

    /** Fila de sugerencia -> JSON con las mismas claves que el formato de origen. */
    private function suggestionToJson(array $row): array {
        $out = [
            'orden'    => (int)$row['orden'],
            'type'     => $row['type'],
            'title'    => $row['title'],
            'location' => $row['location'],
            'reason'   => $row['reason'],
            'proposed' => $row['proposed'],
        ];
        if ($row['type'] === 'replace') {
            $out['original'] = $row['original'];
        } else {
            $out['anchor']   = $row['anchor'];
            $out['insert']   = $row['insert_mode'];
            $out['previous'] = $row['previous'];
            $out['next']     = $row['next'];
        }
        return $out;
    }

    private function slugify(string $text): string {
        $text = strtolower(trim($text));
        $text = preg_replace('/[^a-z0-9]+/u', '-', $text);
        return trim($text, '-') ?: 'revision';
    }
}
