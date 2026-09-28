<?php

/** Cuentas: registro y login por email+contraseña. Sin Google en esta fase. */
class AuthController {
    public function handle(string $method, ?string $action): void {
        switch ($action) {
            case 'register':
                if ($method !== 'POST') { $this->methodNotAllowed(); return; }
                $this->register();
                break;
            case 'login':
                if ($method !== 'POST') { $this->methodNotAllowed(); return; }
                $this->login();
                break;
            case 'logout':
                if ($method !== 'POST') { $this->methodNotAllowed(); return; }
                $this->logout();
                break;
            case 'me':
                if ($method !== 'GET') { $this->methodNotAllowed(); return; }
                $this->me();
                break;
            default:
                http_response_code(404);
                echo json_encode(['error' => 'Ruta no encontrada']);
        }
    }

    private function methodNotAllowed(): void {
        http_response_code(405);
        echo json_encode(['error' => 'Método no permitido']);
    }

    private function register(): void {
        $body = json_body();
        $email = strtolower(trim($body['email'] ?? ''));
        $password = (string)($body['password'] ?? '');
        $name = trim($body['name'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($password) < 8) {
            http_response_code(400);
            echo json_encode(['error' => 'Email inválido o contraseña demasiado corta (mínimo 8 caracteres)']);
            return;
        }

        $pdo = get_pdo();
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email = :email');
        $stmt->execute(['email' => $email]);
        if ($stmt->fetch()) {
            http_response_code(409);
            echo json_encode(['error' => 'Ya existe una cuenta con ese email']);
            return;
        }

        $stmt = $pdo->prepare(
            'INSERT INTO users (email, password_hash, name) VALUES (:email, :password_hash, :name)'
        );
        $stmt->execute([
            'email' => $email,
            'password_hash' => password_hash($password, PASSWORD_DEFAULT),
            'name' => $name !== '' ? $name : null,
        ]);
        $userId = (int)$pdo->lastInsertId();

        echo json_encode([
            'token' => issue_token($userId),
            'user' => ['id' => $userId, 'email' => $email, 'name' => $name ?: null],
        ]);
    }

    private function login(): void {
        $body = json_body();
        $email = strtolower(trim($body['email'] ?? ''));
        $password = (string)($body['password'] ?? '');

        $pdo = get_pdo();
        $stmt = $pdo->prepare('SELECT id, email, name, password_hash FROM users WHERE email = :email');
        $stmt->execute(['email' => $email]);
        $user = $stmt->fetch();

        if (!$user || !$user['password_hash'] || !password_verify($password, $user['password_hash'])) {
            http_response_code(401);
            echo json_encode(['error' => 'Email o contraseña incorrectos']);
            return;
        }

        echo json_encode([
            'token' => issue_token((int)$user['id']),
            'user' => ['id' => (int)$user['id'], 'email' => $user['email'], 'name' => $user['name']],
        ]);
    }

    private function logout(): void {
        $token = bearer_token();
        if ($token) {
            $pdo = get_pdo();
            $pdo->prepare('DELETE FROM auth_tokens WHERE token_hash = :token_hash')
                ->execute(['token_hash' => hash_token($token)]);
        }
        echo json_encode(['ok' => true]);
    }

    private function me(): void {
        $userId = require_auth();
        $pdo = get_pdo();
        $stmt = $pdo->prepare('SELECT id, email, name FROM users WHERE id = :id');
        $stmt->execute(['id' => $userId]);
        echo json_encode($stmt->fetch());
    }
}
