import 'package:flutter/material.dart';
import 'screens/projects_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GarageApp());
}

/// Корневой виджет приложения.
class GarageApp extends StatelessWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage',
      // Убираем баннер "DEBUG" в правом верхнем углу.
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ProjectsScreen(),
    );
  }
}
