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
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
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
  IntColumn get entryId =>
      integer().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  BlobColumn get data => blob()(); // Uint8List
  DateTimeColumn get createdAt => dateTime()();
}

// ============================================================
// ТАБЛИЦА MATERIAL_ITEMS
// ============================================================
// Материалы проекта. status: 'need' | 'ordered' | 'have'.
// price — цена за единицу, REAL (для MVP; точные деньги — техдолг).
class MaterialItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('шт'))();
  RealColumn get price => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('need'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// ТАБЛИЦА LINKS
// ============================================================
// Ссылки проекта (URL + заметка). title — необязателен,
// если пусто — UI покажет url вместо него.
class Links extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get url => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ============================================================
// КЛАСС AppDatabase
// ============================================================
@DriftDatabase(
  tables: [Projects, JournalEntries, EntryPhotos, MaterialItems, Links],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v1 → v2
      if (from < 2) {
        await m.createTable(journalEntries);
      }
      // v2 → v3
      if (from < 3) {
        await m.createTable(entryPhotos);
      }
      // v3 → v4: FK + CASCADE (пересоздание таблиц)
      if (from < 4) {
        await customStatement('PRAGMA foreign_keys = OFF');        

        await transaction(() async {
          // Чистим сирот ДО пересоздания таблиц с FK.
          // 1) Записи журнала без родительского проекта.
          await customStatement('''
      DELETE FROM journal_entries
      WHERE projectId NOT IN (SELECT id FROM projects)
    ''');
          // 2) Фото без родительской записи.
          await customStatement('''
      DELETE FROM entry_photos
      WHERE entryId NOT IN (SELECT id FROM journal_entries)
    ''');

          await m.alterTable(TableMigration(journalEntries));
          await m.alterTable(TableMigration(entryPhotos));
        });

        final wrong = await customSelect('PRAGMA foreign_key_check').get();
        assert(wrong.isEmpty, 'FK violations: ${wrong.map((e) => e.data)}');
      }

      // v5 → v6: новая таблица ссылок.
        // createTable сразу с FK — alterTable не нужен, данных нет.
        if (from < 6) {
          await m.createTable(links);
        }

      // v4 → v5: новая таблица материалов.
      // createTable сразу с FK — alterTable не нужен, данных в таблице нет.
      if (from < 5) {
        await m.createTable(materialItems);
      }
    },
    beforeOpen: (details) async {
      // Обязательно: без этого SQLite игнорирует FK.
      await customStatement('PRAGMA foreign_keys = ON');
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
