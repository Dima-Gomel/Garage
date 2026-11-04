import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'data/project_repository.dart';
import 'data/journal_repository.dart';
import 'data/material_repository.dart';
import 'data/link_repository.dart';
import 'screens/projects_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<ProjectRepository>(create: (_) => ProjectRepository(database)),
        Provider<JournalRepository>(create: (_) => JournalRepository(database)),
        Provider<MaterialRepository>(
          create: (_) => MaterialRepository(database),
        ),
        Provider<LinkRepository>(create: (_) => LinkRepository(database)),
      ],
      child: const GarageApp(),
    ),
  );
}

class GarageApp extends StatelessWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ProjectsScreen(),
    );
  }
}
