// lib/screens/materials_screen.dart — список материалов проекта

import 'package:flutter/material.dart';

import '../data/material_repository.dart';
import '../models/material_item.dart';
import '../theme/app_theme.dart';

/// Экран материалов одного проекта.
/// Список «есть / нужно / заказано», цена, количество.
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({
    super.key,
    required this.materialRepository,
    required this.projectId,
  });

  final MaterialRepository materialRepository;
  final int projectId;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  // Мостик к репозиторию, чтобы не писать widget.materialRepository везде.
  MaterialRepository get materialRepository => widget.materialRepository;
  int get projectId => widget.projectId;

  /// Открыть sheet создания (material == null) или редактирования.
  Future<void> _openMaterialSheet({MaterialItem? material}) async {
    final result = await showModalBottomSheet<_MaterialSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MaterialSheet(existing: material),
    );

    if (result == null) return; // закрыли без сохранения

    try {
      if (result.action == _MaterialSheetAction.delete) {
        await materialRepository.deleteMaterial(int.parse(material!.id));
        return;
      }

      if (material == null) {
        // create
        await materialRepository.createMaterial(
          projectId: projectId,
          name: result.name,
          quantity: result.quantity,
          unit: result.unit,
          price: result.price,
          status: result.status,
          notes: result.notes,
        );
      } else {
        // edit
        await materialRepository.updateMaterial(
          id: int.parse(material.id),
          name: result.name,
          quantity: result.quantity,
          unit: result.unit,
          price: result.price,
          status: result.status,
          notes: result.notes,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Материалы')),
      body: StreamBuilder<List<MaterialItem>>(
        stream: materialRepository.watchMaterials(projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки материалов:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final materials = snapshot.data ?? const <MaterialItem>[];

          if (materials.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Материалов пока нет.\nНажми «+», чтобы добавить.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final m = materials[index];
              return _MaterialCard(
                material: m,
                onTap: () => _openMaterialSheet(material: m),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMaterialSheet(),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// _MaterialSheet — форма создания / редактирования материала
// ============================================================

/// Что вернул sheet.
enum _MaterialSheetAction { save, delete }

/// Результат работы sheet'а. Если null — пользователь закрыл без сохранения.
class _MaterialSheetResult {
  const _MaterialSheetResult({
    required this.action,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.status,
    required this.notes,
  });

  final _MaterialSheetAction action;
  final String name;
  final int quantity;
  final String unit;
  final double? price;
  final MaterialStatus status;
  final String notes;
}

class _MaterialSheet extends StatefulWidget {
  const _MaterialSheet({this.existing});

  /// null → создание, не null → редактирование.
  final MaterialItem? existing;

  @override
  State<_MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends State<_MaterialSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _notesCtrl;
  late MaterialStatus _status;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _quantityCtrl = TextEditingController(text: (e?.quantity ?? 1).toString());
    _unitCtrl = TextEditingController(text: e?.unit ?? 'шт');
    _priceCtrl = TextEditingController(
      text: e?.price != null ? _formatPrice(e!.price!) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _status = e?.status ?? MaterialStatus.need;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Цена для поля ввода: без хвостовых нулей, с запятой.
  String _formatPrice(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  /// Парсим цену: пусто → null, «12,5» → 12.5, мусор → null.
  double? _parsePrice(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Парсим количество: пусто/мусор → 1, минимум 1.
  int _parseQuantity(String raw) {
    final v = int.tryParse(raw.trim()) ?? 1;
    return v < 1 ? 1 : v;
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название не может быть пустым')),
      );
      return;
    }

    Navigator.of(context).pop(
      _MaterialSheetResult(
        action: _MaterialSheetAction.save,
        name: name,
        quantity: _parseQuantity(_quantityCtrl.text),
        unit: _unitCtrl.text.trim().isEmpty ? 'шт' : _unitCtrl.text.trim(),
        price: _parsePrice(_priceCtrl.text),
        status: _status,
        notes: _notesCtrl.text.trim(),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      const _MaterialSheetResult(
        action: _MaterialSheetAction.delete,
        name: '',
        quantity: 1,
        unit: 'шт',
        price: null,
        status: MaterialStatus.need,
        notes: '',
      ),
    );
  }

  Color _statusColor(MaterialStatus s) {
    return switch (s) {
      MaterialStatus.need => AppTheme.statusInProgress, // оранжевый — «нужно»
      MaterialStatus.ordered => AppTheme.statusIdea, // синий — «заказано»
      MaterialStatus.have => AppTheme.statusDone, // зелёный — «есть»
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Поднимаем sheet над клавиатурой.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // «Ручка» сверху.
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
              const SizedBox(height: 16),
              Text(
                _isEdit ? 'Редактировать материал' : 'Новый материал',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Название.
              TextField(
                controller: _nameCtrl,
                autofocus: !_isEdit,
                decoration: const InputDecoration(labelText: 'Название'),
                style: const TextStyle(color: AppTheme.textPrimary),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              // Количество + единица — в одной строке.
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(labelText: 'Ед.'),
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Цена.
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Цена за единицу (опционально)',
                  suffixText: '₽',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),

              // Статус — три сегмента.
              const Text(
                'Статус',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in MaterialStatus.values) ...[
                    Expanded(
                      child: _StatusChip(
                        label: s.label,
                        color: _statusColor(s),
                        selected: _status == s,
                        onTap: () => setState(() => _status = s),
                      ),
                    ),
                    if (s != MaterialStatus.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Заметки.
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Заметки (опционально)',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),

              // Сохранить.
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isEdit ? 'Сохранить' : 'Добавить',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Удалить — только в режиме редактирования, не под пальцем.
              if (_isEdit) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Удалить материал',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// _StatusChip — сегмент выбора статуса
// ============================================================
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// _MaterialCard — карточка материала в списке
// ============================================================
class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.onTap});

  final MaterialItem material;
  final VoidCallback onTap;

  Color _statusColor(MaterialStatus s) {
    return switch (s) {
      MaterialStatus.need => AppTheme.statusInProgress,
      MaterialStatus.ordered => AppTheme.statusIdea,
      MaterialStatus.have => AppTheme.statusDone,
    };
  }

  /// «2 шт · 150 ₽/шт · 300 ₽» или короче, если цена не задана.
  String _subtitle() {
    final base = '${material.quantity} ${material.unit}';
    final price = material.price;
    if (price == null) return base;
    final unitPrice = _formatPrice(price);
    final total = _formatPrice(price * material.quantity);
    return '$base · $unitPrice ₽/${material.unit} · $total ₽';
  }

  String _formatPrice(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(material.status);
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      material.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Бейдж статуса.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      material.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (material.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  material.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
