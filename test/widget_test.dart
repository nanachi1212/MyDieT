import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/app.dart';

void main() {
  testWidgets('App 啟動後顯示 Dashboard，並可切換到其他分頁', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyDietApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard placeholder'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('Profile placeholder'), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('Settings placeholder'), findsOneWidget);
  });
}
