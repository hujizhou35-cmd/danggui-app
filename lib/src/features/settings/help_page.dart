import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/theme/theme.dart';
import '../../ui/components/components.dart';
import 'help_document.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _searchController = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};
  Future<HelpDocument>? _document;
  String? _assetLanguage;
  var _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = _supportedAssetLanguage(
      Localizations.localeOf(context).languageCode,
    );
    if (_assetLanguage != language) {
      _assetLanguage = language;
      _document = _loadDocument(language);
      _sectionKeys.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              DangguiTopBar(
                leading: DangguiIconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  semanticLabel: MaterialLocalizations.of(context)
                      .backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                content: Text(
                  l10n.helpTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.dangguiTheme.pageHorizontalPadding,
                ),
                child: _HelpSearchField(
                  controller: _searchController,
                  hint: l10n.helpSearchHint,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<HelpDocument>(
                  future: _document,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _HelpLoadError(
                        label: l10n.bootstrapError,
                        retryLabel: l10n.retry,
                        onRetry: () => setState(() {
                          _document = _loadDocument(_assetLanguage ?? 'zh');
                        }),
                      );
                    }
                    final source = snapshot.requireData;
                    final result = source.search(_query);
                    if (result.sections.isEmpty &&
                        result.introduction.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.helpNoResults,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.dangguiTheme.muted),
                          ),
                        ),
                      );
                    }
                    return _HelpDocumentView(
                      document: result,
                      tableOfContents: _query.trim().isEmpty
                          ? source.sections
                          : const <HelpSection>[],
                      query: _query,
                      sectionKeys: _sectionKeys,
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

  Future<HelpDocument> _loadDocument(String language) async {
    final source = await rootBundle.loadString('assets/help/help_$language.md');
    return HelpDocument.parse(source);
  }

  static String _supportedAssetLanguage(String language) =>
      const <String>{'zh', 'en', 'ja', 'ru'}.contains(language)
      ? language
      : 'zh';
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paper2.withAlpha(190),
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.elliptical(17, 16),
          topRight: const Radius.elliptical(14, 19),
          bottomRight: const Radius.elliptical(18, 14),
          bottomLeft: const Radius.elliptical(15, 18),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _HelpDocumentView extends StatelessWidget {
  const _HelpDocumentView({
    required this.document,
    required this.tableOfContents,
    required this.query,
    required this.sectionKeys,
  });

  final HelpDocument document;
  final List<HelpSection> tableOfContents;
  final String query;
  final Map<String, GlobalKey> sectionKeys;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (document.introduction.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
          child: _SelectableHelpText(
            text: document.introduction,
            query: query,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    for (final section in document.sections) {
      final key = sectionKeys.putIfAbsent(section.title, GlobalKey.new);
      children.add(_HelpSectionView(key: key, section: section, query: query));
    }

    return Column(
      children: <Widget>[
        if (tableOfContents.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: context.dangguiTheme.pageHorizontalPadding,
                vertical: 4,
              ),
              itemCount: tableOfContents.length,
              separatorBuilder: (context, index) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final title = tableOfContents[index].title;
                return ActionChip(
                  label: Text(title),
                  onPressed: () {
                    final target = sectionKeys[title]?.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: .04,
                      );
                    }
                  },
                );
              },
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey<String>('help-document'),
            padding: EdgeInsets.fromLTRB(
              context.dangguiTheme.pageHorizontalPadding,
              8,
              context.dangguiTheme.pageHorizontalPadding,
              32,
            ),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpSectionView extends StatelessWidget {
  const _HelpSectionView({
    super.key,
    required this.section,
    required this.query,
  });

  final HelpSection section;
  final String query;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SelectableHelpText(
            text: section.title,
            query: query,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 20, color: tokens.ink),
          ),
          const SizedBox(height: 10),
          for (final block in section.blocks)
            _HelpBlockView(block: block, query: query),
        ],
      ),
    );
  }
}

class _HelpBlockView extends StatelessWidget {
  const _HelpBlockView({required this.block, required this.query});

  final HelpBlock block;
  final String query;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(height: 1.75);
    switch (block.type) {
      case HelpBlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: _SelectableHelpText(
            text: block.text,
            query: query,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 16),
          ),
        );
      case HelpBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _SelectableHelpText(
            text: block.text,
            query: query,
            style: bodyStyle,
          ),
        );
      case HelpBlockType.bullet:
      case HelpBlockType.numbered:
        final marker = block.type == HelpBlockType.bullet
            ? '•'
            : '${block.ordinal}.';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Text(
                  marker,
                  style: bodyStyle?.copyWith(
                    color: tokens.brown,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _SelectableHelpText(
                  text: block.text,
                  query: query,
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _SelectableHelpText extends StatelessWidget {
  const _SelectableHelpText({
    required this.text,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cleanText = text.replaceAll('`', '');
    final needle = query.trim();
    if (needle.isEmpty) return Text(cleanText, style: style);
    final lowerText = cleanText.toLowerCase();
    final lowerNeedle = needle.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    while (true) {
      final match = lowerText.indexOf(lowerNeedle, start);
      if (match < 0) {
        spans.add(TextSpan(text: cleanText.substring(start)));
        break;
      }
      if (match > start) {
        spans.add(TextSpan(text: cleanText.substring(start, match)));
      }
      spans.add(
        TextSpan(
          text: cleanText.substring(match, match + needle.length),
          style: TextStyle(
            backgroundColor: context.dangguiTheme.sageSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = match + needle.length;
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _HelpLoadError extends StatelessWidget {
  const _HelpLoadError({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
