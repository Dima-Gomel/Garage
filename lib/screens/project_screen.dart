import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../screens/journal_screen.dart';
import '../screens/materials_screen.dart';
import '../screens/links_screen.dart';

import 'package:provider/provider.dart';

/// Экран одного проекта.
///
/// Показывает title / статус / описание / дату.
/// Слушает watchProject(id) — если проект удалят или
/// поменяют статус, экран перерисуется сам.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, required this.projectId});

  final int projectId;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  /// true, пока идёт удаление — блокируем кнопку и показываем спиннер.
  bool _isDeleting = false;

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
    final repo = context.read<ProjectRepository>();

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

    await repo.updateProjectStatus(int.parse(project.id), selected);
  }

  /// Открыть bottom sheet «Переключиться на проект».
  ///
  /// Возвращает выбранный проект или null. Если выбрали ДРУГОЙ проект —
  /// делаем pushReplacement, чтобы стек не рос: Projects → Project(B).
  Future<void> _openProjectSwitcher() async {
    // Правило №41: репозиторий — ДО await, не после.
    final repo = context.read<ProjectRepository>();

    final selected = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ProjectSwitcherSheet(
        currentProjectId: projectId,
        projectsStream: repo.watchAllProjects(),
      ),
    );

    if (selected == null) return; // закрыли без выбора
    if (int.parse(selected.id) == projectId) return; // тот же проект

    if (!mounted) return;

    // pushReplacement, а не push — стек не растёт.
    // «Назад» с нового проекта ведёт на главный, а не в предыдущий.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ProjectScreen(projectId: int.parse(selected.id)),
      ),
    );
  }

  /// Открыть экран журнала проекта.
  void _openJournal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JournalScreen(projectId: projectId),
      ),
    );
  }

  void _openMaterials() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialsScreen(projectId: projectId),
      ),
    );
  }

  void _openLinks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinksScreen(projectId: projectId),
      ),
    );
  }

  /// Диалог подтверждения удаления + само удаление.
  Future<void> _confirmDelete() async {
    // 1. Спрашиваем подтверждение.
    final repo = context.read<ProjectRepository>();
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
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // отмена — ничего не делаем

    // 2. Ставим флаг — блокируем повторное нажатие + спиннер.
    setState(() => _isDeleting = true);

    try {
      await repo.deleteProject(projectId);

      // 3. ВАЖНО: после await проверяем, что экран ещё жив.
      if (!mounted) return;

      // 4. Возвращаемся на главный экран.
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
          // Переключение на другой проект — частая операция, левее корзины.
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            color: AppTheme.accent,
            tooltip: 'Переключиться на проект',
            onPressed: _openProjectSwitcher,
          ),
          // Удаление — опасное действие, правее, отдельно.
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
        stream: context.read<ProjectRepository>().watchProject(projectId),
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
              Expanded(child: _buildContent(project)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openJournal,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: const BorderSide(
                                    color: AppTheme.accent,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text(
                                  'Журнал',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openMaterials,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: const BorderSide(
                                    color: AppTheme.accent,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text(
                                  'Материал',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openLinks,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: const BorderSide(
                                    color: AppTheme.accent,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  minimumSize: const Size(0, 56),
                                ),
                                child: const Text(
                                  'Ссылки',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openStatusSheet(context, project),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Сменить статус',
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
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
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
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
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

/// Bottom sheet «Переключиться на проект».
///
/// Получает СТРИМ (а не снимок), поэтому список живой:
/// если проект создадут/переименуют — увидим.
class _ProjectSwitcherSheet extends StatelessWidget {
  const _ProjectSwitcherSheet({
    required this.currentProjectId,
    required this.projectsStream,
  });

  /// id текущего проекта — помечаем его галочкой и не даём выбрать.
  final int currentProjectId;

  /// Стрим всех проектов (watchAllProjects).
  final Stream<List<Project>> projectsStream;

  Color _colorFor(ProjectStatus s) {
    return switch (s) {
      ProjectStatus.idea => AppTheme.statusIdea,
      ProjectStatus.inProgress => AppTheme.statusInProgress,
      ProjectStatus.frozen => AppTheme.statusFrozen,
      ProjectStatus.done => AppTheme.statusDone,
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
                'Переключиться на проект',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Список проектов — живой, через StreamBuilder.
            StreamBuilder<List<Project>>(
              stream: projectsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ошибка: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                final projects = snapshot.data ?? const <Project>[];

                // Проектов нет вообще — маловероятно (мы уже в проекте),
                // но обработаем честно.
                if (projects.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Проектов нет',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                // Есть только текущий — подскажем, что переключаться некуда.
                if (projects.length == 1) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Других проектов нет',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                // Список проектов. Ограничим высоту, чтобы не улетел
                // на весь экран при большом количестве проектов.
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isCurrent =
                          int.parse(project.id) == currentProjectId;
                      return _ProjectTile(
                        project: project,
                        isCurrent: isCurrent,
                        statusColor: _colorFor(project.status),
                        onTap: isCurrent
                            ? null // уже здесь — тап игнорируем
                            : () => Navigator.of(context).pop(project),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Одна строка в sheet — проект.
class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.isCurrent,
    required this.statusColor,
    required this.onTap,
  });

  final Project project;
  final bool isCurrent;
  final Color statusColor;

  /// null — текущий проект, тап не нужен.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Цветной кружок статуса — как в _StatusTile.
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Название проекта — жирнее, если текущий.
            Expanded(
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Галочка на текущем.
            if (isCurrent) Icon(Icons.check, color: AppTheme.accent, size: 22),
          ],
        ),
      ),
    );
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
            if (isCurrent) Icon(Icons.check, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
