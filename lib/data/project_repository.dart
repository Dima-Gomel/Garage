// project_repository.dart — слой между UI и БД.
// Экраны не знают про drift — они работают только с этим классом.

import 'package:drift/drift.dart';
import '../models/project.dart';
import 'database.dart' hide Project;

// ============================================================
// МАППИНГ ProjectStatus ↔ String
// ============================================================

ProjectStatus _statusFromString(String value) {
  return ProjectStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ProjectStatus.idea,
  );
}

String _statusToString(ProjectStatus status) {
  return status.name;
}

// ============================================================
// РЕПОЗИТОРИЙ
// ============================================================
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  // ----------------------------------------------------------
  // Получить все проекты (стрим).
  // ----------------------------------------------------------
  Stream<List<Project>> watchAllProjects() {
    final query = _db.select(_db.projects)
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapRowToProject).toList(),
        );
  }

  // ----------------------------------------------------------
  // Получить один проект по id (стрим).
  // Нужен для экрана проекта: когда статус меняется,
  // экран сам перерисуется.
  //
  // Возвращает Stream<Project?> — null, если проекта нет
  // (например, его только что удалили).
  // ----------------------------------------------------------
  Stream<Project?> watchProject(int id) {
    final query = _db.select(_db.projects)
      ..where((t) => t.id.equals(id));

    return query.watchSingleOrNull().map(
          (row) => row == null ? null : _mapRowToProject(row),
        );
  }

  // ----------------------------------------------------------
  // Создать новый проект.
  // ----------------------------------------------------------
  Future<int> createProject({
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.idea,
    String? coverImage,
  }) async {
    final now = DateTime.now();

    return _db.into(_db.projects).insert(
          ProjectsCompanion.insert(
            title: title,
            description: Value(description),
            status: Value(_statusToString(status)),
            coverImage: Value(coverImage),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // ----------------------------------------------------------
  // Обновить статус проекта.
  // ----------------------------------------------------------
  Future<bool> updateProjectStatus(int id, ProjectStatus newStatus) async {
    final rowsUpdated = await (_db.update(_db.projects)
          ..where((t) => t.id.equals(id)))
        .write(
      ProjectsCompanion(
        status: Value(_statusToString(newStatus)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return rowsUpdated > 0;
  }

  // ----------------------------------------------------------
  // Удалить проект по id.
  // ----------------------------------------------------------
  Future<int> deleteProject(int id) {
    return (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
  }

  // ----------------------------------------------------------
  // Преобразование drift-строки в domain-модель Project.
  // ----------------------------------------------------------
  Project _mapRowToProject(dynamic row) {
    return Project(
      id: row.id.toString(),
      title: row.title as String,
      description: row.description as String,
      status: _statusFromString(row.status as String),
      coverImage: row.coverImage as String?,
      createdAt: row.createdAt as DateTime,
      updatedAt: row.updatedAt as DateTime,
    );
  }
}