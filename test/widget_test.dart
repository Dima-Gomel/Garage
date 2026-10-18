import 'package:flutter_test/flutter_test.dart';
import 'package:garage/data/project_repository.dart';
import 'package:garage/main.dart';
import 'package:garage/models/project.dart';

/// Фейковый репозиторий для теста.
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

void main() {
  testWidgets('Garage запускается и показывает пустой экран проектов',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GarageApp(repository: FakeProjectRepository()),
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