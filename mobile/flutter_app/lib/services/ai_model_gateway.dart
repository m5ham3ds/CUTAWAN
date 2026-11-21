import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum AiProviderId { openAi, gemini, huggingFace, compatible }

enum AiApiKind { openAiChat, geminiInteractions }

class AiModelChoice {
  const AiModelChoice({
    required this.id,
    required this.provider,
    this.label,
    this.isFreeTrial,
    this.contextLength,
  });

  final String id;
  final AiProviderId provider;
  final String? label;
  final bool? isFreeTrial;
  final int? contextLength;

  String get displayName =>
      label == null || label!.isEmpty ? id : label!;

  factory AiModelChoice.fromJson(
    Map<String, dynamic> json,
    AiProviderId provider,
  ) {
    final rawId = json['id'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('Model entry has no valid id.');
    }
    final providerEntries = json['providers'] is List<Object?>
        ? json['providers'] as List<Object?>
        : const <Object?>[];
    final freeTrial = providerEntries.any(
      (item) => item is Map<String, dynamic> && item['is_free'] == true,
    );
    final contextLength = providerEntries
        .whereType<Map<String, dynamic>>()
        .map((item) => item['context_length'])
        .whereType<num>()
        .fold<int?>(null, (best, value) {
      final next = value.toInt();
      return best == null || next > best ? next : best;
    });
    return AiModelChoice(
      id: rawId.trim(),
      provider: provider,
      label: json['name'] is String ? json['name'] as String : null,
      isFreeTrial: freeTrial || json['is_free'] == true,
      contextLength: contextLength,
    );
  }
}

class AiProviderDefinition {
  const AiProviderDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultBaseUrl,
    required this.keyLabel,
    required this.apiKind,
    this.keyRequired = true,
    this.fixedEndpoint = false,
  });

  final AiProviderId id;
  final String name;
  final String description;
  final String defaultBaseUrl;
  final String keyLabel;
  final AiApiKind apiKind;
  final bool keyRequired;
  final bool fixedEndpoint;
}

class AiProviderCatalog {
  static const providers = <AiProviderDefinition>[
    AiProviderDefinition(
      id: AiProviderId.openAi,
      name: 'OpenAI',
      description:
          'يجلب النماذج المتاحة لمفتاحك ويستخدم واجهة Chat Completions.',
      defaultBaseUrl: 'https://api.openai.com/v1/',
      keyLabel: 'OpenAI API key',
      apiKind: AiApiKind.openAiChat,
      fixedEndpoint: true,
    ),
    AiProviderDefinition(
      id: AiProviderId.gemini,
      name: 'Google Gemini',
      description:
          'قائمة Gemini الرسمية مع Interactions API وتجربة GenerateContent التوافقية.',
      defaultBaseUrl:
          'https://generativelanguage.googleapis.com/v1beta/',
      keyLabel: 'Gemini API key',
      apiKind: AiApiKind.geminiInteractions,
      fixedEndpoint: true,
    ),
    AiProviderDefinition(
      id: AiProviderId.huggingFace,
      name: 'Hugging Face Inference Providers',
      description:
          'قائمة النماذج المتاحة عبر Router وبيانات التجربة المجانية حين توفرها المنصة.',
      defaultBaseUrl: 'https://router.huggingface.co/v1/',
      keyLabel: 'Hugging Face token',
      apiKind: AiApiKind.openAiChat,
      fixedEndpoint: true,
    ),
    AiProviderDefinition(
      id: AiProviderId.compatible,
      name: 'OpenAI-compatible endpoint',
      description:
          'أي مزوّد يوفر /models و/chat/completions بالتنسيق المتوافق.',
      defaultBaseUrl: '',
      keyLabel: 'API key (يمكن تركه فارغاً للخوادم المحلية)',
      apiKind: AiApiKind.openAiChat,
    ),
  ];

  static AiProviderDefinition byId(AiProviderId id) =>
      providers.firstWhere((provider) => provider.id == id);
}

