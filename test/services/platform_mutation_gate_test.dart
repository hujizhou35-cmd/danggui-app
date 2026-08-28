import 'dart:async';

import 'package:danggui/src/services/platform_mutation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operations are FIFO and a failure cannot strand later work', () async {
    final gate = PlatformMutationGate();
    final firstMayFinish = Completer<void>();
    final order = <String>[];

    final first = gate.protect(() async {
      order.add('first-start');
      await firstMayFinish.future;
      order.add('first-fail');
      throw StateError('injected');
    });
    final second = gate.protect(() async {
      order.add('second');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, <String>['first-start']);
    firstMayFinish.complete();
    await expectLater(first, throwsStateError);
    expect(await second, 2);
    expect(order, <String>['first-start', 'first-fail', 'second']);
  });
}
