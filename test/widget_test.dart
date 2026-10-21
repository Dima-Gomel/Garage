import 'dart:typed_data';
import 'package:garage/models/entry_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/data/journal_repository.dart';
import 'package:garage/data/project_repository.dart';
import 'package:garage/main.dart';
import 'package:garage/models/project.dart';
import 'package:garage/models/journal_entry.dart';

/// Фейковый репозиторий ПРОЕКТОВ для теста.
///
/// Реальная AppDatabase в тестах не поднимается —
/// ей нужен нативный sqlite3, которого в test-раннере нет.
/// Поэтому подсовываем этот класс: ProjectsScreen его не отличит.
class FakeProjectRepository implements ProjectRepository {
  @override
  Stream<List<Project>> watchAllProjects() =>
      Stream.value(const <Project>[]);

  @override
  Stream<Project?> watchProject(int id) =>
      Stream.value(null);

  @override
  Future<int> createProject({
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.idea,
    String? coverImage,
  }) async {
    // В тесте создание не проверяем — возвращаем фиктивный id.
    return 1;
  }

  @override
  Future<bool> updateProjectStatus(int id, ProjectStatus newStatus) async {
    return true;
  }

  @override
  Future<int> deleteProject(int id) async {
    return 1;
  }
}

/// Фейковый репозиторий ЖУРНАЛА для теста.
///
/// Нужен, потому что GarageApp требует оба репозитория.
/// Пока журнальные экраны в тестах не открываются —
/// методы возвращают пустые значения.
class FakeJournalRepository implements JournalRepository {
  @override
  Stream<List<JournalEntry>> watchEntries(int projectId) {
    return Stream.value(const []);
  }

  @override
  Future<int> createEntry({
    required int projectId,
    required String text,
  }) async {
    return 0;
  }

  @override
  Future<bool> updateEntry(int id, String newText) async {
    return false;
  }

  @override
  Future<int> deleteEntry(int id) async {
    return 0;
  }

    // ----------------------------------------------------------
  // Фото — заглушки. Храним в памяти, чтобы тест мог проверить
  // UI без реальной БД.
  // ----------------------------------------------------------
  final List<EntryPhoto> _photos = <EntryPhoto>[];
  int _nextPhotoId = 1;

  @override
  Future<int> addPhoto({
    required int entryId,
    required Uint8List data,
  }) async {
    final id = _nextPhotoId++;
    _photos.add(EntryPhoto(
      id: id.toString(),
      entryId: entryId.toString(),
      data: data,
      createdAt: DateTime.now(),
    ));
    return id;
  }

  @override
  Stream<List<EntryPhoto>> watchPhotos(int entryId) {
    final filtered = _photos
        .where((p) => p.entryId == entryId.toString())
        .toList();
    return Stream.value(filtered);
  }

  @override
  Future<int> deletePhoto(int id) async {
    final before = _photos.length;
    _photos.removeWhere((p) => p.id == id.toString());
    return before - _photos.length;
  }
}

void main() {
  testWidgets('Garage запускается и показывает пустой экран проектов',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GarageApp(
        projectRepository: FakeProjectRepository(),
        journalRepository: FakeJournalRepository(),
      ),
    );

    // StreamBuilder отдаёт данные асинхронно.
    // Stream.value(...) завершится в микротаске — нужен один pump(),
    // чтобы UI успел перерисоваться с пустым списком.
    await tester.pump();

    expect(find.text('🔧 Garage'), findsOneWidget);
    expect(find.text('Пока пусто'), findsOneWidget);
    expect(find.text('Новый проект'), findsOneWidget);
  });
}