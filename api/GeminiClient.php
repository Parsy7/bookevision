<?php

/**
 * Cliente fino sobre la API de Google AI Studio (Gemini). Primer cliente
 * HTTP saliente de BookeVision: sin nada previo que calcar, ver
 * https://ai.google.dev/api/generate-content.
 */
class GeminiClient {
    /** Reintentos ante saturación puntual del modelo (429/503, "high demand"). */
    private const INTENTOS = 3;
    private const ESPERA_INICIAL_MS = 800;

    /**
     * Si el modelo principal sigue saturado tras agotar los reintentos, se
     * prueba una vez con este modelo de reserva antes de rendirse — Google
     * separa la capacidad de Flash y Flash-Lite, así que una sobrecarga
     * sostenida (no un simple pico) del primero no tiene por qué afectar al
     * segundo. Configurable con `GEMINI_MODEL_FALLBACK` en `db.php`.
     */
    private const MODELO_RESERVA_POR_DEFECTO = 'gemini-flash-lite-latest';

    /**
     * Pide contenido al modelo. Si `$schema` no es null, fuerza salida JSON
     * estructurada (`generationConfig.responseSchema`) y devuelve también el
     * resultado ya decodificado en `json`.
     *
     * @return array{text: string, json: ?array}
     */
    public static function generar(string $prompt, ?array $schema = null): array {
        if (!defined('GEMINI_API_KEY') || GEMINI_API_KEY === '') {
            throw new Exception('GEMINI_API_KEY no está configurada en api/db.php');
        }
        $modeloPrincipal = (defined('GEMINI_MODEL') && GEMINI_MODEL !== '')
            ? GEMINI_MODEL : 'gemini-flash-latest';

        $body = ['contents' => [['parts' => [['text' => $prompt]]]]];
        if ($schema !== null) {
            $body['generationConfig'] = [
                'responseMimeType' => 'application/json',
                'responseSchema' => $schema,
            ];
        }

        $resultado = self::intentar($modeloPrincipal, $body, $schema, self::INTENTOS);
        if ($resultado['ok']) return $resultado['valor'];

        $modeloReserva = (defined('GEMINI_MODEL_FALLBACK') && GEMINI_MODEL_FALLBACK !== '')
            ? GEMINI_MODEL_FALLBACK : self::MODELO_RESERVA_POR_DEFECTO;
        if ($resultado['transitorio'] && $modeloReserva !== $modeloPrincipal) {
            $resultadoReserva = self::intentar($modeloReserva, $body, $schema, 2);
            if ($resultadoReserva['ok']) return $resultadoReserva['valor'];
            throw new Exception($resultadoReserva['mensaje']);
        }

        throw new Exception($resultado['mensaje']);
    }

    /**
     * Reintenta hasta `$intentos` veces contra un modelo concreto, con espera
     * creciente. Nunca lanza: siempre dice si acabó bien y, si no, si el
     * último fallo fue de los que merece la pena reintentar con otro modelo.
     *
     * @return array{ok: bool, valor?: array, transitorio?: bool, mensaje?: string}
     */
    private static function intentar(string $modelo, array $body, ?array $schema, int $intentos): array {
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$modelo}:generateContent";
        $esperaMs = self::ESPERA_INICIAL_MS;
        $transitorio = false;
        $mensaje = 'Gemini no respondió tras varios intentos';

        for ($intento = 1; $intento <= $intentos; $intento++) {
            [$httpCode, $decoded, $raw, $error] = self::llamar($url, $body);

            if ($raw === false) {
                $transitorio = false;
                $mensaje = 'No se pudo contactar con Gemini: ' . $error;
            } elseif ($httpCode >= 200 && $httpCode < 300) {
                $texto = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
                if ($texto === null) {
                    return ['ok' => false, 'transitorio' => false, 'mensaje' => 'Gemini no devolvió ningún texto'];
                }
                return ['ok' => true, 'valor' => [
                    'text' => $texto,
                    'json' => $schema !== null ? json_decode($texto, true) : null,
                ]];
            } else {
                $textoError = is_array($decoded) ? ($decoded['error']['message'] ?? $raw) : $raw;
                $transitorio = self::esTransitorio($httpCode, (string)$textoError);
                $mensaje = 'Gemini devolvió un error: ' . $textoError;
                if (!$transitorio) {
                    return ['ok' => false, 'transitorio' => false, 'mensaje' => $mensaje];
                }
            }

            if ($intento < $intentos) {
                usleep($esperaMs * 1000);
                $esperaMs *= 2;
            }
        }

        return ['ok' => false, 'transitorio' => $transitorio, 'mensaje' => $mensaje];
    }

    /** 429 (cuota) y 503 (sobrecarga) son los códigos que Google documenta como reintentables. */
    private static function esTransitorio(int $httpCode, string $mensaje): bool {
        if ($httpCode === 429 || $httpCode === 503) return true;
        return stripos($mensaje, 'high demand') !== false
            || stripos($mensaje, 'overloaded') !== false;
    }

    /** @return array{0: int, 1: ?array, 2: string|false, 3: string} */
    private static function llamar(string $url, array $body): array {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'x-goog-api-key: ' . GEMINI_API_KEY,
            ],
            CURLOPT_POSTFIELDS => json_encode($body),
            CURLOPT_TIMEOUT => 30,
        ]);
        $raw = curl_exec($ch);
        $error = curl_error($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        $decoded = $raw !== false ? json_decode($raw, true) : null;
        return [$httpCode, $decoded, $raw, $error];
    }
}
