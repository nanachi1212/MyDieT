import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'food_recognizer.dart';

/// 任何 OpenAI 相容的 Chat Completions 端點（Gemini、OpenRouter、Groq…）。
///
/// 各家對 JSON 格式的支援程度不同，這裡只要求 `json_object`，格式靠 prompt
/// 說明，再由 [parseFoodItems] 容錯解析。
class OpenAiCompatibleRecognizer implements FoodRecognizer {
  OpenAiCompatibleRecognizer({
    required this.apiKey,
    required String baseUrl,
    required this.model,
    http.Client? client,
  }) : _endpoint = Uri.parse(
         // 貼基底網址（…/v1）或完整端點（…/v1/chat/completions）都可以
         '${baseUrl.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'/chat/completions$'), '')}'
         '/chat/completions',
       ),
       _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final Uri _endpoint;
  final http.Client _client;

  /// 常見有免費額度的服務，給設定頁當快速填入。模型名稱各家常改，
  /// 由使用者自己填。
  static const presets = {
    'Gemini': 'https://generativelanguage.googleapis.com/v1beta/openai',
    'OpenRouter': 'https://openrouter.ai/api/v1',
    'Groq': 'https://api.groq.com/openai/v1',
  };

  @override
  Future<List<RecognizedFood>> recognize(
    Uint8List image, {
    List<String> knownNames = const [],
  }) async {
    final res = await _post({
      'model': model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': foodPrompt(knownNames)},
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${imageMediaType(image)};base64,${base64Encode(image)}',
              },
            },
          ],
        },
      ],
    });

    if (res case {
      'choices': [
        {'message': {'content': final String text}} && final Map choice,
        ...,
      ],
    }) {
      if (choice['finish_reason'] == 'length') {
        throw const AiException('回應不完整，請再試一次');
      }
      return parseFoodItems(text);
    }
    throw badResponse;
  }

  @override
  Future<void> ping() async {
    final res = await _post({
      'model': model,
      'max_tokens': 16,
      'messages': [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
    });
    if (res case {'choices': List()}) return;
    throw badResponse;
  }

  Future<Map<String, dynamic>> _post(Map<String, Object> body) => postJson(
    _client,
    _endpoint,
    headers: {'authorization': 'Bearer $apiKey'},
    body: body,
  );
}
