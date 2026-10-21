import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../data/project_repository.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../screens/journal_screen.dart';

/// Экран одного проекта.
///
/// Показывает title / статус / описание / дату.
/// Слушает watchProject(id) — если проект удалят или
/// поменяют статус, экран перерисуется сам.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({
    super.key,
    required this.projectRepository,
    required this.journalRepository,
    required this.projectId,
  });

  final ProjectRepository projectRepository;
  final JournalRepository journalRepository;

  /// id в БД — int (в модели Project.id — String,
  /// конвертация происходит на вызывающей стороне).
  final int projectId;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  /// true, пока идёт удаление — блокируем кнопку и показываем спиннер.
  bool _isDeleting = false;

  // Мостики к полям родителя, чтобы не переписывать весь код ниже.
  ProjectRepository get projectRepository => widget.projectRepository;
  JournalRepository get journalRepository => widget.journalRepository;
  int get projectId => widget.projectId;

  /// Цвет для бейджа статуса (та же логика, что в ProjectCard).
  Color _statusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.idea => AppTheme.statusIdea,
      ProjectStatus.inProgress => AppTheme.statusInProgress,
      ProjectStatus.frozen => AppTheme.statusFrozen,
      ProjectStatus.done => AppTheme.statusDone,
    };
  }

  /// Открыть bottom sheet со списком статусов.
  /// Возвращает выбранный статус или null, если закрыли без выбора.
  Future<void> _openStatusSheet(BuildContext context, Project project) async {
    final selected = await showModalBottomSheet<ProjectStatus>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StatusSheet(current: project.status),
    );

    if (selected == null) return;
    if (selected == project.status) return; // тот же статус — ничего не делаем

    // Вызываем репозиторий. Стрим watchProject сам пришлёт обновление,
    // setState не нужен.
    await projectRepository.updateProjectStatus(
      int.parse(project.id),
      selected,
    );
  }

  /// Открыть экран журнала проекта.
  void _openJournal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JournalScreen(
          journalRepository: journalRepository,
          projectId: projectId,
        ),
      ),
    );
  }

  /// Диалог подтверждения удаления + само удаление.
  Future<void> _confirmDelete() async {
    // 1. Спрашиваем подтверждение.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Удалить проект?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Удалить',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // отмена — ничего не делаем

    // 2. Ставим флаг — блокируем повторное нажатие + спиннер.
    setState(() => _isDeleting = true);

    try {
      await projectRepository.deleteProject(projectId);

      // 3. ВАЖНО: после await проверяем, что экран ещё жив.
      // Пользователь мог нажать «назад», пока мы ждали БД.
      if (!mounted) return;

      // 4. Возвращаемся на главный экран.
      // Список там обновится сам (watchAllProjects).
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проект'),
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            color: AppTheme.statusFrozen,
            tooltip: 'Удалить проект',
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: StreamBuilder<Project?>(
        stream: projectRepository.watchProject(projectId),
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

          return Column(
            children: [
              // Контент — скроллится.
              Expanded(child: _buildContent(project)),

              // Кнопки внизу, под большим пальцем.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // «Журнал» — обводка, вторичная по иерархии,
                      // но крупная (частая операция).
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openJournal,
                          icon: const Icon(Icons.menu_book_outlined, size: 24),
                          label: const Text(
                            'Журнал',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(
                              color: AppTheme.accent,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // «Сменить статус» — заливка, главная кнопка.
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openStatusSheet(context, project),
                          icon: const Icon(Icons.swap_horiz, size: 24),
                          label: const Text(
                            'Сменить статус',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
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

/// Bottom sheet со списком статусов.
/// Возвращает выбранный статус через Navigator.pop(status).
class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.current});

  /// Текущий статус — подсветим его галочкой.
  final ProjectStatus current;

  Color _colorFor(ProjectStatus s) {
    return switch (s) {
      ProjectStatus.idea => AppTheme.statusIdea,
      ProjectStatus.inProgress => AppTheme.statusInProgress,
      ProjectStatus.frozen => AppTheme.statusFrozen,
      ProjectStatus.done => AppTheme.statusDone,
    };
  }

  String _labelFor(ProjectStatus s) {
    return switch (s) {
      ProjectStatus.idea => 'Идея',
      ProjectStatus.inProgress => 'В работе',
      ProjectStatus.frozen => 'Заморожен',
      ProjectStatus.done => 'Готово',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // «Ручка» сверху — визуальная подсказка, что это bottom sheet.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Сменить статус',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Список 4 статусов.
            for (final status in ProjectStatus.values)
              _StatusTile(
                status: status,
                label: _labelFor(status),
                color: _colorFor(status),
                isCurrent: status == current,
                onTap: () => Navigator.of(context).pop(status),
              ),
          ],
        ),
      ),
    );
  }
}

/// Одна строка в bottom sheet — «Идея», «В работе», и т.д.
class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.status,
    required this.label,
    required this.color,
    required this.isCurrent,
    required this.onTap,
  });

  final ProjectStatus status;
  final String label;
  final Color color;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Цветной кружок статуса.
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Название статуса — жирнее, если текущий.
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Галочка на текущем статусе.
            if (isCurrent)
              Icon(Icons.check, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}