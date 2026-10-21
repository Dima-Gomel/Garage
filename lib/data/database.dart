// database.dart — описание таблиц Projects, JournalEntries, EntryPhotos и класса AppDatabase

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ============================================================
// ТАБЛИЦА PROJECTS
// ============================================================
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('idea'))();
  TextColumn get coverImage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// ТАБЛИЦА JOURNAL_ENTRIES
// ============================================================
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// ТАБЛИЦА ENTRY_PHOTOS
// ============================================================
// Фото к записи журнала. Храним байтами в BLOB.
// На вебе — байты лягут в IndexedDB, на нативе — в SQLite.
// entryId — без FK, техдолг (добавим вместе с каскадным удалением).
class EntryPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId => integer()();
  BlobColumn get data => blob()();           // Uint8List
  DateTimeColumn get createdAt => dateTime()();
}

// ============================================================
// КЛАСС AppDatabase
// ============================================================
@DriftDatabase(tables: [Projects, JournalEntries, EntryPhotos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v1 → v2: добавили journal_entries
          if (from < 2) {
            await m.createTable(journalEntries);
          }
          // v2 → v3: добавили entry_photos
          if (from < 3) {
            await m.createTable(entryPhotos);
          }
        },
      );

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