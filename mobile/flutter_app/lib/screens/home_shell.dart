import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/caption_catalog.dart';
import '../domain/caption_animation.dart';
import '../domain/caption_layout.dart';
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
import 'device_acceptance_page.dart';
import 'features/dashboard_page.dart';
import 'features/settings_page.dart';
import 'features/clip_editor_page.dart';
import 'home_shell/navigation_components.dart';
import 'home_shell/models_page.dart';
import 'home_shell/create_page.dart';
import 'home_shell/shared_ui_primitives.dart';

part 'home_shell/jobs_page.dart';
part 'home_shell/review_page.dart';
part 'home_shell/caption_studio_page.dart';
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

  static const List<CutawanNavigationDestination> _destinations = [
    (label: 'الرئيسية', icon: Icons.space_dashboard_outlined, selected: Icons.space_dashboard_rounded, hint: 'Dashboard'),
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

  Future<void> _handleProjectSaved() async {
    await _reloadProjects();
    if (!mounted) return;
    _selectDestination(3);
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    _navigationGlow.forward(from: 0);
  }

  void _openDeviceDiagnostics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DeviceAcceptancePage(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        onDiagnostics: _openDeviceDiagnostics,
        onModels: _openModels,
      ),
    ));
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
        child: DashboardPage(
          projects: _projects,
          onCreate: () => _selectDestination(1),
          onOpenJobs: () => _selectDestination(2),
          onOpenReview: () => _selectDestination(3),
          onOpenModels: _openModels,
          onOpenSettings: _openSettings,
        ),
      ),
      TickerMode(
        enabled: _selectedIndex == 1,
        child: CreatePage(repository: _repository, onProjectSaved: _handleProjectSaved),
      ),
      TickerMode(
        enabled: _selectedIndex == 2,
        child: JobsPage(
          projects: _projects,
          repository: _repository,
          onProjectsChanged: _reloadProjects,
          onOpenReview: () => _selectDestination(3),
          onOpenCreate: () => _selectDestination(1),
          storageUsageBytes: widget.storageUsageBytes,
        ),
      ),
      TickerMode(
        enabled: _selectedIndex == 3,
        child: ReviewPage(projects: _projects, repository: _repository, onProjectsChanged: _reloadProjects),
      ),
      TickerMode(
        enabled: _selectedIndex == 4,
        child: CaptionStudioPage(projects: _projects, repository: _repository, onProjectsChanged: _reloadProjects),
      ),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        body: SafeArea(bottom: false, child: Column(children: [
          CutawanTopBar(onModels: _openModels, onRefresh: _reloadProjects, onDiagnostics: _openDeviceDiagnostics, onSettings: _openSettings),
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
        bottomNavigationBar: CutawanNavigationBar(selectedIndex: _selectedIndex, onSelected: _selectDestination, destinations: _destinations, animation: _navigationGlow),
      ),
    );
  }
}

