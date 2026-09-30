<?php

/**
 * Asistente de IA (Google AI Studio / Gemini): chat libre, preguntas sobre un
 * fragmento seleccionado, y generación de sugerencias de edición en el mismo
 * formato que ya soporta la app.
 *
 *   POST /ai/chat                       -> {mensaje, revisionId?, capitulo?} -> {respuesta}
 *   POST /ai/preguntar-seleccion        -> {seleccion, pregunta, revisionId?, capitulo?} -> {respuesta}
 *   POST /revisiones/{id}/ia-sugerencias -> {instruccion?, seed?} -> revisión completa
 *
 * `capitulo`, si viene, es el texto que el cliente use como contexto —
 * compuesto con las decisiones ya tomadas en el revisor y en vista previa,
 * o el original literal en "Ver original" —, y se usa tal cual sin volver
 * a componerlo aquí (esa lógica solo existe en el cliente). Sin `capitulo`,
 * se cae a leer `revisiones.chapter` por `revisionId`, que es siempre el
 * original sin editar.
 *
 * El chat libre y "preguntar sobre selección" llevan siempre delante
 * `INSTRUCCION_SISTEMA`: le dice a la IA que es el asistente de escritura de
 * bookevision, qué puede hacer, y que no conteste temas ajenos al capítulo.
 */
class AiController {
    /**
     * Identidad y alcance de la IA en el chat libre y en "preguntar sobre
     * selección" — sin esto no sabe que es parte de bookevision ni qué se
     * espera de ella, y podría ponerse a hablar de cualquier cosa.
     */
    private const INSTRUCCION_SISTEMA =
        'Eres el asistente de escritura de bookevision (siempre en minúsculas), app para revisar '
        . 'capítulos de novelas. Ayudas con: corrección ortográfica, gramatical y de puntuación '
        . '(faltas, erratas, signos); redacción y reescritura de frases o párrafos; ampliación de '
        . 'párrafos; inserción de contenido nuevo; y dudas sobre el capítulo o un fragmento '
        . 'seleccionado. Responde directamente a lo que se pide, sin saludar ni presentarte; solo '
        . 'si el autor te saluda, devuelve un saludo breve. Cíñete a la escritura del '
        . 'capítulo/novela — ante temas ajenos (tiempo, noticias, charla genérica...), dilo '
        . 'brevemente y redirige al capítulo.';

    /** `/ai/{accion}` — aquí `$id` hace de acción, igual que en /auth/{accion}. */
    public function handle(string $method, ?string $id, int $userId): void {
        if ($method !== 'POST') {
            http_response_code(405);
            echo json_encode(['error' => 'Método no permitido']);
            return;
        }
        switch ($id) {
            case 'chat':
                $this->chat($userId);
                break;
            case 'preguntar-seleccion':
                $this->preguntarSeleccion($userId);
                break;
            default:
                http_response_code(404);
                echo json_encode(['error' => 'Ruta no encontrada']);
        }
    }

    private function chat(int $userId): void {
        $body = json_body();
        $mensaje = trim($body['mensaje'] ?? '');
        if ($mensaje === '') {
            http_response_code(400);
            echo json_encode(['error' => 'Falta mensaje']);
            return;
        }
        $prompt = $this->conContextoDelCapitulo(
            $mensaje,
            $body,
            $userId,
            'Capítulo que el autor está revisando ahora mismo',
            'Mensaje del autor'
        );
        try {
            $resultado = GeminiClient::generar($prompt);
        } catch (Throwable $e) {
            http_response_code(502);
            echo json_encode(['error' => $e->getMessage()]);
            return;
        }
        echo json_encode(['respuesta' => $resultado['text']]);
    }

    private function preguntarSeleccion(int $userId): void {
        $body = json_body();
        $seleccion = trim($body['seleccion'] ?? '');
        $pregunta = trim($body['pregunta'] ?? '');
        if ($seleccion === '' || $pregunta === '') {
            http_response_code(400);
            echo json_encode(['error' => 'Faltan seleccion o pregunta']);
            return;
        }
        $prompt = $this->conContextoDelCapitulo(
            $pregunta,
            $body,
            $userId,
            'Capítulo del que forma parte el fragmento sobre el que pregunta el autor',
            "El autor seleccionó este fragmento del capítulo:\n\"{$seleccion}\"\n\nY pregunta"
        );
        try {
            $resultado = GeminiClient::generar($prompt);
        } catch (Throwable $e) {
            http_response_code(502);
            echo json_encode(['error' => $e->getMessage()]);
            return;
        }
        echo json_encode(['respuesta' => $resultado['text']]);
    }

    /**
     * Sin el capítulo como contexto, la IA no tiene ni idea de qué capítulo
     * habla el autor — vital para que el chat libre y las preguntas sobre una
     * selección tengan sentido. Prioriza el `capitulo` que mande el cliente
     * (el compuesto con las decisiones ya tomadas, o el original literal en
     * "Ver original" — cada pantalla decide cuál le toca) y solo si no viene
     * cae a leer `revisiones.chapter` por `revisionId` (que es siempre el
     * original sin editar). Sin ninguno de los dos, se manda el mensaje tal
     * cual en vez de fallar la petición entera.
     */
    private function conContextoDelCapitulo(
        string $mensaje,
        array $body,
        int $userId,
        string $introduccion,
        string $etiquetaMensaje
    ): string {
        $capitulo = trim($body['capitulo'] ?? '');
        if ($capitulo === '') {
            $revisionId = trim($body['revisionId'] ?? '');
            if ($revisionId !== '') {
                $capitulo = $this->capituloDe($revisionId, $userId) ?? '';
            }
        }
        if ($capitulo === '') {
            return self::INSTRUCCION_SISTEMA . "\n\n{$etiquetaMensaje}: {$mensaje}";
        }
        return self::INSTRUCCION_SISTEMA
            . "\n\n{$introduccion}:\n\n\"\"\"\n{$capitulo}\n\"\"\"\n\n{$etiquetaMensaje}: {$mensaje}";
    }

    private function capituloDe(string $revisionId, int $userId): ?string {
        $stmt = get_pdo()->prepare(
            'SELECT r.chapter FROM revisiones r
               JOIN libros b ON b.id = r.libro_id
              WHERE r.id = :id AND b.user_id = :user_id'
        );
        $stmt->execute(['id' => $revisionId, 'user_id' => $userId]);
        $fila = $stmt->fetch();
        return $fila ? $fila['chapter'] : null;
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
