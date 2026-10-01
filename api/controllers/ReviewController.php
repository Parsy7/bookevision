<?php

/**
 * Revisiones: capítulo + sugerencias. La importación acepta tanto el formato
 * de revisión ('la-jaula-rota-review-v4') como el de estado guardado
 * ('la-jaula-rota-state-v2'), replicando loadReview/loadState del HTML.
 */
class ReviewController {
    public function handle(string $method, ?string $id, int $userId): void {
        $pdo = get_pdo();

        switch ($method) {
            case 'GET':
                if ($id) { $this->getOne($pdo, $id, $userId); }
                else     { $this->getList($pdo, $userId); }
                break;
            case 'POST':
                $this->import($pdo, $userId);
                break;
            case 'PUT':
                $this->update($pdo, $id, $userId);
                break;
            case 'DELETE':
                $this->delete($pdo, $id, $userId);
                break;
            default:
                http_response_code(405);
                echo json_encode(['error' => 'Método no permitido']);
        }
    }

    /** Comprueba que el libro existe y es del usuario. */
    private function libroDelUsuario(PDO $pdo, string $libroId, int $userId): bool {
        $stmt = $pdo->prepare('SELECT 1 FROM libros WHERE id = :id AND user_id = :user_id');
        $stmt->execute(['id' => $libroId, 'user_id' => $userId]);
        return (bool)$stmt->fetch();
    }

