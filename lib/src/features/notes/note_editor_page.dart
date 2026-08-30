import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../domain/models.dart';
import '../../services/export/portable_export_service.dart';
import '../../services/export/temporary_share_artifact.dart';
import '../../ui/components/components.dart';
import '../tasks/task_creation_sheet.dart';

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
    with WidgetsBindingObserver, EditorSaveFeedbackMixin<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  final _bodyUndoController = UndoHistoryController();
  late final AppStoreController _store;
  String? _folderId;
  var _pinned = false;
  var _allowPop = false;
  var _closing = false;
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
  StateConflictException? _versionConflict;

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
    disposeEditorSaveFeedback();
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingDraft != null) {
      unawaited(_startSaveLoop());
    }
    _titleController.removeListener(_onDraftChanged);
    _bodyController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _scrollController.dispose();
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
        _mergeExternalNote(note);
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
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: EditorPageFrame(
          key: const Key('note-editor-page'),
          topBar: DangguiTopBar(
            key: const Key('note-editor-top-bar'),
            leading: DangguiIconButton(
              key: const Key('note-editor-back'),
              icon: const Icon(Icons.arrow_back_rounded),
              semanticLabel: MaterialLocalizations.of(context)
                  .backButtonTooltip,
              onPressed: _saveAndClose,
            ),
            actions: <Widget>[
              DangguiIconButton(
                key: const Key('note-editor-pin'),
                icon: Icon(
                  _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
                semanticLabel: _pinned ? l10n.unpin : l10n.pin,
                selected: _pinned,
                onPressed: () {
                  setState(() => _pinned = !_pinned);
                  _onDraftChanged();
                },
              ),
              PopupMenuButton<String>(
                key: const Key('note-editor-menu'),
                onSelected: (value) => _handleMenu(value, currentNote),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(value: 'copy', child: Text(l10n.copy)),
                  PopupMenuItem(value: 'export', child: Text(l10n.export)),
                  PopupMenuItem(value: 'task', child: Text(l10n.convertToTask)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
                child: DangguiIconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  semanticLabel: MaterialLocalizations.of(context)
                      .showMenuTooltip,
                ),
              ),
            ],
          ),
          editor: DangguiFastScrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_versionConflict != null)
                    _NoteVersionConflictBanner(
                      key: const Key('note-editor-version-conflict'),
                      message: l10n.editorVersionConflict,
                      reloadLabel: l10n.reload,
                      onReload: _reloadAfterVersionConflict,
                    ),
                  TextField(
                    key: const Key('note-editor-title'),
                    controller: _titleController,
                    minLines: 1,
                    maxLines: 3,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: InputDecoration(hintText: l10n.noteTitleHint),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: const Key('note-editor-folder'),
                    initialValue: _folderId,
                    decoration: InputDecoration(labelText: l10n.folders),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.uncategorized),
                      ),
                      for (final folder in asyncState.requireValue.folders)
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
                    key: const Key('note-editor-body'),
                    controller: _bodyController,
                    undoController: _bodyUndoController,
                    minLines: 15,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(hintText: l10n.noteBodyHint),
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
          toolbar: EditorToolbar(
            key: const Key('note-editor-toolbar'),
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
                icon: editorSaveFeedbackIcon(
                  key: const Key('note-editor-save'),
                ),
                semanticLabel: l10n.save,
                onPressed: editorSaveInProgress
                    ? null
                    : () {
                        unawaited(
                          runEditorManualSave(
                            flush: () => _flushSave(interactive: true),
                            savedLabel: l10n.saved,
                          ),
                        );
                      },
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
    _versionConflict = null;
    _showSaveErrors = false;
    _lastObservedSignature = _draftSignature();
    _controllersReady = true;
  }

  void _mergeExternalNote(NoteViewModel note) {
    final template = _noteTemplate;
    if (template == null) {
      _hydrate(note);
      return;
    }
    if (note.rowVersion == template.rowVersion) {
      _noteTemplate = note;
      return;
    }
    if (_saveOperation != null) return;
    if (_pendingDraft != null) {
      _autosaveTimer?.cancel();
      _versionConflict ??= const StateConflictException(
        '笔记已在其他操作中更新，请重新加载后再编辑。',
      );
      return;
    }
    _hydrate(note);
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
    if (_versionConflict != null) return;
    _autosaveTimer = Timer(widget.autosaveDelay, () {
      unawaited(_startSaveLoop());
    });
  }

  Future<bool> _flushSave({required bool interactive}) {
    _autosaveTimer?.cancel();
    if (interactive) _showSaveErrors = true;
    final conflict = _versionConflict;
    if (conflict != null) {
      if (interactive && mounted) {
        showDangguiSnackBar(
          context,
          message: AppLocalizations.of(context).editorVersionConflict,
          duration: dangguiSnackBarErrorDuration,
        );
      }
      return Future<bool>.value(false);
    }
    return _startSaveLoop();
  }

  Future<bool> _startSaveLoop() {
    if (_versionConflict != null) return Future<bool>.value(false);
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
      } on StateConflictException catch (error) {
        _autosaveTimer?.cancel();
        _versionConflict = error;
        if (mounted) {
          setState(() {});
          showDangguiSnackBar(
            context,
            message: AppLocalizations.of(context).editorVersionConflict,
            duration: dangguiSnackBarErrorDuration,
          );
        }
        return false;
      } on Object catch (error) {
        if (_showSaveErrors && mounted) {
          showDangguiSnackBar(
            context,
            message: error.toString(),
            duration: dangguiSnackBarErrorDuration,
          );
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
    } else {
      await _store.updateNote(draft.note);
    }
    // A test or embedding callback may delegate to the real AppStore. Rebase
    // from the authoritative provider after either persistence path so a
    // second draft captured during the first write receives the committed
    // rowVersion instead of retrying forever with a stale CAS token.
    _rebaseAfterOwnNoteSave(draft);
  }

  void _rebaseAfterOwnNoteSave(_NoteSaveDraft committedDraft) {
    NoteViewModel? latest;
    for (final candidate
        in ref.read(appStoreProvider).value?.notes ?? const <NoteViewModel>[]) {
      if (candidate.id == widget.noteId) latest = candidate;
    }
    if (latest == null || latest.rowVersion <= committedDraft.note.rowVersion) {
      return;
    }
    _noteTemplate = latest;
    final pending = _pendingDraft;
    if (pending != null && pending.revision > committedDraft.revision) {
      _pendingDraft = _NoteSaveDraft(
        revision: pending.revision,
        note: pending.note.copyWith(rowVersion: latest.rowVersion),
      );
    }
  }

  void _reloadAfterVersionConflict() {
    NoteViewModel? latest;
    for (final candidate
        in ref.read(appStoreProvider).value?.notes ?? const <NoteViewModel>[]) {
      if (candidate.id == widget.noteId) latest = candidate;
    }
    if (latest == null) return;
    setState(() => _hydrate(latest!));
  }

  Future<void> _saveAndClose() async {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await _flushSave(interactive: true)) {
      _closing = false;
      return;
    }
    if (!mounted) return;
    await _closeRouteAfterPopBarrier();
  }

  Future<void> _closeRouteAfterPopBarrier() async {
    if (!mounted) return;
    final editorRoute = ModalRoute.of(context);
    setState(() => _allowPop = true);
    await waitForEditorRoutePopBarrier();
    if (mounted && (editorRoute == null || editorRoute.isCurrent)) {
      context.pop();
    }
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
    final result = await showTaskCreationSheet(
      context,
      initialTitle: initialTitle,
      initialBody: initialBody,
    );
    if (result == null || !mounted) return;
    if (!await _flushSave(interactive: true) || !mounted) return;
    final taskId = await ref
        .read(appStoreProvider.notifier)
        .createTask(
          title: result.title,
          body: result.body,
          dueDate: result.dueDate,
        );
    if (result.openDetails && mounted) {
      await settleTaskCreationKeyboard(context: context);
      if (mounted) await context.push('/tasks/$taskId');
    }
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
        await withDangguiTemporaryShareArtifact(
          file: result.file,
          action: () async {
            if (!mounted) return;
            await SharePlus.instance.share(
              ShareParams(
                subject: _titleController.text,
                files: <XFile>[XFile(result.file.path)],
              ),
            );
          },
        );
      case 'task':
        await _convertSelectionToTask();
      case 'delete':
        _autosaveTimer?.cancel();
        _pendingDraft = null;
        await ref.read(appStoreProvider.notifier).deleteNote(note.id);
        await _closeRouteAfterPopBarrier();
    }
  }
}

final class _NoteSaveDraft {
  const _NoteSaveDraft({required this.revision, required this.note});

  final int revision;
  final NoteViewModel note;
}

class _NoteVersionConflictBanner extends StatelessWidget {
  const _NoteVersionConflictBanner({
    super.key,
    required this.message,
    required this.reloadLabel,
    required this.onReload,
  });

  final String message;
  final String reloadLabel;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onReload, child: Text(reloadLabel)),
        ],
      ),
    );
  }
}
