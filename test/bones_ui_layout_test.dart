@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_layout.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UILayout commands', () {
    late final _LayoutRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _LayoutRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    /// Creates a `relative` container (in the DOM) holding [children].
    web.HTMLDivElement newContainer(List<web.HTMLElement> children) {
      var container = web.HTMLDivElement()
        ..style.position = 'relative'
        ..style.width = '200px'
        ..style.height = '100px';

      for (var e in children) {
        container.append(e);
      }

      uiRoot.content!.append(container);
      return container;
    }

    test('multiple `;` separated commands are all applied', () {
      var element = web.HTMLDivElement();
      newContainer([element]);

      UILayout(uiRoot, element, 'x(10px); y(20px)');

      expect(element.style.position, equals('absolute'));
      expect(element.style.left, equals('10px'));
      expect(element.style.top, equals('20px'));
    });

    test('a `container` layout is relative', () {
      var element = web.HTMLDivElement();
      newContainer([element]);

      UILayout(uiRoot, element, 'container');

      expect(element.style.position, equals('relative'));
    });

    test('`width`/`height` as a percentage of the parent', () {
      var element = web.HTMLDivElement();
      newContainer([element]);

      UILayout(uiRoot, element, 'width(50%); height(50%)');

      expect(element.style.width, equals('100px'));
      expect(element.style.height, equals('50px'));
    });

    test('`centerx` with a fractional `px` reference', () {
      var reference = web.HTMLDivElement()
        ..id = 'layoutref'
        ..style.position = 'absolute'
        ..style.left = '4.5px';

      var element = web.HTMLDivElement();

      newContainer([reference, element]);

      // Resolves the `style.left` of `#layoutref` (`4.5px`), which used to
      // throw a `FormatException` when parsed as an `int`:
      UILayout(uiRoot, element, 'centerx(#layoutref)');

      expect(
        element.style.left,
        equals('4.5px'),
        reason: 'A fractional `px` reference should be resolved',
      );
    });

    test('a non-numeric `px` reference is applied as is', () {
      var reference = web.HTMLDivElement()
        ..id = 'layoutrefcalc'
        ..style.position = 'absolute';

      reference.style.setProperty('left', 'calc(10px + 2px)');

      var element = web.HTMLDivElement();

      newContainer([reference, element]);

      UILayout(uiRoot, element, 'centerx(#layoutrefcalc)');

      expect(element.style.left, contains('calc'));
    });
  });
}

class _LayoutRoot extends UIRoot {
  _LayoutRoot(super.rootContainer) : super(id: 'layout-root');

  @override
  UIComponent? renderContent() => null;
}
