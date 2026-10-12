// database.dart — описание таблицы Projects и класса AppDatabase

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
// КЛАСС AppDatabase
// ============================================================
@DriftDatabase(tables: [Projects])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

@override
int get schemaVersion => 1;

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
