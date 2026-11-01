// lib/models/material_item.dart — доменная модель материала проекта

/// Статус материала.
/// В БД хранится строкой: 'need' | 'ordered' | 'have'.
enum MaterialStatus {
  need('need', 'Нужно'),
  ordered('ordered', 'Заказано'),
  have('have', 'Есть');

  const MaterialStatus(this.dbValue, this.label);

  /// Значение для колонки `status` в БД.
  final String dbValue;

  /// Человекочитаемая подпись для UI.
  final String label;

  /// Обратный маппинг: строка из БД → enum.
  /// Неизвестное значение (битые данные) трактуем как `need`.
  static MaterialStatus fromDb(String value) {
    return MaterialStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => MaterialStatus.need,
    );
  }
}

/// Материал проекта — «есть / нужно / заказано», цена, количество.
/// Immutable: любое изменение — через copyWith.
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.projectId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// id в БД — int, здесь String (конвертация на стыке с репозиторием).
  final String id;
  final String projectId;
  final String name;
  final int quantity;
  final String unit;

  /// Цена за единицу, опционально. null — цена не задана.
  final double? price;

  final MaterialStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialItem copyWith({
    String? id,
    String? projectId,
    String? name,
    int? quantity,
    String? unit,
    double? price,
    MaterialStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
