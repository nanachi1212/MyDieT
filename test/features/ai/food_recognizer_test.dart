import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mydiet/features/ai/claude_food_recognizer.dart';
import 'package:mydiet/features/ai/food_recognizer.dart';
import 'package:mydiet/features/ai/openai_compatible_recognizer.dart';

/// 最小的 JPEG 檔頭，夠讓 imageMediaType 判斷格式。
final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);

const itemsJson =
    '{"items":[{"name":"白飯","grams":180,"calories_per_100g":183,'
    '"protein_per_100g":3.1,"carbs_per_100g":41,"fat_per_100g":0.3},'
    '{"name":"空氣","grams":0,"calories_per_100g":0,"protein_per_100g":0,'
    '"carbs_per_100g":0,"fat_per_100g":0}]}';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('Claude', () {
    test('送出圖片與 JSON schema，解析回應並略過 0 公克', () async {
      late http.Request sent;
      final recognizer = ClaudeFoodRecognizer(
        'sk-ant-test',
        client: MockClient((req) async {
          sent = req;
          return jsonResponse({
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'thinking', 'thinking': ''},
              {'type': 'text', 'text': itemsJson},
            ],
          });
        }),
      );

      final items = await recognizer.recognize(jpeg, knownNames: ['白飯']);

      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], 'sk-ant-test');
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final body = jsonDecode(sent.body) as Map;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['output_config']['format']['type'], 'json_schema');
      final content = body['messages'][0]['content'] as List;
      expect(content[0]['source']['media_type'], 'image/jpeg');
      expect(content[1]['text'], contains('白飯'));

      expect(items, hasLength(1));
      expect(items.single.name, '白飯');
      expect(items.single.grams, 180);
      expect(items.single.per100g!.calories, 183);
      expect(items.single.per100g!.sugar, isNull);
    });

    test('401 → 提示 key 無效', () async {
      final recognizer = ClaudeFoodRecognizer(
        'bad',
        client: MockClient((_) async => jsonResponse({'type': 'error'}, 401)),
      );
      expect(
        () => recognizer.recognize(jpeg),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('API key'),
          ),
        ),
      );
    });

    test('拒絕分析 → AiException，不會去解析內容', () async {
      final recognizer = ClaudeFoodRecognizer(
        'k',
        client: MockClient(
          (_) async => jsonResponse({'stop_reason': 'refusal', 'content': []}),
        ),
      );
      expect(() => recognizer.recognize(jpeg), throwsA(isA<AiException>()));
    });
  });

  group('OpenAI 相容', () {
    test('網址結尾斜線、Bearer key、data URL 圖片、```json 包裝都能處理', () async {
      late http.Request sent;
      final recognizer = OpenAiCompatibleRecognizer(
        apiKey: 'free-key',
        baseUrl: 'https://example.com/v1/',
        model: 'some-vision-model',
        client: MockClient((req) async {
          sent = req;
          return jsonResponse({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': '結果如下：\n```json\n$itemsJson\n```'},
              },
            ],
          });
        }),
      );

      final items = await recognizer.recognize(jpeg);

      expect(sent.url.toString(), 'https://example.com/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer free-key');
      final body = jsonDecode(sent.body) as Map;
      expect(body['model'], 'some-vision-model');
      final image = (body['messages'][0]['content'] as List)[1];
      expect(image['image_url']['url'], startsWith('data:image/jpeg;base64,'));
      expect(items.single.name, '白飯');
    });

    test('429 → 提示額度或頻率', () async {
      final recognizer = OpenAiCompatibleRecognizer(
        apiKey: 'k',
        baseUrl: 'https://example.com/v1',
        model: 'm',
        client: MockClient((_) async => jsonResponse({}, 429)),
      );
      expect(
        () => recognizer.recognize(jpeg),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('額度'),
          ),
        ),
      );
    });
  });

  test('回應不是 JSON → AiException', () {
    expect(() => parseFoodItems('抱歉我看不出來'), throwsA(isA<AiException>()));
  });

  test('HEIC 等不支援的格式在送出前就擋下', () {
    final heic = Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]);
    expect(() => imageMediaType(heic), throwsA(isA<AiException>()));
  });

  test('說明文字裡有其他 JSON 範例，仍能取出真正的結果', () {
    final items = parseFoodItems('格式範例：{"name":"x"}\n實際結果：$itemsJson\n以上');
    expect(items.single.name, '白飯');
  });

  test('營養值缺漏或無效（NaN、負數）→ 保留名稱與份量，營養留給資料庫或使用者', () {
    final items = parseFoodItems(
      '{"items":[{"name":"壞資料","grams":100,"calories_per_100g":"NaN",'
      '"protein_per_100g":1,"carbs_per_100g":1,"fat_per_100g":1},'
      '{"name":"負數","grams":100,"calories_per_100g":-50,'
      '"protein_per_100g":1,"carbs_per_100g":1,"fat_per_100g":1},'
      '{"name":"只有份量","grams":"80"},'
      '{"name":"白飯","grams":100,"calories_per_100g":183,'
      '"protein_per_100g":3.1,"carbs_per_100g":41,"fat_per_100g":0.3},'
      '{"name":"沒份量","grams":0}]}',
    );
    expect(items.map((i) => i.name), ['壞資料', '負數', '只有份量', '白飯']);
    expect(items[2].grams, 80);
    expect(
      [for (final i in items) i.per100g == null],
      [true, true, true, false],
    );
  });

  test('貼完整的 .../chat/completions 也不會重複接一次', () async {
    late Uri sent;
    final recognizer = OpenAiCompatibleRecognizer(
      apiKey: 'k',
      baseUrl: 'https://example.com/v1/chat/completions/',
      model: 'm',
      client: MockClient((req) async {
        sent = req.url;
        return jsonResponse({'choices': []});
      }),
    );
    await recognizer.ping();
    expect(sent.toString(), 'https://example.com/v1/chat/completions');
  });

  test('HTTP 200 但回傳 HTML 或格式不對 → AiException', () async {
    for (final body in ['<html>proxy</html>', '[1,2,3]', '{"content":"x"}']) {
      final claude = ClaudeFoodRecognizer(
        'k',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        claude.recognize(jpeg),
        throwsA(isA<AiException>()),
        reason: body,
      );
      final compat = OpenAiCompatibleRecognizer(
        apiKey: 'k',
        baseUrl: 'https://example.com/v1',
        model: 'm',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        compat.ping(),
        throwsA(isA<AiException>()),
        reason: body,
      );
      await expectLater(
        compat.recognize(jpeg),
        throwsA(isA<AiException>()),
        reason: body,
      );
    }
  });
}
