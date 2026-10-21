import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/project_repository.dart';
import 'data/journal_repository.dart';
import 'screens/projects_screen.dart';
import 'theme/app_theme.dart';

/// main теперь async, потому что инициализация БД — асинхронная.
/// ensureInitialized() нужен до любого обращения к платформе
/// (в нашем случае — до создания AppDatabase).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Создаём БД один раз на всё приложение.
  final database = AppDatabase();

  // Два репозитория поверх одной БД:
  //  - ProjectRepository — проекты
  //  - JournalRepository — записи журнала
  final projectRepository = ProjectRepository(database);
  final journalRepository = JournalRepository(database);

  runApp(GarageApp(
    projectRepository: projectRepository,
    journalRepository: journalRepository,
  ));
}

/// Корневой виджет приложения.
class GarageApp extends StatelessWidget {
  const GarageApp({
    super.key,
    required this.projectRepository,
    required this.journalRepository,
  });

  /// Репозиторий проектов.
  final ProjectRepository projectRepository;

  /// Репозиторий журнала.
  final JournalRepository journalRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ProjectsScreen(
        projectRepository: projectRepository,
        journalRepository: journalRepository,
      ),
    );
  }
}