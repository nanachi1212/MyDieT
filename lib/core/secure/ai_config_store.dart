import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 拍照辨識要用哪一家 AI。
enum AiProviderType {
  /// Anthropic Claude（Messages API）。
  claude,

  /// 任何 OpenAI 相容的 Chat Completions 端點：Gemini、OpenRouter、Groq、
  /// 本機 Ollama…填網址、模型名稱、key 就能用。
  openAiCompatible,
}

/// 目前選用的 AI 設定。
class AiConfig {
  const AiConfig({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.model,
  });

  final AiProviderType provider;
  final String apiKey;

  /// 只有 OpenAI 相容需要。
  final String? baseUrl;
  final String? model;
}

/// AI 設定與 API key 的唯一讀寫入口（Android Keystore / iOS Keychain）。
///
/// 每一家的 key 分開存，切換服務不會弄丟另一家的 key。其他地方不可直接碰
/// FlutterSecureStorage，也不可把 key 寫進 log。
class AiConfigStore {
  AiConfigStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _providerKey = 'ai_provider';
  static const _baseUrlKey = 'ai_openai_base_url';
  static const _modelKey = 'ai_openai_model';
  static String _apiKeyKey(AiProviderType p) => 'ai_key_${p.name}';

  /// 讀不出來（例如加密金鑰遺失）就當作沒設定，讓使用者重新輸入，
  /// 不讓設定頁或辨識流程卡住。
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception {
      return null;
    }
  }

  Future<AiProviderType> provider() async =>
      AiProviderType.values.asNameMap()[await _read(_providerKey)] ??
      AiProviderType.claude;

  Future<String?> apiKey(AiProviderType p) => _read(_apiKeyKey(p));
  Future<String?> baseUrl() => _read(_baseUrlKey);
  Future<String?> model() => _read(_modelKey);

  /// 目前選用的設定；key（或 OpenAI 相容的網址、模型）沒填齊時回 null。
  Future<AiConfig?> load() async {
    final p = await provider();
    final key = await apiKey(p);
    if (key == null || key.isEmpty) return null;
    if (p == AiProviderType.claude) {
      return AiConfig(provider: p, apiKey: key);
    }
    final url = await baseUrl();
    final m = await model();
    if (url == null || url.isEmpty || m == null || m.isEmpty) return null;
    return AiConfig(provider: p, apiKey: key, baseUrl: url, model: m);
  }

  /// 儲存並設為目前選用的服務。[apiKey] 留空 = 沿用這一家已存的 key。
  Future<void> save({
    required AiProviderType provider,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    await _storage.write(key: _providerKey, value: provider.name);
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _storage.write(key: _apiKeyKey(provider), value: apiKey.trim());
    }
    if (provider == AiProviderType.openAiCompatible) {
      await _storage.write(key: _baseUrlKey, value: baseUrl?.trim());
      await _storage.write(key: _modelKey, value: model?.trim());
    }
  }

  Future<void> deleteKey(AiProviderType p) =>
      _storage.delete(key: _apiKeyKey(p));

  /// 只露出頭尾，例如 `sk-ant-••••abcd`。不提供顯示完整 key 的方式。
  static String mask(String apiKey) => apiKey.length <= 12
      ? '••••'
      : '${apiKey.substring(0, 7)}••••${apiKey.substring(apiKey.length - 4)}';
}
