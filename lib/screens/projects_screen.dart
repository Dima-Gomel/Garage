import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/project_card.dart';

/// Главный экран — список проектов.
///
/// Данные приходят из ProjectRepository (stream из drift).
/// StatefulWidget оставляем — нужен context для модалки и SnackBar.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.repository});

  /// Репозиторий — источник данных. Передан из main.dart.
  final ProjectRepository repository;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  /// Открыть окно создания нового проекта.
  ///
  /// showModalBottomSheet возвращает `Future<String?>` — текст,
  /// который ввёл пользователь (или null, если закрыл).
  Future<void> _openNewProjectSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _NewProjectSheet(),
    );

    // Пользователь закрыл окно без ввода — выходим.
    if (result == null || result.trim().isEmpty) return;

    // Создаём проект в БД. Стрим watchAllProjects() сам
    // пришлёт обновление — перерисовывать через setState не нужно.
    await widget.repository.createProject(title: result.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Garage'),
      ),

      // === ТЕЛО ЭКРАНА ===
      // StreamBuilder — виджет, который слушает стрим и
      // перестраивается при каждом новом значении.
      body: StreamBuilder<List<Project>>(
        stream: widget.repository.watchAllProjects(),
        builder: (context, snapshot) {
          // Пока стрим не прислал первое значение — крутим спиннер.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Если drift прислал ошибку — покажем её текстом.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки проектов:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          // Данные пришли (может быть пустой список).
          final projects = snapshot.data ?? const <Project>[];

          if (projects.isEmpty) {
            return _buildEmptyState();
          }
          return _buildProjectsList(projects);
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewProjectSheet,
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Новый проект',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Что показываем, когда проектов нет.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока пусто',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Создай первый проект — и он появится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Список проектов. Принимает список из StreamBuilder.
  Widget _buildProjectsList(List<Project> projects) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return ProjectCard(
          project: project,
          onTap: () {
            // Пока заглушка — открытие экрана проекта сделаем дальше.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Открыть: ${project.title}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}

/// Всплывающее окно снизу для создания нового проекта.
/// Не изменилось — логика ввода та же, только теперь
/// текст уходит в repository.createProject().
class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Новый проект',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Например: Мини-трактор',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Создать',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
