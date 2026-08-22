import 'package:danggui/src/features/settings/help_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = '''
# Operation guide

Everything stays on this device.

## Tasks

### Create a task

1. Tap add.
2. Enter a title.

- Dates are optional.

Long paragraphs can span
multiple source lines.

## Notes

Write and organize notes offline.
''';

  test('parses the limited bundled-help Markdown vocabulary', () {
    final document = HelpDocument.parse(source);

    expect(document.title, 'Operation guide');
    expect(document.introduction, 'Everything stays on this device.');
    expect(document.sections, hasLength(2));
    expect(document.sections.first.title, 'Tasks');
    expect(
      document.sections.first.blocks.map((block) => block.type),
      <HelpBlockType>[
        HelpBlockType.heading,
        HelpBlockType.numbered,
        HelpBlockType.numbered,
        HelpBlockType.bullet,
        HelpBlockType.paragraph,
      ],
    );
    expect(document.sections.first.blocks[1].ordinal, 1);
    expect(
      document.sections.first.blocks.last.text,
      'Long paragraphs can span multiple source lines.',
    );
  });

  test('search keeps only matching blocks while retaining their section', () {
    final document = HelpDocument.parse(source);

    final result = document.search('optional');
    expect(result.introduction, isEmpty);
    expect(result.sections, hasLength(1));
    expect(result.sections.single.title, 'Tasks');
    expect(result.sections.single.blocks, hasLength(1));
    expect(result.sections.single.blocks.single.text, 'Dates are optional.');
  });

  test('section-title and introduction search remain useful', () {
    final document = HelpDocument.parse(source);

    expect(document.search('notes').sections.single.blocks, hasLength(1));
    expect(
      document.search('device').introduction,
      'Everything stays on this device.',
    );
    expect(document.search('missing').sections, isEmpty);
  });
}
