import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/journal_repository.dart';
import '../models/entry_photo.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Экран журнала одного проекта.
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.journalRepository,
    required this.projectId,
  });

  final JournalRepository journalRepository;
  final int projectId;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  JournalRepository get journalRepository => widget.journalRepository;
  int get projectId => widget.projectId;

  Future<void> _openEntrySheet({JournalEntry? entry}) async {
    // Стрим существующих фото — отдаём sheet'у как стрим (а не List),
    // чтобы StreamBuilder сам перерисовал, когда drift отдаст полный
    // список. При create — null.
    final existingPhotosStream = entry != null
        ? journalRepository.watchPhotos(int.parse(entry.id))
        : null;

    final result = await showModalBottomSheet<_EntrySheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _EntrySheet(entry: entry, existingPhotosStream: existingPhotosStream),
    );

    if (result == null) return;

    switch (result.action) {
      case _EntrySheetAction.save:
        {
          final text = result.text.trim();
          if (text.isEmpty) return;

          final int entryId;
          if (entry == null) {
            entryId = await journalRepository.createEntry(
              projectId: projectId,
              text: text,
            );
          } else {
            entryId = int.parse(entry.id);
            await journalRepository.updateEntry(entryId, text);
          }

          for (final bytes in result.newPhotos) {
            await journalRepository.addPhoto(entryId: entryId, data: bytes);
          }

          for (final photoId in result.existingPhotoIdsToDelete) {
            await journalRepository.deletePhoto(photoId);
          }
        }
      case _EntrySheetAction.delete:
        {
          if (entry != null) {
            await journalRepository.deleteEntry(int.parse(entry.id));
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Журнал')),
      body: StreamBuilder<List<JournalEntry>>(
        stream: journalRepository.watchEntries(projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки журнала:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final entries = snapshot.data ?? const <JournalEntry>[];

          if (entries.isEmpty) {
            return _buildEmptyState();
          }
          return _buildEntriesList(entries);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntrySheet(),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Запись',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока нет записей',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Записывай мысли, замеры, идеи',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesList(List<JournalEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => _openEntrySheet(entry: entry),
          borderRadius: BorderRadius.circular(12),
          child: _EntryCard(entry: entry, journalRepository: journalRepository),
        );
      },
    );
  }
}

