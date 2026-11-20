import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';
import '../domain/caption_catalog.dart';
import '../domain/caption_animation.dart';
import '../domain/clip_preferences.dart';
import '../domain/project_contract.dart';
import '../domain/transcript_contract.dart';
import '../domain/clip_candidate.dart';
import '../domain/reframe_contract.dart';
import '../services/android_video_picker.dart';
import '../services/direct_video_downloader.dart';
import '../services/local_project_repository.dart';
import '../services/whisper_transcription_service.dart';
import '../services/qwen_model_manager.dart';
import '../services/candidate_discovery_service.dart';
import '../services/local_editorial_annotation_service.dart';
import '../services/ai_model_gateway.dart';
import '../services/android_reframe_analysis_service.dart';
import '../services/processing_job_service.dart';
import '../services/processing_pipeline_service.dart';

part 'home_shell/create_page.dart';
part 'home_shell/jobs_page.dart';
part 'home_shell/review_page.dart';
part 'home_shell/caption_studio_page.dart';
part 'home_shell/models_page.dart';
part 'home_shell/shared_widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.repository, this.storageUsageBytes});
  final LocalProjectRepository? repository;
  final Future<int> Function()? storageUsageBytes;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  late final LocalProjectRepository _repository;
  final ValueNotifier<List<CutawanProject>> _projects = ValueNotifier<List<CutawanProject>>([]);
  late final AnimationController _navigationGlow;
  int _selectedIndex = 0;
  bool _didRecoverJobs = false;

  static const _destinations = [
    (label: 'إنشاء', icon: Icons.add_circle_outline_rounded, selected: Icons.add_circle_rounded, hint: 'Create'),
    (label: 'المهام', icon: Icons.grid_view_rounded, selected: Icons.grid_view_rounded, hint: 'Projects'),
    (label: 'المراجعة', icon: Icons.movie_filter_outlined, selected: Icons.movie_filter_rounded, hint: 'Review'),
    (label: 'الاستوديو', icon: Icons.closed_caption_outlined, selected: Icons.closed_caption_rounded, hint: 'Captions'),
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalProjectRepository();
    _navigationGlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 360), value: 1);
    _reloadProjects();
  }

  Future<void> _reloadProjects() async {
    try {
      if (!_didRecoverJobs) {
        _didRecoverJobs = true;
        await ProcessingJobService(repository: _repository).recoverInterruptedJobs();
      }
      final projects = await _repository.listProjects();
      if (mounted) _projects.value = projects;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر قراءة سجل المشاريع: $error')));
      }
    }
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    _navigationGlow.forward(from: 0);
  }

  void _openModels() {
    Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, secondaryAnimation) => const ModelsPage(),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
          child: child,
        ));
      },
    ));
  }

  @override
  void dispose() {
    _navigationGlow.dispose();
    _projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TickerMode(
        enabled: _selectedIndex == 0,
        child: CreatePage(repository: _repository, onProjectSaved: _reloadProjects),
      ),
      TickerMode(
        enabled: _selectedIndex == 1,
        child: JobsPage(
          projects: _projects,
          repository: _repository,
          onProjectsChanged: _reloadProjects,
          onOpenReview: () => _selectDestination(2),
          storageUsageBytes: widget.storageUsageBytes,
        ),
      ),
      TickerMode(
        enabled: _selectedIndex == 2,
        child: ReviewPage(projects: _projects, repository: _repository, onProjectsChanged: _reloadProjects),
      ),
      TickerMode(
        enabled: _selectedIndex == 3,
        child: CaptionStudioPage(projects: _projects, repository: _repository, onProjectsChanged: _reloadProjects),
      ),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        body: SafeArea(bottom: false, child: Column(children: [
          _CutawanTopBar(onModels: _openModels, onRefresh: _reloadProjects),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            reverseDuration: const Duration(milliseconds: 210),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(begin: Offset(_selectedIndex >= 2 ? -0.018 : 0.018, 0.012), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
            },
            child: KeyedSubtree(key: ValueKey<int>(_selectedIndex), child: pages[_selectedIndex]),
          )),
        ])),
        bottomNavigationBar: _CutawanNavigationBar(selectedIndex: _selectedIndex, onSelected: _selectDestination, destinations: _destinations, animation: _navigationGlow),
      ),
    );
  }
}

class _CutawanTopBar extends StatelessWidget {
  const _CutawanTopBar({required this.onModels, required this.onRefresh});
  final VoidCallback onModels;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 20, 10, compact ? 8 : 20, 10),
      child: Row(children: [
        Container(width: compact ? 34 : 40, height: compact ? 34 : 40, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))]), child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary, size: 21)),
        SizedBox(width: compact ? 8 : 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CUTAWAN', maxLines: 1, style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 0.4, fontWeight: FontWeight.w900, fontSize: compact ? 12 : 17)),
          if (!compact)
            Text('AI CREATOR STUDIO', maxLines: 1, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.7, fontSize: 8)),
        ])),
        if (!compact) ...[
          _TopBarAction(icon: Icons.refresh_rounded, tooltip: 'تحديث المشاريع', onTap: onRefresh),
          const SizedBox(width: 8),
        ],
        _TopBarAction(icon: Icons.memory_rounded, tooltip: 'مركز النماذج', onTap: onModels, accent: true),
      ]),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({required this.icon, required this.tooltip, required this.onTap, this.accent = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(message: tooltip, child: Material(
      color: accent ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: accent ? scheme.primary.withValues(alpha: 0.28) : scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 19, color: accent ? scheme.primary : scheme.onSurface)),
      ),
    ));
  }
}

class _CutawanNavigationBar extends StatelessWidget {
  const _CutawanNavigationBar({required this.selectedIndex, required this.onSelected, required this.destinations, required this.animation});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<({String label, IconData icon, IconData selected, String hint})> destinations;
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 4 : 14, 0, compact ? 4 : 14, bottom > 0 ? 8 : 13),
      padding: EdgeInsets.fromLTRB(compact ? 1 : 7, 6, compact ? 1 : 7, 6),
      decoration: BoxDecoration(color: scheme.surfaceContainer.withValues(alpha: 0.96), borderRadius: BorderRadius.circular(24), border: Border.all(color: scheme.outlineVariant), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 28, offset: const Offset(0, 10))]),
      child: ClipRect(child: Row(children: List.generate(destinations.length, (index) {
        final item = destinations[index];
        final selected = index == selectedIndex;
        return Expanded(child: Semantics(button: true, selected: selected, label: item.hint, child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: selected ? scheme.primary.withValues(alpha: 0.13) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(scale: selected ? 1.08 : 1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack, child: Icon(selected ? item.selected : item.icon, size: 22, color: selected ? scheme.primary : scheme.onSurfaceVariant)),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 180), style: TextStyle(fontSize: compact ? 9 : 10, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? scheme.primary : scheme.onSurfaceVariant), child: Text(item.label)),
            ]),
          ),
        )));
      }))),
    );
  }
}
