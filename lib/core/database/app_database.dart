import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// 產生的 app_database.g.dart 直接參照這些 enum，屬於同一個 library，
// 因此必須在這裡 import。
import '../../features/diary/domain/diary_enums.dart';
import '../../features/profile/domain/profile_enums.dart';
import '../nutrition/serving_unit.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserProfiles,
    BodyMeasurements,
    DailyNutritionTargets,
    FoodItems,
    FoodEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [executor] 留給測試注入記憶體資料庫；正式執行時走裝置檔案。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mydiet'));

  /// v1：UserProfiles（P0）
  /// v2：BodyMeasurements / DailyNutritionTargets / FoodItems / FoodEntries（P1 #5）
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // UserProfiles 不動，既有資料完整保留。
        await m.createTable(bodyMeasurements);
        await m.createTable(dailyNutritionTargets);
        await m.createTable(foodItems);
        await m.createTable(foodEntries);
        await _createIndexes();
      }
    },
    beforeOpen: (details) async {
      // FoodEntries → FoodItems 的 onDelete 行為需要這個才會生效。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 索引集中在這裡定義，onCreate 與 onUpgrade 共用同一份。
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_food_entries_date '
      'ON food_entries (date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_food_entries_date_meal '
      'ON food_entries (date, meal_type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items (name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_body_measurements_measured_at '
      'ON body_measurements (measured_at)',
    );
  }
}
