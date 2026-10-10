/// Pequeñas cuentas sobre el texto de un capítulo, para el diseño de
/// escritorio.
class TextoCapitulo {
  TextoCapitulo._();

  /// Palabras: lo que hay entre espacios en blanco.
  static int palabras(String texto) =>
      RegExp(r'\S+').allMatches(texto).length;

  /// Párrafos: bloques de texto separados por una línea en blanco (el mismo
  /// criterio con el que el lector numera los suyos).
  static int parrafos(String texto) =>
      texto.split(RegExp(r'\n{2,}')).where((p) => p.trim().isNotEmpty).length;

  /// 3412 → «3.412», con el punto de millar del español.
  static String miles(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// 15 → «XV». Del 1 al 3999; fuera de ahí, el número tal cual (un capítulo
  /// 0 o 5000 no tiene numeral).
  static String romano(int n) {
    if (n < 1 || n > 3999) return '$n';
    const tabla = [
      (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'),
      (90, 'XC'), (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'),
      (4, 'IV'), (1, 'I'),
    ];
    var resto = n;
    final b = StringBuffer();
    for (final (valor, letras) in tabla) {
      while (resto >= valor) {
        b.write(letras);
        resto -= valor;
      }
    }
    return b.toString();
  }

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// «Hoy, 09:15» / «Ayer, 22:03» / «10 oct» (y con el año si no es el
  /// actual). [ahora] solo existe para los tests.
  static String fecha(DateTime f, {DateTime? ahora}) {
    final hoy = ahora ?? DateTime.now();
    final a = DateTime(f.year, f.month, f.day);
    final b = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = b.difference(a).inDays;
    String dos(int n) => n.toString().padLeft(2, '0');
    final hora = '${dos(f.hour)}:${dos(f.minute)}';
    if (dias == 0) return 'Hoy, $hora';
    if (dias == 1) return 'Ayer, $hora';
    final dia = '${f.day} ${_meses[f.month - 1]}';
    return f.year == hoy.year ? dia : '$dia ${f.year}';
  }
}
