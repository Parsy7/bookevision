<?php

/**
 * Capítulos de un libro. Cada uno agrupa sus revisiones.
 *
 *   GET    /capitulos?libro_id=     -> [{id, libro_id, numero, titulo, revisiones, listas, updated_at}]
 *   POST   /capitulos               -> {libro_id, titulo, numero?} -> capítulo creado
 *   PUT    /capitulos/{id}          -> {titulo?, numero?} -> capítulo actualizado
 *   DELETE /capitulos/{id}          -> borra el capítulo y sus revisiones (cascada)
 */
class CapituloController {
    public function handle(string $method, ?string $id, int $userId): void {
        $pdo = get_pdo();
        switch ($method) {
            case 'GET':
                $this->getList($pdo, $userId);
                break;
            case 'POST':
                $this->create($pdo, $userId);
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

    /**
     * Crea un capítulo y devuelve su id. Sin [numero], va el siguiente al
     * mayor del libro. La usa también la importación sin capítulo.
     */
    public static function crear(PDO $pdo, int $libroId, string $titulo, ?int $numero): int {
        if ($numero === null) {
            $stmt = $pdo->prepare('SELECT COALESCE(MAX(numero), 0) + 1 FROM capitulos WHERE libro_id = :id');
            $stmt->execute(['id' => $libroId]);
            $numero = (int)$stmt->fetchColumn();
        }
        $pdo->prepare('INSERT INTO capitulos (libro_id, numero, titulo) VALUES (:libro_id, :numero, :titulo)')
            ->execute(['libro_id' => $libroId, 'numero' => $numero, 'titulo' => $titulo]);
        return (int)$pdo->lastInsertId();
    }

    private function getList(PDO $pdo, int $userId): void {
        $libroId = $_GET['libro_id'] ?? null;
        $stmt = $pdo->prepare('SELECT 1 FROM libros WHERE id = :id AND user_id = :user_id');
        $stmt->execute(['id' => (string)$libroId, 'user_id' => $userId]);
        if (!$libroId || !ctype_digit((string)$libroId) || !$stmt->fetch()) {
            http_response_code(404);
            echo json_encode(['error' => 'Libro no encontrado']);
            return;
        }

        $stmt = $pdo->prepare(
            'SELECT id, libro_id, numero, titulo, updated_at FROM capitulos
              WHERE libro_id = :id ORDER BY numero ASC, id ASC'
        );
        $stmt->execute(['id' => $libroId]);
        $capitulos = [];
        foreach ($stmt->fetchAll() as $c) {
            $c['id'] = (int)$c['id'];
            $c['libro_id'] = (int)$c['libro_id'];
            $c['numero'] = (int)$c['numero'];
            $c['revisiones'] = 0;
            $c['listas'] = 0;
            $capitulos[$c['id']] = $c;
        }
        foreach (ReviewController::listarConProgreso($pdo, 'libro_id', (int)$libroId) as $r) {
            $c = $r['capitulo_id'];
            if ($c === null || !isset($capitulos[$c])) continue;
            $capitulos[$c]['revisiones']++;
            if ($r['lista']) $capitulos[$c]['listas']++;
            // El capítulo se ve "tocado" cuando se toca cualquiera de sus revisiones.
            if ($r['updated_at'] > $capitulos[$c]['updated_at']) {
                $capitulos[$c]['updated_at'] = $r['updated_at'];
            }
        }
        echo json_encode(array_values($capitulos));
    }

    /** `titulo` no vacío y `numero` entero positivo (o ausente si es opcional). */
    private function leerCampos(array $body, bool $tituloObligatorio): ?array {
        $titulo = trim((string)($body['titulo'] ?? ''));
        $numero = $body['numero'] ?? null;
        if ($tituloObligatorio && $titulo === '') return null;
        if ($numero !== null && (!is_numeric($numero) || (int)$numero < 1)) return null;
        return ['titulo' => $titulo, 'numero' => $numero === null ? null : (int)$numero];
    }

    private function create(PDO $pdo, int $userId): void {
        $body = json_body();
        $libroId = $body['libro_id'] ?? null;
        $stmt = $pdo->prepare('SELECT 1 FROM libros WHERE id = :id AND user_id = :user_id');
        $stmt->execute(['id' => (string)$libroId, 'user_id' => $userId]);
        if (!$libroId || !ctype_digit((string)$libroId) || !$stmt->fetch()) {
            http_response_code(404);
            echo json_encode(['error' => 'Libro no encontrado']);
            return;
        }
        $campos = $this->leerCampos($body, true);
        if ($campos === null) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta el título, o el número no es válido']);
            return;
        }
        $id = self::crear($pdo, (int)$libroId, $campos['titulo'], $campos['numero']);
        $this->responderUno($pdo, $id, $userId);
    }

    private function update(PDO $pdo, ?string $id, int $userId): void {
        if (!$id || !ReviewController::capituloDelUsuario($pdo, $id, $userId)) {
            http_response_code(404);
            echo json_encode(['error' => 'Capítulo no encontrado']);
            return;
        }
        $campos = $this->leerCampos(json_body(), false);
        if ($campos === null) {
            http_response_code(400);
            echo json_encode(['error' => 'El número no es válido']);
            return;
        }
        $cambios = [];
        $params = ['id' => $id];
        if ($campos['titulo'] !== '') {
            $cambios[] = 'titulo = :titulo';
            $params['titulo'] = $campos['titulo'];
        }
        if ($campos['numero'] !== null) {
            $cambios[] = 'numero = :numero';
            $params['numero'] = $campos['numero'];
        }
        if ($cambios) {
            $pdo->prepare('UPDATE capitulos SET ' . implode(', ', $cambios) . ' WHERE id = :id')
                ->execute($params);
        }
        $this->responderUno($pdo, (int)$id, $userId);
    }

    private function delete(PDO $pdo, ?string $id, int $userId): void {
        if (!$id || !ReviewController::capituloDelUsuario($pdo, $id, $userId)) {
            http_response_code(404);
            echo json_encode(['error' => 'Capítulo no encontrado']);
            return;
        }
        // Sus revisiones (y con ellas sugerencias, respuestas y ediciones)
        // caen en cascada por FK.
        $pdo->prepare('DELETE FROM capitulos WHERE id = :id')->execute(['id' => $id]);
        echo json_encode(['ok' => true]);
    }

    private function responderUno(PDO $pdo, int $id, int $userId): void {
        $c = ReviewController::capituloDelUsuario($pdo, (string)$id, $userId);
        echo json_encode([
            'id' => (int)$c['id'],
            'libro_id' => (int)$c['libro_id'],
            'numero' => (int)$c['numero'],
            'titulo' => $c['titulo'],
            'updated_at' => $c['updated_at'],
            'revisiones' => 0,
            'listas' => 0,
        ]);
    }
}
