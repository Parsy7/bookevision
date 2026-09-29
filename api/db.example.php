<?php
// Configuración de conexión a MariaDB.
// Copia este archivo como db.php (fuera de git) y rellena los valores reales.
define('DB_HOST', 'localhost');
define('DB_NAME', 'jaula_revisor');
define('DB_USER', 'jaula_user');
define('DB_PASS', 'CAMBIA_ESTA_CONTRASENA');

// Secreto para ejecutar los scripts de un solo uso de api/scripts/ (migraciones)
// visitando su URL en el navegador en vez de por SSH:
//   https://TU-DOMINIO/revisor/api/scripts/run_migrations.php?secret=ESTE_VALOR
// Genera una cadena larga al azar y no la compartas.
define('SCRIPT_SECRET', '');

// Clave de Google AI Studio (https://aistudio.google.com) para el asistente
// de IA. Nunca se manda al cliente Flutter: todas las llamadas a Gemini
// pasan por aquí, en el servidor.
define('GEMINI_API_KEY', '');
// Alias de Google que apunta siempre al Flash estable más reciente, para no
// tener que tocar código cada vez que retiran una versión.
define('GEMINI_MODEL', 'gemini-flash-latest');
// Opcional: modelo de reserva si el principal está saturado (Google separa
// la capacidad de Flash y Flash-Lite). Sin definir, GeminiClient usa
// 'gemini-flash-lite-latest' por defecto — solo hace falta tocar esto para
// cambiar ese valor por defecto.
// define('GEMINI_MODEL_FALLBACK', 'gemini-flash-lite-latest');

function get_pdo(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4';
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            // Sin esto, rowCount() tras un UPDATE cuenta solo las filas que han
            // cambiado de verdad, no las que ha encontrado el WHERE. Los
            // controladores usan rowCount() === 0 para decidir "no existe" (404).
            PDO::MYSQL_ATTR_FOUND_ROWS => true,
        ]);
    }
    return $pdo;
}

function json_body(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}
