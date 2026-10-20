/// Одна запись журнала проекта.
///
/// Журнал — это лента заметок мастера: «замерил вал — 42 мм»,
/// «пришла идея: кронштейн из уголка», «купил подшипник 6203».
/// Пока запись = просто текст. Фото, тип записи, голос — позже.
class JournalEntry {
  final String id;         // уникальный ID (строка, как в Project)
  final String projectId;  // к какому проекту относится (строка)
  final String text;       // сам текст записи
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    required this.projectId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Копия объекта с изменёнными полями (как в Project).
  JournalEntry copyWith({
    String? id,
    String? projectId,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Короткое превью для списка — первые ~80 символов,
  /// с многоточием, если текст длиннее.
  /// Переносы строк заменяем на пробел, чтобы превью было в одну строку.
  String get preview {
    final singleLine = text.replaceAll('\n', ' ').trim();
    if (singleLine.length <= 80) return singleLine;
    return '${singleLine.substring(0, 80)}…';
  }
}