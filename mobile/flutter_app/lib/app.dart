import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/cutawan_theme.dart';
import 'services/local_project_repository.dart';

class CutawanApp extends StatelessWidget {
  const CutawanApp({super.key, this.repository, this.storageUsageBytes});

  final LocalProjectRepository? repository;
  final Future<int> Function()? storageUsageBytes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cutawan',
      debugShowCheckedModeBanner: false,
      theme: CutawanTheme.light(),
      darkTheme: CutawanTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(
        repository: repository,
        storageUsageBytes: storageUsageBytes,
      ),
    );
  }
}
