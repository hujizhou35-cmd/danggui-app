import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../services/export/portable_export_service.dart';
import '../../ui/components/components.dart';

class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({
    super.key,
    required this.noteId,
    this.autosaveDelay = const Duration(milliseconds: 650),
    this.autosaveRetryDelay = const Duration(seconds: 2),
    this.onPersist,
  });

  final String noteId;
  final Duration autosaveDelay;
  final Duration autosaveRetryDelay;
  final Future<void> Function(NoteViewModel note)? onPersist;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyUndoController = UndoHistoryController();
  late final AppStoreController _store;
  String? _folderId;
  var _pinned = false;
  var _allowPop = false;
  String? _loadedId;
  NoteViewModel? _noteTemplate;
  Timer? _autosaveTimer;
  _NoteSaveDraft? _pendingDraft;
  Future<bool>? _saveOperation;
  Object? _lastObservedSignature;
  var _nextRevision = 0;
  var _persistedRevision = 0;
  var _showSaveErrors = false;
  var _controllersReady = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(appStoreProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_onDraftChanged);
    _bodyController.addListener(_onDraftChanged);
    _bodyUndoController.addListener(_refreshUndoButtons);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingDraft != null) {
      unawaited(_startSaveLoop());
    }
    _titleController.removeListener(_onDraftChanged);
    _bodyController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyUndoController
      ..removeListener(_refreshUndoButtons)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _autosaveTimer?.cancel();
      unawaited(_startSaveLoop());
    }
  }

  void _refreshUndoButtons() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(appStoreProvider);
    NoteViewModel? note;
    for (final candidate
        in asyncState.value?.notes ?? const <NoteViewModel>[]) {
      if (candidate.id == widget.noteId) note = candidate;
    }
    if (note != null) {
      if (_loadedId != note.id) {
        _hydrate(note);
      } else {
        _noteTemplate = note;
      }
    }
    if (note == null) {
      return Scaffold(
        body: Center(
          child: asyncState.isLoading
              ? const CircularProgressIndicator()
              : FilledButton(onPressed: context.pop, child: Text(l10n.cancel)),
        ),
      );
    }
    final currentNote = note;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PaperBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                DangguiTopBar(
                  leading: DangguiIconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    semanticLabel: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: _saveAndClose,
                  ),
                  actions: <Widget>[
                    DangguiIconButton(
                      icon: Icon(
                        _pinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                      semanticLabel: _pinned ? l10n.unpin : l10n.pin,
                      selected: _pinned,
                      onPressed: () {
                        setState(() => _pinned = !_pinned);
                        _onDraftChanged();
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenu(value, currentNote),
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'copy', child: Text(l10n.copy)),
                        PopupMenuItem(
                          value: 'export',
                          child: Text(l10n.export),
                        ),
                        PopupMenuItem(
                          value: 'task',
                          child: Text(l10n.convertToTask),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                      child: DangguiIconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        semanticLabel: MaterialLocalizations.of(context)
                            .showMenuTooltip,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextField(
                          controller: _titleController,
                          minLines: 1,
                          maxLines: 3,
                          style: Theme.of(context).textTheme.titleLarge,
                          decoration: InputDecoration(
                            hintText: l10n.noteTitleHint,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: _folderId,
                          decoration: InputDecoration(labelText: l10n.folders),
                          items: <DropdownMenuItem<String?>>[
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.uncategorized),
                            ),
                            for (final folder
                                in asyncState.requireValue.folders)
                              DropdownMenuItem<String?>(
                                value: folder.id,
                                child: Text(folder.name),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _folderId = value);
                            _onDraftChanged();
                          },
                        ),
                        const Divider(height: 26),
                        TextField(
                          controller: _bodyController,
                          undoController: _bodyUndoController,
                          minLines: 15,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: l10n.noteBodyHint,
                          ),
                          contextMenuBuilder: (context, editableTextState) {
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: editableTextState.contextMenuAnchors,
                              buttonItems: <ContextMenuButtonItem>[
                                ...editableTextState.contextMenuButtonItems,
                                ContextMenuButtonItem(
                                  label: l10n.convertToTask,
                                  onPressed: _convertSelectionToTask,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: EditorToolbar(
            items: <EditorToolbarItem>[
              EditorToolbarItem(
                icon: const Icon(Icons.format_list_bulleted_rounded),
                semanticLabel: l10n.bulletedList,
                onPressed: () => _insertPrefix('• '),
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.format_list_numbered_rounded),
                semanticLabel: l10n.numberedList,
                onPressed: () => _insertPrefix('1. '),
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.check_box_outlined),
                semanticLabel: l10n.checklist,
                onPressed: _toggleChecklist,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.undo_rounded),
                semanticLabel: l10n.undo,
                onPressed: _bodyUndoController.value.canUndo
                    ? _bodyUndoController.undo
                    : null,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.redo_rounded),
                semanticLabel: l10n.redo,
                onPressed: _bodyUndoController.value.canRedo
                    ? _bodyUndoController.redo
                    : null,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.save_outlined),
                semanticLabel: l10n.save,
                onPressed: () => _flushSave(interactive: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hydrate(NoteViewModel note) {
    _autosaveTimer?.cancel();
    _controllersReady = false;
    _loadedId = note.id;
    _noteTemplate = note;
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _folderId = note.folderId;
    _pinned = note.pinned;
    _pendingDraft = null;
    _nextRevision = 0;
    _persistedRevision = 0;
    _lastObservedSignature = _draftSignature();
    _controllersReady = true;
  }

  Object _draftSignature() =>
      (_titleController.text, _bodyController.text, _folderId, _pinned);

  void _onDraftChanged() {
    if (!_controllersReady || _noteTemplate == null) return;
    final signature = _draftSignature();
    if (signature == _lastObservedSignature) return;
    _lastObservedSignature = signature;
    final revision = ++_nextRevision;
    _pendingDraft = _NoteSaveDraft(
      revision: revision,
      note: _noteTemplate!.copyWith(
        title: _titleController.text,
        body: _bodyController.text,
        folderId: _folderId,
        pinned: _pinned,
      ),
    );
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(widget.autosaveDelay, () {
      unawaited(_startSaveLoop());
    });
  }

  Future<bool> _flushSave({required bool interactive}) {
    _autosaveTimer?.cancel();
    if (interactive) _showSaveErrors = true;
    return _startSaveLoop();
  }

  Future<bool> _startSaveLoop() {
    final currentOperation = _saveOperation;
    if (currentOperation != null) return currentOperation;
    final operation = _runSaveLoop();
    _saveOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_saveOperation, operation)) {
          _saveOperation = null;
          _showSaveErrors = false;
        }
      }),
    );
    return operation;
  }

  Future<bool> _runSaveLoop() async {
    while (true) {
      final draft = _pendingDraft;
      if (draft == null || draft.revision <= _persistedRevision) return true;
      try {
        await _persistDraft(draft);
      } on Object catch (error) {
        if (_showSaveErrors && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
        if (mounted) {
          _autosaveTimer?.cancel();
          _autosaveTimer = Timer(widget.autosaveRetryDelay, () {
            unawaited(_startSaveLoop());
          });
        }
        return false;
      }
      _persistedRevision = draft.revision;
      if (identical(_pendingDraft, draft)) _pendingDraft = null;
    }
  }

  Future<void> _persistDraft(_NoteSaveDraft draft) async {
    final persist = widget.onPersist;
    if (persist != null) {
      await persist(draft.note);
      return;
    }
    await _store.updateNote(draft.note);
  }

  Future<void> _saveAndClose() async {
    if (!await _flushSave(interactive: true)) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  void _insertPrefix(String prefix) {
    final selection = _bodyController.selection;
    final offset = selection.isValid
        ? selection.start
        : _bodyController.text.length;
    final text = _bodyController.text;
    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  void _toggleChecklist() {
    final selection = _bodyController.selection;
    final offset = selection.isValid
        ? selection.start
        : _bodyController.text.length;
    final text = _bodyController.text;
    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    final checked = text.startsWith('☒ ', lineStart);
    final unchecked = text.startsWith('☐ ', lineStart);
    if (checked || unchecked) {
      _bodyController.value = _bodyController.value.replaced(
        TextRange(start: lineStart, end: lineStart + 2),
        checked ? '☐ ' : '☒ ',
      );
      return;
    }
    _insertPrefix('☐ ');
  }

  Future<void> _convertSelectionToTask() async {
    final selection = _bodyController.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final selected = hasSelection
        ? selection.textInside(_bodyController.text)
        : _bodyController.text;
    ContextMenuController.removeAny();
    final lines = selected
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final initialTitle = hasSelection && lines.isNotEmpty
        ? lines.first
        : _titleController.text.trim();
    final initialBody = hasSelection
        ? lines.skip(1).join('\n')
        : _bodyController.text;
    if (initialTitle.isEmpty || !mounted) return;
    final titleController = TextEditingController(text: initialTitle);
    final bodyController = TextEditingController(text: initialBody);
    DateTime? dueDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.convertToTask),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    maxLength: 160,
                    decoration: InputDecoration(hintText: l10n.taskTitleHint),
                  ),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(hintText: l10n.bodyHint),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.dueDate),
                    subtitle: Text(
                      dueDate == null
                          ? l10n.noDate
                          : MaterialLocalizations.of(context)
                                .formatMediumDate(dueDate!),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final value = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? now,
                        firstDate: DateTime(now.year - 10),
                        lastDate: DateTime(now.year + 20),
                      );
                      if (value != null) {
                        setDialogState(() => dueDate = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    final title = titleController.text.trim();
    final body = bodyController.text;
    titleController.dispose();
    bodyController.dispose();
    if (confirmed != true || title.isEmpty || !mounted) return;
    await ref
        .read(appStoreProvider.notifier)
        .createTask(title: title, body: body, dueDate: dueDate);
  }

  Future<void> _handleMenu(String value, NoteViewModel note) async {
    final text = '${_titleController.text}\n\n${_bodyController.text}';
    switch (value) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
      case 'export':
        if (!await _flushSave(interactive: true)) return;
        final result = await ref
            .read(portableExportServiceProvider)
            .export(PortableExportRequest.notesByIds(<String>[note.id]));
        await SharePlus.instance.share(
          ShareParams(
            subject: _titleController.text,
            files: <XFile>[XFile(result.file.path)],
          ),
        );
      case 'task':
        await _convertSelectionToTask();
      case 'delete':
        _autosaveTimer?.cancel();
        _pendingDraft = null;
        await ref.read(appStoreProvider.notifier).deleteNote(note.id);
        if (mounted) {
          setState(() => _allowPop = true);
          context.pop();
        }
    }
  }
}

final class _NoteSaveDraft {
  const _NoteSaveDraft({required this.revision, required this.note});

  final int revision;
  final NoteViewModel note;
}
