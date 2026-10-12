import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/project_repository.dart';
import 'screens/projects_screen.dart';
import 'theme/app_theme.dart';

/// main теперь async, потому что инициализация БД — асинхронная.
/// ensureInitialized() нужен до любого обращения к платформе
/// (в нашем случае — до создания AppDatabase).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Создаём БД и репозиторий один раз на всё приложение.
  // Пока без Provider/riverpod — просто держим ссылку в GarageApp.
  final database = AppDatabase();
  final repository = ProjectRepository(database);

  runApp(GarageApp(repository: repository));
}

/// Корневой виджет приложения.
class GarageApp extends StatelessWidget {
  const GarageApp({super.key, required this.repository});

  /// Репозиторий проектов. Прокидываем его вниз по дереву
  /// руками (вариант А). Когда репозиториев станет много —
  /// перейдём на Provider/riverpod.
  final ProjectRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: ProjectsScreen(repository: repository),
    );
  }
}
