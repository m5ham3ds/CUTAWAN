part of '../home_shell.dart';

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  final WhisperModelManager _whisper = WhisperModelManager();
  final QwenModelManager _qwen = QwenModelManager();
  final AiCredentialStore _credentials = AiCredentialStore();
  late final AiModelGateway _gateway = AiModelGateway(credentials: _credentials);

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  AiProviderId _provider = AiProviderId.openAi;
  List<AiModelChoice> _remoteModels = [];
  String? _selectedRemoteModel;
  String _executionMode = 'local';
  String? _providerMessage;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _remoteBusy = false;
  bool _whisperInstalled = false;
  bool _qwenInstalled = false;
  bool _keySaved = false;
  bool _cloudConsent = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _refreshModels();
    _loadProviderPreferences();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _whisper.close();
    _gateway.close();
    super.dispose();
  }

  Future<void> _loadProviderPreferences() async {
    final provider = _provider;
    final definition = AiProviderCatalog.byId(provider);
    final values = await Future.wait<Object?>([
      _credentials.hasApiKey(provider),
      _credentials.readBaseUrl(provider),
      _credentials.readSelectedModel(provider),
      _credentials.readExecutionMode(),
      _credentials.hasCloudConsent(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _keySaved = values[0] as bool;
      final savedBase = values[1] as String?;
      _baseUrlController.text =
          savedBase?.isNotEmpty == true ? savedBase! : definition.defaultBaseUrl;
      _selectedRemoteModel = values[2] as String?;
      _executionMode = values[3] as String? ?? 'local';
      _cloudConsent = values[4] as bool? ?? false;
    });
  }

  Future<void> _selectProvider(AiProviderId? provider) async {
    if (provider == null || _remoteBusy) {
      return;
    }
    setState(() {
      _provider = provider;
      _remoteModels = [];
      _selectedRemoteModel = null;
      _providerMessage = null;
      _error = null;
      _apiKeyController.clear();
    });
    await _loadProviderPreferences();
  }

  Future<void> _refreshModels() async {
    try {
      final whisperFile =
          await _whisper.findCatalogModel(WhisperModelCatalog.base);
      final qwenFile = await _qwen.findInstalled();
      if (!mounted) {
      return;
    }
      setState(() {
        _whisperInstalled = whisperFile != null;
        _qwenInstalled = qwenFile != null;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر التحقق من سلامة أحد النماذج المحلية: $error';
          _loading = false;
        });
      }
    }
  }

  Future<bool> _hasFreeSpace(int requiredBytes) async {
    final available = await AndroidVideoPicker.availableStorageBytes();
    if (available >= requiredBytes) {
      return true;
    }
    if (mounted) {
      setState(() => _error =
          'المساحة الحرة غير كافية. المطلوب نحو ${_formatBytes(requiredBytes)}، والمتاح ${_formatBytes(available)}.');
    }
    return false;
  }

  Future<void> _downloadWhisper() async {
    if (_busy) {
      return;
    }
    final required = WhisperModelCatalog.base.approximateBytes +
        96 * 1024 * 1024;
    if (!await _hasFreeSpace(required)) {
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      await for (final update
          in _whisper.downloadCatalogModel(WhisperModelCatalog.base)) {
        if (mounted) {
          setState(() => _progress = update.fraction);
        }
      }
      await _refreshModels();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'فشل تنزيل/التحقق من Whisper: $error');
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; _progress = null; });
      }
    }
  }

  Future<void> _downloadQwen() async {
    if (_busy) {
      return;
    }
    if (!await _hasFreeSpace(QwenModelManager.minimumFreeBytes)) {
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      await _qwen.download(onProgress: (update) {
        if (mounted) {
          setState(() => _progress = update.fraction);
        }
      });
      await _refreshModels();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'فشل تنزيل/التحقق من Qwen: $error');
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; _progress = null; });
      }
    }
  }

  Future<void> _deleteWhisper() async {
    if (_busy) {
      return;
    }
    try {
      final model = await _whisper.find(WhisperModelCatalog.base.fileName);
      if (model != null) {
        await model.delete();
      }
      if (mounted) {
        setState(() => _whisperInstalled = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حذف نموذج Whisper: $error');
      }
    }
  }

  Future<void> _deleteQwen() async {
    if (_busy) {
      return;
    }
    try {
      await _qwen.deleteInstalled();
      if (mounted) {
        setState(() => _qwenInstalled = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حذف نموذج Qwen: $error');
      }
    }
  }

  Future<void> _saveRemoteSettings() async {
    if (_remoteBusy) {
      return;
    }
    final definition = AiProviderCatalog.byId(_provider);
    setState(() {
      _remoteBusy = true;
      _providerMessage = null;
      _error = null;
    });
    try {
      final baseUrl = _baseUrlController.text.trim();
      if (!definition.fixedEndpoint) {
        await _credentials.saveBaseUrl(_provider, baseUrl);
      }
      final key = _apiKeyController.text.trim();
      if (key.isNotEmpty) {
        await _credentials.saveApiKey(_provider, key);
        _apiKeyController.clear();
      }
      final hasKey = await _credentials.hasApiKey(_provider);
      if (definition.keyRequired && !hasKey) {
        throw StateError('أدخل مفتاح API صالحاً واحفظه أولاً.');
      }
      if (mounted) {
        setState(() {
          _keySaved = hasKey;
          _providerMessage = 'حُفظت الإعدادات في التخزين الآمن على الجهاز.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حفظ إعدادات المزوّد: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _remoteBusy = false);
      }
    }
  }

  Future<void> _removeRemoteKey() async {
    setState(() {
      _remoteBusy = true;
      _providerMessage = null;
      _error = null;
    });
    try {
      await _credentials.deleteApiKey(_provider);
      if (mounted) {
        setState(() {
          _keySaved = false;
          _remoteModels = [];
          _selectedRemoteModel = null;
          _providerMessage = 'تم حذف مفتاح هذا المزوّد من التخزين الآمن.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حذف المفتاح: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _remoteBusy = false);
      }
    }
  }

  Future<void> _loadRemoteModels() async {
    setState(() {
      _remoteBusy = true;
      _providerMessage = null;
      _error = null;
    });
    try {
      final models = await _gateway.listModels(
        _provider,
        baseUrlOverride: _provider == AiProviderId.compatible
            ? _baseUrlController.text.trim()
            : null,
      );
      final saved = await _credentials.readSelectedModel(_provider);
      final selected = models.any((model) => model.id == saved)
          ? saved
          : models.first.id;
      await _credentials.saveSelectedModel(_provider, selected!);
      await _credentials.saveActiveProvider(_provider);
      if (!mounted) {
      return;
    }
      setState(() {
        _remoteModels = models;
        _selectedRemoteModel = selected;
        _providerMessage =
            'جُلبت ${models.length} نتيجة نموذج من حساب المزوّد. ليست كل النتائج بالضرورة نماذج محادثة.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر جلب النماذج: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _remoteBusy = false);
      }
    }
  }

  Future<void> _saveSelectedRemoteModel(String? value) async {
    if (value == null) {
      return;
    }
    try {
      await _credentials.saveSelectedModel(_provider, value);
      await _credentials.saveActiveProvider(_provider);
      if (mounted) {
        setState(() {
          _selectedRemoteModel = value;
          _providerMessage = 'تم حفظ النموذج الافتراضي لهذا المزوّد.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حفظ النموذج المحدد: $error');
      }
    }
  }

  Future<void> _testRemoteModel() async {
    final model = _selectedRemoteModel;
    if (model == null || _remoteBusy) {
      return;
    }
    setState(() {
      _remoteBusy = true;
      _providerMessage = 'جارٍ إرسال طلب اختبار نصي قصير…';
      _error = null;
    });
    try {
      final result = await _gateway.testModel(
        _provider,
        modelId: model,
        baseUrlOverride: _provider == AiProviderId.compatible
            ? _baseUrlController.text.trim()
            : null,
      );
      if (mounted) {
        final excerpt = result.length > 220
            ? result.substring(0, 220)
            : result;
        setState(() => _providerMessage = 'نجح الاتصال مع $model\n$excerpt');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'فشل اختبار النموذج: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _remoteBusy = false);
      }
    }
  }

  Future<void> _setExecutionMode(String mode) async {
    if (mode == 'remote' && !_cloudConsent) {
      setState(() => _error =
          'فعّل موافقة الإرسال السحابي بعد قراءة التنبيه قبل استخدام نموذج خارجي.');
      return;
    }
    if (mode == 'remote' && _selectedRemoteModel == null) {
      setState(() => _error = 'اجلب النماذج واختر نموذجاً افتراضياً أولاً.');
      return;
    }
    await _credentials.saveExecutionMode(mode);
    if (mounted) {
      setState(() {
        _executionMode = mode;
        _providerMessage = mode == 'local'
            ? 'سيستخدم CUTAWAN نموذج Qwen المحلي عند تثبيته.'
            : 'اختير النموذج الخارجي. ستُرسل مقتطفات النص فقط بموافقتك.';
      });
    }
  }

  Future<void> _setCloudConsent(bool enabled) async {
    await _credentials.saveCloudConsent(enabled);
    if (mounted) {
      setState(() {
        _cloudConsent = enabled;
        if (!enabled && _executionMode == 'remote') {
          _executionMode = 'local';
        }
      });
    }
    if (!enabled) {
      await _credentials.saveExecutionMode('local');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = AiProviderCatalog.byId(_provider);
    return Scaffold(
      appBar: AppBar(title: const Text('مركز النماذج'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'النماذج المحلية',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'تعمل هذه النماذج على الهاتف بعد تنزيل الأوزان والتحقق من سلامتها. لا تحتاج مفاتيح API.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _StatusNote(text: _error!),
          ],
          if (_providerMessage != null) ...[
            const SizedBox(height: 12),
            _StatusNote(text: _providerMessage!),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 6),
            Text(
              _progress == null
                  ? 'جارٍ تجهيز النموذج…'
                  : 'اكتمل ${(_progress! * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 18),
          _modelCard(
            context,
            title: 'Whisper Base متعدد اللغات',
            description:
                'تفريغ محلي للعربية والإنجليزية مع توقيتات الكلمات. الحجم التقريبي 148 MB؛ يعمل بوضع CPU على ARM64.',
            metadata: 'whisper.cpp · لا تُضمّن الأوزان في APK',
            installed: _whisperInstalled,
            onInstall: _downloadWhisper,
            onRemove: _deleteWhisper,
          ),
          const SizedBox(height: 12),
          _modelCard(
            context,
            title: 'Qwen2.5-0.5B-Instruct Q4_K_M',
            description:
                'نموذج GGUF محلي للتعليقات التحريرية على المقاطع. الحجم نحو 491.4 MB.',
            metadata: 'llama.cpp · Apache-2.0 · لا يعدّل التوقيت أو التقييم',
            installed: _qwenInstalled,
            onInstall: _downloadQwen,
            onRemove: _deleteQwen,
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const Divider(height: 36),
          Text(
            'اختيار محرك الذكاء الاصطناعي',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'local',
                icon: Icon(Icons.phone_android),
                label: Text('محلي'),
              ),
              ButtonSegment(
                value: 'remote',
                icon: Icon(Icons.cloud_outlined),
                label: Text('سحابي'),
              ),
            ],
            selected: {_executionMode},
            onSelectionChanged: _remoteBusy
                ? null
                : (values) => _setExecutionMode(values.first),
          ),
          const SizedBox(height: 8),
          Text(
            _executionMode == 'local'
                ? 'يستخدم Qwen المحلي إن كان مثبتاً؛ وإلا تحفظ المقاطع بالترتيب الحتمي.'
                : 'يستخدم المزوّد الخارجي والنموذج المحفوظين. يتطلب موافقة صريحة.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _cloudConsent,
            onChanged: _remoteBusy
                ? null
                : (value) => _setCloudConsent(value ?? false),
            title: const Text('أوافق على إرسال مقتطفات نص التفريغ للمزوّد الخارجي'),
            subtitle: const Text(
              'لا يُرسل ملف الفيديو أو مفتاح API ضمن نص الطلب. سياسة الاحتفاظ بالبيانات تخضع للمزوّد.',
            ),
          ),
          const Divider(height: 36),
          Text(
            'منصات النماذج السحابية',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'قائمة النماذج تُجلب من حسابك. ظهور النموذج لا يعني أنه مجاني أو أنه يدعم المحادثة؛ توافره وسعره تحددهما المنصة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<AiProviderId>(
            key: ValueKey(_provider),
            initialValue: _provider,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المزوّد',
              prefixIcon: Icon(Icons.cloud_queue_outlined),
            ),
            items: AiProviderCatalog.providers.map((item) =>
              DropdownMenuItem(
                value: item.id,
                child: Text(item.name),
              )).toList(),
            onChanged: _remoteBusy ? null : _selectProvider,
          ),
          const SizedBox(height: 8),
          Text(provider.description, style: theme.textTheme.bodySmall),
          if (_provider == AiProviderId.compatible) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://provider.example.com/v1/',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: provider.keyLabel,
              hintText: _keySaved
                  ? 'المفتاح محفوظ — أدخل مفتاحاً جديداً للاستبدال'
                  : 'أدخل مفتاح API',
              prefixIcon: const Icon(Icons.key_outlined),
              helperText:
                  'لا يُعرض المفتاح بعد الحفظ ولا يُكتب في ملفات المشروع.',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _remoteBusy ? null : _saveRemoteSettings,
                icon: const Icon(Icons.lock_outline),
                label: const Text('حفظ الإعدادات بأمان'),
              ),
              if (_keySaved) ...[
                TextButton.icon(
                  onPressed: _remoteBusy ? null : _removeRemoteKey,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف المفتاح'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _remoteBusy ? null : _loadRemoteModels,
                icon: const Icon(Icons.sync),
                label: const Text('جلب النماذج'),
              ),
            ],
          ),
          if (_remoteModels.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('${_provider.name}:$_selectedRemoteModel'),
              initialValue: _selectedRemoteModel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'النموذج الافتراضي',
                prefixIcon: Icon(Icons.auto_awesome),
              ),
              items: _remoteModels.map((model) {
                final freeLabel = model.isFreeTrial == true
                    ? ' · توافر مجاني حسب المزوّد'
                    : '';
                return DropdownMenuItem(
                  value: model.id,
                  child: Text(
                    '${model.displayName}$freeLabel',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _remoteBusy ? null : _saveSelectedRemoteModel,
            ),
            const SizedBox(height: 8),
            Text(
              'المعرّف: $_selectedRemoteModel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _remoteBusy ? null : _testRemoteModel,
              icon: _remoteBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('اختبار النموذج فعلياً'),
            ),
          ],
          const SizedBox(height: 14),
          const _StatusNote(
            text: 'تُحفظ المفاتيح عبر تخزين آمن على الجهاز مع استخدام Android Keystore. تعطيل النسخ الاحتياطي يمنع نقل النص المشفّر إلى جهاز لا يملك مفتاح Keystore الأصلي.',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _busy || _remoteBusy ? null : _refreshModels,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة فحص النماذج المحلية'),
          ),
        ],
      ),
    );
  }

  Widget _modelCard(
    BuildContext context, {
    required String title,
    required String description,
    required String metadata,
    required bool installed,
    required Future<void> Function() onInstall,
    required Future<void> Function() onRemove,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(child: Icon(Icons.memory_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(label: Text(installed ? 'متحقق' : 'غير مثبت')),
            ]),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 6),
            Text(
              metadata,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : installed ? null : onInstall,
                icon: const Icon(Icons.download_outlined),
                label: Text(installed ? 'مثبت' : 'تنزيل والتحقق'),
              ),
              if (installed) ...[
                TextButton.icon(
                  onPressed: _busy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('إزالة'),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
