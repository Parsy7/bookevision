import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/models/tema.dart';

Map<String, dynamic> _fila([Map<String, dynamic> extra = const {}]) => {
      'id': 2,
      'nombre': 'Marino y dorado',
      'paper': '#F6F2EA',
      'sheet': '#FCFAF5',
      'white': '#FFFFFF',
      'ink': '#1E2A3E',
      'acento': '#C9A26B',
      'blue': '#2F6F86',
      'grey1': '#4E566A',
      'grey2': '#5E6577',
      'grey3': '#8A8F9C',
      'strike': '#646A7A',
      ...extra,
    };

void main() {
  test('sin los tokens nuevos, acento de texto y peligro caen en lo de antes',
      () {
    final t = Tema.fromJson(_fila({'acento_texto': null}));
    expect(t.acentoTexto, t.acento);
    expect(t.peligro, Tema.peligroClasico);
  });

  test('sobre un acento claro (dorado) el texto va oscuro, no blanco', () {
    final t = Tema.fromJson(_fila());
    expect(t.sobreAcento, t.ink,
        reason: 'blanco sobre dorado no se lee, aunque falte la migración');
  });

  test('sobre el rojo de Clásico el texto sigue siendo blanco', () {
    expect(Tema.clasico.sobreAcento, Tema.clasico.white);
  });

  test('sobre el peligro, siempre blanco', () {
    final t = Tema.fromJson(_fila({'peligro': '#B03A2E'}));
    expect(t.sobrePeligro, const Color(0xFFFFFFFF));
  });

  test('con los tokens nuevos, manda lo que trae el tema', () {
    final t = Tema.fromJson(_fila({
      'acento_texto': '#9C7536',
      'peligro': '#B03A2E',
      'sobre_acento': '#3D2B12',
    }));
    expect(t.acentoTexto, const Color(0xFF9C7536));
    expect(t.peligro, const Color(0xFFB03A2E));
    expect(t.sobreAcento, const Color(0xFF3D2B12));
  });

  test('se guarda y se recupera igual (caché del dispositivo)', () {
    final t = Tema.fromJson(_fila({'peligro': '#B03A2E'}));
    final vuelta = Tema.fromJson(t.toJson());
    expect(vuelta.peligro, t.peligro);
    expect(vuelta.acentoTexto, t.acento,
        reason: 'lo que no venía sigue sin venir: no se congela el fallback');
  });
}
