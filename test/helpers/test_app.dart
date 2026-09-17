import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/providers.dart';
import 'package:mydiet/core/theme/app_theme.dart';

/// 真實的種子 CSV，測試啟動前先同步讀進來。
///
/// 直接讓 appStartup 走 rootBundle 的話，testWidgets 的 FakeAsync 不會讓出給
/// 真實檔案 I/O，pumpAndSettle 會一直等不到結果。
final _seedCsv = File('assets/data/taiwan_foods.csv').readAsStringSync();

/// 建立一個接在記憶體資料庫上的 ProviderContainer。
ProviderContainer testContainer(AppDatabase db) {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      foodSeedLoaderProvider.overrideWithValue(() async => _seedCsv),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AppDatabase memoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  // 可能已經在 disposeTreeOnTearDown 裡關過了，重複關掉不算錯。
  addTearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });
  return db;
}

/// 把一個 widget 包進 MaterialApp + ProviderScope，給 widget test 用。
Widget wrapForTest(Widget child, AppDatabase db) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    foodSeedLoaderProvider.overrideWithValue(() async => _seedCsv),
  ],
  child: MaterialApp(
    localizationsDelegates: AppTheme.localizationsDelegates,
    supportedLocales: AppTheme.supportedLocales,
    locale: const Locale('zh', 'TW'),
    home: child,
  ),
);

/// drift 的 watch() stream 在 ProviderScope 被拆掉時會排一個 0 秒 timer。
/// testWidgets 跑在 FakeAsync 裡，那個 timer 沒被執行到測試就會以
/// "Pending timers" 失敗。
///
/// 重點：清理**必須在測試本體內**完成。Flutter 的 binding 是在 tearDown
/// 之前就檢查 pending timer，放進 addTearDown 沒有用。
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// 會掛載 drift stream 的 widget test 用這個，自動放大畫布並在結束時清乾淨。
void widgetTestWithTree(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    useTallSurface(tester);
    await body(tester);
    await disposeTree(tester);
  });
}

/// 測試畫布預設只有 800x600，長表單會被裁掉導致找不到按鈕。
/// 呼叫這個把畫布放大，測試結束自動還原。
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
