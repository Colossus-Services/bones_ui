@TestOn('browser')
// Short on purpose: a regression here is a hang, and it should fail
// fast rather than sit on the default timeout.
@Timeout(Duration(seconds: 30))
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

class _ChainRoot extends UIRoot {
  _ChainRoot(super.rootContainer) : super(id: 'chain-root');

  @override
  UIComponent? renderContent() => null;
}

void main() {
  testUI<_ChainRoot>('test chain', (c) => _ChainRoot(c), (context) {
    // A failing step used to be reported as an uncaught error while the
    // future the test awaited never completed, so the test body hung
    // until its timeout — 20 minutes in a real suite.
    test(
      'a failing step completes the awaited future with its error',
      () async {
        await expectLater(
          context.document.selectFirstWhereUntil(
            '.never-rendered',
            timeoutMs: 200,
            (e) => true,
          ),
          throwsA(isA<TestFailure>()),
        );
      },
    );

    test('a failing step deeper in the chain completes it too', () async {
      await expectLater(
        context.document
            .selectUntil('#chain-root', timeoutMs: 200)
            .selectFirstWhereUntil(
              '.never-rendered',
              timeoutMs: 200,
              (e) => true,
            ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
