// project_repository.dart — слой между UI и БД.
// Экраны не знают про drift — они работают только с этим классом.

import 'package:drift/drift.dart';

import '../models/project.dart';
import 'database.dart' hide Project;

// ============================================================
// МАППИНГ ProjectStatus ↔ String
// ============================================================
// В БД статус лежит строкой ('idea', 'inProgress', ...).
// В модели — enum ProjectStatus.
// Эти две функции переводят одно в другое.
// ============================================================

ProjectStatus _statusFromString(String value) {
  // values — список всех значений enum
  // firstWhere ищет первое совпадение; orElse — что вернуть, если не нашли
  return ProjectStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ProjectStatus.idea, // если строка битая — fallback на idea
  );
}

String _statusToString(ProjectStatus status) {
  // .name у enum возвращает имя значения как строку: 'idea', 'inProgress', ...
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
  // Стрим — "живой" список: когда в БД что-то меняется,
  // UI автоматически перерисуется. Не нужно вручную обновлять.
  // ----------------------------------------------------------
  Stream<List<Project>> watchAllProjects() {
    final query = _db.select(_db.projects)
      ..orderBy([
        // Сортируем по updatedAt, свежие сверху
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapRowToProject).toList(),
        );
  }

  // ----------------------------------------------------------
  // Создать новый проект.
  // Возвращаем id созданной записи.
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
            // Value() оборачивает nullable-поля и поля со значением по умолчанию
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
  // Используем copyWith-стиль: находим запись, обновляем поля.
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

    // rowsUpdated — сколько строк изменилось. 1 = успех, 0 = проект не найден.
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
  // Это единственное место, где мы "переводим" одно в другое.
  // ----------------------------------------------------------
  Project _mapRowToProject(dynamic row) {
    return Project(
      // ВАЖНО: в БД id — int, в модели — String.
      // Конвертируем через .toString().
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
