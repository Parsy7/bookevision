import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/models/capitulo.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/models/review_state.dart';
import 'package:bookevision/models/review_summary.dart';
import 'package:bookevision/models/suggestion.dart';
import 'package:bookevision/services/api_service.dart';

/// Escribe en el campo del chat con la IA. Al abrirse, el campo tiene el
/// foco pero no el teclado (va en solo lectura hasta el primer toque), así
/// que hay que tocarlo antes, como haría el autor.
Future<void> escribirEnChat(WidgetTester tester, String texto) async {
  final campo = find.widgetWithText(TextField, 'Escribe tu mensaje…');
  await tester.tap(campo);
  await tester.pump();
  await tester.enterText(campo, texto);
}

/// Frase que sustituye la única sugerencia de [revisionDePrueba].
const fraseOriginal = 'su frase original';

String _relleno(int veces) => List.filled(
      veces,
      'La jaula seguia abierta y nadie en la casa se atrevia a decirlo en voz '
          'alta.',
    ).join(' ');

/// Capítulo con dos bloques de prosa (uno antes y otro después de la
/// sustitución), los dos más altos que la pantalla del test.
final Review revisionDePrueba = Review(
  id: 'x',
  format: 'la-jaula-rota-review-v4',
  title: 'Capítulo de prueba',
  chapter: '${_relleno(30)} $fraseOriginal ${_relleno(30)}',
  suggestions: const [
    Suggestion(
      orden: 0,
      type: 'replace',
      title: 'Una sugerencia',
      original: fraseOriginal,
      proposed: 'su frase propuesta',
    ),
  ],
);

/// API de mentira: ni red ni disco. Se le puede dar otra revisión para probar
/// el motor de composición con capítulos a medida.
class ApiFalsa extends ApiService {
  ApiFalsa([Review? revision]) : revision = revision ?? revisionDePrueba;

  final Review revision;
  int guardados = 0;

  @override
  Future<Review> getRevision(String id) async => revision;

  @override
  Future<ReviewState> getEstado(String id) async =>
      const ReviewState(answers: [], manualEdits: {});

  @override
  Future<void> putEstado(String id, ReviewState state) async => guardados++;

  @override
  Future<void> resetEstado(String id) async {}

  @override
  Future<String> chat(
    String mensaje, {
    required String revisionId,
    required String capitulo,
    List<Map<String, String>> historial = const [],
  }) async =>
      'Respuesta de mentira';

  @override
  Future<String> preguntarSeleccion(
    String seleccion,
    String pregunta, {
    required String revisionId,
    required String capitulo,
    List<Map<String, String>> historial = const [],
  }) async =>
      'Respuesta sobre la selección';

  /// Lo último que se marcó o reabrió, por revisión.
  final Map<String, bool> finalizadas = {};

  @override
  Future<void> setFinalizada(String id, bool finalizada) async =>
      finalizadas[id] = finalizada;

  int sugerenciasGeneradas = 0;

  @override
  Future<Review> generarSugerencias(
    String revisionId, {
    String? instruccion,
    Map<String, dynamic>? seed,
  }) async {
    sugerenciasGeneradas++;
    return revision;
  }
}

/// Lista larga, para comprobar qué pasa con el último elemento del scroll.
class ApiFalsaConVarias extends ApiFalsa {
  @override
  Future<List<ReviewSummary>> getRevisiones({String? libroId, int? capituloId}) async => [
        for (var i = 1; i <= 8; i++)
          ReviewSummary(
            id: 'c$i',
            format: 'la-jaula-rota-review-v4',
            title: 'Capítulo $i',
            total: 3,
            resolved: i,
            manual: 0,
          ),
        // Un capítulo suelto ya marcado como finalizado.
        const ReviewSummary(
          id: 'suelto',
          format: 'la-jaula-rota-review-v4',
          title: 'Versión final',
          total: 0,
          resolved: 0,
          manual: 0,
          finalizada: true,
        ),
      ];

  /// Lo que se movió, por revisión → capítulo de destino.
  final Map<String, int> movidas = {};

  @override
  Future<List<Capitulo>> getCapitulos(int libroId) async => const [
        Capitulo(id: 1, libroId: 1, numero: 13, titulo: 'XIII La huida', revisiones: 2, listas: 2),
        Capitulo(id: 2, libroId: 1, numero: 14, titulo: 'XIV Primero la promesa', revisiones: 3, listas: 1),
        Capitulo(id: 3, libroId: 1, numero: 15, titulo: 'XV El regreso'),
      ];

  @override
  Future<void> moverRevision(String id, int capituloId) async => movidas[id] = capituloId;
}

/// Lista vacía, para la pantalla «Página en blanco».
class ApiFalsaVacia extends ApiFalsa {
  @override
  Future<List<ReviewSummary>> getRevisiones({String? libroId, int? capituloId}) async => const [];

  @override
  Future<List<Capitulo>> getCapitulos(int libroId) async => const [];
}
