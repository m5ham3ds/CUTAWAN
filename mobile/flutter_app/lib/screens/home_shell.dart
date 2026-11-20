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

class _HomeShellState extends State<HomeShell> {
  late final LocalProjectRepository _repository;
  final ValueNotifier<List<CutawanProject>> _projects =
      ValueNotifier<List<CutawanProject>>([]);
  int _selectedIndex = 0;
  bool _didRecoverJobs = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalProjectRepository();
    _reloadProjects();
  }

  Future<void> _reloadProjects() async {
    try {
      if (!_didRecoverJobs) {
        _didRecoverJobs = true;
        await ProcessingJobService(repository: _repository).recoverInterruptedJobs();
      }
      final projects = await _repository.listProjects();
      if (mounted) { _projects.value = projects; }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر قراءة سجل المشاريع: $error')),
        );
      }
    }
  }

  void _openModels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelsPage()),
    );
  }

  @override
  void dispose() {
    _projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CreatePage(repository: _repository, onProjectSaved: _reloadProjects),
      JobsPage(
        projects: _projects,
        repository: _repository,
        onProjectsChanged: _reloadProjects,
        storageUsageBytes: widget.storageUsageBytes,
      ),
      ReviewPage(
        projects: _projects,
        repository: _repository,
        onProjectsChanged: _reloadProjects,
      ),
      TickerMode(
        enabled: _selectedIndex == 3,
        child: CaptionStudioPage(
          projects: _projects,
          repository: _repository,
          onProjectsChanged: _reloadProjects,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CUTAWAN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('MOBILE CLIPPING STUDIO', style: TextStyle(fontSize: 9, letterSpacing: 1.6)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'مركز النماذج',
            onPressed: _openModels,
            icon: const Icon(Icons.memory_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_link_outlined), selectedIcon: Icon(Icons.add_link), label: 'إدخال'),
          NavigationDestination(icon: Icon(Icons.pending_actions_outlined), selectedIcon: Icon(Icons.pending_actions), label: 'المهام'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'المراجعة'),
          NavigationDestination(icon: Icon(Icons.subtitles_outlined), selectedIcon: Icon(Icons.subtitles), label: 'الاستوديو'),
        ],
      ),
    );
  }
}

