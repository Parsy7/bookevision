/// Valores posibles de `choice`. En sustituciones: `original` = mantener,
/// `proposed` = aceptar, `custom` = versión propia. En inserciones:
/// `original` = no añadir nada, `proposed` = añadir la propuesta, `custom` =
/// añadir texto propio.
class Choice {
  Choice._();
  static const String original = 'original';
  static const String proposed = 'proposed';
  static const String custom = 'custom';
}

/// Posición elegida para una inserción.
class InsertPosition {
  InsertPosition._();
  static const String before = 'before';
  static const String between = 'between';
  static const String after = 'after';
}

/// Decisión del usuario para una sugerencia (indexada por [orden]). Mutable:
/// el [ReviewSession] la va editando y persistiendo.
class Answer {
  final int orden;
  String? choice; // ver Choice; null = sin decidir
  String custom;
  String? insertPosition; // ver InsertPosition; solo inserciones

  Answer({
    required this.orden,
    this.choice,
    this.custom = '',
    this.insertPosition,
  });

  /// Réplica de `isResolved` del HTML: aceptada, original, o personalizada no
  /// vacía.
  bool get isResolved =>
      choice == Choice.original ||
      choice == Choice.proposed ||
      (choice == Choice.custom && custom.trim().isNotEmpty);

  factory Answer.fromJson(Map<String, dynamic> j) => Answer(
        orden: (j['orden'] as num).toInt(),
        choice: j['choice'] as String?,
        custom: (j['custom'] as String?) ?? '',
        insertPosition: j['insertPosition'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'orden': orden,
        'choice': choice,
        'custom': custom,
        'insertPosition': insertPosition,
      };
}
