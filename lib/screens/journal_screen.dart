import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Экран журнала одного проекта.
///
/// Показывает список записей (свежие сверху) через watchEntries(projectId).
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.repository,
    required this.projectId,
  });

  final ProjectRepository repository;

  /// id проекта в БД — int (в модели Project.id — String).
  final int projectId;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  // Мостики к полям родителя.
  ProjectRepository get repository => widget.repository;
  int get projectId => widget.projectId;

  /// Открыть bottom sheet записи.
  /// [entry] == null — создание, иначе — редактирование.
  Future<void> _openEntrySheet({JournalEntry? entry}) async {
    final result = await showModalBottomSheet<_EntrySheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EntrySheet(entry: entry),
    );

    if (result == null) return;

    switch (result.action) {
      case _EntrySheetAction.save: {
        final text = result.text?.trim() ?? '';
        if (text.isEmpty) return;
        if (entry == null) {
          await repository.createEntry(projectId: projectId, text: text);
        } else {
          await repository.updateEntry(int.parse(entry.id), text);
        }
      }
      case _EntrySheetAction.delete: {
        if (entry != null) {
          await repository.deleteEntry(int.parse(entry.id));
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал'),
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: repository.watchEntries(projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки журнала:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final entries = snapshot.data ?? const <JournalEntry>[];

          if (entries.isEmpty) {
            return _buildEmptyState();
          }
          return _buildEntriesList(entries);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntrySheet(),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Запись',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока нет записей',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Записывай мысли, замеры, идеи',
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

    Widget _buildEntriesList(List<JournalEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // снизу отступ под FAB
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => _openEntrySheet(entry: entry),
          borderRadius: BorderRadius.circular(12),
          child: _EntryCard(entry: entry),
        );
      },
    );
  }
}

/// Карточка одной записи журнала.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.preview,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDate(entry.createdAt),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
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

/// Что сделал пользователь в bottom sheet записи.
enum _EntrySheetAction { save, delete }

/// Результат работы bottom sheet записи.
class _EntrySheetResult {
  const _EntrySheetResult(this.action, [this.text]);
  final _EntrySheetAction action;
  final String? text;
}

/// Bottom sheet создания/редактирования записи журнала.
/// Возвращает _EntrySheetResult через Navigator.pop.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({this.entry});

  /// null — создание, не null — редактирование.
  final JournalEntry? entry;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final TextEditingController _controller;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    // При правке сразу заполняем поле текущим текстом.
    _controller = TextEditingController(text: widget.entry?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _EntrySheetResult(_EntrySheetAction.save, _controller.text),
    );
  }

  /// Диалог подтверждения удаления. Возвращает true, если подтвердили.
  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Удалить запись?',
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
    return confirmed == true;
  }

  Future<void> _onDeletePressed() async {
    final ok = await _confirmDelete();
    if (!ok) return;
    // ВАЖНО: после await проверяем mounted — sheet мог закрыться.
    if (!mounted) return;
    Navigator.of(context).pop(
      const _EntrySheetResult(_EntrySheetAction.delete),
    );
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
            // «Ручка» сверху.
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
            Text(
              _isEditing ? 'Редактировать запись' : 'Новая запись',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Мысли, замеры, идеи…',
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
                  'Сохранить',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Кнопка удаления — только в режиме правки.
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _onDeletePressed,
                  icon: const Icon(Icons.delete_outline, size: 24),
                  label: const Text(
                    'Удалить запись',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}