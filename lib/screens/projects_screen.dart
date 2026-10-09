import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/project_card.dart';

/// Главный экран — список проектов.
/// 
/// StatefulWidget — потому что экран ПОМНИТ список проектов
/// и должен перерисовываться, когда список меняется.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

/// Класс состояния. Здесь живут данные и логика экрана.
class _ProjectsScreenState extends State<ProjectsScreen> {
  /// Список проектов в памяти. Пока без БД.
  /// Фигурные скобки [...] — это литерал списка.
  final List<Project> _projects = [];

  /// Счётчик для генерации ID. Простейший вариант —
  /// потом заменим на UUID или автоинкремент из БД.
  int _nextId = 1;

  /// Открыть окно создания нового проекта.
  /// async — потому что showModalBottomSheet возвращает Future,
  /// которая завершается, когда окно закрыли.
  Future<void> _openNewProjectSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      // isScrollControlled — окно может быть выше половины экрана,
      // нужно чтобы не обрезалось, когда откроется клавиатура.
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _NewProjectSheet(),
    );

    // result — то, что вернуло окно. Если null — пользователь закрыл без ввода.
    if (result == null || result.trim().isEmpty) return;

    // Создаём новый проект и добавляем в список.
    final now = DateTime.now();
    final newProject = Project(
      id: _nextId.toString(),
      title: result.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // setState — говорим Flutter: "данные поменялись, перерисуй экран".
    // Без setState изменения в UI не отобразятся.
    setState(() {
      _projects.add(newProject);
      _nextId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold — стандартный "каркас" экрана:
      // appBar сверху, body по центру, floatingActionButton внизу.
      appBar: AppBar(
        title: const Text('🔧 Garage'),
        // Настройки темы уже применяются из AppTheme.dark,
        // тут ничего переопределять не нужно.
      ),

      // === ТЕЛО ЭКРАНА ===
      body: _projects.isEmpty
          ? _buildEmptyState()
          : _buildProjectsList(),

      // === ПЛАВАЮЩАЯ КНОПКА ВНИЗУ ===
      // Большая кнопка под большой палец, справа внизу.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewProjectSheet,
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Новый проект',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Что показываем, когда проектов нет.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка — большая, блёклая.
            Icon(
              Icons.build_circle_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока пусто',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Создай первый проект — и он появится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Список проектов.
  Widget _buildProjectsList() {
    // ListView.builder — эффективный список.
    // Он рисует ТОЛЬКО видимые карточки, а не все сразу.
    // Важно, когда проектов станет много.
    return ListView.builder(
      // Отступы сверху/снизу, чтобы карточки не липли к краям.
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return ProjectCard(
          project: project,
          onTap: () {
            // Пока просто заглушка. Открытие карточки проекта
            // сделаем на следующем шаге.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Открыть: ${project.title}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}

/// Всплывающее окно снизу для создания нового проекта.
/// Приватный виджет, используется только на этом экране.
class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  /// TextEditingController — "ручка" для текстового поля.
  /// Через него читаем и пишем текст в поле.
  final _controller = TextEditingController();

  @override
  void dispose() {
    // dispose — вызывается, когда виджет удаляется.
    // Контроллеры нужно освобождать, иначе утечка памяти.
    _controller.dispose();
    super.dispose();
  }

  /// Закрыть окно и вернуть введённый текст.
  void _submit() {
    // Navigator.pop — закрыть текущий экран/окно.
    // Передаём результат — его получит тот, кто открыл окно.
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery — доступ к информации об устройстве,
    // здесь — высота клавиатуры, чтобы поднять окно над ней.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // padding добавляет отступ снизу, равный высоте клавиатуры.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Ручка" сверху — визуальный намёк, что окно можно тащить вниз.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Новый проект',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Поле ввода названия.
            TextField(
              controller: _controller,
              autofocus: true, // сразу открыть клавиатуру
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Например: Мини-трактор',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              // Что делать, когда нажали Enter на клавиатуре.
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // Кнопка "Создать" — большая, во всю ширину.
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Создать',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
