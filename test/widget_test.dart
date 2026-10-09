import 'package:flutter_test/flutter_test.dart';
import 'package:garage/main.dart';

void main() {
  testWidgets('Garage запускается и показывает пустой экран проектов',
      (WidgetTester tester) async {
    // Запускаем приложение.
    await tester.pumpWidget(const GarageApp());
    // pumpWidget — построить дерево виджетов. Приложение "нарисовано",
    // но без анимаций/таймеров — их надо "прокрутить" через pump().

    // Проверяем, что видим заголовок.
    expect(find.text('🔧 Garage'), findsOneWidget);

    // Проверяем, что видим пустой стейт.
    expect(find.text('Пока пусто'), findsOneWidget);

    // Проверяем, что видим кнопку "Новый проект".
    expect(find.text('Новый проект'), findsOneWidget);
  });
}
