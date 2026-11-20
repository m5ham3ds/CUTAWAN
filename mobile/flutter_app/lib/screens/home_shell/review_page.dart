part of '../home_shell.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Map<String, CutawanTranscript?> _transcripts = {};
  final Map<String, CandidateSet?> _candidateSets = {};
  final Map<String, ReframePlan?> _reframePlans = {};
  final Set<String> _loadingArtifacts = {};
  String? _busyProjectId;
  String? _busyStage;
  String? _lastError;
  double? _progress;

  @override
  void initState() {
    super.initState();
    widget.projects.addListener(_handleProjectsChanged);
    _handleProjectsChanged();
  }

  @override
  void didUpdateWidget(covariant ReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects) {
      oldWidget.projects.removeListener(_handleProjectsChanged);
      widget.projects.addListener(_handleProjectsChanged);
      _handleProjectsChanged();
    }
  }

  @override
  void dispose() {
    widget.projects.removeListener(_handleProjectsChanged);
    super.dispose();
  }

  void _handleProjectsChanged() {
    for (final project in widget.projects.value) {
      _loadArtifacts(project.id);
    }
  }

  Future<void> _loadArtifacts(String projectId) async {
    if (_loadingArtifacts.contains(projectId)) { return; }
    _loadingArtifacts.add(projectId);
    try {
      final transcript = await widget.repository.loadTranscript(projectId);
      final candidates = await widget.repository.loadCandidates(projectId);
      final reframePlan = await widget.repository.loadReframePlan(projectId);
      if (!mounted) { return; }
      setState(() {
        _transcripts[projectId] = transcript;
        _candidateSets[projectId] = candidates;
        _reframePlans[projectId] = reframePlan;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _lastError = 'تعذّر تحميل نتائج التحليل: $error');
      }
    } finally {
      _loadingArtifacts.remove(projectId);
    }
  }

  Future<void> _verifySource(
    BuildContext context,
    CutawanProject project,
  ) async {
    try {
      final refreshed = await AndroidVideoPicker.inspectVideo(project.source.uri);
      final unchanged = project.source.hasSameMediaInfo(refreshed);
      await widget.repository.refreshSource(project.id, refreshed);
      await widget.onProjectsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unchanged
                  ? 'الملف ما زال متاحًا والبيانات تطابق السجل المحفوظ.'
                  : 'الملف متاح؛ تم تحديث بياناته المحفوظة بعد إعادة الفحص.',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'تعذّر الوصول إلى الملف المحفوظ.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل فحص مصدر الفيديو: $error')),
        );
      }
    }
  }

  Future<void> _transcribe(CutawanProject project) async {
    if (_busyProjectId != null) { return; }
    setState(() {
      _busyProjectId = project.id;
      _busyStage = 'whisper';
      _lastError = null;
      _progress = 0;
    });
    try {
      final transcript = await WhisperTranscriptionService().transcribeVideo(
        sourceUri: project.source.uri,
        sourceDurationMs: project.source.durationMs,
        onProgress: (percent) {
          if (!mounted || _busyProjectId != project.id) { return; }
          setState(() => _progress = percent / 100);
        },
      );
      await widget.repository.saveTranscript(project.id, transcript);
      await _loadArtifacts(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transcript.wordTimingReliable
                  ? 'اكتمل التفريغ المحلي وحُفظ توقيت الكلمات.'
                  : 'حُفظ النص، لكن توقيت الكلمات غير كافٍ لاكتشاف المقاطع.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) { setState(() => _lastError = 'فشل التفريغ المحلي: $error'); }
    } finally {
      if (mounted) {
        setState(() {
          _busyProjectId = null;
          _busyStage = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _discover(CutawanProject project) async {
    if (_busyProjectId != null) { return; }
    setState(() {
      _busyProjectId = project.id;
      _busyStage = 'candidates';
      _lastError = null;
      _progress = null;
    });
    var localModelUsed = false;
    try {
      final transcript = _transcripts[project.id] ??
          await widget.repository.loadTranscript(project.id);
      if (transcript == null) {
        throw StateError('نفّذ التفريغ المحلي أولاً.');
      }
      final discovery = const CandidateDiscoveryService();
      var candidateSet = discovery.discover(transcript, project.preferences);
      var modelUsedLabel = '';
      try {
        final credentials = AiCredentialStore();
        final mode = await credentials.readExecutionMode();
        if (mode == 'remote') {
          if (!await credentials.hasCloudConsent()) {
            throw StateError('تم إلغاء موافقة الإرسال السحابي؛ ستظل المقاطع محلية.');
          }
          final provider = await credentials.readActiveProvider();
          final modelId = await credentials.readSelectedModel(provider);
          if (modelId == null || modelId.isEmpty) {
            throw StateError('اختر نموذجاً سحابياً من مركز النماذج أولاً.');
          }
          final modelGateway = AiModelGateway(credentials: credentials);
          try {
            final prompt = LocalEditorialAnnotationService.buildAnnotationPrompt(
              candidateSet,
            );
            final raw = await modelGateway.complete(
              provider,
              modelId: modelId,
              prompt: prompt,
              maxTokens: 1100,
            );
            candidateSet =
                LocalEditorialAnnotationService.applyJsonAnnotations(
              candidateSet,
              raw,
            );
            modelUsedLabel = candidateSet.candidates.any((item) => item.modelAnnotated)
                ? 'النموذج السحابي: $modelId'
                : 'اكتمل الطلب لكن لم تُقبل تعليقات JSON؛ تم الاحتفاظ بالترتيب الحتمي.';
          } finally {
            modelGateway.close();
          }
        } else {
          final modelFile = await QwenModelManager().findInstalled();
          if (modelFile != null) {
            candidateSet = await const LocalEditorialAnnotationService().annotate(
              candidateSet,
              modelPath: modelFile.path,
            );
            localModelUsed =
                candidateSet.candidates.any((item) => item.modelAnnotated);
            if (localModelUsed) {
              modelUsedLabel = 'Qwen المحلي';
            }
          }
        }
      } catch (error) {
        if (mounted) {
          setState(() => _lastError =
              'تم إنشاء المقاطع بالترتيب الحتمي، لكن تعذّر تشغيل النموذج المختار: $error');
        }
      }
      await widget.repository.saveCandidates(project.id, candidateSet);
      await _loadArtifacts(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              candidateSet.candidates.isEmpty
                  ? 'لم يعثر التحليل على مقاطع مكتملة ضمن المدة المحددة؛ لم تتم إضافة مقاطع وهمية.'
                  : localModelUsed
                      ? 'تم حفظ ${candidateSet.candidates.length} اقتراحًا مع تعليقات $modelUsedLabel.'
                      : 'تم حفظ ${candidateSet.candidates.length} اقتراحًا من أدلة التفريغ والصوت والصورة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) { setState(() => _lastError = 'فشل اكتشاف المقاطع: $error'); }
    } finally {
      if (mounted) {
        setState(() {
          _busyProjectId = null;
          _busyStage = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _analyzeFraming(CutawanProject project) async {
    if (_busyProjectId != null) { return; }
    setState(() {
      _busyProjectId = project.id;
      _busyStage = 'reframe';
      _lastError = null;
      _progress = null;
    });
    try {
      final source = project.source;
      final rotated = source.rotationDegrees.abs() % 180 != 0;
      final sourceWidth = rotated ? source.height : source.width;
      final sourceHeight = rotated ? source.width : source.height;
      final targetAspectRatio = switch (project.preferences.aspectRatio) {
        ClipAspectRatio.portrait916 => 9 / 16,
        ClipAspectRatio.square11 => 1.0,
        ClipAspectRatio.landscape169 => 16 / 9,
        ClipAspectRatio.original => sourceWidth / sourceHeight,
      };
      final plan = await const AndroidReframeAnalysisService().analyze(
        sourceUri: source.uri,
        sourceDurationMs: source.durationMs,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        targetAspectRatio: targetAspectRatio,
      );
      await widget.repository.saveReframePlan(project.id, plan);
      if (!mounted) { return; }
      setState(() => _reframePlans[project.id] = plan);
      final message = plan.focusTrack == null
          ? 'لم تتوفر ثقة كافية لتحديد وجه مستمر؛ حُفظت خطة إظهار المشهد كاملاً.'
          : 'تم تحليل الوجه في ${plan.focusTrack!.keyframes.length} عينة وحُفظت خطة التأطير. هذا ليس تصنيفاً صوتياً مؤكداً للمتحدث النشط.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _lastError = 'فشل تحليل التأطير: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyProjectId = null;
          _busyStage = null;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: widget.projects,
      builder: (context, items, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const _Eyebrow('مساحة العمل  /  التحليل والمراجعة'),
          const SizedBox(height: 14),
          Text(
            'مراجعة المشاريع',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'التفريغ واكتشاف المقاطع يعملان محليًا بعد تثبيت النماذج. درجات الاقتراحات مؤشرات تحريرية وليست ضمانًا للانتشار.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 12),
            _StatusNote(text: _lastError!),
          ],
          const SizedBox(height: 24),
          if (items.isEmpty)
            const _EmptyState(
              icon: Icons.video_collection_outlined,
              title: 'لا توجد مقاطع للمراجعة',
              description: 'استورد فيديو من شاشة الإدخال ليظهر هنا.',
            )
          else
            for (final project in items) _projectCard(context, project),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context, CutawanProject project) {
    final theme = Theme.of(context);
    final transcript = _transcripts[project.id];
    final candidateSet = _candidateSets[project.id];
    final reframePlan = _reframePlans[project.id];
    final isBusy = _busyProjectId == project.id;
    final isLoading = _loadingArtifacts.contains(project.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(project.source.displayName),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${project.source.width} × ${project.source.height}')),
                Chip(label: Text(_formatDuration(project.source.durationMs))),
                Chip(label: Text(_formatBytes(project.source.sizeBytes))),
              ],
            ),
            Text(
              'المصدر: ${project.source.mimeType}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => _verifySource(context, project),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('إعادة فحص الوصول والبيانات'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : () => _transcribe(project),
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('تفريغ الكلام'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : () => _analyzeFraming(project),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('تحليل الوجه والتأطير'),
                ),
                FilledButton.icon(
                  onPressed: isBusy || transcript == null ||
                          !transcript.wordTimingReliable
                      ? null
                      : () => _discover(project),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('اقتراح المقاطع'),
                ),
              ],
            ),
            if (isBusy) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _busyStage == 'whisper'
                    ? 'Whisper يعمل على الجهاز…'
                    : _busyStage == 'reframe'
                        ? 'تحليل عينات الوجه وبناء خطة تأطير محلية…'
                        : 'تحليل الحدود وترتيب المقاطع محليًا…',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (transcript != null) ...[
              const Divider(height: 24),
              Text(
                'التفريغ • ${transcript.language} • ${transcript.words.length} كلمة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                transcript.wordTimingReliable
                    ? 'توقيت الكلمات متاح ويمكن استخدامه لضبط حدود المقاطع.'
                    : 'النص محفوظ، لكن توقيت الكلمات غير موثوق؛ اكتشاف المقاطع معطّل لتجنب قصّ عشوائي.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (transcript.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  transcript.text.length > 420
                      ? '${transcript.text.substring(0, 420)}…'
                      : transcript.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            if (reframePlan != null) ...[
              const Divider(height: 24),
              Text(
                'التأطير • ${reframePlan.shots.length} مقطع زمني • ${reframePlan.aspectRatio.toStringAsFixed(3)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                reframePlan.focusTrack == null
                    ? 'وضع آمن: إظهار المشهد كاملاً. ${reframePlan.fallbackReason ?? ''}'
                    : 'تتبّع وجه أمامي • ثقة ${(reframePlan.focusTrack!.averageConfidence * 100).round()}% • تغطية ${(reframePlan.focusTrack!.coverage * 100).round()}% • ${reframePlan.focusTrack!.keyframes.length} نقطة تركيز',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              const Text(
                'النسخة الحالية تتبع الوجه الأمامي فقط؛ لا تعتبر ذلك حكماً مؤكداً على المتحدث من الصوت والصورة.',
                style: TextStyle(fontSize: 11),
              ),
            ],
            if (candidateSet != null) ...[
              const Divider(height: 24),
              Text(
                'الاقتراحات • ${candidateSet.candidates.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'المحرك: ${candidateSet.rankingEngine} · لا توجد مقاطع مضافة لتلبية العدد المطلوب إذا لم توجد أدلة كافية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final candidate in candidateSet.candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(candidate.title.isEmpty ? 'مقطع مقترح' : candidate.title),
                  subtitle: Text(
                    '${_formatDuration(candidate.startMs)}–${_formatDuration(candidate.endMs)} · ${candidate.durationMs ~/ 1000}s · ${candidate.score.toStringAsFixed(0)}/100'
                    '${candidate.modelAnnotated ? ' · وصف محلي' : ''}'
                    '\n${candidate.explanations.take(2).join(' · ')}',
                  ),
                  isThreeLine: true,
                  leading: const Icon(Icons.movie_creation_outlined),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
