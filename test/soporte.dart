import 'package:bookevision/models/review.dart';
import 'package:bookevision/models/review_state.dart';
import 'package:bookevision/models/suggestion.dart';
import 'package:bookevision/services/api_service.dart';

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
}
