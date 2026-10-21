// entry_photo.dart — domain-модель фото к записи журнала.
// Хранит байты картинки (Uint8List) + связь с записью.

import 'dart:typed_data';

class EntryPhoto {
  const EntryPhoto({
    required this.id,
    required this.entryId,
    required this.data,
    required this.createdAt,
  });

  /// id в БД — int, в модели String (техдолг, как у Project/JournalEntry).
  final String id;

  /// id записи журнала, к которой привязано фото (int в БД → String здесь).
  final String entryId;

  /// Байты картинки. На вебе — из IndexedDB, на нативе — из SQLite.
  final Uint8List data;

  final DateTime createdAt;

  EntryPhoto copyWith({
    String? id,
    String? entryId,
    Uint8List? data,
    DateTime? createdAt,
  }) {
    return EntryPhoto(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}