/// Карточка одной записи журнала.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.journalRepository});

  final JournalEntry entry;
  final JournalRepository journalRepository;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.preview,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDate(entry.createdAt),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          StreamBuilder<List<EntryPhoto>>(
            stream: journalRepository.watchPhotos(int.parse(entry.id)),
            builder: (context, snapshot) {
              final photos = snapshot.data ?? const <EntryPhoto>[];
              if (photos.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final photo in photos)
                      GestureDetector(
                        onTap: () => _openFullPhoto(context, photo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            photo.data,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openFullPhoto(BuildContext context, EntryPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(photo.data, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}, '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

enum _EntrySheetAction { save, delete }

class _EntrySheetResult {
  const _EntrySheetResult({
    required this.action,
    required this.text,
    this.newPhotos = const <Uint8List>[],
    this.existingPhotoIdsToDelete = const <int>[],
  });

  final _EntrySheetAction action;
  final String text;
  final List<Uint8List> newPhotos;
  final List<int> existingPhotoIdsToDelete;
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({this.entry, this.existingPhotosStream});

  /// null — создание, не null — редактирование.
  final JournalEntry? entry;

  /// Живой стрим фото, уже сохранённых в БД (только при редактировании).
  /// null — создание записи.
  final Stream<List<EntryPhoto>>? existingPhotosStream;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final TextEditingController _controller;

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _pickedPhotos = <Uint8List>[];
  final Set<int> _existingPhotoIdsToDelete = <int>{};
  bool _isPicking = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entry?.text ?? '');
  }

  @override
  void dispose() {
    _speech.stop(); // безопасно, даже если не начинали слушать
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (!mounted) return;

      setState(() => _pickedPhotos.add(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось добавить фото: $e')));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_isInitializing) return;

    if (_isListening) {
      await _stopListening();
      return;
    }

    // Ленивая инициализация — только при первом нажатии.
    if (_speechAvailable == null) {
      setState(() => _isInitializing = true);
      try {
        final available = await _speech.initialize(
          onError: (error) {
            if (!mounted) return;
            _showSpeechSnackBar('Ошибка распознавания: ${error.errorMsg}');
          },
          onStatus: (status) {
            // status == 'done' / 'notListening' — распознавание остановилось
            // само (тишина, таймаут). Синхронизируем флаг.
            if (!mounted) return;
            if (status == 'done' || status == 'notListening') {
              if (_isListening) setState(() => _isListening = false);
            }
          },
        );
        _speechAvailable = available;
        if (!available) {
          _showSpeechSnackBar(
            'Распознавание речи недоступно на этом устройстве',
          );
        }
      } catch (e) {
        _speechAvailable = false;
        _showSpeechSnackBar('Не удалось запустить распознавание: $e');
      } finally {
        if (mounted) setState(() => _isInitializing = false);
      }
    }

    if (_speechAvailable != true) return;

    await _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() => _isListening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          if (result.finalResult) {
            _appendRecognized(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'ru_RU',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isListening = false);
      _showSpeechSnackBar('Ошибка запуска микрофона: $e');
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _appendRecognized(String words) {
    final trimmed = words.trim();
    if (trimmed.isEmpty) return;

    final current = _controller.text;
    // Дописываем, не заменяем. Если текст уже есть — ставим пробел.
    final needsSpace = current.isNotEmpty && !current.endsWith(' ');
    _controller.text = current + (needsSpace ? ' ' : '') + trimmed;
    // Курсор — в конец.
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _showSpeechSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    Navigator.of(context).pop(
      _EntrySheetResult(
        action: _EntrySheetAction.save,
        text: _controller.text,
        newPhotos: List<Uint8List>.unmodifiable(_pickedPhotos),
        existingPhotoIdsToDelete: List<int>.unmodifiable(
          _existingPhotoIdsToDelete,
        ),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Удалить запись?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _onDeletePressed() async {
    final ok = await _confirmDelete();
    if (!ok) return;
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(const _EntrySheetResult(action: _EntrySheetAction.delete, text: ''));
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitializing = false;
  bool? _speechAvailable; // null — ещё не инициализировали

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 20),
              Text(
                _isEditing ? 'Редактировать запись' : 'Новая запись',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Мысли, замеры, идеи…',
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
              ),

              // ── Существующие фото (живой стрим, только в edit-режиме) ──
              // ВАЖНО: отдельно от блока новых фото — рисуются всегда,
              // как только drift отдаст данные. Не зависит от _pickedPhotos.
              if (widget.existingPhotosStream != null)
                StreamBuilder<List<EntryPhoto>>(
                  stream: widget.existingPhotosStream,
                  builder: (context, snapshot) {
                    final photos = snapshot.data ?? const <EntryPhoto>[];
                    if (photos.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final photo in photos)
                              if (!_existingPhotoIdsToDelete.contains(
                                int.parse(photo.id),
                              ))
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        photo.data,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _existingPhotoIdsToDelete.add(
                                            int.parse(photo.id),
                                          ),
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // ── Новые (ещё не сохранённые) фото ──
              if (_pickedPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _pickedPhotos.length; i++)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                _pickedPhotos[i],
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _pickedPhotos.removeAt(i)),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isInitializing ? null : _toggleListening,
                      icon: _isInitializing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(_isListening ? 'Стоп' : 'Голос'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isListening
                            ? Colors.red
                            : AppTheme.accent,
                        side: BorderSide(
                          color: (_isListening ? Colors.red : AppTheme.accent)
                              .withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPicking ? null : _pickPhoto,
                      icon: _isPicking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: Text(_isPicking ? 'Выбор…' : 'Фото'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: BorderSide(
                          color: AppTheme.accent.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
                    'Сохранить',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _onDeletePressed,
                    icon: const Icon(Icons.delete_outline, size: 24),
                    label: const Text(
                      'Удалить запись',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
