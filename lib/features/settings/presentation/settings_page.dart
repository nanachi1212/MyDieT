import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/secure/ai_config_store.dart';
import '../../ai/claude_food_recognizer.dart';
import '../../ai/food_recognizer.dart';
import '../../ai/openai_compatible_recognizer.dart';

/// 設定：拍照辨識用的 AI 服務與 API key。Health 設定屬於 P3。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKey = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();

  AiProviderType _provider = AiProviderType.claude;
  final _savedKeys = <AiProviderType, String?>{};
  bool _loading = true;
  bool _busy = false;

  AiConfigStore get _store => ref.read(aiConfigStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = await _store.provider();
    for (final p in AiProviderType.values) {
      _savedKeys[p] = await _store.apiKey(p);
    }
    _baseUrl.text = await _store.baseUrl() ?? '';
    _model.text = await _store.model() ?? '';
    if (mounted) {
      setState(() {
        _provider = provider;
        _loading = false;
      });
    }
  }

  bool get _isClaude => _provider == AiProviderType.claude;

  /// 表單目前的內容；key 欄位留空就用已存的 key。缺東西時回傳錯誤訊息。
  (AiConfig?, String?) _formConfig() {
    final key = _apiKey.text.trim().isNotEmpty
        ? _apiKey.text.trim()
        : _savedKeys[_provider];
    if (key == null || key.isEmpty) return (null, '請輸入 API key');
    if (_isClaude) return (AiConfig(provider: _provider, apiKey: key), null);

    final url = _baseUrl.text.trim();
    if (!url.startsWith('http')) return (null, '請輸入以 https:// 開頭的網址');
    if (_model.text.trim().isEmpty) return (null, '請輸入模型名稱');
    return (
      AiConfig(
        provider: _provider,
        apiKey: key,
        baseUrl: url,
        model: _model.text.trim(),
      ),
      null,
    );
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final (config, error) = _formConfig();
    if (config == null) return _toast(error!);
    await _store.save(
      provider: config.provider,
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
      model: config.model,
    );
    _apiKey.clear();
    await _load();
    if (mounted) _toast('已儲存，拍照辨識會使用這個設定');
  }

  Future<void> _test() async {
    final (config, error) = _formConfig();
    if (config == null) return _toast(error!);
    setState(() => _busy = true);
    try {
      await ref.read(foodRecognizerFactoryProvider)(config).ping();
      if (mounted) _toast('連線成功');
    } on AiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteKey() async {
    await _store.deleteKey(_provider);
    await _load();
    if (mounted) _toast('已刪除 API key');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final saved = _savedKeys[_provider];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('拍照辨識的 AI 服務', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AiProviderType>(
            segments: const [
              ButtonSegment(
                value: AiProviderType.claude,
                label: Text('Claude'),
              ),
              ButtonSegment(
                value: AiProviderType.openAiCompatible,
                label: Text('OpenAI 相容'),
              ),
            ],
            selected: {_provider},
            onSelectionChanged: (v) => setState(() {
              _provider = v.first;
              _apiKey.clear();
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _isClaude
                ? '模型：${ClaudeFoodRecognizer.model}'
                : 'Gemini、OpenRouter、Groq 等提供 OpenAI 相容端點的服務都能用，'
                      '模型請選支援圖片的。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          if (!_isClaude) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final MapEntry(:key, :value)
                    in OpenAiCompatibleRecognizer.presets.entries)
                  ActionChip(
                    label: Text(key),
                    onPressed: () => setState(() => _baseUrl.text = value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('ai_base_url_field'),
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: '端點網址'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_model_field'),
              controller: _model,
              decoration: const InputDecoration(
                labelText: '模型名稱',
                helperText: '到服務商網站查支援圖片輸入的模型名稱',
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (saved != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('已儲存的 API key'),
              subtitle: Text(
                key: const Key('ai_saved_key'),
                AiConfigStore.mask(saved),
              ),
              trailing: IconButton(
                tooltip: '刪除 API key',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteKey,
              ),
            ),
          TextField(
            key: const Key('ai_api_key_field'),
            controller: _apiKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: saved == null ? 'API key' : '換新的 API key（留空＝沿用）',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('ai_test_button'),
                  onPressed: _busy ? null : _test,
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('測試連線'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('ai_save_button'),
                  onPressed: _busy ? null : _save,
                  child: const Text('儲存並使用'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '照片只會送到你選的服務，費用或免費額度由你的帳戶負擔。'
            'API key 加密存在這支手機，只在呼叫你選的服務時送出。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