abstract interface class AiSecretStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterAiSecretStorage implements AiSecretStorage {
  FlutterAiSecretStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AiCredentialStore {
  AiCredentialStore({AiSecretStorage? storage})
      : _storage = storage ?? FlutterAiSecretStorage();

  final AiSecretStorage _storage;

  String _key(AiProviderId provider) => 'ai.provider.${provider.name}.key';
  String _base(AiProviderId provider) => 'ai.provider.${provider.name}.base';
  String _model(AiProviderId provider) => 'ai.provider.${provider.name}.model';

  static const _executionModeKey = 'ai.execution.mode';
  static const _activeProviderKey = 'ai.execution.provider';
  static const _cloudConsentKey = 'ai.execution.cloud_consent';

  Future<void> saveApiKey(AiProviderId provider, String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw const FormatException('API key is empty.');
    }
    if (normalized.length > 4096 || normalized.contains('\n')) {
      throw const FormatException('API key has an invalid format.');
    }
    await _storage.write(_key(provider), normalized);
  }

  Future<String?> readApiKey(AiProviderId provider) =>
      _storage.read(_key(provider));

  Future<bool> hasApiKey(AiProviderId provider) async =>
      (await readApiKey(provider))?.isNotEmpty ?? false;

  Future<void> deleteApiKey(AiProviderId provider) =>
      _storage.delete(_key(provider));

  Future<void> saveBaseUrl(AiProviderId provider, String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isNotEmpty) _validateBaseUrl(normalized);
    await _storage.write(_base(provider), normalized);
  }

  Future<String?> readBaseUrl(AiProviderId provider) =>
      _storage.read(_base(provider));

  Future<void> saveSelectedModel(
    AiProviderId provider,
    String modelId,
  ) async {
    if (modelId.trim().isEmpty) {
      throw const FormatException('Model ID is empty.');
    }
    await _storage.write(_model(provider), modelId.trim());
  }

  Future<String?> readSelectedModel(AiProviderId provider) =>
      _storage.read(_model(provider));

  Future<void> deleteSelectedModel(AiProviderId provider) =>
      _storage.delete(_model(provider));

  Future<void> saveExecutionMode(String mode) async {
    if (mode != 'local' && mode != 'remote') {
      throw const FormatException('Execution mode must be local or remote.');
    }
    if (mode == 'remote' && !await hasCloudConsent()) {
      throw StateError('Cloud execution requires explicit persisted consent.');
    }
    await _storage.write(_executionModeKey, mode);
  }

  Future<String> readExecutionMode() async {
    final saved = await _storage.read(_executionModeKey) ?? 'local';
    if (saved != 'remote' && saved != 'local') {
      await _storage.write(_executionModeKey, 'local');
      return 'local';
    }
    if (saved == 'remote' && !await hasCloudConsent()) {
      await _storage.write(_executionModeKey, 'local');
      return 'local';
    }
    return saved;
  }

  Future<void> saveActiveProvider(AiProviderId provider) =>
      _storage.write(_activeProviderKey, provider.name);

  Future<AiProviderId> readActiveProvider() async {
    final value = await _storage.read(_activeProviderKey);
    return AiProviderId.values.firstWhere(
      (provider) => provider.name == value,
      orElse: () => AiProviderId.openAi,
    );
  }

  Future<void> saveCloudConsent(bool enabled) =>
      _storage.write(_cloudConsentKey, enabled ? 'true' : 'false');

  Future<bool> hasCloudConsent() async =>
      await _storage.read(_cloudConsentKey) == 'true';

  static Uri _validateBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    final secureRemote = uri?.scheme == 'https';
    final localEmulator = uri?.scheme == 'http' &&
        const {'10.0.2.2', '127.0.0.1', 'localhost'}.contains(uri?.host);
    if (uri == null ||
        !uri.hasAuthority ||
        !(secureRemote || localEmulator) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'استخدم HTTPS للمضيف الخارجي، أو عنوان loopback محلياً لاختبار الخادم.',
      );
    }
    return uri;
  }
}

class AiProviderRequestException implements Exception {
  const AiProviderRequestException(this.statusCode, this.code);

  final int statusCode;
  final String? code;

  @override
  String toString() =>
      'AI provider request failed: HTTP $statusCode'
      '${code == null ? '' : ' ($code)'}';
}

class AiModelGateway {
  AiModelGateway({
    AiCredentialStore? credentials,
    http.Client? client,
  })  : credentials = credentials ?? AiCredentialStore(),
        _client = client ?? http.Client();

  final AiCredentialStore credentials;
  final http.Client _client;

