import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';

/// Виджет карточки одного проекта.
/// 
/// StatelessWidget — виджет без собственного состояния.
/// Он просто рисует то, что ему передали. Ничего не помнит, ничего не меняет.
class ProjectCard extends StatelessWidget {
  /// Сам проект, который рисуем.
  final Project project;

  /// Коллбэк — что делать, когда по карточке тапнули.
  /// `VoidCallback?` значит: функция без параметров и без возврата, опционально.
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,              // см. объяснение ниже
    required this.project,
    this.onTap,
  });

  /// Возвращает цвет для бейджа статуса.
  /// switch expression — современный синтаксис Dart 3.
  Color _statusColor() {
    return switch (project.status) {
      ProjectStatus.idea => AppTheme.statusIdea,
      ProjectStatus.inProgress => AppTheme.statusInProgress,
      ProjectStatus.frozen => AppTheme.statusFrozen,
      ProjectStatus.done => AppTheme.statusDone,
    };
  }

  /// Человекочитаемая дата создания: "создан 3 дня назад".
  String _createdLabel() {
    final days = project.daysSinceCreated;
    if (days == 0) return 'создан сегодня';
    if (days == 1) return 'создан вчера';
    return 'создан $days дн. назад';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // Отступы снаружи карточки: сверху/снизу 6, слева/справа 12.
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // Цвет фона карточки — берём из нашей темы.
      color: AppTheme.surface,
      // Закруглённые углы. RoundedRectangleBorder — «скруглённый прямоугольник».
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Убираем тень — на тёмном фоне она выглядит грязно.
      elevation: 0,
      // InkWell — обёртка, которая делает карточку «нажимаемой»
      // и даёт визуальный отклик при тапе.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // Внутренние отступы карточки.
          padding: const EdgeInsets.all(16),
          child: Column(
            // mainAxisSize.min — колонка занимает минимум высоты,
            // а не растягивается на весь экран.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === СТРОКА 1: НАЗВАНИЕ + СТАТУС-БЕЙДЖ ===
              Row(
                children: [
                  // Expanded — "займи всё свободное место".
                  // Без него длинное название вытолкнет бейдж за край.
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      // Если название слишком длинное — обрезаем "...".
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: project.statusLabel,
                    color: _statusColor(),
                  ),
                ],
              ),

              // === СТРОКА 2: ОПИСАНИЕ (если есть) ===
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  project.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // === СТРОКА 3: ДАТА СОЗДАНИЯ ===
              const SizedBox(height: 10),
              Text(
                _createdLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Маленький вспомогательный виджет — цветной бейдж статуса.
/// Приватный (начинается с _), используется только внутри этого файла.
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // withValues — полупрозрачный вариант цвета (alpha 0.2 = 20%).
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
