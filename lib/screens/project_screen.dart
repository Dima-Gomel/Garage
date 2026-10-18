import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// Экран одного проекта.
///
/// Показывает title / статус / описание / дату.
/// Слушает watchProject(id) — если проект удалят или
/// поменяют статус, экран перерисуется сам.
class ProjectScreen extends StatelessWidget {
  const ProjectScreen({
    super.key,
    required this.repository,
    required this.projectId,
  });

  final ProjectRepository repository;

  /// id в БД — int (в модели Project.id — String,
  /// конвертация происходит на вызывающей стороне).
  final int projectId;

  /// Цвет для бейджа статуса (та же логика, что в ProjectCard).
  Color _statusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.idea => AppTheme.statusIdea,
      ProjectStatus.inProgress => AppTheme.statusInProgress,
      ProjectStatus.frozen => AppTheme.statusFrozen,
      ProjectStatus.done => AppTheme.statusDone,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проект'),
      ),
      body: StreamBuilder<Project?>(
        stream: repository.watchProject(projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки проекта:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final project = snapshot.data;

          // null — проект удалён (или его никогда не было).
          if (project == null) {
            return const Center(
              child: Text(
                'Проект не найден',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return _buildContent(project);
        },
      ),
    );
  }

  Widget _buildContent(Project project) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(project.status).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              project.statusLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _statusColor(project.status),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (project.description.isNotEmpty) ...[
            const Text(
              'Описание',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              project.description,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Создан',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(project.createdAt),
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Обновлён',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(project.updatedAt),
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Простой формат даты без intl: "18.10.2026, 14:35".
  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}, '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}