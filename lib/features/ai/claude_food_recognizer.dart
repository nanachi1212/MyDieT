import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'food_recognizer.dart';

/// Anthropic Claude（Messages API）。
///
/// Dart 沒有官方 Anthropic SDK，所以直接打 HTTP。回應用 structured outputs
/// （`output_config.format`）鎖成 [foodItemsSchema]。
class ClaudeFoodRecognizer implements FoodRecognizer {
  ClaudeFoodRecognizer(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const model = 'claude-opus-5-5';
  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  @override
  Future<List<RecognizedFood>> recognize(
    Uint8List image, {
    List<String> knownNames = const [],
  }) async {
    final res = await _post({
      'model': model,
      'max_tokens': 16000,
      // 被安全分類器擋下時，由 API 自動換推薦的模型重跑
      'fallbacks': 'default',
      'output_config': {
        'effort': 'medium',
        'format': {'type': 'json_schema', 'schema': foodItemsSchema},
      },
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': imageMediaType(image),
                'data': base64Encode(image),
              },
            },
            {'type': 'text', 'text': foodPrompt(knownNames)},
          ],
        },
      ],
    }, beta: 'server-side-fallback-2026-07-01');

    final content = switch (res) {
      {'content': final List content} => content,
      _ => throw badResponse,
    };
    return parseFoodItems(
      [
        for (final block in content)
          if (block case {'type': 'text', 'text': final String text}) text,
      ].join(),
    );
  }

  @override
  Future<void> ping() async {
    final res = await _post({
      'model': model,
      'max_tokens': 1024,
      'output_config': {'effort': 'low'},
      'messages': [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
    });
    if (res case {'content': List()}) return;
    throw badResponse;
  }

  Future<Map<String, dynamic>> _post(
    Map<String, Object> body, {
    String? beta,
  }) async {
    final res = await postJson(
      _client,
      _endpoint,
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': ?beta,
      },
      body: body,
    );
    switch (res['stop_reason']) {
      case 'refusal':
        throw const AiException('Claude 無法分析這張照片，請改用手動輸入');
      case 'max_tokens':
        throw const AiException('回應不完整，請再試一次');
    }
    return res;
  }
}
