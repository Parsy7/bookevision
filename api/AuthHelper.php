<?php
// Tokens de sesión opacos (no JWT): random_bytes + hash guardado en auth_tokens.
// El cliente manda "Authorization: Bearer <token>" en cada petición.

function generate_token(): string {
    return bin2hex(random_bytes(32));
}

function hash_token(string $token): string {
    return hash('sha256', $token);
}

function issue_token(int $userId): string {
    $pdo = get_pdo();
    $token = generate_token();
    $stmt = $pdo->prepare('INSERT INTO auth_tokens (user_id, token_hash) VALUES (:user_id, :token_hash)');
    $stmt->execute(['user_id' => $userId, 'token_hash' => hash_token($token)]);
    return $token;
}

function bearer_token(): ?string {
    // Apache/mod_php a veces no expone la cabecera Authorization a
    // getallheaders(); de ahí el fallback a $_SERVER (con y sin el prefijo
    // REDIRECT_ que añade una reescritura de .htaccess).
    $auth = '';
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    foreach (['Authorization', 'authorization'] as $key) {
        if (!empty($headers[$key])) {
            $auth = $headers[$key];
            break;
        }
    }
    if ($auth === '') {
        $auth = $_SERVER['HTTP_AUTHORIZATION']
            ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
            ?? '';
    }

    if (!preg_match('/^Bearer\s+(.+)$/i', $auth, $matches)) {
        return null;
    }
    return trim($matches[1]);
}

/** Devuelve el user_id autenticado o corta la petición con 401. */
function require_auth(): int {
    $token = bearer_token();
    if (!$token) {
        http_response_code(401);
        echo json_encode(['error' => 'No autenticado']);
        exit;
    }

    $tokenHash = hash_token($token);
    $pdo = get_pdo();
    $stmt = $pdo->prepare('SELECT user_id FROM auth_tokens WHERE token_hash = :token_hash');
    $stmt->execute(['token_hash' => $tokenHash]);
    $row = $stmt->fetch();
    if (!$row) {
        http_response_code(401);
        echo json_encode(['error' => 'Sesión inválida o caducada']);
        exit;
    }

    $pdo->prepare('UPDATE auth_tokens SET last_used_at = NOW() WHERE token_hash = :token_hash')
        ->execute(['token_hash' => $tokenHash]);

    return (int)$row['user_id'];
}
