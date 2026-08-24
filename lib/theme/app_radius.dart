import 'package:flutter/material.dart';

/// Radios de esquina. Prohibido escribir radios literales: usar estos tokens.
class AppRadius {
  AppRadius._();

  static const double cardValue = 24;
  static const double smValue = 12;
  static const double mdValue = 24;
  static const double pillValue = 999;

  static BorderRadius get card => BorderRadius.circular(cardValue);
  static BorderRadius get sm => BorderRadius.circular(smValue);
  static BorderRadius get md => BorderRadius.circular(mdValue);
  static BorderRadius get pill => BorderRadius.circular(pillValue);
}
