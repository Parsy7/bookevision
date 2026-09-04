import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/screens/import_screen.dart';
import 'package:bookevision/screens/preview_screen.dart';
import 'package:bookevision/screens/review_list_screen.dart';
import 'package:bookevision/screens/reviewer_screen.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/widgets/app_button.dart';
import 'package:bookevision/widgets/prose_block.dart';

import 'soporte.dart';

/// Alto de la barra de navegación de 3 botones de Android.
const _navegacion = 48.0;
const _alto = 600.0;

const _cuentas = Counts(
  total: 2,
  done: 2,
  pending: 0,
  accepted: 1,
  originals: 1,
  custom: 0,
  omitted: 0,
  manual: 0,
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  void conBarraDeAndroid(WidgetTester tester) {
    addTearDown(tester.view.reset);
    final fisicos = _navegacion * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(bottom: fisicos);
    tester.view.padding = FakeViewPadding(bottom: fisicos);
  }

  void esperarLibre(WidgetTester tester, Finder f, String que) {
    expect(tester.getRect(f).bottom, lessThanOrEqualTo(_alto - _navegacion),
        reason: '$que queda debajo de la barra de Android');
  }

  Widget app(Widget home) => MaterialApp(theme: appTheme, home: home);

  testWidgets('vista previa: el botón de exportar', (tester) async {
    conBarraDeAndroid(tester);
    await tester.pumpWidget(app(const PreviewScreen(
        title: 'Capítulo', text: 'Texto corto.', counts: _cuentas)));
    await tester.pump();

    esperarLibre(tester, find.byType(AppButton), 'Exportar');
  });

  testWidgets('lector: la barra de abajo y la de edición', (tester) async {
    conBarraDeAndroid(tester);
    await tester.pumpWidget(Provider<ApiService>.value(
      value: ApiFalsa(),
      child: app(const ReviewerScreen(reviewId: 'x')),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    esperarLibre(tester, find.byType(AppButton), 'la barra de pendientes');

    final bloque = tester.getRect(find.byType(ProseBlock).first);
    await tester.longPressAt(Offset(bloque.left + 30, bloque.top + 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    esperarLibre(tester, find.widgetWithText(AppButton, 'Guardar'),
        'Guardar de la edición');
  });

  testWidgets('importar: el último botón del scroll', (tester) async {
    conBarraDeAndroid(tester);
    await tester.pumpWidget(Provider<ApiService>.value(
      value: ApiFalsa(),
      child: app(const ImportScreen()),
    ));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();

    esperarLibre(
        tester, find.widgetWithText(AppButton, 'Importar'), 'Importar');
  });

  testWidgets('lista: la última revisión del scroll', (tester) async {
    conBarraDeAndroid(tester);
    await tester.pumpWidget(Provider<ApiService>.value(
      value: ApiFalsaConVarias(),
      child: app(const ReviewListScreen()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();

    esperarLibre(tester, find.text('Capítulo 8').last, 'la última revisión');
  });
}
