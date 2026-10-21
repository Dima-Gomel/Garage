// journal_repository.dart — слой между UI и БД для журнала.
// Отвечает ТОЛЬКО за записи журнала (JournalEntries).
// Проекты (Projects) — в project_repository.dart.

import 'package:drift/drift.dart';

import '../models/journal_entry.dart';
import '../models/entry_photo.dart';
import 'database.dart' hide Project, JournalEntry, EntryPhoto;

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
  // Добавить фото к записи журнала.
  // Принимает уже готовые байты (сжатие — на стороне UI).
  // Возвращает int id созданного фото.
  // ----------------------------------------------------------
  Future<int> addPhoto({
    required int entryId,
    required Uint8List data,
  }) async {
    return _db.into(_db.entryPhotos).insert(
          EntryPhotosCompanion.insert(
            entryId: entryId,
            data: data,
            createdAt: DateTime.now(),
          ),
        );
  }

  // ----------------------------------------------------------
  // Все фото конкретной записи (стрим).
  // Сортировка: старые сверху (createdAt ASC) — так фото
  // идут в порядке добавления, как гаражная хроника.
  // ----------------------------------------------------------
  Stream<List<EntryPhoto>> watchPhotos(int entryId) {
    final query = _db.select(_db.entryPhotos)
      ..where((t) => t.entryId.equals(entryId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapRowToPhoto).toList(),
        );
  }

  // ----------------------------------------------------------
  // Удалить фото по id.
  // Возвращает число удалённых строк.
  // ----------------------------------------------------------
  Future<int> deletePhoto(int id) {
    return (_db.delete(_db.entryPhotos)..where((t) => t.id.equals(id))).go();
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

    // ----------------------------------------------------------
  // Преобразование drift-строки в domain-модель EntryPhoto.
  // ----------------------------------------------------------
  EntryPhoto _mapRowToPhoto(dynamic row) {
    return EntryPhoto(
      id: row.id.toString(),
      entryId: row.entryId.toString(),
      data: row.data as Uint8List,
      createdAt: row.createdAt as DateTime,
    );
  }
}