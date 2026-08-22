import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

@immutable
class ExportSheetOption {
  const ExportSheetOption({
    required this.label,
    required this.tag,
    required this.onPressed,
    this.semanticLabel,
    this.enabled = true,
  });

  final String label;
  final String tag;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final bool enabled;
}

/// Shared, content-driven export sheet.
///
/// The sheet caps itself at 85% of the available height and scrolls, avoiding
/// clipped English or Russian labels on compact phones.
class ExportSheet extends StatelessWidget {
  const ExportSheet({
    super.key,
    required this.title,
    required this.options,
    required this.cancelLabel,
    required this.continueLabel,
    required this.onCancel,
    required this.onContinue,
  });

  final String title;
  final List<ExportSheetOption> options;
  final String cancelLabel;
  final String continueLabel;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * .85;
    return Material(
      color: tokens.paper2,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.sheetRadius,
        side: BorderSide(color: tokens.lineDark, width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.lineDark.withAlpha(210),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 10),
                for (final option in options) _ExportOptionTile(option: option),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    TextButton(onPressed: onCancel, child: Text(cancelLabel)),
                    FilledButton(
                      onPressed: onContinue,
                      child: Text(continueLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({required this.option});

  final ExportSheetOption option;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Semantics(
      button: true,
      enabled: option.enabled,
      label: option.semanticLabel ?? option.label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.line)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: option.enabled ? option.onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          option.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.line),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            option.tag,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
