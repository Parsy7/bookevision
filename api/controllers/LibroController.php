<?php

/**
 * Libros (proyectos): agrupan las revisiones de un usuario.
 *
 *   GET    /libros      -> lista los del usuario, con nº de capítulos
 *   POST   /libros      -> crea uno nuevo ({title})
 *   DELETE /libros/{id} -> lo borra (solo si es suyo); sus revisiones caen
 *                          en cascada por FK
 */
class LibroController {
    public function handle(string $method, ?string $id, int $userId): void {
        $pdo = get_pdo();

        switch ($method) {
            case 'GET':
                $this->getList($pdo, $userId);
                break;
            case 'POST':
                $this->create($pdo, $userId);
                break;
            case 'DELETE':
                $this->delete($pdo, $id, $userId);
                break;
            default:
                http_response_code(405);
                echo json_encode(['error' => 'Método no permitido']);
        }
    }

    private function getList(PDO $pdo, int $userId): void {
        $stmt = $pdo->prepare(
            "SELECT
                l.id, l.title, l.created_at, l.updated_at,
                (SELECT COUNT(*) FROM capitulos c WHERE c.libro_id = l.id) AS capitulos
             FROM libros l
             WHERE l.user_id = :user_id
             ORDER BY l.updated_at DESC"
        );
        $stmt->execute(['user_id' => $userId]);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
            $row['capitulos'] = (int)$row['capitulos'];
        }
        echo json_encode($rows);
    }

    private function create(PDO $pdo, int $userId): void {
        $body = json_body();
        $title = trim($body['title'] ?? '');
        if ($title === '') {
            http_response_code(400);
            echo json_encode(['error' => 'Falta el título del libro']);
            return;
        }

        $stmt = $pdo->prepare('INSERT INTO libros (user_id, title) VALUES (:user_id, :title)');
        $stmt->execute(['user_id' => $userId, 'title' => $title]);
        $id = (int)$pdo->lastInsertId();

        echo json_encode(['id' => $id, 'title' => $title, 'capitulos' => 0]);
    }

    private function delete(PDO $pdo, ?string $id, int $userId): void {
        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta id']);
            return;
        }
        $stmt = $pdo->prepare('DELETE FROM libros WHERE id = :id AND user_id = :user_id');
        $stmt->execute(['id' => $id, 'user_id' => $userId]);
        if ($stmt->rowCount() === 0) {
            http_response_code(404);
            echo json_encode(['error' => 'Libro no encontrado']);
            return;
        }
        echo json_encode(['ok' => true]);
    }
}
