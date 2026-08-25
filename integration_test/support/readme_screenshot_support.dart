import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const readmeScreenshotLocales = <String>{'zh', 'en'};

enum ReadmeScreenshotFrame {
  startup('startup'),
  tasksReminders('tasks-reminders'),
  taskDetail('task-detail'),
  past('past'),
  notes('notes'),
  exportSettings('export-settings'),
  privacySettings('privacy-settings');

  const ReadmeScreenshotFrame(this.slug);

  final String slug;

  String fileStem(String locale) {
    final order = (index + 1).toString().padLeft(2, '0');
    return '$locale-$order-$slug';
  }
}

final class ReadmeScreenshotFixture {
  const ReadmeScreenshotFixture({
    required this.reminderTaskTitle,
    required this.reminderTaskPlan,
    required this.reminderTaskBody,
    required this.detailTaskTitle,
    required this.detailTaskPlan,
    required this.detailTaskBody,
    required this.thirdTaskTitle,
    required this.primaryFolder,
    required this.secondaryFolder,
    required this.firstNoteTitle,
    required this.firstNoteBody,
    required this.secondNoteTitle,
    required this.secondNoteBody,
    required this.thirdNoteTitle,
    required this.thirdNoteBody,
    required this.pastDocument,
  });

  factory ReadmeScreenshotFixture.forLocale(String locale) {
    return switch (locale) {
      'zh' => const ReadmeScreenshotFixture(
        reminderTaskTitle: '晚饭后整理一周的行动轨迹',
        reminderTaskPlan: '19:30 开始，只记录真正推动了我的行动。',
        reminderTaskBody: '• 看见计划与行动之间的距离\n• 选出下周要继续的一小步',
        detailTaskTitle: '设计下周的一个小实验',
        detailTaskPlan: '连续七天，在精力最好的时段先做最重要的事。',
        detailTaskBody: '☐ 每天只设一个关键行动\n☐ 完成后写下一句感受\n\n不追求完美，只观察什么真正有效。',
        thirdTaskTitle: '把二十分钟散步留进日程',
        primaryFolder: '工作流',
        secondaryFolder: '灵感',
        firstNoteTitle: '这一周，什么真正推动了我？',
        firstNoteBody: '专注不是把日程填满，而是知道下一步为什么值得做。',
        secondNoteTitle: '精力观察',
        secondNoteBody: '上午适合深度工作，傍晚适合整理与回望。',
        thirdNoteTitle: '下周的一点改变',
        thirdNoteBody: '把提醒放在行动最容易发生的时刻。',
        pastDocument: '2032-05-12\n\n'
            '09:10  完成一周计划回顾\n'
            '我发现，持续的小步比突然用力更可靠。\n\n'
            '☒ 把散步和阅读留在日程里\n\n'
            '• 记录精力最好的两个小时\n\n'
            '20:40  写下明天最重要的一件事',
      ),
      'en' => const ReadmeScreenshotFixture(
        reminderTaskTitle: 'Review this week after dinner',
        reminderTaskPlan: 'Start at 19:30 and keep only the actions that mattered.',
        reminderTaskBody: '• Notice the gap between plans and action\n• Choose one small step to keep',
        detailTaskTitle: 'Design one small experiment for next week',
        detailTaskPlan: 'For seven days, do the most important thing during my best hour.',
        detailTaskBody: '☐ Choose one key action each day\n☐ Write one sentence after finishing\n\nNo perfection—just notice what actually works.',
        thirdTaskTitle: 'Keep a twenty-minute walk on the calendar',
        primaryFolder: 'Workflow',
        secondaryFolder: 'Ideas',
        firstNoteTitle: 'What truly moved me forward this week?',
        firstNoteBody: 'Focus is not a full calendar. It is knowing why the next step matters.',
        secondNoteTitle: 'Energy notes',
        secondNoteBody: 'Mornings favor deep work; evenings favor sorting and reflection.',
        thirdNoteTitle: 'One change for next week',
        thirdNoteBody: 'Place reminders where action is most likely to begin.',
        pastDocument: '2032-05-12\n\n'
            '09:10  Finished the weekly review\n'
            'Small, steady steps proved more reliable than sudden effort.\n\n'
            '☒ Kept walking and reading on the calendar\n\n'
            '• Noted the two hours with the most energy\n\n'
            '20:40  Wrote down tomorrow’s most important action',
      ),
      _ => throw ArgumentError.value(
        locale,
        'locale',
        'README screenshots support only zh and en.',
      ),
    };
  }

  final String reminderTaskTitle;
  final String reminderTaskPlan;
  final String reminderTaskBody;
  final String detailTaskTitle;
  final String detailTaskPlan;
  final String detailTaskBody;
  final String thirdTaskTitle;
  final String primaryFolder;
  final String secondaryFolder;
  final String firstNoteTitle;
  final String firstNoteBody;
  final String secondNoteTitle;
  final String secondNoteBody;
  final String thirdNoteTitle;
  final String thirdNoteBody;
  final String pastDocument;
}

Future<void> waitForReadmeScreenshotFinder(
  WidgetTester tester,
  Finder finder, {
  required String phase,
  Duration timeout = const Duration(seconds: 20),
}) async {
  const interval = Duration(milliseconds: 100);
  final attempts = (timeout.inMicroseconds / interval.inMicroseconds).ceil();
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(interval);
    expect(
      tester.takeException(),
      isNull,
      reason: 'An unhandled Flutter exception occurred during $phase.',
    );
  }
  fail('$phase did not complete within ${timeout.inSeconds} seconds.');
}

Future<void> waitForReadmeScreenshotCondition(
  WidgetTester tester,
  bool Function() condition, {
  required String phase,
  Duration timeout = const Duration(seconds: 20),
}) async {
  const interval = Duration(milliseconds: 100);
  final attempts = (timeout.inMicroseconds / interval.inMicroseconds).ceil();
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    if (condition()) return;
    await tester.pump(interval);
    expect(
      tester.takeException(),
      isNull,
      reason: 'An unhandled Flutter exception occurred during $phase.',
    );
  }
  fail('$phase did not complete within ${timeout.inSeconds} seconds.');
}

Future<void> captureReadmeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester, {
  required String locale,
  required ReadmeScreenshotFrame frame,
  required Finder readyWhen,
  required String phase,
  Duration stabilizeFor = const Duration(milliseconds: 250),
}) async {
  await waitForReadmeScreenshotFinder(
    tester,
    readyWhen,
    phase: '$phase readiness',
  );
  if (stabilizeFor > Duration.zero) {
    await tester.pump(stabilizeFor);
  }
  expect(
    tester.takeException(),
    isNull,
    reason: 'An unhandled Flutter exception occurred before $phase capture.',
  );
  await binding.takeScreenshot(frame.fileStem(locale));
}
