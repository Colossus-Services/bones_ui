@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

/// `initializeTestUIRoot` shuts its root down after its tests
/// (`closeOnTearDown`): after the tests of the group of its `setUpAll`, or
/// after the test calling it. The tests run in declaration order.
void main() {
  late _Root inGroup;
  late _Plain inGroupComponent;
  late _Root kept;
  _Root? inTest;

  group('a root initialized in setUpAll', () {
    setUpAll(() async {
      inGroup = await initializeTestUIRoot(
        _Root.new,
        outputDivID: 'teardown-in-group',
      );
      await inGroup.callRenderAndWait();
      inGroupComponent = _Plain(inGroup.content);
      await inGroupComponent.callRenderAndWait();
    });

    test('is open during its group', () async {
      expect(inGroup.isClosed, isFalse);
    });

    test('is still open in the next test of its group', () async {
      expect(inGroup.isClosed, isFalse);
      expect(inGroupComponent.isDisposed, isFalse);
    });
  });

  group('closeOnTearDown: false', () {
    setUpAll(() async {
      kept = await initializeTestUIRoot(
        _Root.new,
        outputDivID: 'teardown-kept',
        closeOnTearDown: false,
      );
    });

    test('is open during its group', () async {
      expect(kept.isClosed, isFalse);
    });
  });

  test('after the groups', () async {
    // Closed after its group's tests, its components disposed:
    expect(inGroup.isClosed, isTrue);
    expect(inGroupComponent.isDisposed, isTrue);

    // Kept open:
    expect(kept.isClosed, isFalse);
    expect(await kept.close(), isTrue);
  });

  test('a root initialized in a test', () async {
    inTest = await initializeTestUIRoot(
      _Root.new,
      outputDivID: 'teardown-in-test',
    );
    expect(inTest!.isClosed, isFalse);
  });

  test('is closed after that test', () async {
    expect(inTest!.isClosed, isTrue);
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'teardown-root');

  @override
  UIComponent? renderContent() => null;
}

class _Plain extends UIComponent {
  _Plain(super.parent);

  @override
  dynamic render() => 'plain';
}
