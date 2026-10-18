@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

// Its own file: the components are registered once per app (here, per test
// file), by the first `UIRoot` constructed.
void main() {
  group('UIRoot `registerComponents`', () {
    late final _Root uiRoot;

    Set<String> registered() =>
        UIComponent.domGenerator.registeredElementsGenerators.keys.toSet();

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _Root(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('registers what the app passes, in place of all of them', () {
      expect(_Root.registrations, equals(1));
      expect(registered(), contains('ui-dialog'));
      expect(registered(), isNot(contains('ui-document')));
      expect(registered(), isNot(contains('ui-button')));
      expect(registered(), isNot(contains('ui-svg')));
    });

    test('is called once, by the first root', () {
      _Root(createDivInline());
      expect(_Root.registrations, equals(1));
      expect(registered(), isNot(contains('ui-document')));
    });

    test('the root renders without the others', () {
      expect(uiRoot.isRendered, isTrue);
    });
  });
}

class _Root extends UIRoot {
  static int registrations = 0;

  _Root(super.rootContainer)
    : super(
        registerComponents: () {
          registrations++;
          UIDialog.register();
        },
      );

  @override
  UIComponent? renderContent() => null;
}
