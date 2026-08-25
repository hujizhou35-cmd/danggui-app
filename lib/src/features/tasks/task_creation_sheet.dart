import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/theme.dart';
import '../../ui/components/components.dart';

/// The normalized result shared by every task-creation entry point.
final class TaskCreationResult {
  const TaskCreationResult({
    required this.title,
    required this.body,
    required this.dueDate,
    required this.openDetails,
  });

  final String title;
  final String body;
  final DateTime? dueDate;
  final bool openDetails;
}

/// Opens task creation above the shell navigator so the keyboard and the next
/// detail route never belong to different navigators.
Future<TaskCreationResult?> showTaskCreationSheet(
  BuildContext context, {
  String initialTitle = '',
  String initialBody = '',
  bool openDetails = false,
}) {
  return showModalBottomSheet<TaskCreationResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => TaskCreationSheet(
      initialTitle: initialTitle,
      initialBody: initialBody,
      openDetails: openDetails,
    ),
  );
}

/// Releases the editor focus and gives the platform IME a bounded window to
/// clear its inset before a full-screen editor route is pushed.
Future<void> settleTaskCreationKeyboard({
  required BuildContext context,
  Duration timeout = const Duration(milliseconds: 320),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await waitForImeToDismiss(context, timeout: timeout);
}

class TaskCreationSheet extends StatefulWidget {
  const TaskCreationSheet({
    super.key,
    this.initialTitle = '',
    this.initialBody = '',
    this.openDetails = false,
  });

  final String initialTitle;
  final String initialBody;

  /// Makes the primary action continue into the full task editor. The regular
  /// quick-add mode keeps Save as its primary action and exposes a separate
  /// "planning and reminder" action.
  final bool openDetails;

  @override
  State<TaskCreationSheet> createState() => _TaskCreationSheetState();
}

class _TaskCreationSheetState extends State<TaskCreationSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _titleFocusNode;
  late DateTime? _dueDate;

  bool get _showBody =>
      widget.initialTitle.trim().isNotEmpty || widget.initialBody.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _titleFocusNode = FocusNode(debugLabel: 'task-creation-title');
    final now = DateTime.now();
    _dueDate = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.dangguiTheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: tokens.paper2,
        shape: RoundedRectangleBorder(borderRadius: tokens.sheetRadius),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.lineDark,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.quickAdd,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('task-creation-title'),
                controller: _titleController,
                focusNode: _titleFocusNode,
                maxLength: 160,
                textInputAction: _showBody
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: InputDecoration(hintText: l10n.taskTitleHint),
                onSubmitted: _showBody
                    ? null
                    : (_) => _finish(widget.openDetails),
              ),
              if (_showBody) ...<Widget>[
                TextField(
                  key: const Key('task-creation-body'),
                  controller: _bodyController,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(hintText: l10n.bodyHint),
                ),
                const SizedBox(height: 8),
              ],
              const Divider(),
              ListTile(
                key: const Key('task-creation-due-date'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 52,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(l10n.dueDate),
                subtitle: Text(
                  _dueDate == null
                      ? l10n.noDate
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(_dueDate!),
                ),
                onTap: _pickDate,
                trailing: _dueDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        key: const Key('task-creation-clear-due-date'),
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: l10n.noDate,
                      ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  if (!widget.openDetails)
                    TextButton(
                      key: const Key('task-creation-more-settings'),
                      onPressed: () => _finish(true),
                      child: Text(l10n.moreSettingsWithReminder),
                    ),
                  FilledButton(
                    key: const Key('task-creation-save'),
                    onPressed: () => _finish(widget.openDetails),
                    child: Text(
                      widget.openDetails ? l10n.moreSettings : l10n.save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (value != null && mounted) setState(() => _dueDate = value);
  }

  void _finish(bool details) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showDangguiSnackBar(
        context,
        message: AppLocalizations.of(context).taskTitleHint,
      );
      return;
    }
    Navigator.pop(
      context,
      TaskCreationResult(
        title: title,
        body: _bodyController.text,
        dueDate: _dueDate,
        openDetails: details,
      ),
    );
  }
}
