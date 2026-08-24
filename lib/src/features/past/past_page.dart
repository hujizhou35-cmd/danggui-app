import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../domain/models.dart';
import '../../services/export/portable_export_service.dart';
import '../../ui/components/components.dart';
import '../tasks/task_creation_sheet.dart';

class PastPage extends ConsumerStatefulWidget {
  const PastPage({
    super.key,
    this.autosaveDelay = const Duration(milliseconds: 650),
    this.autosaveRetryDelay = const Duration(seconds: 2),
    this.onPersist,
  });

  final Duration autosaveDelay;
  final Duration autosaveRetryDelay;
  final Future<void> Function(String text)? onPersist;

  @override
  ConsumerState<PastPage> createState() => _PastPageState();
}

class _PastPageState extends ConsumerState<PastPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _documentController = TextEditingController();
  final _focusNode = FocusNode();
  final _undoController = UndoHistoryController();
  late final AppStoreController _store;
  late final Future<void> Function(String text) _persist;
  late final Duration _autosaveDelay;
  late final Duration _autosaveRetryDelay;
  Timer? _autosaveTimer;
  _PastSaveDraft? _pendingDraft;
  Future<bool>? _saveOperation;
  String _persistedText = '';
  String _lastObservedText = '';
  var _nextRevision = 0;
  var _persistedRevision = 0;
  var _initialized = false;
  var _isForeground = true;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(appStoreProvider.notifier);
    _persist = widget.onPersist ?? _store.replacePastDocumentText;
    _autosaveDelay = widget.autosaveDelay;
    _autosaveRetryDelay = widget.autosaveRetryDelay;
    _isForeground = switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached => false,
      _ => true,
    };
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChanged);
    _undoController.addListener(_refreshToolbar);
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _undoController.removeListener(_refreshToolbar);
    // The latest immutable draft was captured by _onDocumentChanged. Start a
    // best-effort write before disposing the controllers; the save loop only
    // uses the cached persistence callback and never reads ref or UI state.
    if (_pendingDraft != null) unawaited(_startSaveLoop());
    _searchController.dispose();
    _documentController.dispose();
    _focusNode.dispose();
    _undoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      if (_pendingDraft != null) unawaited(_startSaveLoop());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _autosaveTimer?.cancel();
      unawaited(_startSaveLoop());
    }
  }

  void _refreshToolbar() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) unawaited(_flushSave());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(appStoreProvider);
    if (asyncState.hasValue) {
      _synchronizeDocument(asyncState.requireValue.pastBlocks);
    }
    return EditorPageFrame(
      key: const Key('past-editor-page'),
      includeBottomSafeArea: false,
      topBar: DangguiTopBar(
        key: const Key('past-editor-top-bar'),
        content: TextField(
          key: const Key('past-search-field'),
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          textInputAction: TextInputAction.search,
          onChanged: _locateQuery,
        ),
        actions: <Widget>[
          DangguiIconButton(
            icon: const Icon(Icons.ios_share_rounded),
            semanticLabel: l10n.export,
            onPressed: asyncState.hasValue
                ? () => _showExport(asyncState.requireValue.pastBlocks)
                : null,
          ),
          DangguiIconButton(
            icon: const Icon(Icons.add_rounded),
            semanticLabel: l10n.addPastText,
            onPressed: _appendParagraph,
          ),
        ],
      ),
      editor: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.bootstrapError)),
        data: (state) => _buildDocumentEditor(l10n),
      ),
      toolbar: EditorToolbar(
        key: const Key('past-editor-toolbar'),
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
            onPressed: () => _insertPrefix('☐ '),
          ),
          EditorToolbarItem(
            icon: const Icon(Icons.undo_rounded),
            semanticLabel: l10n.undo,
            onPressed: _undoController.value.canUndo
                ? _undoController.undo
                : null,
          ),
          EditorToolbarItem(
            icon: const Icon(Icons.redo_rounded),
            semanticLabel: l10n.redo,
            onPressed: _undoController.value.canRedo
                ? _undoController.redo
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentEditor(AppLocalizations l10n) {
    return Semantics(
      textField: true,
      multiline: true,
      label: l10n.pastTitle,
      child: TextField(
        key: const Key('past-continuous-document-editor'),
        controller: _documentController,
        focusNode: _focusNode,
        undoController: _undoController,
        expands: true,
        minLines: null,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        scrollPadding: const EdgeInsets.only(bottom: 120),
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: l10n.emptyPastHint,
          contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
        ),
        onChanged: _onDocumentChanged,
        contextMenuBuilder: (context, editableTextState) {
          final items = <ContextMenuButtonItem>[
            ...editableTextState.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: l10n.convertToTask,
              onPressed: () {
                final selected = _selectedText();
                ContextMenuController.removeAny();
                unawaited(_convertToTask(selected));
              },
            ),
          ];
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: items,
          );
        },
      ),
    );
  }

  void _synchronizeDocument(List<PastBlockViewModel> blocks) {
    final serialized = _serializeBlocks(blocks);
    if (!_initialized) {
      _initialized = true;
      _persistedText = serialized;
      _lastObservedText = serialized;
      _documentController.value = TextEditingValue(
        text: serialized,
        selection: TextSelection.collapsed(offset: serialized.length),
      );
      return;
    }
    final hasLocalChanges =
        _pendingDraft != null || _documentController.text != _persistedText;
    if (!_focusNode.hasFocus &&
        !hasLocalChanges &&
        serialized != _persistedText) {
      _persistedText = serialized;
      _lastObservedText = serialized;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusNode.hasFocus) return;
        _documentController.value = TextEditingValue(
          text: serialized,
          selection: TextSelection.collapsed(offset: serialized.length),
        );
      });
    }
  }

  void _onDocumentChanged(String value) {
    if (!_initialized || value == _lastObservedText) return;
    _lastObservedText = value;
    _pendingDraft = _PastSaveDraft(revision: ++_nextRevision, text: value);
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      unawaited(_startSaveLoop());
    });
  }

  Future<bool> _flushSave() {
    _autosaveTimer?.cancel();
    return _startSaveLoop();
  }

  Future<bool> _startSaveLoop() {
    final currentOperation = _saveOperation;
    if (currentOperation != null) return currentOperation;
    final operation = _runSaveLoop();
    _saveOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_saveOperation, operation)) _saveOperation = null;
      }),
    );
    return operation;
  }

  Future<bool> _runSaveLoop() async {
    while (true) {
      final draft = _pendingDraft;
      if (draft == null || draft.revision <= _persistedRevision) return true;
      try {
        await _persist(draft.text);
      } on Object catch (error) {
        // Keep the failed draft intact. Background failures are retried when
        // the app resumes; foreground failures also receive a bounded retry.
        if (!_disposed && _isForeground) {
          if (mounted && Scaffold.maybeOf(context) != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
          }
          _autosaveTimer?.cancel();
          _autosaveTimer = Timer(_autosaveRetryDelay, () {
            unawaited(_startSaveLoop());
          });
        }
        return false;
      }
      _persistedRevision = draft.revision;
      _persistedText = draft.text;
      if (identical(_pendingDraft, draft)) _pendingDraft = null;
      // If editing continued during the awaited write, loop immediately and
      // persist the newer revision serially so the old value cannot win.
    }
  }

  void _locateQuery(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;
    final start = _documentController.text.toLowerCase().indexOf(query);
    if (start < 0) return;
    _focusNode.requestFocus();
    _documentController.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + query.length,
    );
  }

  void _appendParagraph() {
    _focusNode.requestFocus();
    final selection = _safeSelection();
    final insertion = _documentController.text.isEmpty ? '' : '\n\n';
    _documentController.value = _documentController.value.replaced(
      selection,
      insertion,
    );
    _onDocumentChanged(_documentController.text);
  }

  void _insertPrefix(String prefix) {
    _focusNode.requestFocus();
    final selection = _safeSelection();
    final text = _documentController.text;
    final lineStart =
        text.lastIndexOf('\n', selection.start > 0 ? selection.start - 1 : 0) +
        1;
    _documentController.value = _documentController.value.replaced(
      TextSelection.collapsed(offset: lineStart),
      prefix,
    );
    _onDocumentChanged(_documentController.text);
  }

  TextSelection _safeSelection() {
    final selection = _documentController.selection;
    if (selection.isValid) return selection;
    return TextSelection.collapsed(offset: _documentController.text.length);
  }

  String _selectedText() {
    final selection = _safeSelection();
    if (!selection.isCollapsed) {
      return selection.textInside(_documentController.text);
    }
    final text = _documentController.text;
    final before =
        text.lastIndexOf('\n', selection.start > 0 ? selection.start - 1 : 0) +
        1;
    final after = text.indexOf('\n', selection.start);
    return text.substring(before, after < 0 ? text.length : after);
  }

  Future<void> _convertToTask(String source) async {
    final lines = source
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty || !mounted) return;
    final result = await showTaskCreationSheet(
      context,
      initialTitle: lines.first,
      initialBody: lines.skip(1).join('\n'),
    );
    if (result == null || !mounted) return;
    if (!await _flushSave() || !mounted) return;
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).addTask)),
      );
    }
  }

  Future<void> _showExport(List<PastBlockViewModel> blocks) async {
    final l10n = AppLocalizations.of(context);
    var selected = 'all';
    var confirmed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ExportSheet(
        title: l10n.export,
        cancelLabel: l10n.cancel,
        continueLabel: l10n.export,
        onCancel: () => Navigator.pop(sheetContext),
        onContinue: () {
          confirmed = true;
          Navigator.pop(sheetContext);
        },
        options: <ExportSheetOption>[
          ExportSheetOption(
            label: l10n.exportAll,
            tag: 'ZIP',
            onPressed: () => selected = 'all',
          ),
          ExportSheetOption(
            label: l10n.exportRange,
            tag: 'ZIP',
            onPressed: () => selected = 'range',
          ),
          ExportSheetOption(
            label: l10n.exportSelection,
            tag: 'ZIP',
            onPressed: () => selected = 'selection',
          ),
        ],
      ),
    );
    if (!confirmed || !mounted) return;

    late final PortableExportRequest request;
    if (selected == 'selection') {
      final text = _selectedText().trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.helpNoResults)));
        return;
      }
      request = PortableExportRequest.pastSelection(text);
    } else if (selected == 'range') {
      final datedBlocks =
          blocks
              .where((block) => block.type == DocumentBlockType.pastDate)
              .map((block) => DateTime.tryParse(block.text))
              .whereType<DateTime>()
              .toList(growable: true)
            ..sort();
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: datedBlocks.isEmpty
            ? DateTime(now.year - 10)
            : datedBlocks.first,
        lastDate: datedBlocks.isEmpty
            ? DateTime(now.year + 10)
            : datedBlocks.last,
        initialDateRange: datedBlocks.isEmpty
            ? null
            : DateTimeRange(start: datedBlocks.first, end: datedBlocks.last),
      );
      if (range == null || !mounted) return;
      request = PortableExportRequest.pastDateRange(
        startLocalDate: _isoLocalDate(range.start),
        endLocalDate: _isoLocalDate(range.end),
      );
    } else {
      request = PortableExportRequest.pastAll();
    }
    final result = await ref
        .read(portableExportServiceProvider)
        .export(request);
    await SharePlus.instance.share(
      ShareParams(
        subject: l10n.pastTitle,
        files: <XFile>[XFile(result.file.path)],
      ),
    );
  }
}

String _isoLocalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _serializeBlocks(List<PastBlockViewModel> blocks) {
  var number = 0;
  return blocks
      .map((block) {
        return switch (block.type) {
          DocumentBlockType.bullet => '• ${block.text}',
          DocumentBlockType.numbered => '${++number}. ${block.text}',
          DocumentBlockType.checklist =>
            '${block.isChecked == true ? '☒' : '☐'} ${block.text}',
          _ => block.text,
        };
      })
      .join('\n\n');
}

final class _PastSaveDraft {
  const _PastSaveDraft({required this.revision, required this.text});

  final int revision;
  final String text;
}
