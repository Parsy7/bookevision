<?php

/**
 * Catálogo de temas de color. Compartido entre todos los usuarios (no tiene
 * dueño, a diferencia de los libros): añadir uno nuevo es un INSERT en
 * `temas`, sin tocar código ni desplegar una versión nueva de la app.
 *
 *   GET /temas -> lista todos, en orden
 */
class TemaController {
    public function handle(string $method): void {
        if ($method !== 'GET') {
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
            return;
        }

        $pdo = get_pdo();
        $stmt = $pdo->query(
            'SELECT id, nombre, paper, sheet, white, ink, acento, blue,
                    grey1, grey2, grey3, strike,
                    acento_texto, peligro, sobre_acento
             FROM temas
             ORDER BY orden ASC'
        );
        $rows = $stmt->fetchAll();
        foreach ($rows as &$row) {
            $row['id'] = (int)$row['id'];
        }
        echo json_encode($rows);
    }
}
