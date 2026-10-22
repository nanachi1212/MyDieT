import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/diary/data/diary_repository.dart';
import '../features/foods/data/food_repository.dart';
import '../features/foods/data/taiwan_food_seeder.dart';
import '../features/profile/data/profile_repository.dart';
import 'database/app_database.dart';

/// 全 App 唯一的資料庫實例。測試時用 overrideWithValue 換成記憶體資料庫。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

final foodRepositoryProvider = Provider(
  (ref) => FoodRepository(ref.watch(appDatabaseProvider)),
);

final diaryRepositoryProvider = Provider(
  (ref) => DiaryRepository(ref.watch(appDatabaseProvider)),
);

/// 是否已經完成 Onboarding。
///
/// null = 還在判斷中。用 ValueNotifier 是因為 go_router 的 redirect 需要
/// 同步讀值，且需要一個 Listenable 來觸發重新評估路由。
final onboardingStateProvider = Provider<ValueNotifier<bool?>>((ref) {
  final notifier = ValueNotifier<bool?>(null);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// 種子食物 CSV 的讀取方式。null = 用 TaiwanFoodSeeder 預設的 rootBundle。
///
/// 測試會覆寫這個，避免在 FakeAsync 裡等真實的 asset I/O 而卡住。
final foodSeedLoaderProvider = Provider<Future<String> Function()?>(
  (ref) => null,
);

/// App 啟動流程：匯入種子食物 + 判斷是否需要 Onboarding。
final appStartupProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await TaiwanFoodSeeder(db, loadCsv: ref.watch(foodSeedLoaderProvider)).seed();

  final profile = await ref.watch(profileRepositoryProvider).getProfile();
  ref.read(onboardingStateProvider).value = profile != null;
});

/// 目前的 Profile（會隨資料庫變動）。
final userProfileProvider = StreamProvider(
  (ref) => ref.watch(profileRepositoryProvider).watchProfile(),
);

/// 某一天的飲食紀錄（會隨資料庫變動）。
final dayEntriesProvider = StreamProvider.family(
  (ref, DateTime day) => ref.watch(diaryRepositoryProvider).watchDay(day),
);

/// 某一天適用的熱量目標（會隨資料庫變動）。
final dayTargetProvider = StreamProvider.family(
  (ref, DateTime day) =>
      ref.watch(profileRepositoryProvider).watchTargetFor(day),
);

/// 近 90 天的體重紀錄，舊到新。
final weightHistoryProvider = StreamProvider(
  (ref) => ref
      .watch(profileRepositoryProvider)
      .watchMeasurementsSince(
        DateTime.now().subtract(const Duration(days: 90)),
      ),
);

/// 最新一筆體重紀錄。
final latestMeasurementProvider = StreamProvider(
  (ref) => ref.watch(profileRepositoryProvider).watchLatestMeasurement(),
);
