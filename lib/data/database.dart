// database.dart — описание таблиц Projects, JournalEntries и класса AppDatabase

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ============================================================
// ТАБЛИЦА PROJECTS
// ============================================================
class Projects extends Table {
  // id — целое, autoIncrement (SQLite сам выдаёт следующий)
  IntColumn get id => integer().autoIncrement()();

  // title — обязательный текст
  TextColumn get title => text()();

  // description — текст, default '' (не nullable, но с дефолтом)
  TextColumn get description => text().withDefault(const Constant(''))();

  // status — текст, храним enum как строку ('idea', 'inProgress', ...)
  TextColumn get status => text().withDefault(const Constant('idea'))();

  // coverImage — nullable текст (путь к файлу обложки)
  TextColumn get coverImage => text().nullable()();

  // createdAt, updatedAt — даты
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// ТАБЛИЦА JOURNAL_ENTRIES
// ============================================================
// Записи журнала проекта. Пока только текст.
// projectId — просто int, без FK. Внешний ключ с каскадным
// удалением заложим отдельным шагом вместе с deleteEntry.
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  // К какому проекту относится запись (Projects.id)
  IntColumn get projectId => integer()();

  // Текст записи
  TextColumn get content => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// КЛАСС AppDatabase
// ============================================================
@DriftDatabase(tables: [Projects, JournalEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Миграция №2: добавляем таблицу journal_entries.
          // if (from < 2), а не (from == 1) — на будущее:
          // когда будет версия 3 и кто-то обновится с 1 сразу до 3,
          // эта ветка тоже должна сработать.
          if (from < 2) {
            await m.createTable(journalEntries);
          }
        },
      );

  // ← static! Теперь доступен из инициализатора
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'garage_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}