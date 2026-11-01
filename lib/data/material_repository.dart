// lib/data/material_repository.dart — репозиторий материалов проекта

import 'package:drift/drift.dart';
import 'package:garage/data/database.dart' hide MaterialItem;
import 'package:garage/models/material_item.dart';

/// Репозиторий материалов.
/// Отвечает ТОЛЬКО за таблицу MaterialItems.
class MaterialRepository {
  MaterialRepository(this._db);

  final AppDatabase _db;

  // ============================================================
  // ЧТЕНИЕ
  // ============================================================

  /// Все материалы проекта, новые сверху.
  Stream<List<MaterialItem>> watchMaterials(int projectId) {
    final query = _db.select(_db.materialItems)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) => rows.map(_mapRowToModel).toList());
  }

  // ============================================================
  // СОЗДАНИЕ
  // ============================================================

  /// Создать материал. Возвращает id новой строки.
  Future<int> createMaterial({
    required int projectId,
    required String name,
    int quantity = 1,
    String unit = 'шт',
    double? price,
    MaterialStatus status = MaterialStatus.need,
    String notes = '',
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.materialItems)
        .insert(
          MaterialItemsCompanion.insert(
            projectId: projectId,
            name: name,
            quantity: Value(quantity),
            unit: Value(unit),
            price: Value(price),
            status: Value(status.dbValue),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // ============================================================
  // ОБНОВЛЕНИЕ
  // ============================================================

  /// Полное обновление полей материала. `updatedAt` ставим сами.
  Future<bool> updateMaterial({
    required int id,
    required String name,
    required int quantity,
    required String unit,
    required double? price,
    required MaterialStatus status,
    required String notes,
  }) async {
    final rows =
        await (_db.update(
          _db.materialItems,
        )..where((t) => t.id.equals(id))).write(
          MaterialItemsCompanion(
            name: Value(name),
            quantity: Value(quantity),
            unit: Value(unit),
            price: Value(price),
            status: Value(status.dbValue),
            notes: Value(notes),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  /// Быстрое переключение статуса (для тапа по бейджу).
  Future<bool> updateMaterialStatus(int id, MaterialStatus status) async {
    final rows =
        await (_db.update(
          _db.materialItems,
        )..where((t) => t.id.equals(id))).write(
          MaterialItemsCompanion(
            status: Value(status.dbValue),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  // ============================================================
  // УДАЛЕНИЕ
  // ============================================================

  /// Удалить материал. Безопасно: FK на projects — CASCADE,
  /// при удалении проекта материалы уйдут сами.
  Future<int> deleteMaterial(int id) {
    return (_db.delete(_db.materialItems)..where((t) => t.id.equals(id))).go();
  }

  // ============================================================
  // МАППИНГ: drift-строка → domain-модель
  // ============================================================

  MaterialItem _mapRowToModel(dynamic row) {
    return MaterialItem(
      id: row.id.toString(),
      projectId: row.projectId.toString(),
      name: row.name as String,
      quantity: row.quantity as int,
      unit: row.unit as String,
      price: row.price as double?,
      status: MaterialStatus.fromDb(row.status as String),
      notes: row.notes as String,
      createdAt: row.createdAt as DateTime,
      updatedAt: row.updatedAt as DateTime,
    );
  }
}
