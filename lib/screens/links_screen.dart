import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:provider/provider.dart';

import '../data/link_repository.dart';
import '../models/link.dart';
import '../theme/app_theme.dart';

/// Экран «Ссылки» одного проекта.
///
/// Список ссылок + FAB «+» → sheet create/edit.
/// На карточке — кнопка «📋 Копировать» (Clipboard.setData,
/// без url_launcher — он отложен).
class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key, required this.projectId});

  final int projectId;

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  int get projectId => widget.projectId;

  Future<void> _openLinkSheet({Link? existing}) async {
    // repo ДО await (правило №41).
    final repo = context.read<LinkRepository>();

    final result = await showModalBottomSheet<_LinkSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LinkSheet(existing: existing),
    );

    if (result == null) return;

    switch (result.action) {
      case _LinkSheetAction.save:
        if (existing == null) {
          await repo.createLink(
            projectId: projectId,
            url: result.url,
            title: result.title,
            notes: result.notes,
          );
        } else {
          await repo.updateLink(
            id: int.parse(existing.id),
            url: result.url,
            title: result.title,
            notes: result.notes,
          );
        }
      case _LinkSheetAction.delete:
        if (existing != null) {
          await repo.deleteLink(int.parse(existing.id));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ссылки')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        onPressed: () => _openLinkSheet(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Link>>(
        stream: context.read<LinkRepository>().watchLinks(projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки ссылок:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final links = snapshot.data ?? const <Link>[];

          if (links.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Пока нет ссылок.\nНажми «+», чтобы добавить.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: links.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final link = links[i];
              return _LinkCard(
                link: link,
                onTap: () => _openLinkSheet(existing: link),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// _LinkCard — карточка ссылки. Репозиторий НЕ в конструкторе
// (правило №85), читает context.read при необходимости.
// Здесь репозиторий не нужен вообще — только Clipboard.
// ============================================================
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, required this.onTap});

  final Link link;
  final VoidCallback onTap;

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: AppTheme.textSecondary,
                    tooltip: 'Копировать URL',
                    onPressed: () => _copyUrl(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                link.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (link.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  link.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
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

// ============================================================
// _LinkSheet — create/edit.
// null → создание, не null → редактирование (+ удаление).
// ============================================================
class _LinkSheet extends StatefulWidget {
  const _LinkSheet({this.existing});

  final Link? existing;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  String? _urlError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.existing?.url ?? '');
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Валидация URL: не пусто + префикс http:// / https:// (иначе добавляем).
  String? _normalizeUrl(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }

  void _save() {
    final normalized = _normalizeUrl(_urlCtrl.text);
    if (normalized == null) {
      setState(() => _urlError = 'URL не может быть пустым');
      return;
    }
    setState(() => _urlError = null);
    Navigator.of(context).pop(
      _LinkSheetResult(
        action: _LinkSheetAction.save,
        url: normalized,
        title: _titleCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      const _LinkSheetResult(
        action: _LinkSheetAction.delete,
        url: '',
        title: '',
        notes: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Клавиатура не должна перекрывать поля.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // «Ручка».
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
                _isEdit ? 'Редактировать ссылку' : 'Новая ссылка',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlCtrl,
                autofocus: !_isEdit,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  errorText: _urlError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Название (необязательно)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Заметка (необязательно)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text(
                      'Удалить ссылку',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
// Результат sheet + действие.
// ============================================================
enum _LinkSheetAction { save, delete }

class _LinkSheetResult {
  const _LinkSheetResult({
    required this.action,
    required this.url,
    required this.title,
    required this.notes,
  });

  final _LinkSheetAction action;
  final String url;
  final String title;
  final String notes;
}
