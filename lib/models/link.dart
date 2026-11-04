// models/link.dart — доменная модель ссылки.
//
// Immutable. Поля совпадают с таблицей Links, кроме id:
// в БД id = int (autoIncrement), в модели — String (как у Project/JournalEntry/MaterialItem).
// Конвертация int.parse на стыке UI ↔ репозиторий.

/// Ссылка проекта: URL + необязательные title и заметка.
class Link {
  const Link({
    required this.id,
    required this.projectId,
    required this.url,
    required this.title,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String url;

  /// Если пусто — UI показывает url вместо title.
  final String title;

  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Что показывать в заголовке карточки: title, если есть, иначе url.
  String get displayTitle => title.isNotEmpty ? title : url;

  /// Копия с заменой отдельных полей.
  ///
  /// ⚠️ copyWith(title: null) НЕ обнулит title — оставит старое (правило №38).
  /// Для MVP этого достаточно: title/notes задаются при создании/редактировании,
  /// «стереть в null» не нужно — пустая строка и так = «нет».
  Link copyWith({
    String? id,
    String? projectId,
    String? url,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Link(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      url: url ?? this.url,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
