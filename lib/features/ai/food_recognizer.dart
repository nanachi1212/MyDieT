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
/// AI 沒給或給了無效的營養值時是 null，要靠資料庫或使用者改名補上。
class RecognizedFood {
  const RecognizedFood({required this.name, required this.grams, this.per100g});

  final String name;
  final double grams;
  final NutritionFacts? per100g;
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

/// 回應不是預期的 JSON 結構（HTML 錯誤頁、代理伺服器、模型亂回）。
const badResponse = AiException('AI 服務的回應格式不正確，請檢查網址與模型');

/// 從 AI 回的文字取出食物清單。容許外面包了 ```json 區塊、多餘說明文字，
/// 或說明裡夾了其他 JSON 範例。
///
/// 規格（PROJECT_SPEC §7）：至少要救出名稱與份量。營養值缺欄位或不是
/// 有限的非負數（NaN、Infinity、負數）時，per100g 為 null，交給資料庫或
/// 確認頁處理，不會讓計算當掉或把負熱量記進日記。沒有份量的品項才略過。
List<RecognizedFood> parseFoodItems(String text) {
  final items = _findItemsObject(text)?['items'] as List?;
  if (items == null) {
    throw const AiException('看不懂 AI 的回應，請再試一次或改用手動輸入');
  }

  double? n(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse('$v');
    return d != null && d.isFinite && d >= 0 ? d : null;
  }

  NutritionFacts? per100g(Map i) => switch ((
    n(i['calories_per_100g']),
    n(i['protein_per_100g']),
    n(i['carbs_per_100g']),
    n(i['fat_per_100g']),
  )) {
    (final calories?, final protein?, final carbs?, final fat?) =>
      NutritionFacts(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    _ => null,
  };

  return [
    for (final i in items.whereType<Map>())
      if ((i['name'], n(i['grams'])) case (
        final String name,
        final grams?,
      ) when grams > 0 && name.trim().isNotEmpty)
        RecognizedFood(name: name.trim(), grams: grams, per100g: per100g(i)),
  ];
}

/// 依序試每個括號平衡的 `{...}`，回傳第一個帶 `items` 陣列的物件。
/// 只取「第一個 { 到最後一個 }」的話，說明文字裡有 JSON 範例就會失敗。
Map<String, dynamic>? _findItemsObject(String text) {
  for (
    var start = text.indexOf('{');
    start >= 0;
    start = text.indexOf('{', start + 1)
  ) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
      } else if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}' && --depth == 0) {
        try {
          final v = jsonDecode(text.substring(start, i + 1));
          if (v is Map<String, dynamic> && v['items'] is List) return v;
        } on FormatException {
          // 不是合法 JSON，換下一個起點
        }
        break;
      }
    }
  }
  return null;
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
  try {
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is Map<String, dynamic>) return json;
  } on FormatException {
    // HTML、壞掉的 UTF-8 等，往下丟出統一的錯誤
  }
  throw badResponse;
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