  Future<List<AiModelChoice>> listModels(
    AiProviderId provider, {
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final definition = AiProviderCatalog.byId(provider);
    final key = apiKeyOverride ?? await credentials.readApiKey(provider);
    if (definition.keyRequired && (key == null || key.isEmpty)) {
      throw StateError('احفظ مفتاح API لهذا المزوّد أولاً.');
    }
    final base = await _resolveBase(provider, baseUrlOverride);
    final uri = provider == AiProviderId.gemini
        ? _geminiModelsUri(base)
        : _openAiModelsUri(base);
    final response = await _client
        .get(uri, headers: _headers(provider, key))
        .timeout(const Duration(seconds: 25));
    final decoded = _decodeResponse(response);
    final rawModels = provider == AiProviderId.gemini
        ? decoded['models']
        : decoded['data'];
    if (rawModels is! List) {
      throw const FormatException(
        'Provider response did not contain a model list.',
      );
    }

    final result = <AiModelChoice>[];
    for (final raw in rawModels) {
      if (raw is! Map<String, dynamic>) continue;
      Map<String, dynamic> modelJson = raw;
      if (provider == AiProviderId.gemini) {
        final name = raw['name'];
        if (name is! String || name.isEmpty) continue;
        modelJson = {
          'id': name.replaceFirst('models/', ''),
          'name': raw['displayName'] ?? name,
        };
        final methods = raw['supportedGenerationMethods'];
        if (methods is List &&
            !methods.contains('generateContent') &&
            !methods.contains('interactions')) {
          continue;
        }
      }
      try {
        result.add(AiModelChoice.fromJson(modelJson, provider));
      } on FormatException {
        continue;
      }
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    if (result.isEmpty) {
      throw const FormatException('لم يُرجع المزوّد نماذج قابلة للاستخدام.');
    }
    return result;
  }

  Future<String> testModel(
    AiProviderId provider, {
    required String modelId,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) =>
      complete(
        provider,
        modelId: modelId,
        prompt: 'Reply with exactly: CUTAWAN connection successful.',
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
        maxTokens: 48,
      );

  Future<String> complete(
    AiProviderId provider, {
    required String modelId,
    required String prompt,
    String? apiKeyOverride,
    String? baseUrlOverride,
    int maxTokens = 900,
  }) async {
    if (modelId.trim().isEmpty) {
      throw const FormatException('Model ID is empty.');
    }
    if (prompt.trim().isEmpty || prompt.length > 50000) {
      throw const FormatException('AI prompt is empty or exceeds the limit.');
    }
    final definition = AiProviderCatalog.byId(provider);
    final key = apiKeyOverride ?? await credentials.readApiKey(provider);
    if (definition.keyRequired && (key == null || key.isEmpty)) {
      throw StateError('احفظ مفتاح API لهذا المزوّد أولاً.');
    }
    final base = await _resolveBase(provider, baseUrlOverride);
    if (provider == AiProviderId.gemini) {
      try {
        return await _completeGeminiInteractions(
          base,
          key,
          modelId,
          prompt,
        );
      } on AiProviderRequestException catch (error) {
        if (!_supportsLegacyGeminiFallback(error)) rethrow;
        return _completeGeminiGenerateContent(
          base,
          key,
          modelId,
          prompt,
        );
      }
    }
    final response = await _client
        .post(
          _openAiCompletionUri(base),
          headers: {
            ..._headers(provider, key),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': modelId,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'max_tokens': maxTokens,
            'temperature': 0,
          }),
        )
        .timeout(const Duration(seconds: 90));
    return _extractOpenAiText(_decodeResponse(response));
  }

  Future<String> _completeGeminiInteractions(
    Uri base,
    String? key,
    String model,
    String prompt,
  ) async {
    final response = await _client
        .post(
          _geminiInteractionsUri(base),
          headers: {
            ..._headers(AiProviderId.gemini, key),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'model': model, 'input': prompt}),
        )
        .timeout(const Duration(seconds: 90));
    return _extractGeminiText(_decodeResponse(response));
  }

  Future<String> _completeGeminiGenerateContent(
    Uri base,
    String? key,
    String model,
    String prompt,
  ) async {
    final uri = base.resolve('models/${Uri.encodeComponent(model)}:generateContent');
    final response = await _client
        .post(
          uri,
          headers: {
            ..._headers(AiProviderId.gemini, key),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': prompt}],
              },
            ],
            'generationConfig': {'temperature': 0, 'maxOutputTokens': 900},
          }),
        )
        .timeout(const Duration(seconds: 90));
    final decoded = _decodeResponse(response);
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty ||
        candidates.first is! Map<String, dynamic>) {
      throw const FormatException(
        'Gemini GenerateContent response has no candidates.',
      );
    }
    final content = (candidates.first as Map<String, dynamic>)['content'];
    if (content is! Map<String, dynamic> || content['parts'] is! List<Object?>) {
      throw const FormatException('Gemini response did not contain text parts.');
    }
    final parts = (content['parts'] as List<Object?>)
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>()
        .toList(growable: false);
    if (parts.isEmpty) {
      throw const FormatException('Gemini response contained no text.');
    }
    return parts.join('\n');
  }

  bool _supportsLegacyGeminiFallback(AiProviderRequestException error) =>
      error.statusCode == 404 ||
      (error.statusCode == 400 &&
          const {'NOT_FOUND', 'INVALID_ARGUMENT', 'UNSUPPORTED'}.
              contains(error.code));

  Future<Uri> _resolveBase(
    AiProviderId provider,
    String? override,
  ) async {
    final definition = AiProviderCatalog.byId(provider);
    final saved = await credentials.readBaseUrl(provider);
    final base = (override ??
            saved ??
            definition.defaultBaseUrl)
        .trim();
    if (provider == AiProviderId.gemini) {
      final uri = AiCredentialStore._validateBaseUrl(base);
      if (uri.host != 'generativelanguage.googleapis.com' ||
          !uri.path.startsWith('/v1beta')) {
        throw const FormatException('Gemini base URL must use the Google API host.');
      }
      return _ensureTrailingSlash(uri);
    }
    final uri = AiCredentialStore._validateBaseUrl(base);
    if (provider == AiProviderId.openAi &&
        uri.host != 'api.openai.com') {
      throw const FormatException('OpenAI base URL host is fixed.');
    }
    if (provider == AiProviderId.huggingFace &&
        uri.host != 'router.huggingface.co') {
      throw const FormatException('Hugging Face base URL host is fixed.');
    }
    return _ensureTrailingSlash(uri);
  }

  Uri _ensureTrailingSlash(Uri uri) {
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }

  Uri _openAiModelsUri(Uri base) => base.resolve('models');
  Uri _openAiCompletionUri(Uri base) => base.resolve('chat/completions');
  Uri _geminiModelsUri(Uri base) => base.resolve('models');
  Uri _geminiInteractionsUri(Uri base) => base.resolve('interactions');

  Map<String, String> _headers(AiProviderId provider, String? key) => {
        'Accept': 'application/json',
        if (key != null && key.isNotEmpty) 'Authorization': 'Bearer $key',
        if (provider == AiProviderId.gemini && key != null)
          'x-goog-api-key': key,
      };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final error = body['error'];
          final rawCode = error is Map<String, dynamic> ? error['code'] : body['code'];
          if (rawCode is String) code = rawCode;
        }
      } on FormatException {
        // Never include raw response bodies in errors; they can echo secrets.
      }
      throw AiProviderRequestException(response.statusCode, code);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI provider returned invalid JSON.');
    }
    return decoded;
  }

  String _extractOpenAiText(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map<String, dynamic>) {
      throw const FormatException('Chat completion returned no choices.');
    }
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Chat completion returned no message.');
    }
    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      final parts = content
          .whereType<Map<String, dynamic>>()
          .map((part) => part['text'])
          .whereType<String>()
          .toList(growable: false);
      if (parts.isNotEmpty) return parts.join('\n');
    }
    throw const FormatException('Chat completion contained no text.');
  }

  String _extractGeminiText(Map<String, dynamic> body) {
    final output = body['output'];
    if (output is List) {
      final parts = output
          .whereType<Map<String, dynamic>>()
          .where((item) => item['type'] == 'text')
          .map((item) => item['text'])
          .whereType<String>()
          .toList(growable: false);
      if (parts.isNotEmpty) return parts.join('\n');
    }
    final outputText = body['output_text'];
    if (outputText is String && outputText.isNotEmpty) return outputText;
    throw const FormatException('Gemini Interactions response contained no text.');
  }

  void close() => _client.close();
}
