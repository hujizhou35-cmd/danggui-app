enum HelpBlockType { heading, paragraph, bullet, numbered }

final class HelpBlock {
  const HelpBlock({required this.type, required this.text, this.ordinal});

  final HelpBlockType type;
  final String text;
  final int? ordinal;
}

final class HelpSection {
  const HelpSection({required this.title, required this.blocks});

  final String title;
  final List<HelpBlock> blocks;

  String get searchableText => <String>[
    title,
    for (final block in blocks) block.text,
  ].join('\n').toLowerCase();
}

/// Small, deliberately limited Markdown model for the bundled operation guide.
///
/// It supports exactly the constructs used by `assets/help`: document and
/// section headings, subheadings, paragraphs, bullets, and numbered steps.
/// There is no HTML, image, link, or network loader in this feature.
final class HelpDocument {
  const HelpDocument({
    required this.title,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String introduction;
  final List<HelpSection> sections;

  static final _numbered = RegExp(r'^(\d+)\.\s+(.+)$');

  factory HelpDocument.parse(String markdown) {
    var title = '';
    final introduction = <String>[];
    final sections = <HelpSection>[];
    String? sectionTitle;
    var blocks = <HelpBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join(' ').trim();
      if (text.isNotEmpty) {
        if (sectionTitle == null) {
          introduction.add(text);
        } else {
          blocks.add(HelpBlock(type: HelpBlockType.paragraph, text: text));
        }
      }
      paragraph.clear();
    }

    void flushSection() {
      flushParagraph();
      if (sectionTitle == null) return;
      sections.add(
        HelpSection(
          title: sectionTitle,
          blocks: List<HelpBlock>.unmodifiable(blocks),
        ),
      );
      blocks = <HelpBlock>[];
    }

    for (final rawLine in markdown.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (line.startsWith('# ')) {
        flushParagraph();
        title = line.substring(2).trim();
        continue;
      }
      if (line.startsWith('## ')) {
        flushSection();
        sectionTitle = line.substring(3).trim();
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        blocks.add(
          HelpBlock(
            type: HelpBlockType.heading,
            text: line.substring(4).trim(),
          ),
        );
        continue;
      }
      if (line.startsWith('- ')) {
        flushParagraph();
        blocks.add(
          HelpBlock(type: HelpBlockType.bullet, text: line.substring(2).trim()),
        );
        continue;
      }
      final numbered = _numbered.firstMatch(line);
      if (numbered != null) {
        flushParagraph();
        blocks.add(
          HelpBlock(
            type: HelpBlockType.numbered,
            text: numbered.group(2)!.trim(),
            ordinal: int.parse(numbered.group(1)!),
          ),
        );
        continue;
      }
      paragraph.add(line);
    }
    flushSection();
    if (sectionTitle == null) flushParagraph();

    return HelpDocument(
      title: title,
      introduction: introduction.join('\n\n'),
      sections: List<HelpSection>.unmodifiable(sections),
    );
  }

  HelpDocument search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return this;
    final matchingSections = <HelpSection>[];
    for (final section in sections) {
      if (section.title.toLowerCase().contains(needle)) {
        matchingSections.add(section);
        continue;
      }
      final matchingBlocks = section.blocks
          .where((block) => block.text.toLowerCase().contains(needle))
          .toList(growable: false);
      if (matchingBlocks.isNotEmpty) {
        matchingSections.add(
          HelpSection(title: section.title, blocks: matchingBlocks),
        );
      }
    }
    return HelpDocument(
      title: title,
      introduction: introduction.toLowerCase().contains(needle)
          ? introduction
          : '',
      sections: List<HelpSection>.unmodifiable(matchingSections),
    );
  }
}
