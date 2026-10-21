import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Экран журнала одного проекта.
///
/// Показывает список записей (свежие сверху) через watchEntries(projectId).
/// FAB — пока заглушка, создание записи будет в Ж3.
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

  /// FAB-заглушка. Создание записи — в Ж3.
  void _onAddEntry() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Создание записи — в Ж3'),
        backgroundColor: AppTheme.surfaceLight,
      ),
    );
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
        onPressed: _onAddEntry,
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
        return _EntryCard(entry: entry);
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