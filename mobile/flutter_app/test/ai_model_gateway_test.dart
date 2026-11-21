import 'dart:convert';

import 'package:cutawan_mobile/services/ai_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemorySecretStorage implements AiSecretStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test('provider catalog includes local/cloud-compatible choices', () {
    expect(AiProviderCatalog.providers.map((p) => p.id), containsAll([
      AiProviderId.openAi,
      AiProviderId.gemini,
      AiProviderId.huggingFace,
      AiProviderId.compatible,
    ]));
    expect(
      AiProviderCatalog.byId(AiProviderId.compatible).keyRequired,
      isFalse,
    );
  });

  test('API key is kept in the secure-storage adapter and can be removed', () async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    await credentials.saveApiKey(AiProviderId.openAi, 'test-secret-key');
    expect(await credentials.hasApiKey(AiProviderId.openAi), isTrue);
    expect(await credentials.readApiKey(AiProviderId.openAi), 'test-secret-key');
    expect(storage.values.values, contains('test-secret-key'));
    await credentials.deleteApiKey(AiProviderId.openAi);
    expect(await credentials.hasApiKey(AiProviderId.openAi), isFalse);
  });

  test('API key format and insecure remote endpoints are rejected', () async {
    final credentials = AiCredentialStore(storage: MemorySecretStorage());
    await expectLater(
      credentials.saveApiKey(AiProviderId.openAi, 'key\r\nforged-header'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      credentials.saveSelectedModel(AiProviderId.openAi, 'model\nheader'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      credentials.saveBaseUrl(
        AiProviderId.compatible,
        'http://public-provider.example/v1',
      ),
      throwsA(isA<FormatException>()),
    );
    await credentials.saveBaseUrl(
      AiProviderId.compatible,
      'http://10.0.2.2:8080/v1/',
    );
  });

  test('OpenAI models list and test completion use account-visible IDs', () async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    await credentials.saveApiKey(AiProviderId.openAi, 'mock-openai-key');
    await credentials.saveCloudConsent(true);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/models')) {
        return http.Response(jsonEncode({
          'data': [
            {'id': 'gpt-6.1-model', 'object': 'model'},
            {'id': 'embedding-only-model'},
          ],
        }), 200);
      }
      return http.Response(jsonEncode({
        'choices': [
          {'message': {'role': 'assistant', 'content': 'CUTAWAN OK'}}
        ],
      }), 200);
    });
    final gateway = AiModelGateway(credentials: credentials, client: client);
    final models = await gateway.listModels(AiProviderId.openAi);
    expect(models.map((model) => model.id), contains('gpt-6.1-model'));
    expect(requests.first.url.path, '/v1/models');
    final reply = await gateway.testModel(
      AiProviderId.openAi,
      modelId: 'gpt-6.1-model',
    );
    expect(reply, 'CUTAWAN OK');
    expect(requests.last.url.path, '/v1/chat/completions');
    expect(requests.last.headers['authorization'], 'Bearer mock-openai-key');
    gateway.close();
  });

  test('Gemini uses the official host and falls back to GenerateContent', () async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    await credentials.saveApiKey(AiProviderId.gemini, 'mock-gemini-key');
    await credentials.saveCloudConsent(true);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/models')) {
        return http.Response(jsonEncode({
          'models': [
            {
              'name': 'models/gemini-3-flash',
              'displayName': 'Gemini 3 Flash',
              'supportedGenerationMethods': ['generateContent'],
            }
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/interactions')) {
        return http.Response(jsonEncode({
          'error': {'code': 'NOT_FOUND'}
        }), 404);
      }
      return http.Response(jsonEncode({
        'candidates': [{
          'content': {'parts': [{'text': 'Gemini OK'}]}
        }]
      }), 200);
    });
    final gateway = AiModelGateway(credentials: credentials, client: client);
    final models = await gateway.listModels(AiProviderId.gemini);
    expect(models.single.id, 'gemini-3-flash');
    final reply = await gateway.testModel(
      AiProviderId.gemini,
      modelId: 'gemini-3-flash',
    );
    expect(reply, 'Gemini OK');
    expect(
      requests.last.url.path,
      '/v1beta/models/gemini-3-flash:generateContent',
    );
    expect(
      requests.last.headers['x-goog-api-key'],
      'mock-gemini-key',
    );
    expect(requests.last.headers.containsKey('authorization'), isFalse);
    gateway.close();
  });

  test('Hugging Face lists models and reports free provider metadata', () async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    await credentials.saveApiKey(AiProviderId.huggingFace, 'mock-hf-token');
    await credentials.saveCloudConsent(true);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/models')) {
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 'Qwen/Qwen3-32B',
              'providers': [
                {'provider': 'test-provider', 'is_free': true, 'context_length': 32768}
              ],
            }
          ],
        }), 200);
      }
      return http.Response(jsonEncode({
        'choices': [{'message': {'content': 'HF OK'}}]
      }), 200);
    });
    final gateway = AiModelGateway(credentials: credentials, client: client);
    final models = await gateway.listModels(AiProviderId.huggingFace);
    expect(models.single.id, 'Qwen/Qwen3-32B');
    expect(models.single.isFreeTrial, isTrue);
    expect(models.single.contextLength, 32768);
    expect(
      await gateway.testModel(
        AiProviderId.huggingFace,
        modelId: models.single.id,
      ),
      'HF OK',
    );
    gateway.close();
  });

  test('Gemini cannot be redirected to an arbitrary remote hostname', () async {
    final credentials = AiCredentialStore(storage: MemorySecretStorage());
    await credentials.saveApiKey(AiProviderId.gemini, 'mock-key');
    await credentials.saveCloudConsent(true);
    final gateway = AiModelGateway(credentials: credentials);
    await expectLater(
      gateway.listModels(
        AiProviderId.gemini,
        baseUrlOverride: 'https://evil.example/v1beta/',
      ),
      throwsA(isA<FormatException>()),
    );
    gateway.close();
  });

  test('execution mode cannot persist or restore remote without cloud consent', () async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    expect(await credentials.readExecutionMode(), 'local');
    expect(await credentials.hasCloudConsent(), isFalse);
    await expectLater(
      credentials.saveExecutionMode('remote'),
      throwsA(isA<StateError>()),
    );

    await credentials.saveCloudConsent(true);
    await credentials.saveExecutionMode('remote');
    expect(await credentials.readExecutionMode(), 'remote');

    // Simulate interruption after consent revocation but before mode reset.
    await credentials.saveCloudConsent(false);
    storage.values['ai.execution.mode'] = 'remote';
    expect(await credentials.readExecutionMode(), 'local');
    expect(storage.values['ai.execution.mode'], 'local');
  });

  test('gateway blocks cloud requests until consent is saved', () async {
    final credentials = AiCredentialStore(storage: MemorySecretStorage());
    await credentials.saveApiKey(AiProviderId.openAi, 'mock-key');
    var requestCount = 0;
    final gateway = AiModelGateway(
      credentials: credentials,
      client: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      gateway.listModels(AiProviderId.openAi),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      gateway.complete(
        AiProviderId.openAi,
        modelId: 'chat-model',
        prompt: 'This text must not be sent.',
      ),
      throwsA(isA<StateError>()),
    );
    expect(requestCount, 0);
    gateway.close();
  });

  test('local compatible endpoint works without cloud consent or API key', () async {
    final credentials = AiCredentialStore(storage: MemorySecretStorage());
    await credentials.saveBaseUrl(
      AiProviderId.compatible,
      'http://10.0.2.2:8080/v1/',
    );
    final requests = <http.Request>[];
    final gateway = AiModelGateway(
      credentials: credentials,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({
          'data': [{'id': 'local-chat-model'}],
        }), 200);
      }),
    );

    final models = await gateway.listModels(AiProviderId.compatible);
    expect(models.single.id, 'local-chat-model');
    expect(requests.single.url.host, '10.0.2.2');
    expect(requests.single.headers.containsKey('authorization'), isFalse);
    gateway.close();
  });

  test('deleting a provider model removes only that provider selection', async {
    final storage = MemorySecretStorage();
    final credentials = AiCredentialStore(storage: storage);
    await credentials.saveSelectedModel(AiProviderId.openAi, 'chat-model');
    await credentials.saveSelectedModel(AiProviderId.gemini, 'gemini-model');
    await credentials.deleteSelectedModel(AiProviderId.openAi);
    expect(await credentials.readSelectedModel(AiProviderId.openAi), isNull);
    expect(
      await credentials.readSelectedModel(AiProviderId.gemini),
      'gemini-model',
    );
  });
}
