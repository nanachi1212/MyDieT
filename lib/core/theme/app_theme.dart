import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Material 3 light / dark theme。P0 只做到可用，不美化。
abstract final class AppTheme {
  static const _seed = Color(0xFF4CAF50);

  /// Material 內建元件（日期選擇器、對話框按鈕…）要跟著顯示繁體中文，
  /// 否則會 fallback 成英文。這只是啟用 Flutter 內建翻譯，不是導入 i18n 框架。
  static const localizationsDelegates = <LocalizationsDelegate<Object>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[
    Locale('zh', 'TW'),
    Locale('zh'),
    Locale('en'),
  ];

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
