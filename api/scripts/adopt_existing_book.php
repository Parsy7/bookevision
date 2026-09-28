<?php
// Script de UN SOLO USO: adopta el libro y las revisiones que ya existían
// antes de las cuentas de usuario, asignándoselos a una cuenta real.
//
// Requisitos previos:
//   1. Haber aplicado sql/migrations/2026-09-28-users-libros-revisiones.sql.
//   2. Haberte registrado ya en la app (o vía POST /auth/register) — este
//      script NO crea la cuenta ni inventa una contraseña por ti.
//
// Uso (por SSH, desde la carpeta api/scripts):
//   php adopt_existing_book.php tu@email.com

require_once __DIR__ . '/../db.php';

if ($argc < 2) {
    fwrite(STDERR, "Uso: php adopt_existing_book.php <email>\n");
    exit(1);
}

$email = strtolower(trim($argv[1]));

$pdo = get_pdo();

$stmt = $pdo->prepare('SELECT id FROM users WHERE email = :email');
$stmt->execute(['email' => $email]);
$user = $stmt->fetch();
if (!$user) {
    fwrite(STDERR, "No existe ninguna cuenta con ese email. Regístrate primero en la app.\n");
    exit(1);
}
$userId = (int)$user['id'];

$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare('SELECT id FROM libros WHERE user_id = :user_id AND title = :title');
    $stmt->execute(['user_id' => $userId, 'title' => 'La jaula rota']);
    $libro = $stmt->fetch();

    if ($libro) {
        $libroId = (int)$libro['id'];
    } else {
        $pdo->prepare('INSERT INTO libros (user_id, title) VALUES (:user_id, :title)')
            ->execute(['user_id' => $userId, 'title' => 'La jaula rota']);
        $libroId = (int)$pdo->lastInsertId();
    }

    $stmt = $pdo->prepare('UPDATE revisiones SET libro_id = :libro_id WHERE libro_id IS NULL');
    $stmt->execute(['libro_id' => $libroId]);
    $adoptadas = $stmt->rowCount();

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    fwrite(STDERR, 'Error: ' . $e->getMessage() . "\n");
    exit(1);
}

echo "Libro 'La jaula rota' (id={$libroId}) asignado a {$email}. "
    . "Revisiones adoptadas: {$adoptadas}.\n";
