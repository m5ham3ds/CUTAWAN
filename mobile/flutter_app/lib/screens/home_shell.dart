import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/project_contract.dart';
import '../services/android_video_picker.dart';
import '../services/app_preferences_store.dart';
import '../services/direct_video_downloader.dart';
import '../services/local_project_repository.dart';
import '../services/processing_job_service.dart';
import 'device_acceptance_page.dart';
import 'features/dashboard_page.dart';
import 'features/settings_page.dart';
import 'home_shell/navigation_components.dart';
import '../l10n/app_strings.dart';
import 'home_shell/models_page.dart';
import 'home_shell/create_page.dart';
import 'home_shell/jobs_page.dart';
import 'home_shell/review_page.dart';
import 'features/caption_studio_page.dart';


class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.repository, this.storageUsageBytes, this.settingsStore});
  final LocalProjectRepository? repository;
  final Future<int> Function()? storageUsageBytes;
  final AppPreferencesStore? settingsStore;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  late final LocalProjectRepository _repository;
  late final AppPreferencesStore _settingsStore;
  late final bool _ownsSettingsStore;
  final ValueNotifier<List<CutawanProject>> _projects = ValueNotifier<List<CutawanProject>>([]);
  late final AnimationController _navigationGlow;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _didRecoverJobs = false;
  String? _requestedReviewProjectId;

  List<CutawanNavigationDestination> _navigationDestinations(BuildContext context) => [
        (label: cutawanText(context, 'الرئيسية'), icon: Icons.space_dashboard_outlined, selected: Icons.space_dashboard_rounded, hint: 'Dashboard'),
        (label: cutawanText(context, 'إنشاء'), icon: Icons.add_circle_outline_rounded, selected: Icons.add_circle_rounded, hint: 'Create'),
        (label: cutawanText(context, 'المهام'), icon: Icons.grid_view_rounded, selected: Icons.grid_view_rounded, hint: 'Projects'),
        (label: cutawanText(context, 'المراجعة'), icon: Icons.movie_filter_outlined, selected: Icons.movie_filter_rounded, hint: 'Review'),
        (label: cutawanText(context, 'الاستوديو'), icon: Icons.closed_caption_outlined, selected: Icons.closed_caption_rounded, hint: 'Captions'),
      ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalProjectRepository();
    _ownsSettingsStore = widget.settingsStore == null;
    _settingsStore = widget.settingsStore ?? AppPreferencesStore.inMemory();
    unawaited(_settingsStore.load());
    _navigationGlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 360), value: 1);
    _reloadProjects();
  }

  DirectVideoDownloader _downloader() => DirectVideoDownloader(
        availableStorageBytes: AndroidVideoPicker.availableStorageBytes,
        inspectLocalFile: AndroidVideoPicker.inspectLocalFile,
      );

  Future<int> _readStorageUsage() =>
      (widget.storageUsageBytes ?? _downloader().storageUsageBytes)();

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _animateNavigation() {
    if (!_reduceMotion) _navigationGlow.forward(from: 0);
  }

  void _openProjectInReview(CutawanProject project) {
    HapticFeedback.selectionClick();
    setState(() {
      _requestedReviewProjectId = project.id;
      _selectedIndex = 3;
    });
    _animateNavigation();
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
    _requestedReviewProjectId = null;
    await _reloadProjects();
    if (!mounted) return;
    _selectDestination(3);
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    _animateNavigation();
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
        store: _settingsStore,
        onDiagnostics: _openDeviceDiagnostics,
        onModels: _openModels,
      ),
    ));
  }

  void _openModels() {
    Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 360),
      reverseTransitionDuration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
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
    if (_ownsSettingsStore) _settingsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _navigationDestinations(context);
    final pages = <Widget>[
      TickerMode(
        enabled: _selectedIndex == 0,
        child: DashboardPage(
          projects: _projects,
          onCreate: () => _selectDestination(1),
          onOpenJobs: () => _selectDestination(2),
          onOpenReview: () => _selectDestination(3),
          onOpenSettings: _openSettings,
          onOpenProject: _openProjectInReview,
          storageUsageBytes: _readStorageUsage,
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
          storageUsageBytes: _readStorageUsage,
        ),
      ),
      TickerMode(
        enabled: _selectedIndex == 3,
        child: ReviewPage(
          projects: _projects,
          repository: _repository,
          onProjectsChanged: _reloadProjects,
          initialProjectId: _requestedReviewProjectId,
        ),
      ),
      TickerMode(
        enabled: _selectedIndex == 4,
        child: CaptionStudioPage(projects: _projects, repository: _repository, onProjectsChanged: _reloadProjects),
      ),
    ];
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: CutawanNavigationDrawer(
          selectedIndex: _selectedIndex,
          destinations: destinations,
          onSelect: _selectDestination,
          onSettings: _openSettings,
          onDiagnostics: _openDeviceDiagnostics,
          onModels: _openModels,
        ),
        body: SafeArea(bottom: false, child: Column(children: [
          CutawanTopBar(
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onRefresh: _reloadProjects,
            onSettings: _openSettings,
          ),
          Expanded(child: AnimatedSwitcher(
            duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
            reverseDuration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 210),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(begin: Offset(_selectedIndex >= 2 ? -0.018 : 0.018, 0.012), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
            },
            child: KeyedSubtree(key: ValueKey<int>(_selectedIndex), child: pages[_selectedIndex]),
          )),
        ])),
        bottomNavigationBar: CutawanNavigationBar(selectedIndex: _selectedIndex, onSelected: _selectDestination, destinations: destinations, animation: _navigationGlow),
      ),
    );
  }
}

