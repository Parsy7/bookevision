<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/controllers/ReviewController.php';
require_once __DIR__ . '/controllers/StateController.php';

// Router simple basado en PATH_INFO:
//   /api/index.php/revisiones
//   /api/index.php/revisiones/{id}
//   /api/index.php/revisiones/{id}/estado
$path = $_SERVER['PATH_INFO'] ?? '/';
$segments = array_values(array_filter(explode('/', $path)));
$resource = $segments[0] ?? '';
$id       = isset($segments[1]) ? urldecode($segments[1]) : null;
$action   = $segments[2] ?? null;
$method   = $_SERVER['REQUEST_METHOD'];

// Sin login: no hay require_auth(). Esta API es de un solo usuario.
try {
    switch ($resource) {
        case 'revisiones':
            if ($action === 'estado') {
                (new StateController())->handle($method, $id);
            } else {
                (new ReviewController())->handle($method, $id);
            }
            break;
        default:
            http_response_code(404);
            echo json_encode(['error' => 'Recurso no encontrado']);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