    /**
     * Capítulo del usuario (con su libro_id), o null si no existe o no es
     * suyo. Lo usan también CapituloController y las revisiones.
     */
    public static function capituloDelUsuario(PDO $pdo, string $capituloId, int $userId): ?array {
        $stmt = $pdo->prepare(
            'SELECT c.* FROM capitulos c
               JOIN libros b ON b.id = c.libro_id
              WHERE c.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => $capituloId, 'user_id' => $userId]);
        return $stmt->fetch() ?: null;
    }

    /**
     * Revisiones con su progreso, filtradas por `libro_id` o `capitulo_id`
     * (el llamador ya ha comprobado que es del usuario). Único sitio donde se
     * decide si una revisión está lista: con sugerencias, todas resueltas;
     * sin ellas (capítulo suelto), marcada como finalizada a mano.
     */
    public static function listarConProgreso(PDO $pdo, string $campo, int $valor): array {
        $columna = $campo === 'capitulo_id' ? 'r.capitulo_id' : 'r.libro_id';
        $stmt = $pdo->prepare(
            "SELECT
                r.id, r.libro_id, r.capitulo_id, r.finalizada, r.format, r.title, r.source,
                r.created_at, r.updated_at,
                (SELECT COUNT(*) FROM sugerencias s WHERE s.revision_id = r.id) AS total,
                (SELECT COUNT(*) FROM respuestas a
                   WHERE a.revision_id = r.id
                     AND (a.choice IN ('original','proposed','omit')
                          OR (a.choice = 'custom' AND a.custom IS NOT NULL AND a.custom <> ''))
                ) AS resolved,
                (SELECT COUNT(*) FROM ediciones_manuales e WHERE e.revision_id = r.id) AS manual
             FROM revisiones r
             WHERE {$columna} = :valor
             ORDER BY r.updated_at DESC"
        );
        $stmt->execute(['valor' => $valor]);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['capitulo_id'] = $row['capitulo_id'] === null ? null : (int)$row['capitulo_id'];
            $row['total']       = (int)$row['total'];
            $row['resolved']    = (int)$row['resolved'];
            $row['manual']      = (int)$row['manual'];
            $row['finalizada']  = (bool)$row['finalizada'];
            $row['lista']       = $row['total'] > 0
                ? $row['resolved'] >= $row['total']
                : $row['finalizada'];
        }
        return $rows;
    }

    /** Lista de revisiones de un capítulo (`?capitulo_id=`) o de un libro entero (`?libro_id=`). */
    private function getList(PDO $pdo, int $userId): void {
        $capituloId = $_GET['capitulo_id'] ?? null;
        if ($capituloId !== null) {
            if (!ctype_digit((string)$capituloId)
                || !self::capituloDelUsuario($pdo, (string)$capituloId, $userId)) {
                http_response_code(404);
                echo json_encode(['error' => 'Capítulo no encontrado']);
                return;
            }
            echo json_encode(self::listarConProgreso($pdo, 'capitulo_id', (int)$capituloId));
            return;
        }

        $libroId = $_GET['libro_id'] ?? null;
        if (!$libroId || !ctype_digit((string)$libroId)) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta libro_id o capitulo_id']);
            return;
        }
        if (!$this->libroDelUsuario($pdo, (string)$libroId, $userId)) {
            http_response_code(404);
            echo json_encode(['error' => 'Libro no encontrado']);
            return;
        }
        echo json_encode(self::listarConProgreso($pdo, 'libro_id', (int)$libroId));
    }

    /** Revisión completa: metadatos + capítulo + sugerencias ordenadas. */
    private function getOne(PDO $pdo, string $id, int $userId): void {
        $stmt = $pdo->prepare(
            'SELECT r.* FROM revisiones r
               JOIN libros b ON b.id = r.libro_id
              WHERE r.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => $id, 'user_id' => $userId]);
        $review = $stmt->fetch();
        if (!$review) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }
        $review['capitulo_id'] = $review['capitulo_id'] === null ? null : (int)$review['capitulo_id'];
        $review['finalizada'] = (bool)$review['finalizada'];

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
     * Va a `capitulo_id`; sin él (clientes anteriores a los capítulos) basta
     * `libro_id` y se le crea un capítulo propio con su título.
     * Si el id ya existe se responde 409 (bórrala antes de reimportar).
     */
    private function import(PDO $pdo, int $userId): void {
        $body = json_body();

        $capituloId = $body['capitulo_id'] ?? null;
        $libroId = $body['libro_id'] ?? null;
        if ($capituloId !== null) {
            $capitulo = ctype_digit((string)$capituloId)
                ? self::capituloDelUsuario($pdo, (string)$capituloId, $userId)
                : null;
            if (!$capitulo) {
                http_response_code(404);
                echo json_encode(['error' => 'Capítulo no encontrado']);
                return;
            }
            $libroId = $capitulo['libro_id'];
        } else {
            if (!$libroId || !ctype_digit((string)$libroId)) {
                http_response_code(400);
                echo json_encode(['error' => 'Falta capitulo_id o libro_id']);
                return;
            }
            if (!$this->libroDelUsuario($pdo, (string)$libroId, $userId)) {
                http_response_code(404);
                echo json_encode(['error' => 'Libro no encontrado']);
                return;
            }
        }

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
        $errorValidacion = SuggestionValidator::validar($review['suggestions']);
        if ($errorValidacion !== null) {
            http_response_code(400);
            echo json_encode(['error' => $errorValidacion]);
            return;
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
            if ($capituloId === null) {
                $capituloId = CapituloController::crear(
                    $pdo, (int)$libroId, (string)($review['title'] ?? 'Capítulo'), null
                );
            }
            $pdo->prepare(
                'INSERT INTO revisiones (id, libro_id, capitulo_id, format, title, source, chapter)
                 VALUES (:id, :libro_id, :capitulo_id, :format, :title, :source, :chapter)'
            )->execute([
                'id'      => $id,
                'libro_id' => $libroId,
                'capitulo_id' => $capituloId,
                'format'  => $review['format'] ?? 'la-jaula-rota-review-v4',
                'title'   => $review['title'] ?? 'Capítulo',
                'source'  => $review['source'] ?? null,
                'chapter' => $review['chapter'],
            ]);

            SuggestionValidator::insertar($pdo, $id, $review['suggestions']);

            // Si venía un estado guardado, lo aplicamos encima.
            if ($isState) {
                $this->applyImportedState($pdo, $id, $body);
            }

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        $this->getOne($pdo, $id, $userId);
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
                'choice'          => in_array($a['choice'] ?? null, ['original','proposed','custom','omit'], true)
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

    /**
     * `PUT /revisiones/{id}` con `capitulo_id` (moverla a otro capítulo del
     * mismo libro) y/o `finalizada` (marcar o reabrir un capítulo suelto).
     */
    private function update(PDO $pdo, ?string $id, int $userId): void {
        $stmt = $pdo->prepare(
            'SELECT r.id, r.libro_id FROM revisiones r
               JOIN libros b ON b.id = r.libro_id
              WHERE r.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => (string)$id, 'user_id' => $userId]);
        $revision = $stmt->fetch();
        if (!$revision) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }

        $body = json_body();
        $cambios = [];
        $params = ['id' => $revision['id']];
        if (array_key_exists('capitulo_id', $body)) {
            $capitulo = ctype_digit((string)$body['capitulo_id'])
                ? self::capituloDelUsuario($pdo, (string)$body['capitulo_id'], $userId)
                : null;
            if (!$capitulo || (int)$capitulo['libro_id'] !== (int)$revision['libro_id']) {
                http_response_code(404);
                echo json_encode(['error' => 'Capítulo no encontrado en este libro']);
                return;
            }
            $cambios[] = 'capitulo_id = :capitulo_id';
            $params['capitulo_id'] = (int)$capitulo['id'];
        }
        if (array_key_exists('finalizada', $body)) {
            $cambios[] = 'finalizada = :finalizada';
            $params['finalizada'] = $body['finalizada'] ? 1 : 0;
        }
        if (!$cambios) {
            http_response_code(400);
            echo json_encode(['error' => 'Nada que cambiar: capitulo_id o finalizada']);
            return;
        }
        $pdo->prepare('UPDATE revisiones SET ' . implode(', ', $cambios) . ' WHERE id = :id')
            ->execute($params);
        echo json_encode(['ok' => true]);
    }

    private function delete(PDO $pdo, ?string $id, int $userId): void {
        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta id']);
            return;
        }
        // respuestas, sugerencias y ediciones caen en cascada por FK.
        $stmt = $pdo->prepare(
            'DELETE r FROM revisiones r
               JOIN libros b ON b.id = r.libro_id
              WHERE r.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => $id, 'user_id' => $userId]);
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
