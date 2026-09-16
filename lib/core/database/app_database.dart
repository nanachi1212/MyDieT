import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// 產生的 app_database.g.dart 直接參照這些 enum，屬於同一個 library，
// 因此必須在這裡 import。
import '../../features/profile/domain/profile_enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [UserProfiles])
class AppDatabase extends _$AppDatabase {
  /// [executor] 留給測試注入記憶體資料庫；正式執行時走裝置檔案。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mydiet'));

  @override
  int get schemaVersion => 1;
}
