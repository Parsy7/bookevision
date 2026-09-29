<?php

/**
 * Cliente fino sobre la API de Google AI Studio (Gemini). Primer cliente
 * HTTP saliente de BookeVision: sin nada previo que calcar, ver
 * https://ai.google.dev/api/generate-content.
 */
class GeminiClient {
    /**
     * Pide contenido al modelo. Si `$schema` no es null, fuerza salida JSON
     * estructurada (`generationConfig.responseSchema`) y devuelve también el
     * resultado ya decodificado en `json`.
     *
     * @return array{text: string, json: ?array}
     */
    /** Reintentos ante saturación puntual del modelo (429/503, "high demand"). */
    private const INTENTOS = 3;
    private const ESPERA_INICIAL_MS = 800;

    public static function generar(string $prompt, ?array $schema = null): array {
        if (!defined('GEMINI_API_KEY') || GEMINI_API_KEY === '') {
            throw new Exception('GEMINI_API_KEY no está configurada en api/db.php');
        }
        $modelo = (defined('GEMINI_MODEL') && GEMINI_MODEL !== '')
            ? GEMINI_MODEL : 'gemini-flash-latest';
        $url = "https://generativelanguage.googleapis.com/v1beta/models/{$modelo}:generateContent";

        $body = ['contents' => [['parts' => [['text' => $prompt]]]]];
        if ($schema !== null) {
            $body['generationConfig'] = [
                'responseMimeType' => 'application/json',
                'responseSchema' => $schema,
            ];
        }

        $esperaMs = self::ESPERA_INICIAL_MS;
        for ($intento = 1; $intento <= self::INTENTOS; $intento++) {
            [$httpCode, $decoded, $raw, $error] = self::llamar($url, $body);
            $ultimoIntento = $intento === self::INTENTOS;

            if ($raw === false) {
                if ($ultimoIntento) {
                    throw new Exception('No se pudo contactar con Gemini: ' . $error);
                }
            } elseif ($httpCode >= 200 && $httpCode < 300) {
                $texto = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
                if ($texto === null) {
                    throw new Exception('Gemini no devolvió ningún texto');
                }
                return [
                    'text' => $texto,
                    'json' => $schema !== null ? json_decode($texto, true) : null,
                ];
            } else {
                $mensaje = is_array($decoded) ? ($decoded['error']['message'] ?? $raw) : $raw;
                if (!$ultimoIntento && self::esTransitorio($httpCode, (string)$mensaje)) {
                    // Modelo saturado un instante: se reintenta sin que el
                    // usuario llegue a ver el error, en vez de rendirse a la
                    // primera (Gemini avisa explícitamente de que son picos
                    // puntuales de demanda).
                } else {
                    throw new Exception('Gemini devolvió un error: ' . $mensaje);
                }
            }

            usleep($esperaMs * 1000);
            $esperaMs *= 2;
        }

        throw new Exception('Gemini no respondió tras varios intentos');
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
