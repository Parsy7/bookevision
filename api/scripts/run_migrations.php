<?php
// Aplica las migraciones pendientes de api/sql/migrations/*.sql en orden de
// nombre, saltando las ya aplicadas. Ejecutar visitando su URL:
//   https://TU-DOMINIO/revisor/api/scripts/run_migrations.php?secret=SCRIPT_SECRET
//
// El esquema base (api/sql/schema.sql) se aplica UNA vez a mano (phpMyAdmin o
// CLI); es destructivo. Los cambios posteriores van como migraciones nuevas.

header('Content-Type: text/plain; charset=utf-8');
require_once __DIR__ . '/../db.php';

if (!defined('SCRIPT_SECRET') || SCRIPT_SECRET === '' ||
    ($_GET['secret'] ?? '') !== SCRIPT_SECRET) {
    http_response_code(403);
    echo "Prohibido: secreto no válido.\n";
    exit;
}

$pdo = get_pdo();
$pdo->exec(
    'CREATE TABLE IF NOT EXISTS _migrations (
        name VARCHAR(191) PRIMARY KEY,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

$applied = $pdo->query('SELECT name FROM _migrations')->fetchAll(PDO::FETCH_COLUMN);
$applied = array_flip($applied);

$dir = __DIR__ . '/../sql/migrations';
$files = glob($dir . '/*.sql') ?: [];
sort($files, SORT_STRING);

$done = 0;
foreach ($files as $file) {
    $name = basename($file);
    if (isset($applied[$name])) continue;

    $sql = file_get_contents($file);
    $pdo->beginTransaction();
    try {
        $pdo->exec($sql);
        $pdo->prepare('INSERT INTO _migrations (name) VALUES (:name)')
            ->execute(['name' => $name]);
        $pdo->commit();
        echo "Aplicada: $name\n";
        $done++;
    } catch (Throwable $e) {
        $pdo->rollBack();
        echo "ERROR en $name: " . $e->getMessage() . "\n";
        exit;
    }
}

echo $done === 0 ? "Nada que aplicar; todo al día.\n" : "Hecho: $done migración(es).\n";
