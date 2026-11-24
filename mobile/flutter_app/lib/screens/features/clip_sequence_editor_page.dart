import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/clip_candidate.dart';
import '../../domain/clip_sequence.dart';
import '../../domain/project_contract.dart';
import '../../services/local_project_repository.dart';

class ClipSequenceEditorPage extends StatefulWidget {
  const ClipSequenceEditorPage({
    required this.project,
    required this.candidateSet,
    required this.repository,
    required this.onSaved,
    super.key,
  });

  final CutawanProject project;
  final CandidateSet candidateSet;
  final LocalProjectRepository repository;
  final Future<void> Function() onSaved;

  @override
  State<ClipSequenceEditorPage> createState() => _ClipSequenceEditorPageState();
}

class _ClipSequenceEditorPageState extends State<ClipSequenceEditorPage> {
  ClipSequence? _sequence;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSequence());
  }

  Future<void> _loadSequence() async {
    try {
      widget.candidateSet.validate();
      final saved = await widget.repository.loadClipSequence(widget.project.id);
      final sequence = saved ??
          ClipSequence.empty(sourceDurationMs: widget.project.source.durationMs);
      sequence.validate(
        candidateSet: widget.candidateSet,
        expectedSourceDurationMs: widget.project.source.durationMs,
      );
      if (!mounted) return;
      setState(() {
        _sequence = sequence;
        _loading = false;
        _error = null;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل التسلسل المحفوظ: $error';
      });
    }
  }

  String _trackLabel(ClipSequenceTrackType type) => switch (type) {
        ClipSequenceTrackType.video => 'مسار فيديو',
        ClipSequenceTrackType.audio => 'مسار صوتي',
        ClipSequenceTrackType.overlay => 'مسار طبقات',
      };

  IconData _trackIcon(ClipSequenceTrackType type) => switch (type) {
        ClipSequenceTrackType.video => Icons.movie_rounded,
        ClipSequenceTrackType.audio => Icons.graphic_eq_rounded,
        ClipSequenceTrackType.overlay => Icons.layers_rounded,
      };

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  void _replaceSequence(ClipSequence next) {
    next.validate(
      candidateSet: widget.candidateSet,
      expectedSourceDurationMs: widget.project.source.durationMs,
    );
    setState(() {
      _sequence = next;
      _dirty = true;
      _error = null;
    });
  }

  void _addTrack(ClipSequenceTrackType type) {
    final sequence = _sequence;
    if (sequence == null || _saving) return;
    if (sequence.tracks.length >= ClipSequence.maxTracks) {
      _showMessage('وصلت إلى الحد الأقصى لعدد المسارات.', isError: true);
      return;
    }
    var suffix = 1;
    String trackId() => 'track_${type.name}_$suffix';
    while (sequence.tracks.any((track) => track.id == trackId())) {
      suffix++;
    }
    final next = ClipSequence(
      schemaVersion: sequence.schemaVersion,
      sourceDurationMs: sequence.sourceDurationMs,
      tracks: [
        ...sequence.tracks,
        ClipSequenceTrack(
          id: trackId(),
          type: type,
          name: '${_trackLabel(type)} $suffix',
          order: sequence.tracks.length,
        ),
      ],
      clips: sequence.clips,
    );
    _replaceSequence(next);
  }

  Future<ClipCandidate?> _chooseCandidate() async {
    return showDialog<ClipCandidate>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('اختر مقطعاً من النتائج المحفوظة'),
        children: [
          for (final candidate in widget.candidateSet.candidates)
            SimpleDialogOption(
              key: ValueKey<String>('sequence-candidate-choice-${candidate.id}'),
              onPressed: () => Navigator.of(dialogContext).pop(candidate),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title.isEmpty ? 'مقطع مقترح' : candidate.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatTime(candidate.startMs)} – ${_formatTime(candidate.endMs)} · ${candidate.durationMs ~/ 1000} ثانية',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addClip(String trackId) async {
    final sequence = _sequence;
    if (sequence == null || _saving) return;
    final track = sequence.tracks.where((value) => value.id == trackId);
    if (track.isEmpty) return;
    final candidate = await _chooseCandidate();
    if (candidate == null || !mounted) return;
    final trackItems = sequence.clips.where((clip) => clip.trackId == trackId);
    final startMs = track.first.type == ClipSequenceTrackType.overlay
        ? 0
        : trackItems.fold<int>(
            0,
            (end, clip) => clip.timelineEndMs > end ? clip.timelineEndMs : end,
          );
    var suffix = 1;
    String itemId() => 'item_$suffix';
    while (sequence.clips.any((clip) => clip.id == itemId())) {
      suffix++;
    }
    final next = ClipSequence(
      schemaVersion: sequence.schemaVersion,
      sourceDurationMs: sequence.sourceDurationMs,
      tracks: sequence.tracks,
      clips: [
        ...sequence.clips,
        ClipSequenceItem(
          id: itemId(),
          candidateId: candidate.id,
          trackId: trackId,
          sourceStartMs: candidate.startMs,
          sourceEndMs: candidate.endMs,
          timelineStartMs: startMs,
        ),
      ],
    );
    try {
      _replaceSequence(next);
    } on FormatException catch (error) {
      _showMessage('تعذّر إضافة المقطع: $error', isError: true);
    }
  }

  void _moveClip(ClipSequenceItem item, int deltaMs) {
    final sequence = _sequence;
    if (sequence == null || _saving) return;
    final nextStart = item.timelineStartMs + deltaMs;
    if (nextStart < 0) {
      _showMessage('لا يمكن وضع المقطع قبل بداية التسلسل.', isError: true);
      return;
    }
    final next = ClipSequence(
      schemaVersion: sequence.schemaVersion,
      sourceDurationMs: sequence.sourceDurationMs,
      tracks: sequence.tracks,
      clips: sequence.clips
          .map((clip) => clip.id == item.id
              ? ClipSequenceItem(
                  id: clip.id,
                  candidateId: clip.candidateId,
                  trackId: clip.trackId,
                  sourceStartMs: clip.sourceStartMs,
                  sourceEndMs: clip.sourceEndMs,
                  timelineStartMs: nextStart,
                )
              : clip)
          .toList(growable: false),
    );
    try {
      _replaceSequence(next);
    } on FormatException {
      _showMessage(
        'لا يمكن تحريك المقطع فوق مقطع آخر في المسار نفسه. أضف مساراً منفصلاً للتداخل.',
        isError: true,
      );
    }
  }

  void _removeClip(String clipId) {
    final sequence = _sequence;
    if (sequence == null || _saving) return;
    _replaceSequence(
      ClipSequence(
        schemaVersion: sequence.schemaVersion,
        sourceDurationMs: sequence.sourceDurationMs,
        tracks: sequence.tracks,
        clips: sequence.clips.where((clip) => clip.id != clipId).toList(),
      ),
    );
  }

  Future<void> _saveSequence() async {
    final sequence = _sequence;
    if (sequence == null || _saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveClipSequence(widget.project.id, sequence);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _showMessage('تم حفظ ترتيب المسارات والمقاطع.');
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('تعذّر حفظ التسلسل: $error', isError: true);
    }
  }

  Widget _buildTrackCard(ClipSequenceTrack track) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sequence = _sequence!;
    final trackClips = sequence.clips
        .where((clip) => clip.trackId == track.id)
        .toList()
      ..sort((a, b) => a.timelineStartMs.compareTo(b.timelineStartMs));
    return Card(
      key: ValueKey<String>('sequence-track-${track.id}'),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(_trackIcon(track.type), color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text(
                        '${trackClips.length} مقطع · المسار رقم ${track.order + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('sequence-add-clip-${track.id}'),
                  tooltip: 'إضافة مقطع إلى ${track.name}',
                  onPressed: _saving ? null : () => _addClip(track.id),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const Divider(height: 18),
            if (trackClips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'لا توجد مقاطع في هذا المسار بعد.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final item in trackClips) _buildSequenceItem(item),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceItem(ClipSequenceItem item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final candidate = widget.candidateSet.candidates.firstWhere(
      (value) => value.id == item.candidateId,
    );
    return Container(
      key: ValueKey<String>('sequence-item-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.title.isEmpty ? 'مقطع مقترح' : candidate.title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'المصدر ${_formatTime(item.sourceStartMs)}–${_formatTime(item.sourceEndMs)}  ·  التسلسل ${_formatTime(item.timelineStartMs)}–${_formatTime(item.timelineEndMs)}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            'المدة ${item.durationMs ~/ 1000} ثانية',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey<String>('sequence-move-left-${item.id}'),
                tooltip: 'تقديم 0.5 ثانية',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _moveClip(item, -500),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                key: ValueKey<String>('sequence-move-right-${item.id}'),
                tooltip: 'تأخير 0.5 ثانية',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _moveClip(item, 500),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                key: ValueKey<String>('sequence-remove-${item.id}'),
                tooltip: 'إزالة المقطع من التسلسل',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _removeClip(item.id),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sequence = _sequence;
    final orderedTracks = sequence == null
        ? const <ClipSequenceTrack>[]
        : (sequence.tracks.toList()
          ..sort((a, b) => a.order.compareTo(b.order)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسلسل المقاطع والمسارات'),
        actions: [
          IconButton(
            key: const ValueKey('sequence-save-button'),
            tooltip: 'حفظ التسلسل',
            onPressed: _loading || _saving || !_dirty ? null : _saveSequence,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 36),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadSequence,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      widget.project.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'رتّب المقاطع على مسارات مستقلة. تُحفظ التعديلات مع المشروع، ويظل التصدير المركب غير متاح حتى اكتمال محرك التسلسل.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'هذه مساحة ترتيب وحفظ فقط. لا يوجد تشغيل معاينة مركّبة أو دمج نهائي للصوت والصورة في هذه المرحلة.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'إضافة مسار',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('sequence-add-track-video'),
                          onPressed: _saving ? null : () => _addTrack(ClipSequenceTrackType.video),
                          icon: const Icon(Icons.movie_outlined),
                          label: const Text('فيديو'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('sequence-add-track-audio'),
                          onPressed: _saving ? null : () => _addTrack(ClipSequenceTrackType.audio),
                          icon: const Icon(Icons.graphic_eq_rounded),
                          label: const Text('صوت'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('sequence-add-track-overlay'),
                          onPressed: _saving ? null : () => _addTrack(ClipSequenceTrackType.overlay),
                          icon: const Icon(Icons.layers_outlined),
                          label: const Text('طبقة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'المسارات ${sequence!.tracks.length}/${ClipSequence.maxTracks}',
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${sequence.clips.length} مقطع',
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                    for (final track in orderedTracks) _buildTrackCard(track),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('sequence-save-bottom-button'),
                      onPressed: _saving || !_dirty ? null : _saveSequence,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التسلسل'),
                    ),
                  ],
                ),
    );
  }
}
