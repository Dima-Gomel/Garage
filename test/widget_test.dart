import 'dart:typed_data';

import 'package:provider/provider.dart';
import 'package:garage/models/entry_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/data/journal_repository.dart';
import 'package:garage/data/project_repository.dart';
import 'package:garage/main.dart';
import 'package:garage/models/project.dart';
import 'package:garage/models/journal_entry.dart';
import 'package:garage/data/material_repository.dart';
import 'package:garage/models/material_item.dart';

/// Фейковый репозиторий ПРОЕКТОВ для теста.
///
/// Реальная AppDatabase в тестах не поднимается —
/// ей нужен нативный sqlite3, которого в test-раннере нет.
/// Поэтому подсовываем этот класс: ProjectsScreen его не отличит.
class FakeProjectRepository implements ProjectRepository {
  @override
  Stream<List<Project>> watchAllProjects() => Stream.value(const <Project>[]);

  @override
  Stream<Project?> watchProject(int id) => Stream.value(null);

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
  Future<int> addPhoto({required int entryId, required Uint8List data}) async {
    final id = _nextPhotoId++;
    _photos.add(
      EntryPhoto(
        id: id.toString(),
        entryId: entryId.toString(),
        data: data,
        createdAt: DateTime.now(),
      ),
    );
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

// ============================================================
// FakeMaterialRepository — зеркалит MaterialRepository
// ============================================================
// По правилу: при добавлении метода в репозиторий —
// СРАЗУ добавь его в фейк. Иначе analyze ругнётся на
// несоответствие implements.
class FakeMaterialRepository implements MaterialRepository {
  /// Внутреннее хранилище: projectId → список материалов.
  final Map<int, List<MaterialItem>> _store = {};
  int _nextId = 1;

  @override
  Stream<List<MaterialItem>> watchMaterials(int projectId) {
    // Простейший стрим: отдаём текущий снимок и больше ничего.
    // Для тестов виджетов этого достаточно.
    return Stream.value(List.unmodifiable(_store[projectId] ?? const []));
  }

  @override
  Future<int> createMaterial({
    required int projectId,
    required String name,
    int quantity = 1,
    String unit = 'шт',
    double? price,
    MaterialStatus status = MaterialStatus.need,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final id = _nextId++;
    final item = MaterialItem(
      id: id.toString(),
      projectId: projectId.toString(),
      name: name,
      quantity: quantity,
      unit: unit,
      price: price,
      status: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    (_store[projectId] ??= []).add(item);
    return id;
  }

  @override
  Future<bool> updateMaterial({
    required int id,
    required String name,
    required int quantity,
    required String unit,
    required double? price,
    required MaterialStatus status,
    required String notes,
  }) async {
    for (final list in _store.values) {
      final i = list.indexWhere((m) => m.id == id.toString());
      if (i >= 0) {
        final old = list[i];
        list[i] = old.copyWith(
          name: name,
          quantity: quantity,
          unit: unit,
          price: price,
          status: status,
          notes: notes,
          updatedAt: DateTime.now(),
        );
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> updateMaterialStatus(int id, MaterialStatus status) async {
    for (final list in _store.values) {
      final i = list.indexWhere((m) => m.id == id.toString());
      if (i >= 0) {
        list[i] = list[i].copyWith(status: status, updatedAt: DateTime.now());
        return true;
      }
    }
    return false;
  }

  @override
  Future<int> deleteMaterial(int id) async {
    for (final list in _store.values) {
      final before = list.length;
      list.removeWhere((m) => m.id == id.toString());
      if (list.length != before) return 1;
    }
    return 0;
  }
}

void main() {
  testWidgets('Garage запускается и показывает пустой экран проектов', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProjectRepository>.value(value: FakeProjectRepository()),
          Provider<JournalRepository>.value(value: FakeJournalRepository()),
          Provider<MaterialRepository>.value(value: FakeMaterialRepository()),
        ],
        child: const GarageApp(),
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
