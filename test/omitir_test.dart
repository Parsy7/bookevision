import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/models/answer.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/models/suggestion.dart';
import 'package:bookevision/services/review_session.dart';

import 'soporte.dart';

Review _revision(String capitulo, List<Suggestion> sugerencias) => Review(
      id: 'x',
      format: 'la-jaula-rota-review-v4',
      title: 'Capítulo',
      chapter: capitulo,
      suggestions: sugerencias,
    );

Future<ReviewSession> _sesion(Review r) async {
  final s = ReviewSession(api: ApiFalsa(r));
  await s.load('x');
  return s;
}

void main() {
  test('eliminar un párrafo entero no deja una línea en blanco de más',
      () async {
    final s = await _sesion(_revision(
      'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.',
      const [
        Suggestion(
          orden: 0,
          type: 'replace',
          original: 'Párrafo dos.',
          proposed: 'Otra cosa.',
        ),
      ],
    ));

    s.setChoice(0, Choice.omit);

    expect(s.currentText(), 'Párrafo uno.\n\nPárrafo tres.');
    expect(s.allResolved, isTrue, reason: 'eliminar resuelve la tarjeta');
    expect(s.counts().omitted, 1);
    s.dispose();
  });

  test('eliminar una frase dentro de un párrafo no deja doble espacio',
      () async {
    final s = await _sesion(_revision(
      'Frase una. Frase dos. Frase tres.',
      const [
        Suggestion(orden: 0, type: 'replace', original: 'Frase dos.'),
      ],
    ));

    s.setChoice(0, Choice.omit);

    expect(s.currentText(), 'Frase una. Frase tres.');
    s.dispose();
  });

  test('eliminar el primer párrafo no deja el capítulo empezando en blanco',
      () async {
    final s = await _sesion(_revision(
      'Párrafo uno.\n\nPárrafo dos.',
      const [
        Suggestion(orden: 0, type: 'replace', original: 'Párrafo uno.'),
      ],
    ));

    s.setChoice(0, Choice.omit);

    expect(s.currentText(), 'Párrafo dos.');
    s.dispose();
  });

  test('una inserción en ese mismo punto no se pisa', () async {
    final s = await _sesion(_revision(
      'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.',
      const [
        Suggestion(orden: 0, type: 'replace', original: 'Párrafo dos.'),
        Suggestion(
          orden: 1,
          type: 'insert',
          anchor: 'Párrafo dos.',
          insert: 'after',
          previous: 'Párrafo dos.',
          next: 'Párrafo tres.',
          proposed: 'PÁRRAFO NUEVO.',
        ),
      ],
    ));

    s.setChoice(0, Choice.omit);
    s.setChoice(1, Choice.proposed);

    final texto = s.currentText();
    expect(texto, contains('PÁRRAFO NUEVO.'),
        reason: 'el texto insertado no puede quedar mordido');
    expect(texto, isNot(contains('Párrafo dos.')));
    expect(texto, contains('Párrafo uno.'));
    expect(texto, contains('Párrafo tres.'));
    s.dispose();
  });

  test('las demás decisiones siguen componiendo igual', () async {
    final s = await _sesion(_revision(
      'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.',
      const [
        Suggestion(
          orden: 0,
          type: 'replace',
          original: 'Párrafo dos.',
          proposed: 'Párrafo DOS corregido.',
        ),
      ],
    ));

    s.setChoice(0, Choice.original);
    expect(s.currentText(),
        'Párrafo uno.\n\nPárrafo dos.\n\nPárrafo tres.');

    s.setChoice(0, Choice.proposed);
    expect(s.currentText(),
        'Párrafo uno.\n\nPárrafo DOS corregido.\n\nPárrafo tres.');

    s.setCustom(0, 'Lo mío.');
    expect(s.currentText(), 'Párrafo uno.\n\nLo mío.\n\nPárrafo tres.');
    s.dispose();
  });
}
