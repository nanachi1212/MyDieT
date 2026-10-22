import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/nutrition/nutrition_facts.dart';
import '../../core/secure/ai_config_store.dart';
import 'claude_food_recognizer.dart';
import 'openai_compatible_recognizer.dart';

/// AI 認出的一樣食物：名稱、估計份量、AI 估的每 100g 營養。
///
/// [per100g] 只在本機食物資料庫查不到時才會被採用（見 PhotoReviewPage）。
class RecognizedFood {
  const RecognizedFood({
    required this.name,
    required this.grams,
    required this.per100g,
  });

  final String name;
  final double grams;
  final NutritionFacts per100g;
}

/// 給使用者看的錯誤訊息。不含 API key 或 request 內容。
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 拍照辨識食物。每一家 AI 一個實作，共用 prompt 與回應格式。
abstract interface class FoodRecognizer {
  /// [knownNames] 是本機食物資料庫的名稱，讓 AI 盡量用同樣的名字，
  /// 之後才查得到資料庫的營養值。
  Future<List<RecognizedFood>> recognize(
    Uint8List image, {
    List<String> knownNames,
  });

  /// 設定頁的「測試連線」：key 有效且連得上就正常回傳。
  Future<void> ping();
}

FoodRecognizer recognizerFor(AiConfig config, {http.Client? client}) =>
    switch (config.provider) {
      AiProviderType.claude => ClaudeFoodRecognizer(
        config.apiKey,
        client: client,
      ),
      AiProviderType.openAiCompatible => OpenAiCompatibleRecognizer(
        apiKey: config.apiKey,
        baseUrl: config.baseUrl!,
        model: config.model!,
        client: client,
      ),
    };

const _number = {'type': 'number'};

/// 回應的 JSON 格式。Claude 用 structured outputs 強制遵守；OpenAI 相容的
/// 服務不一定支援，所以 prompt 裡也寫明格式。
const foodItemsSchema = {
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'grams': _number,
          'calories_per_100g': _number,
          'protein_per_100g': _number,
          'carbs_per_100g': _number,
          'fat_per_100g': _number,
        },
        'required': [
          'name',
          'grams',
          'calories_per_100g',
          'protein_per_100g',
          'carbs_per_100g',
          'fat_per_100g',
        ],
        'additionalProperties': false,
      },
    },
  },
  'required': ['items'],
  'additionalProperties': false,
};

String foodPrompt(List<String> knownNames) =>
    '辨識這張照片裡的每一樣食物，估計實際份量（公克），以及每 100 公克的'
    '熱量（大卡）、蛋白質、碳水化合物、脂肪（公克）。\n'
    '- name 用台灣慣用的繁體中文。\n'
    '- 便當、套餐請拆成主要組成（例如白飯、雞腿、青菜）。\n'
    '- 如果某樣食物就是下列清單中的一項，name 請完全照清單寫：'
    '${knownNames.join('、')}\n'
    '- 照片裡沒有食物時回傳空的 items。\n'
    '- 只回傳 JSON，格式：{"items":[{"name":"白飯","grams":180,'
    '"calories_per_100g":183,"protein_per_100g":3.1,"carbs_per_100g":41,'
    '"fat_per_100g":0.3}]}';

/// 從 AI 回的文字取出食物清單。容許外面包了 ```json 區塊或多餘說明文字。
List<RecognizedFood> parseFoodItems(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const AiException('看不懂 AI 的回應，請再試一次或改用手動輸入');
  }
  final List items;
  try {
    items =
        (jsonDecode(text.substring(start, end + 1)) as Map)['items'] as List;
  } on Object {
    throw const AiException('看不懂 AI 的回應，請再試一次或改用手動輸入');
  }

  double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

  return [
    for (final i in items.whereType<Map>())
      if (i['name'] is String && (n(i['grams']) ?? 0) > 0)
        RecognizedFood(
          name: (i['name'] as String).trim(),
          grams: n(i['grams'])!,
          per100g: NutritionFacts(
            calories: n(i['calories_per_100g']) ?? 0,
            protein: n(i['protein_per_100g']) ?? 0,
            carbs: n(i['carbs_per_100g']) ?? 0,
            fat: n(i['fat_per_100g']) ?? 0,
          ),
        ),
  ];
}

/// HTTP 狀態碼轉成使用者看得懂的訊息。
AiException httpError(int status) => AiException(switch (status) {
  401 => 'API key 無效，請到設定重新輸入',
  402 || 403 => 'API 帳戶沒有權限或額度不足',
  404 => '找不到這個模型或網址，請檢查設定',
  413 => '照片太大，請換一張',
  429 => '請求太頻繁或免費額度用完，請稍後再試',
  >= 500 => 'AI 服務暫時忙碌，請稍後再試',
  _ => 'AI 服務回傳錯誤（$status）',
});

/// 送出 POST，網路錯誤與非 200 狀態一律轉成 [AiException]。
Future<Map<String, dynamic>> postJson(
  http.Client client,
  Uri url, {
  required Map<String, String> headers,
  required Map<String, Object?> body,
}) async {
  final http.Response res;
  try {
    res = await client
        .post(
          url,
          headers: {'content-type': 'application/json', ...headers},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
  } on Exception {
    throw const AiException('連不上 AI 服務，請檢查網路或網址');
  }
  if (res.statusCode != 200) throw httpError(res.statusCode);
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

/// 依檔頭判斷圖片格式。AI 服務普遍只收 JPEG / PNG / GIF / WebP，其他格式
/// （例如 HEIC）直接擋下，不浪費一次 API 呼叫。
String imageMediaType(Uint8List b) {
  bool at(int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (at(0, [0x47, 0x49, 0x46])) return 'image/gif';
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  throw const AiException('不支援這種圖片格式，請在相機設定改用 JPEG');
}
