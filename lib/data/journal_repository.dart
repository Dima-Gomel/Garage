// journal_repository.dart — слой между UI и БД для журнала.
// Отвечает ТОЛЬКО за записи журнала (JournalEntries).
// Проекты (Projects) — в project_repository.dart.

import 'package:drift/drift.dart';

import '../models/journal_entry.dart';
import 'database.dart' hide Project, JournalEntry;

// ============================================================
// РЕПОЗИТОРИЙ ЖУРНАЛА
// ============================================================
class JournalRepository {
  JournalRepository(this._db);

  final AppDatabase _db;

  // ----------------------------------------------------------
  // Все записи журнала проекта (стрим).
  // Сортировка: свежие сверху (createdAt DESC).
  // ----------------------------------------------------------
  Stream<List<JournalEntry>> watchEntries(int projectId) {
    final query = _db.select(_db.journalEntries)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapRowToEntry).toList(),
        );
  }

  // ----------------------------------------------------------
  // Создать новую запись журнала.
  // Возвращает int id созданной записи.
  // ----------------------------------------------------------
  Future<int> createEntry({
    required int projectId,
    required String text,
  }) async {
    final now = DateTime.now();

    return _db.into(_db.journalEntries).insert(
          JournalEntriesCompanion.insert(
            projectId: projectId,
            content: text, // колонка в БД называется content,
                           // в модели JournalEntry — text
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // ----------------------------------------------------------
  // Обновить текст записи.
  // true — если обновилось, false — если запись не найдена.
  // ----------------------------------------------------------
  Future<bool> updateEntry(int id, String newText) async {
    final rowsUpdated = await (_db.update(_db.journalEntries)
          ..where((t) => t.id.equals(id)))
        .write(
      JournalEntriesCompanion(
        content: Value(newText),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return rowsUpdated > 0;
  }

  // ----------------------------------------------------------
  // Удалить запись журнала по id.
  // Возвращает число удалённых строк.
  // ----------------------------------------------------------
  Future<int> deleteEntry(int id) {
    return (_db.delete(_db.journalEntries)..where((t) => t.id.equals(id))).go();
  }

  // ----------------------------------------------------------
  // Преобразование drift-строки в domain-модель JournalEntry.
  // ----------------------------------------------------------
  JournalEntry _mapRowToEntry(dynamic row) {
    return JournalEntry(
      id: row.id.toString(),
      projectId: row.projectId.toString(),
      text: row.content as String, // БД content → модель text
      createdAt: row.createdAt as DateTime,
      updatedAt: row.updatedAt as DateTime,
    );
  }
}