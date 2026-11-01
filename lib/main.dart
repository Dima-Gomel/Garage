import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/project_repository.dart';
import 'data/journal_repository.dart';
import 'data/material_repository.dart';
import 'screens/projects_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  // Три репозитория поверх одной БД.
  final projectRepository = ProjectRepository(database);
  final journalRepository = JournalRepository(database);
  final materialRepository = MaterialRepository(database);

  runApp(
    GarageApp(
      projectRepository: projectRepository,
      journalRepository: journalRepository,
      materialRepository: materialRepository,
    ),
  );
}

class GarageApp extends StatelessWidget {
  const GarageApp({
    super.key,
    required this.projectRepository,
    required this.journalRepository,
    required this.materialRepository,
  });

  final ProjectRepository projectRepository;
  final JournalRepository journalRepository;
  final MaterialRepository materialRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ProjectsScreen(
        projectRepository: projectRepository,
        journalRepository: journalRepository,
        materialRepository: materialRepository,
      ),
    );
  }
}