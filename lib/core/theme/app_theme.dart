import 'package:flutter/material.dart';

/// Material 3 light / dark theme。P0 只做到可用，不美化。
abstract final class AppTheme {
  static const _seed = Color(0xFF4CAF50);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  );
}
