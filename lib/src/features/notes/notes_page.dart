import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../core/theme/theme.dart';
import '../../services/export/portable_export_service.dart';
import '../../ui/components/components.dart';
import '../tasks/task_creation_sheet.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  String? _folderId;
  var _unfiledOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(appStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              DangguiTopBar(
                content: _selectedIds.isEmpty
                    ? TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.search,
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      )
                    : Text(
                        '${_selectedIds.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                actions: _selectedIds.isEmpty
                    ? <Widget>[
                        DangguiIconButton(
                          icon: const Icon(Icons.create_new_folder_outlined),
                          semanticLabel: l10n.newFolder,
                          onPressed: _createFolder,
                        ),
                        DangguiIconButton(
                          icon: const Icon(Icons.add_rounded),
                          semanticLabel: l10n.newNote,
                          onPressed: _createNote,
                        ),
                      ]
                    : <Widget>[
                        if (_selectedIds.length == 1)
                          DangguiIconButton(
                            icon: const Icon(Icons.task_alt_rounded),
                            semanticLabel: l10n.convertToTask,
                            onPressed: asyncState.hasValue
                                ? () =>
                                      _convertSelected(asyncState.requireValue)
                                : null,
                          ),
                        DangguiIconButton(
                          icon: const Icon(Icons.drive_file_move_outline),
                          semanticLabel: l10n.folders,
                          onPressed: asyncState.hasValue
                              ? () => _moveSelected(asyncState.requireValue)
                              : null,
                        ),
                        DangguiIconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          semanticLabel: l10n.export,
                          onPressed: asyncState.hasValue
                              ? () => _exportSelected(asyncState.requireValue)
                              : null,
                        ),
                        DangguiIconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          semanticLabel: l10n.delete,
                          onPressed: asyncState.hasValue
                              ? () => _deleteSelected(asyncState.requireValue)
                              : null,
                        ),
                        DangguiIconButton(
                          icon: const Icon(Icons.close_rounded),
                          semanticLabel: l10n.cancel,
                          onPressed: () => setState(_selectedIds.clear),
                        ),
                      ],
              ),
              if (asyncState.hasValue)
                SizedBox(
                  // Five vertical pixels on each side leave a full 44dp
                  // touch target for every folder filter.
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 5,
                    ),
                    children: <Widget>[
                      _FolderChip(
                        label: l10n.allNotes,
                        selected: _folderId == null && !_unfiledOnly,
                        onTap: () => setState(() {
                          _folderId = null;
                          _unfiledOnly = false;
                        }),
                      ),
                      _FolderChip(
                        label: l10n.uncategorized,
                        selected: _unfiledOnly,
                        onTap: () => setState(() {
                          _folderId = null;
                          _unfiledOnly = true;
                        }),
                      ),
                      for (final folder in asyncState.requireValue.folders)
                        _FolderChip(
                          label: folder.name,
                          selected: _folderId == folder.id,
                          onTap: () => setState(() {
                            _folderId = folder.id;
                            _unfiledOnly = false;
                          }),
                          onLongPress: () => _deleteFolder(folder),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: asyncState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text(l10n.bootstrapError)),
                  data: (state) {
                    final notes = _filter(state.notes);
                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 54,
                              color: context.dangguiTheme.sage,
                            ),
                            const SizedBox(height: 12),
                            Text(l10n.noNotes),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      key: const PageStorageKey<String>('notes-list'),
                      padding: const EdgeInsets.fromLTRB(17, 5, 17, 25),
                      itemCount: notes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Dismissible(
                          key: ValueKey<String>(note.id),
                          direction: _selectedIds.isEmpty
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: context.dangguiTheme.terraSoft,
                            child: Icon(
                              Icons.delete_outline,
                              color: context.dangguiTheme.terra,
                            ),
                          ),
                          onDismissed: (_) => ref
                              .read(appStoreProvider.notifier)
                              .deleteNote(note.id),
                          child: SketchCard(
                            alternate: index.isOdd,
                            selected: _selectedIds.contains(note.id),
                            onTap: () => _selectedIds.isEmpty
                                ? context.push('/notes/${note.id}')
                                : _toggleSelection(note.id),
                            onLongPress: () => _toggleSelection(note.id),
                            semanticLabel: note.title,
                            padding: const EdgeInsets.fromLTRB(17, 14, 17, 13),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          if (_selectedIds.contains(
                                            note.id,
                                          )) ...<Widget>[
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 18,
                                              color: context.dangguiTheme.sage,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          if (note.pinned) ...<Widget>[
                                            Icon(
                                              Icons.push_pin_rounded,
                                              size: 16,
                                              color: context.dangguiTheme.sage,
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Expanded(
                                            child: Text(
                                              note.title.isEmpty
                                                  ? l10n.noteTitleHint
                                                  : note.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        note.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat.Md(
                                    Localizations.localeOf(context)
                                        .toLanguageTag(),
                                  ).format(note.updatedAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<NoteViewModel> _filter(List<NoteViewModel> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source
        .where((note) {
          if (_folderId != null && note.folderId != _folderId) return false;
          if (_unfiledOnly && note.folderId != null) return false;
          return query.isEmpty ||
              note.title.toLowerCase().contains(query) ||
              note.body.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  void _toggleSelection(String noteId) {
    setState(() {
      if (!_selectedIds.add(noteId)) _selectedIds.remove(noteId);
    });
  }

  List<NoteViewModel> _selectedNotes(DangguiAppState state) => state.notes
      .where((note) => _selectedIds.contains(note.id))
      .toList(growable: false);

  Future<void> _moveSelected(DangguiAppState state) async {
    final l10n = AppLocalizations.of(context);
    final folderId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: <Widget>[
          ListTile(
            title: Text(l10n.uncategorized),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final folder in state.folders)
            ListTile(
              title: Text(folder.name),
              onTap: () => Navigator.pop(context, folder.id),
            ),
        ],
      ),
    );
    if (folderId == null || !mounted) return;
    for (final note in _selectedNotes(state)) {
      await ref
          .read(appStoreProvider.notifier)
          .updateNote(
            note.copyWith(folderId: folderId.isEmpty ? null : folderId),
          );
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _exportSelected(DangguiAppState state) async {
    final notes = _selectedNotes(state);
    if (notes.isEmpty) return;
    final subject = AppLocalizations.of(context).notesTitle;
    final result = await ref
        .read(portableExportServiceProvider)
        .export(PortableExportRequest.notesByIds(notes.map((note) => note.id)));
    await SharePlus.instance.share(
      ShareParams(subject: subject, files: <XFile>[XFile(result.file.path)]),
    );
  }

  Future<void> _deleteSelected(DangguiAppState state) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.retentionHint),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final note in _selectedNotes(state)) {
      await ref.read(appStoreProvider.notifier).deleteNote(note.id);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _convertSelected(DangguiAppState state) async {
    final notes = _selectedNotes(state);
    if (notes.length != 1) return;
    final note = notes.single;
    final result = await showTaskCreationSheet(
      context,
      initialTitle: note.title,
      initialBody: note.body,
    );
    if (result == null || !mounted) return;
    final taskId = await ref
        .read(appStoreProvider.notifier)
        .createTask(
          title: result.title,
          body: result.body,
          dueDate: result.dueDate,
        );
    if (!mounted) return;
    setState(_selectedIds.clear);
    if (result.openDetails) {
      await settleTaskCreationKeyboard(context: context);
      if (mounted) await context.push('/tasks/$taskId');
    }
  }

  Future<void> _createNote() async {
    final id = await ref
        .read(appStoreProvider.notifier)
        .createNote(folderId: _folderId);
    if (mounted) await context.push('/notes/$id');
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).newFolder),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(appStoreProvider.notifier).createFolder(name);
    }
  }

  Future<void> _deleteFolder(FolderViewModel folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(folder.name),
        content: Text(AppLocalizations.of(context).retentionHint),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appStoreProvider.notifier).deleteFolder(folder.id);
      if (_folderId == folder.id) setState(() => _folderId = null);
    }
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        onLongPress: onLongPress,
        excludeSemantics: true,
        child: Material(
          color: selected ? tokens.sageSoft : tokens.paper2.withAlpha(190),
          shape: StadiumBorder(side: BorderSide(color: tokens.lineDark)),
          child: InkWell(
            excludeFromSemantics: true,
            customBorder: const StadiumBorder(),
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(child: Text(label)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
