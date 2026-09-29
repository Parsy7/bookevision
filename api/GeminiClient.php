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

        if ($raw === false) {
            throw new Exception('No se pudo contactar con Gemini: ' . $error);
        }

        $decoded = json_decode($raw, true);
        if ($httpCode < 200 || $httpCode >= 300) {
            $mensaje = is_array($decoded) ? ($decoded['error']['message'] ?? $raw) : $raw;
            throw new Exception('Gemini devolvió un error: ' . $mensaje);
        }

        $texto = $decoded['candidates'][0]['content']['parts'][0]['text'] ?? null;
        if ($texto === null) {
            throw new Exception('Gemini no devolvió ningún texto');
        }

        return [
            'text' => $texto,
            'json' => $schema !== null ? json_decode($texto, true) : null,
        ];
    }
}
