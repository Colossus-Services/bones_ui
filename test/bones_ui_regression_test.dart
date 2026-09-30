@TestOn('browser')
library;

import 'package:bones_ui/bones_ui.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// Regression tests for bugs fixed in 3.1.0.
void main() {
  group('UIConsole', () {
    // Regression: `_format` of a `List` mapped each element to
    // `_format(msg)` (the whole list), recursing until a stack overflow.
    test('error with a List message', () {
      // `_format` runs when both an error and a stack trace are given:
      var trace = StackTrace.current;
      expect(
        () => UIConsole.error(['a', 1, 'b'], 'err', trace),
        returnsNormally,
      );
      expect(() => UIConsole.error(<Object?>[], 'err', trace), returnsNormally);
    });
  });

  group(r'$uiDialog', () {
    // Regression: `$uiDialog` created a `ui-button-loader` tag.
    test('creates a `ui-dialog` tag', () {
      var dialog = $uiDialog(
        id: 'd1',
        show: true,
        showCloseButton: false,
        content: 'x',
      );
      expect(dialog.tag, equals('ui-dialog'));
      expect(dialog.getAttributeValue('show'), equals('true'));
      expect(dialog.getAttributeValue('show-close-button'), equals('false'));
    });
  });

  group('CSSProvider', () {
    // Regression: the CSS of an element in the DOM was read from the
    // computed style's `cssText`, which is empty in Chromium.
    test('css of an element in the DOM', () {
      var div = web.HTMLDivElement()
        ..style.color = 'rgb(255, 0, 0)'
        ..style.width = '42px';
      web.document.body!.appendChild(div);
      addTearDown(() => div.remove());

      var css = CSSProvider.fromElement(div).css;

      expect(css.style, isNotEmpty);
      expect(css.style, contains('width: 42px'));
      expect(css.style, contains('color: rgb(255, 0, 0)'));
    });

    test('css of an element not in the DOM', () {
      var div = web.HTMLDivElement()..style.width = '10px';
      var css = CSSProvider.fromElement(div).css;
      expect(css.style, contains('width: 10px'));
    });
  });

  group('UIComponent.getContentUIComponent', () {
    // Regression (dart2wasm): the content -> component association was an
    // `Expando` keyed by the Dart wrapper, and an element re-read from the DOM
    // can have a distinct wrapper with dart2wasm.
    test('from a content element re-read from the DOM', () async {
      var holder = web.HTMLDivElement()..id = 'regression-content-holder';
      web.document.body!.appendChild(holder);
      addTearDown(() => holder.remove());

      var component = _TextComponent(holder, 'hello');
      await component.callRenderAndWait();

      var content = component.content!;
      expect(UIComponent.getContentUIComponent(content), same(component));

      var reRead = web.document
          .querySelector('#regression-content-holder')!
          .firstElementChild!;
      expect(UIComponent.getContentUIComponent(reRead), same(component));

      expect(UIComponent.getContentUIComponent(web.HTMLDivElement()), isNull);
    });
  });
}

class _TextComponent extends UIComponent {
  final String text;

  _TextComponent(super.parent, this.text);

  @override
  dynamic render() => text;
}
