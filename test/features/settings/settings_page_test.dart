import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/secure/ai_config_store.dart';
import 'package:mydiet/features/settings/presentation/settings_page.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = memoryDb();
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(wrapForTest(const SettingsPage(), db));
    await tester.pumpAndSettle();
  }

  widgetTestWithTree('儲存 Claude key 後只顯示遮罩', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('ai_api_key_field')),
      'sk-ant-api03-secret-abcd',
    );
    await tester.tap(find.byKey(const Key('ai_save_button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('ai_saved_key'))).data,
      'sk-ant-••••abcd',
    );
    expect(find.textContaining('secret'), findsNothing);
    final config = await AiConfigStore().load();
    expect(config!.apiKey, 'sk-ant-api03-secret-abcd');
  });

  widgetTestWithTree('OpenAI 相容：快速填入網址、缺模型擋下、兩家 key 分開存', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'ai_key_claude': 'sk-ant-keep-1234',
    });
    await pumpPage(tester);

    await tester.tap(find.text('OpenAI 相容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai_api_key_field')),
      'free-key-5678',
    );
    await tester.tap(find.byKey(const Key('ai_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('請輸入模型名稱'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ai_model_field')),
      'vision-model',
    );
    await tester.enterText(
      find.byKey(const Key('ai_api_key_field')),
      'free-key-5678',
    );
    await tester.tap(find.byKey(const Key('ai_save_button')));
    await tester.pumpAndSettle();

    final store = AiConfigStore();
    final config = await store.load();
    expect(config!.provider, AiProviderType.openAiCompatible);
    expect(config.baseUrl, contains('generativelanguage.googleapis.com'));
    expect(config.model, 'vision-model');
    expect(await store.apiKey(AiProviderType.claude), 'sk-ant-keep-1234');
  });
}
