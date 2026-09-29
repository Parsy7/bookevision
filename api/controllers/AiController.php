<?php

/**
 * Asistente de IA (Google AI Studio / Gemini): chat libre, preguntas sobre un
 * fragmento seleccionado, y generación de sugerencias de edición en el mismo
 * formato que ya soporta la app.
 *
 *   POST /ai/chat                       -> {mensaje} -> {respuesta}
 *   POST /ai/preguntar-seleccion        -> {seleccion, pregunta} -> {respuesta}
 *   POST /revisiones/{id}/ia-sugerencias -> {instruccion?, seed?} -> revisión completa
 */
class AiController {
    /** `/ai/{accion}` — aquí `$id` hace de acción, igual que en /auth/{accion}. */
    public function handle(string $method, ?string $id, int $userId): void {
        if ($method !== 'POST') {
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
            return;
        }
        switch ($id) {
            case 'chat':
                $this->chat();
                break;
            case 'preguntar-seleccion':
                $this->preguntarSeleccion();
                break;
            default:
                http_response_code(404);
                echo json_encode(['error' => 'Ruta no encontrada']);
        }
    }

    private function chat(): void {
        $body = json_body();
        $mensaje = trim($body['mensaje'] ?? '');
        if ($mensaje === '') {
            http_response_code(400);
            echo json_encode(['error' => 'Falta mensaje']);
            return;
        }
        try {
            $resultado = GeminiClient::generar($mensaje);
        } catch (Throwable $e) {
            http_response_code(502);
            echo json_encode(['error' => $e->getMessage()]);
            return;
        }
        echo json_encode(['respuesta' => $resultado['text']]);
    }

    private function preguntarSeleccion(): void {
        $body = json_body();
        $seleccion = trim($body['seleccion'] ?? '');
        $pregunta = trim($body['pregunta'] ?? '');
        if ($seleccion === '' || $pregunta === '') {
            http_response_code(400);
            echo json_encode(['error' => 'Faltan seleccion o pregunta']);
            return;
        }
        $prompt = "Este es un fragmento de un capítulo de una novela:\n\n"
            . "\"{$seleccion}\"\n\n"
            . "Pregunta sobre ese fragmento: {$pregunta}";
        try {
            $resultado = GeminiClient::generar($prompt);
        } catch (Throwable $e) {
            http_response_code(502);
            echo json_encode(['error' => $e->getMessage()]);
            return;
        }
        echo json_encode(['respuesta' => $resultado['text']]);
    }

    /** `POST /revisiones/{id}/ia-sugerencias`. */
    public function generarSugerencias(string $method, ?string $revisionId, int $userId): void {
        if ($method !== 'POST') {
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
            return;
        }
        if (!$revisionId) {
            http_response_code(400);
            echo json_encode(['error' => 'Falta id de revisión']);
            return;
        }

        $pdo = get_pdo();
        $stmt = $pdo->prepare(
            'SELECT r.chapter FROM revisiones r
               JOIN libros b ON b.id = r.libro_id
              WHERE r.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => $revisionId, 'user_id' => $userId]);
        $revision = $stmt->fetch();
        if (!$revision) {
            http_response_code(404);
            echo json_encode(['error' => 'Revisión no encontrada']);
            return;
        }

        $body = json_body();
        $instruccion = trim($body['instruccion'] ?? '')
            ?: 'Mejora el capítulo con sugerencias de edición de estilo, ritmo y claridad, sin cambiar la trama.';
        $seed = is_array($body['seed'] ?? null) ? $body['seed'] : null;

        $prompt = $this->promptSugerencias($revision['chapter'], $instruccion, $seed);
        $schema = $this->schemaSugerencias();

        try {
            $resultado = GeminiClient::generar($prompt, $schema);
        } catch (Throwable $e) {
            http_response_code(502);
            echo json_encode(['error' => 'La IA no respondió: ' . $e->getMessage()]);
            return;
        }

        $suggestions = $resultado['json']['suggestions'] ?? null;
        if (!is_array($suggestions)) {
            http_response_code(502);
            echo json_encode(['error' => 'La IA devolvió un formato inesperado']);
            return;
        }
        $errorValidacion = SuggestionValidator::validar($suggestions);
        if ($errorValidacion !== null) {
            http_response_code(502);
            echo json_encode(['error' => 'La IA devolvió sugerencias inválidas: ' . $errorValidacion]);
            return;
        }

        if (!empty($suggestions)) {
            $pdo->beginTransaction();
            try {
                SuggestionValidator::insertar($pdo, $revisionId, $suggestions);
                $pdo->commit();
            } catch (Throwable $e) {
                $pdo->rollBack();
                throw $e;
            }
        }

        // Devuelve la revisión completa y actualizada, mismo formato que
        // GET /revisiones/{id}: el cliente no necesita parsear nada nuevo.
        (new ReviewController())->handle('GET', $revisionId, $userId);
    }

    private function promptSugerencias(string $chapter, string $instruccion, ?array $seed): string {
        $prompt = "Eres un editor de novelas. Este es el texto completo de un capítulo:\n\n"
            . "\"\"\"\n{$chapter}\n\"\"\"\n\n"
            . "Instrucción: {$instruccion}\n\n"
            . "Genera sugerencias de edición. Cada sugerencia es de tipo "
            . "\"replace\" (sustituye un fragmento exacto del texto anterior por otro) "
            . "o \"insert\" (añade un fragmento nuevo junto a un ancla exacta del texto anterior). "
            . "El campo \"original\"/\"anchor\" debe ser una copia literal y exacta de un fragmento "
            . "del capítulo, para poder localizarlo.";

        if ($seed !== null) {
            $seleccion = (string)($seed['selection'] ?? '');
            $pregunta = (string)($seed['question'] ?? '');
            $respuesta = (string)($seed['answer'] ?? '');
            if ($seleccion !== '') {
                $prompt .= "\n\nComo contexto adicional, el autor seleccionó este fragmento:\n"
                    . "\"{$seleccion}\"\nY preguntó: \"{$pregunta}\"\nTu respuesta fue: \"{$respuesta}\"\n"
                    . "Convierte esa conversación en una sugerencia concreta sobre ese fragmento.";
            }
        }

        return $prompt;
    }

    /** JSON Schema de `{"suggestions": [...]}` en el formato replace/insert de siempre. */
    private function schemaSugerencias(): array {
        return [
            'type' => 'object',
            'properties' => [
                'suggestions' => [
                    'type' => 'array',
                    'items' => [
                        'type' => 'object',
                        'properties' => [
                            'type' => ['type' => 'string', 'enum' => ['replace', 'insert']],
                            'title' => ['type' => 'string'],
                            'reason' => ['type' => 'string'],
                            'original' => ['type' => 'string'],
                            'proposed' => ['type' => 'string'],
                            'anchor' => ['type' => 'string'],
                            'insert' => ['type' => 'string', 'enum' => ['before', 'after']],
                        ],
                        'required' => ['type', 'reason', 'proposed'],
                    ],
                ],
            ],
            'required' => ['suggestions'],
        ];
    }
}
