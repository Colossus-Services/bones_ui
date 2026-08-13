@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group(r'$uiButtonLoader', () {
    test('`buttonStyle` is emitted without `buttonClasses`', () {
      var domElement = $uiButtonLoader(buttonStyle: 'color: red');

      expect(
        domElement.getAttributeValue('button-style'),
        contains('color'),
        reason: '`buttonStyle` should not depend on `buttonClasses`',
      );
      expect(domElement.getAttributeValue('button-classes'), isNull);
    });

    test('`buttonClasses` does not emit an empty `button-style`', () {
      var domElement = $uiButtonLoader(buttonClasses: 'btn btn-primary');

      expect(
        domElement.getAttributeValue('button-classes'),
        equals('btn btn-primary'),
      );
      expect(domElement.getAttributeValue('button-style'), isNull);
    });

    test('`loadedTextClass` is used for `loaded-text-classes`', () {
      var domElement = $uiButtonLoader(
        buttonClasses: 'btn',
        loadedTextClass: 'text-ok text-bold',
      );

      expect(
        domElement.getAttributeValue('loaded-text-classes'),
        equals('text-ok text-bold'),
        reason:
            '`loaded-text-classes` should be built from `loadedTextClass`, '
            'not from `buttonClasses`',
      );
    });

    test('`loadedTextErrorClass` is used for `loaded-text-error-classes`', () {
      var domElement = $uiButtonLoader(loadedTextErrorClass: 'text-error');

      expect(
        domElement.getAttributeValue('loaded-text-error-classes'),
        equals('text-error'),
      );
    });

    test('texts and `withProgress`', () {
      var domElement = $uiButtonLoader(
        loadedTextOK: 'Done',
        loadedTextError: 'Failed',
        withProgress: true,
      );

      expect(domElement.getAttributeValue('loaded-text-ok'), equals('Done'));
      expect(
        domElement.getAttributeValue('loaded-text-error'),
        equals('Failed'),
      );
      expect(domElement.getAttributeValue('with-progress'), equals('true'));
    });
  });

  group('UIButton', () {
    late final _ButtonRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _ButtonRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('renders a `button` element with the text', () async {
      var button = UIButton(uiRoot.content, 'Click me');
      await button.callRenderAndWait();

      expect(button.content.isA<web.HTMLButtonElement>(), isTrue);
      expect(button.text, equals('Click me'));
      expect(button.content!.text, contains('Click me'));
    });

    test('fires the click event', () async {
      var button = UIButton(uiRoot.content, 'Click me');
      await button.callRenderAndWait();

      var clicks = 0;
      button.onClick.listen((_) => ++clicks);

      button.click();
      await testUISleep(ms: 50);

      expect(clicks, equals(1));
    });

    test('a disabled button does not fire the click event', () async {
      var button = UIButton(uiRoot.content, 'Click me');
      await button.callRenderAndWait();

      var clicks = 0;
      button.onClick.listen((_) => ++clicks);

      button.disabled = true;
      await testUISleep(ms: 50);

      button.click();
      await testUISleep(ms: 50);

      expect(clicks, equals(0));
    });
  });
}

class _ButtonRoot extends UIRoot {
  _ButtonRoot(super.rootContainer) : super(id: 'button-root');

  @override
  UIComponent? renderContent() => null;
}
