/// Статусы проекта.
/// 
/// enum (перечисление) — это способ сказать Dart'у:
/// "переменная этого типа может принимать ТОЛЬКО эти значения".
/// Нельзя опечататься или вписать что-то левое.
enum ProjectStatus {
  idea,        // идея
  inProgress,  // в работе
  frozen,      // заморожен
  done,        // готово
}

/// Модель одного проекта.
/// 
/// Пока это просто контейнер с данными (POJO — Plain Old Dart Object).
/// В будущем добавим методы сериализации для SQLite (drift).
class Project {
  final String id;           // уникальный ID (пока строка, позже — из БД)
  final String title;        // название проекта, например "Мини-трактор"
  final String description;  // короткое описание
  final ProjectStatus status;
  final String? coverImage;  // путь к обложке (nullable — может не быть)
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Конструктор. `const` — для неизменяемости, если все поля тоже константные.
  /// `required` — поле обязательно при создании.
  /// `this.xxx` — синтаксический сахар: сокращённая запись присвоения.
  const Project({
    required this.id,
    required this.title,
    this.description = '',
    this.status = ProjectStatus.idea,
    this.coverImage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Метод copyWith — создаёт КОПИЮ объекта с изменёнными полями.
  /// 
  /// Зачем: поля у нас final (неизменяемые), поэтому чтобы "поменять"
  /// статус, мы не мутируем объект, а делаем новый с другим статусом.
  /// Это стандартный паттерн Flutter.
  Project copyWith({
    String? id,
    String? title,
    String? description,
    ProjectStatus? status,
    String? coverImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      coverImage: coverImage ?? this.coverImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Удобный геттер — сколько дней прошло с момента создания.
  /// Пригодится для карточки проекта в списке.
  int get daysSinceCreated {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Человекочитаемое название статуса — для отображения в UI.
  String get statusLabel {
    switch (status) {
      case ProjectStatus.idea:
        return 'Идея';
      case ProjectStatus.inProgress:
        return 'В работе';
      case ProjectStatus.frozen:
        return 'Заморожен';
      case ProjectStatus.done:
        return 'Готово';
    }
  }
}
