// data/link_repository.dart — доступ к таблице Links.
//
// 5 методов: watchLinks / createLink / updateLink / updateLinkTitleNotes / deleteLink.

import 'package:drift/drift.dart';
import 'package:garage/data/database.dart' as db;
import 'package:garage/models/link.dart';

/// Репозиторий ссылок проекта.
class LinkRepository {
  LinkRepository(this._db);

  final db.AppDatabase _db;

  /// Стрим всех ссылок проекта, новые сверху.
  Stream<List<Link>> watchLinks(int projectId) {
    final query = _db.select(_db.links)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map(
          // row — db.Link (drift data-класс), на выходе — наша модель Link.
          (rows) => rows.map(_mapRowToLink).toList(),
        );
  }

  /// Создать ссылку. Возвращает id новой записи.
  Future<int> createLink({
    required int projectId,
    required String url,
    String title = '',
    String notes = '',
  }) {
    final now = DateTime.now();
    return _db.into(_db.links).insert(
          db.LinksCompanion.insert(
            projectId: projectId,
            url: url,
            title: Value(title),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Полное обновление ссылки (url/title/notes). updatedAt — сам.
  Future<bool> updateLink({
    required int id,
    required String url,
    required String title,
    required String notes,
  }) async {
    final rows = await (_db.update(_db.links)..where((t) => t.id.equals(id)))
        .write(
      db.LinksCompanion(
        url: Value(url),
        title: Value(title),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return rows > 0;
  }

  /// Быстрое обновление только title + notes (url не трогаем).
  Future<bool> updateLinkTitleNotes({
    required int id,
    required String title,
    required String notes,
  }) async {
    final rows = await (_db.update(_db.links)..where((t) => t.id.equals(id)))
        .write(
      db.LinksCompanion(
        title: Value(title),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return rows > 0;
  }

  /// Удалить ссылку.
  Future<int> deleteLink(int id) {
    return (_db.delete(_db.links)..where((t) => t.id.equals(id))).go();
  }

  // ---------- маппинг drift-строка → доменная модель ----------

  Link _mapRowToLink(db.Link row) {
    return Link(
      id: row.id.toString(),
      projectId: row.projectId.toString(),
      url: row.url,
      title: row.title,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}