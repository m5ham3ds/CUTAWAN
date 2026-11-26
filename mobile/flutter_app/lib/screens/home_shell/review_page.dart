import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/clip_candidate.dart';
import '../../domain/clip_preferences.dart';
import '../../domain/project_contract.dart';
import '../../domain/reframe_contract.dart';
import '../../domain/transcript_contract.dart';
import '../../services/ai_model_gateway.dart';
import '../../services/android_reframe_analysis_service.dart';
import '../../services/android_video_picker.dart';
import '../../services/candidate_discovery_service.dart';
import '../../services/local_editorial_annotation_service.dart';
import '../../services/local_project_repository.dart';
import '../../services/processing_pipeline_service.dart';
import '../../services/video_export_service.dart';
import '../../services/qwen_model_manager.dart';
import '../../services/whisper_transcription_service.dart';
import '../features/clip_editor_page.dart';
import '../features/clip_sequence_editor_page.dart';
import 'shared_ui_primitives.dart';
class ReviewPage extends StatefulWidget {
  const ReviewPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    this.initialProjectId,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;
  final String? initialProjectId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Map<String, CutawanTranscript?> _transcripts = {};
  final Map<String, CandidateSet?> _candidateSets = {};
  final Map<String, ReframePlan?> _reframePlans = {};
  final Set<String> _loadingArtifacts = {};
  final Map<String, List<Map<String, dynamic>>> _exportRecords = {};
  final VideoExportService _exportService = VideoExportService();
  final Set<String> _busyExportIds = <String>{};
  bool _pipelineRunning = false;
  String? _pipelineProjectId;
  String? _pipelineStage;
  double _pipelineProgress = 0;
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
      final exports = await widget.repository.loadExportRecords(projectId);
      if (!mounted) { return; }
      setState(() {
        _transcripts[projectId] = transcript;
        _candidateSets[projectId] = candidates;
        _reframePlans[projectId] = reframePlan;
        _exportRecords[projectId] = exports;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _lastError = 'تعذّر تحميل نتائج التحليل: $error');
      }
    } finally {
      _loadingArtifacts.remove(projectId);
    }
  }

  Future<void> _handleExportAction(
    BuildContext context,
    CutawanProject project,
    Map<String, dynamic> export, {
    required bool share,
  }) async {
    final clipId = export['clipId'] as String? ?? '';
    final outputUri = export['outputUri'] as String? ?? '';
    if (clipId.isEmpty || outputUri.isEmpty) return;
    final key = '${project.id}:$clipId';
    if (_busyExportIds.contains(key)) return;
    setState(() => _busyExportIds.add(key));
    try {
      final succeeded = share
          ? await _exportService.shareExport(outputUri)
          : await _exportService.openExport(outputUri);
      if (!succeeded) {
        throw StateError(share
            ? 'تعذّرت مشاركة ملف الفيديو.'
            : 'تعذّر فتح ملف الفيديو.');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(share
                ? 'تم فتح خيارات مشاركة الفيديو.'
                : 'تم إرسال الفيديو إلى مشغل الوسائط.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تنفيذ العملية: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyExportIds.remove(key));
    }
  }

  Future<void> _cleanupSupersededExports(
    BuildContext context,
    CutawanProject project,
    Map<String, dynamic> export,
  ) async {
    final clipId = export['clipId'] as String? ?? '';
    final rawPending = export['supersededOutputUris'];
    final pending = rawPending is List
        ? rawPending.whereType<String>().where((uri) => uri.trim().isNotEmpty).toList()
        : <String>[];
    if (clipId.isEmpty || pending.isEmpty) return;
    final key = '${project.id}:$clipId';
    if (_busyExportIds.contains(key)) return;
    setState(() => _busyExportIds.add(key));
    try {
      final remaining = <String>[];
      for (final uri in pending) {
        try {
          if (!await _exportService.deleteExport(uri)) remaining.add(uri);
        } catch (_) {
          remaining.add(uri);
        }
      }
      final updated = Map<String, Object?>.from(export);
      if (remaining.isEmpty) {
        updated.remove('supersededOutputUris');
      } else {
        updated['supersededOutputUris'] = remaining;
      }
      await widget.repository.saveExportRecord(project.id, updated);
      await _loadArtifacts(project.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining.isEmpty
                  ? 'تم تنظيف النسخ السابقة.'
                  : 'تعذّر تنظيف ${remaining.length} نسخة قديمة؛ بقيت محفوظة لإعادة المحاولة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تنظيف النسخ السابقة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyExportIds.remove(key));
    }
  }

  Future<void> _deleteExport(
    BuildContext context,
    CutawanProject project,
    Map<String, dynamic> export,
  ) async {
    final clipId = export['clipId'] as String? ?? '';
    final outputUri = export['outputUri'] as String? ?? '';
    if (clipId.isEmpty || outputUri.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الفيديو المصدّر؟'),
        content: const Text(
          'سيُحذف ملف MP4 من مساحة مخرجات CUTAWAN على الجهاز، كما سيُزال سجلّه من المشروع. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف الملف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final key = '${project.id}:$clipId';
    if (_busyExportIds.contains(key)) return;
    setState(() => _busyExportIds.add(key));
    try {
      final rawSuperseded = export['supersededOutputUris'];
      if (rawSuperseded is List) {
        for (final uri in rawSuperseded.whereType<String>()) {
          if (uri.trim().isNotEmpty && !await _exportService.deleteExport(uri)) {
            throw StateError('تعذّر تنظيف نسخة سابقة؛ لم يُحذف سجل التصدير.');
          }
        }
      }
      final deleted = await _exportService.deleteExport(outputUri);
      if (!deleted) {
        throw StateError('لم يتم حذف ملف الفيديو من Android.');
      }
      await widget.repository.deleteExportRecord(project.id, clipId);
      await _loadArtifacts(project.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفيديو وسجل التصدير.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر حذف الفيديو: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyExportIds.remove(key));
    }
  }

  Widget _buildExportCard(
    BuildContext context,
    CutawanProject project,
    Map<String, dynamic> export,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clipId = export['clipId'] as String? ?? '';
    final outputUri = export['outputUri'] as String? ?? '';
    final key = '${project.id}:$clipId';
    final busy = _busyExportIds.contains(key);
    final deliverable = clipId.isNotEmpty &&
        outputUri.isNotEmpty &&
        export['validated'] == true &&
        export['fullyDecodeValidated'] == true;
    return Card(
      key: ValueKey('export-card-$clipId'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  export['fullyDecodeValidated'] == true
                      ? Icons.verified_rounded
                      : Icons.video_file_outlined,
                  color: export['fullyDecodeValidated'] == true
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        export['displayName'] as String? ?? 'CUTAWAN export.mp4',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${export['width']} × ${export['height']} · '
                        '${formatCutawanDuration((export['durationMs'] as num? ?? 0).toInt())} · '
                        '${formatCutawanBytes((export['sizeBytes'] as num? ?? 0).toInt())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        export['fullyDecodeValidated'] == true
                            ? 'تم التحقق من فك MP4 حتى نهاية الملف'
                            : 'يحتاج الملف إلى إعادة التحقق من فك الترميز',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (deliverable) ...[
              const Divider(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('open-export-$clipId'),
                    onPressed: busy
                        ? null
                        : () => _handleExportAction(
                              context,
                              project,
                              export,
                              share: false,
                            ),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('فتح الفيديو'),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey('share-export-$clipId'),
                    onPressed: busy
                        ? null
                        : () => _handleExportAction(
                              context,
                              project,
                              export,
                              share: true,
                            ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('مشاركة'),
                  ),
                  IconButton(
                    key: ValueKey('delete-export-$clipId'),
                    tooltip: 'حذف الفيديو المصدّر',
                    onPressed:
                        busy ? null : () => _deleteExport(context, project, export),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  if ((export['supersededOutputUris'] as List?)?.isNotEmpty == true)
                    OutlinedButton.icon(
                      key: ValueKey('cleanup-export-$clipId'),
                      onPressed: busy
                          ? null
                          : () => _cleanupSupersededExports(context, project, export),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('تنظيف النسخ السابقة'),
                    ),
                ],
              ),
            ] else if ((export['supersededOutputUris'] as List?)?.isNotEmpty == true)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: ValueKey('cleanup-export-$clipId'),
                  onPressed: busy
                      ? null
                      : () => _cleanupSupersededExports(context, project, export),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('تنظيف النسخ السابقة'),
                ),
              ),
          ],
        ),
      ),
    );
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
        onStage: (stage, percent) {
          if (!_pipelineRunning) {
            return;
          }
          if (mounted) {
            setState(() => _pipelineStage = stage);
          }
          unawaited(
            widget.repository.saveJobState(
              project.id,
              status: ProjectJobStatus.running,
              stage: stage,
              progress: percent == null
                  ? 0.12
                  : (0.12 + 0.20 * percent / 100).clamp(0.12, 0.32).toDouble(),
            ).then<void>((_) {}, onError: (Object _) {}),
          );
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
      if (_pipelineRunning) {
        rethrow;
      }
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
      if (_pipelineRunning) {
        rethrow;
      }
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
      if (_pipelineRunning) {
        rethrow;
      }
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

  Future<void> _openClipEditor(
    BuildContext context,
    CutawanProject project,
    CandidateSet candidateSet,
    ClipCandidate candidate,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClipEditorPage(
          project: project,
          candidateSet: candidateSet,
          candidate: candidate,
          repository: widget.repository,
          onSaved: () async {
            await _loadArtifacts(project.id);
            await widget.onProjectsChanged();
          },
        ),
      ),
    );
  }

  Future<void> _openSequenceEditor(
    CutawanProject project,
    CandidateSet candidateSet,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClipSequenceEditorPage(
          project: project,
          candidateSet: candidateSet,
          repository: widget.repository,
          onSaved: () async {
            await _loadArtifacts(project.id);
            await widget.onProjectsChanged();
          },
        ),
      ),
    );
  }

  Future<void> _runFullPipeline(
    CutawanProject project, {
    String? onlyClipId,
  }) async {
    if (_pipelineRunning || _busyProjectId != null) {
      return;
    }
    setState(() {
      _pipelineRunning = true;
      _pipelineProjectId = project.id;
      _pipelineStage = 'queued';
      _pipelineProgress = 0;
      _lastError = null;
    });
    try {
      final result = await ProcessingPipelineService(
        repository: widget.repository,
      ).run(
        projectId: project.id,
        transcribe: _transcribe,
        discover: _discover,
        analyzeFraming: _analyzeFraming,
        onlyClipId: onlyClipId,
        onProgress: (stage, progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _pipelineStage = stage;
            _pipelineProgress = progress;
          });
        },
      );
      await _loadArtifacts(project.id);
      await widget.onProjectsChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              onlyClipId == null
                  ? 'اكتمل خط المعالجة: ${result.exportedCount} ملف MP4 جديد، '
                      '${result.skippedCount} نتيجة مستعادة، '
                      '${result.candidatesCount} مقطع مقترح.'
                  : 'اكتمل إخراج المقطع المحدد: ${result.exportedCount} ملف جديد؛ '
                      'تم الاحتفاظ بـ ${result.skippedCount} مخرجاً آخر بعد التحقق منه.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _lastError =
            'توقفت المعالجة عند ${_pipelineStage ?? 'مرحلة غير معروفة'}: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _pipelineRunning = false;
          _pipelineProjectId = null;
          _pipelineStage = null;
          _pipelineProgress = 0;
        });
        await widget.onProjectsChanged();
      }
    }
  }
  Future<void> _renderSingleClip(
    BuildContext context,
    CutawanProject project,
    ClipCandidate candidate,
  ) async {
    final hasExistingExport = (_exportRecords[project.id] ?? const [])
        .any((record) => record['clipId'] == candidate.id);
    if (hasExistingExport) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إعادة تصدير المقطع؟'),
          content: const Text(
            'سيُنشأ ملف جديد ويُتحقق من فك ترميزه بالكامل. ستبقى النسخة الحالية متاحة حتى ينجح البديل؛ وأي نسخة قديمة يتعذر حذفها ستبقى ظاهرة للتنظيف.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('إعادة التصدير'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _runFullPipeline(project, onlyClipId: candidate.id);
  }

  String _workflowStageLabel(CutawanProject project) {
    if (_busyProjectId == project.id && _busyStage != null && !_pipelineRunning) {
      return switch (_busyStage) {
        'whisper' => 'تفريغ الكلام',
        'candidates' => 'اكتشاف المقاطع',
        'reframe' => 'تحليل التأطير',
        'inspecting' => 'فحص مصدر الفيديو',
        _ => 'تنفيذ مرحلة يدوية',
      };
    }
    if (_pipelineRunning && _pipelineProjectId == project.id) {
      return switch (_pipelineStage) {
        'queued' => 'تجهيز المعالجة',
        'inspecting' => 'فحص مصدر الفيديو',
        'transcribing' => 'تفريغ الكلام',
        'discovering' => 'اكتشاف المقاطع',
        'reframing' => 'تحليل التأطير',
        'captioning' => 'إعداد الترجمة',
        'rendering' => 'تصدير المقاطع',
        'validating' => 'التحقق من الملفات',
        'complete' => 'اكتملت المعالجة',
        _ => 'المعالجة قيد التنفيذ',
      };
    }
    if (project.job.status == ProjectJobStatus.completed) {
      return 'اكتملت المعالجة';
    }
    if (project.job.status == ProjectJobStatus.failed) {
      return 'توقفت المعالجة';
    }
    if (project.job.status == ProjectJobStatus.cancelled) {
      return 'المعالجة ملغاة';
    }
    if (project.job.stage.startsWith('render')) {
      return 'تصدير المقاطع';
    }
    return switch (project.job.stage) {
      'source_imported' || 'prepared' => 'جاهز لبدء المعالجة',
      'inspecting' => 'فحص مصدر الفيديو',
      'transcribing' => 'تفريغ الكلام',
      'discovering' => 'اكتشاف المقاطع',
      'reframing' => 'تحليل التأطير',
      'captioning' => 'إعداد الترجمة',
      'rendering' => 'تصدير المقاطع',
      'validating' => 'التحقق من الملفات',
      _ => 'جاهز للمراجعة',
    };
  }

  Widget _workflowStep(
    BuildContext context, {
    required String title,
    required String detail,
    required IconData icon,
    required bool complete,
    required bool active,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = complete
        ? scheme.secondary
        : active
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return CutawanPanel(
      padding: const EdgeInsets.all(11),
      accent: active && !complete,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(complete ? Icons.check_rounded : icon, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context, CutawanProject project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transcript = _transcripts[project.id];
    final candidateSet = _candidateSets[project.id];
    final reframePlan = _reframePlans[project.id];
    final exports = _exportRecords[project.id] ?? const <Map<String, dynamic>>[];
    final pipelineActive = _pipelineRunning && _pipelineProjectId == project.id;
    final isBusy = _busyProjectId == project.id || pipelineActive;
    final canStart = !isBusy && !_pipelineRunning && _busyProjectId == null;
    final isLoading = _loadingArtifacts.contains(project.id);
    final compactStatusLabel = switch (project.job.status) {
      ProjectJobStatus.prepared => 'جاهز',
      ProjectJobStatus.running => 'قيد التنفيذ',
      ProjectJobStatus.completed => 'مكتمل',
      ProjectJobStatus.cancelled => 'ملغاة',
      ProjectJobStatus.failed => 'فشل',
    };
    final activeStage = pipelineActive ? (_pipelineStage ?? project.job.stage) : project.job.stage;
    final stepIndex = project.job.status == ProjectJobStatus.completed
        ? 3
        : activeStage.startsWith('render') || activeStage == 'validating'
            ? 3
            : activeStage == 'discovering' ||
                    activeStage == 'reframing' ||
                    activeStage == 'captioning'
                ? 2
                : activeStage == 'transcribing' || activeStage == 'inspecting'
                    ? 1
                    : 0;
    final progress = pipelineActive
        ? _pipelineProgress
        : _busyProjectId == project.id && _progress != null
            ? _progress
            : project.job.status == ProjectJobStatus.running
                ? project.job.progress
                : null;
    final transcriptDetail = transcript == null
        ? 'بانتظار التفريغ الصوتي'
        : transcript.wordTimingReliable
            ? '${transcript.words.length} كلمة بتوقيت موثوق'
            : 'النص محفوظ؛ التوقيت يحتاج مراجعة';
    final candidatesDetail = candidateSet == null
        ? 'لم يبدأ اكتشاف المقاطع'
        : candidateSet.candidates.isEmpty
            ? 'لا توجد نتائج مناسبة'
            : '${candidateSet.candidates.length} مقطع للمراجعة';
    final exportDetail = exports.isEmpty
        ? 'بانتظار تصدير الفيديو'
        : '${exports.length} ملف مصدّر';

    return Card(
      key: ValueKey<String>('review-project-${project.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(_workflowStageLabel(project),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CutawanStatusBadge(label: compactStatusLabel, status: project.job.status),
              ],
            ),
            const SizedBox(height: 12),
            CutawanPanel(
              accent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.video_file_outlined, color: scheme.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.source.displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              '${project.source.width} × ${project.source.height} · ${formatCutawanDuration(project.source.durationMs)} · ${formatCutawanBytes(project.source.sizeBytes)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('review-verify-${project.id}'),
                      onPressed: canStart ? () => _verifySource(context, project) : null,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('فحص توفر الفيديو'),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 4),
            ],
            const SizedBox(height: 16),
            const CutawanEyebrow('مسار المشروع', icon: Icons.route_outlined),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = 8.0;
                final columns = constraints.maxWidth < 540 ? 2 : 4;
                final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(width: width, child: _workflowStep(
                      context,
                      title: 'المصدر',
                      detail: 'الفيديو محفوظ',
                      icon: Icons.video_file_outlined,
                      complete: true,
                      active: stepIndex == 0,
                    )),
                    SizedBox(width: width, child: _workflowStep(
                      context,
                      title: 'التحليل',
                      detail: transcriptDetail,
                      icon: Icons.graphic_eq_rounded,
                      complete: transcript != null && reframePlan != null,
                      active: stepIndex == 1,
                    )),
                    SizedBox(width: width, child: _workflowStep(
                      context,
                      title: 'المقاطع',
                      detail: candidatesDetail,
                      icon: Icons.auto_awesome_rounded,
                      complete: candidateSet != null,
                      active: stepIndex == 2,
                    )),
                    SizedBox(width: width, child: _workflowStep(
                      context,
                      title: 'الإخراج',
                      detail: exportDetail,
                      icon: Icons.video_file_rounded,
                      complete: exports.isNotEmpty,
                      active: stepIndex == 3,
                    )),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            CutawanPanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_workflowStageLabel(project),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                      if (progress != null)
                        Text('${(progress * 100).round()}%',
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 7,
                      ),
                    ),
                  ] else if (isBusy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 5),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: ValueKey<String>('review-run-pipeline-${project.id}'),
                      onPressed: canStart ? () => _runFullPipeline(project) : null,
                      icon: Icon(pipelineActive ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded),
                      label: Text(
                        pipelineActive
                            ? 'المعالجة تعمل…'
                            : project.job.status == ProjectJobStatus.completed
                                ? 'التحقق من النتائج والاستكمال'
                                : project.job.status == ProjectJobStatus.failed ||
                                        project.job.status == ProjectJobStatus.cancelled
                                    ? 'استئناف المعالجة'
                                    : 'بدء المعالجة الكاملة',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: ExpansionTile(
                key: ValueKey<String>('review-manual-tools-${project.id}'),
                leading: const Icon(Icons.tune_rounded),
                title: const Text('أدوات المراحل اليدوية'),
                subtitle: const Text('إعادة تنفيذ خطوة محددة عند الحاجة'),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: canStart ? () => _transcribe(project) : null,
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: const Text('إعادة التفريغ'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: canStart ? () => _analyzeFraming(project) : null,
                        icon: const Icon(Icons.center_focus_strong_rounded),
                        label: const Text('إعادة تحليل التأطير'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: !canStart || transcript == null || !transcript.wordTimingReliable
                            ? null
                            : () => _discover(project),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('إعادة اكتشاف المقاطع'),
                      ),
                    ],
                  ),
                  if (transcript == null || !transcript.wordTimingReliable) ...[
                    const SizedBox(height: 8),
                    Text('اكتشاف المقاطع متاح بعد وجود تفريغ بتوقيت كلمات موثوق.',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 10),
              child: ExpansionTile(
                key: ValueKey<String>('review-transcript-${project.id}'),
                leading: const Icon(Icons.graphic_eq_rounded),
                title: Text(transcript == null ? 'التفريغ الصوتي' : 'التفريغ الصوتي · ${transcript.words.length} كلمة'),
                subtitle: Text(
                  transcript == null
                      ? 'لم يتم التفريغ بعد'
                      : transcript.wordTimingReliable
                          ? '${transcript.language} · توقيت الكلمات موثوق'
                          : '${transcript.language} · توقيت الكلمات غير موثوق',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (transcript == null)
                    const Text('سيظهر النص هنا بعد إتمام التفريغ الصوتي.')
                  else ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        transcript.text.isEmpty ? 'لم ينتج المحرك نصًا قابلًا للعرض.' : transcript.text,
                        textDirection: transcript.language.toLowerCase().startsWith('ar')
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transcript.wordTimingReliable
                          ? 'يمكن استخدام توقيت الكلمات في اكتشاف المقاطع.'
                          : 'حُفظ النص، لكن اكتشاف المقاطع معطّل لحماية دقة القصّ.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 10),
              child: ExpansionTile(
                key: ValueKey<String>('review-framing-${project.id}'),
                leading: const Icon(Icons.center_focus_strong_rounded),
                title: const Text('خطة التأطير'),
                subtitle: Text(
                  reframePlan == null
                      ? 'لم يتم تحليل الإطارات بعد'
                      : '${reframePlan.shots.length} فترة زمنية · ${reframePlan.aspectRatio.toStringAsFixed(3)}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (reframePlan == null)
                    const Text('سيظهر ملخص التأطير هنا بعد التحليل.')
                  else ...[
                    Text(
                      reframePlan.focusTrack == null
                          ? 'وضع آمن: إظهار المشهد كاملاً. ${reframePlan.fallbackReason ?? ''}'
                          : 'مسار وجه أمامي · ثقة ${(reframePlan.focusTrack!.averageConfidence * 100).round()}% · تغطية ${(reframePlan.focusTrack!.coverage * 100).round()}% · ${reframePlan.focusTrack!.keyframes.length} نقطة تركيز',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'التحليل البصري يتتبع موضع الوجه الأمامي فقط؛ لا يثبت هوية المتحدث النشط من الصوت والصورة.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const CutawanEyebrow('مراجعة المقاطع', icon: Icons.movie_filter_rounded),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('المقاطع المكتشفة',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                if (candidateSet != null)
                  Text('${candidateSet.candidates.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
                      )),
              ],
            ),
            if (candidateSet != null && candidateSet.candidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: ValueKey<String>('review-open-sequence-${project.id}'),
                  onPressed: canStart
                      ? () => _openSequenceEditor(project, candidateSet)
                      : null,
                  icon: const Icon(Icons.view_timeline_rounded),
                  label: const Text('تحرير تسلسل المقاطع والمسارات'),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (candidateSet == null)
              CutawanPanel(
                child: Text('ستظهر المقاطع هنا بعد اكتمال التفريغ واكتشاف اللحظات المناسبة.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              )
            else if (candidateSet.candidates.isEmpty)
              CutawanPanel(
                child: Text('لم يعثر التحليل على مقاطع مكتملة ضمن المدة المحددة. لم تتم إضافة مقاطع وهمية.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              )
            else ...[
              Text('المحرك: ${candidateSet.rankingEngine}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              for (final candidate in candidateSet.candidates)
                Card(
                  key: ValueKey<String>('review-candidate-${candidate.id}'),
                  margin: const EdgeInsets.only(top: 9),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                candidate.title.isEmpty ? 'مقطع مقترح' : candidate.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text('${candidate.score.toStringAsFixed(0)}/100',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${formatCutawanDuration(candidate.startMs)} – ${formatCutawanDuration(candidate.endMs)} · ${candidate.durationMs ~/ 1000} ثانية'
                          '${candidate.modelAnnotated ? ' · تعليق النموذج' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (candidate.explanations.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(candidate.explanations.take(3).join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              key: ValueKey<String>('edit-clip-${candidate.id}'),
                              onPressed: isBusy
                                  ? null
                                  : () => _openClipEditor(context, project, candidateSet, candidate),
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('فتح المحرر'),
                            ),
                            OutlinedButton.icon(
                              key: ValueKey<String>('render-clip-${candidate.id}'),
                              onPressed: canStart
                                  ? () => _renderSingleClip(context, project, candidate)
                                  : null,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                exports.any((item) => item['clipId'] == candidate.id)
                                    ? 'إعادة تصدير هذا المقطع'
                                    : 'تصدير هذا المقطع',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            const CutawanEyebrow('ملفات الإخراج', icon: Icons.video_file_rounded),
            const SizedBox(height: 8),
            Text('الفيديوهات المصدّرة',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            if (exports.isEmpty)
              CutawanPanel(
                child: Text('ستظهر هنا ملفات MP4 التي اجتازت فحص التحقق الكامل بعد التصدير.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              )
            else
              for (final export in exports)
                _buildExportCard(context, project, export),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: widget.projects,
      builder: (context, items, _) {
        final completed = items.where((item) => item.job.status == ProjectJobStatus.completed).length;
        final reviewable = _candidateSets.values.where((value) => value != null).length;
        final orderedItems = List<CutawanProject>.from(items);
        final selectedIndex = orderedItems.indexWhere(
          (project) => project.id == widget.initialProjectId,
        );
        if (selectedIndex > 0) {
          final selectedProject = orderedItems.removeAt(selectedIndex);
          orderedItems.insert(0, selectedProject);
        }
        CutawanProject? selectedProject;
        for (final project in items) {
          if (project.id == widget.initialProjectId) {
            selectedProject = project;
            break;
          }
        }
        return ListView(
          key: const ValueKey('review-workflow-list'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 132),
          children: [
            const CutawanEyebrow('مساحة العمل / المراجعة', icon: Icons.movie_filter_rounded),
            const SizedBox(height: 8),
            Text('راجع النتائج قبل إخراجها',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'تابع تقدم التحليل، افحص المقاطع المكتشفة، ثم افتح المحرر عند الحاجة.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (selectedProject != null) ...[
              const SizedBox(height: 12),
              CutawanStatusNote(
                text: 'المشروع المحدد من الرئيسية: «${selectedProject.title}». تظهر بطاقته أولاً لمتابعة مرحلته المحفوظة.',
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = 8.0;
                  final columns = constraints.maxWidth < 360 ? 2 : 3;
                  final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(width: width, child: CutawanMetricCard(label: 'المشاريع', value: '${items.length}', icon: Icons.video_library_outlined)),
                      SizedBox(width: width, child: CutawanMetricCard(label: 'للمراجعة', value: '$reviewable', icon: Icons.movie_filter_outlined)),
                      SizedBox(width: width, child: CutawanMetricCard(label: 'مكتملة', value: '$completed', icon: Icons.check_circle_outline_rounded)),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 18),
            if (items.isEmpty)
              const CutawanEmptyState(
                icon: Icons.video_collection_outlined,
                title: 'لا توجد مشاريع للمراجعة',
                description: 'أنشئ مشروعًا أولاً. ستظهر هنا مراحل التحليل والمقاطع والملفات الناتجة.',
              )
            else
              for (final project in orderedItems) _projectCard(context, project),
            if (_lastError != null) ...[
              const SizedBox(height: 8),
              CutawanStatusNote(text: _lastError!),
            ],
          ],
        );
      },
    );
  }
}