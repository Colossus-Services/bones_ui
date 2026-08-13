@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UIDialog', () {
    late final _DialogRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _DialogRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    tearDown(() {
      UIDialog.removeAllDialogs();
    });

    test('is hidden by default and shows on demand', () async {
      var dialog = UIDialog($div(content: 'the dialog content'));

      expect(dialog.isShowing, isFalse);

      dialog.show();
      await testUISleep(ms: 100);

      expect(dialog.isShowing, isTrue);
      expect(dialog.content!.text, contains('the dialog content'));
      expect(isComponentInDOM(dialog.content), isTrue);
    });

    test('`show: true` shows it on construction', () async {
      var dialog = UIDialog($div(content: 'shown'), show: true);
      await testUISleep(ms: 100);

      expect(dialog.isShowing, isTrue);
    });

    test('hide restores the previous display style', () async {
      var dialog = UIDialog($div(content: 'x'), show: true);
      await testUISleep(ms: 50);

      expect(dialog.isShowing, isTrue);

      dialog.hide();

      expect(dialog.isShowing, isFalse);
      expect(dialog.content!.style.display, equals('none'));
      expect(dialog.content!.style.visibility, equals('hidden'));

      dialog.show();
      await testUISleep(ms: 50);

      expect(dialog.isShowing, isTrue);
      expect(dialog.content!.style.display, isNot(equals('none')));
    });

    test('onShow/onHide are notified', () async {
      var dialog = UIDialog($div(content: 'x'));

      var shown = 0;
      var hidden = 0;
      dialog.onShow.listen((_) => ++shown);
      dialog.onHide.listen((_) => ++hidden);

      dialog.show();
      await testUISleep(ms: 100);
      expect(shown, equals(1));

      dialog.hide();
      await testUISleep(ms: 100);
      expect(hidden, equals(1));

      // Hiding an already hidden dialog does not notify again:
      dialog.hide();
      await testUISleep(ms: 100);
      expect(hidden, equals(1));
    });

    test('cancel hides and marks it as canceled', () async {
      var dialog = UIDialog($div(content: 'x'), show: true);
      await testUISleep(ms: 50);

      expect(dialog.isCanceled, isFalse);

      dialog.cancel();

      expect(dialog.isCanceled, isTrue);
      expect(dialog.isShowing, isFalse);
    });

    test('showAndWait completes when hidden', () async {
      var dialog = UIDialog($div(content: 'x'));

      var future = dialog.showAndWait();
      await testUISleep(ms: 100);

      expect(dialog.isShowing, isTrue);

      dialog.hide();

      expect(await future, isTrue, reason: 'Hidden without cancel');
    });

    test('showAndWait completes with false when canceled', () async {
      var dialog = UIDialog($div(content: 'x'));

      var future = dialog.showAndWait();
      await testUISleep(ms: 100);

      dialog.cancel();

      expect(await future, isFalse);
    });

    test('getAllDialogs and removeAllDialogs', () async {
      expect(UIDialog.getAllDialogs(), isEmpty);

      UIDialog($div(content: 'a'), show: true);
      UIDialog($div(content: 'b'), show: true);
      await testUISleep(ms: 100);

      expect(UIDialog.getAllDialogs().length, equals(2));

      UIDialog.removeAllDialogs();

      expect(UIDialog.getAllDialogs(), isEmpty);
      expect(
        document.querySelectorAll('.ui-dialog').toList(),
        isEmpty,
        reason: 'The dialog elements should be removed from the DOM',
      );
    });

    test('a close button is rendered when requested', () async {
      var dialog = UIDialog(
        $div(content: 'x'),
        show: true,
        showCloseButton: true,
      );
      await testUISleep(ms: 100);

      var buttons = dialog.querySelectorAllNonTyped(
        '.${UIDialogBase.dialogButtonClass}',
      );
      expect(buttons, isNotEmpty);
    });
  });

  group('UIDialogAlert / UIDialogInput / UIDialogLoading', () {
    late final _DialogRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _DialogRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    tearDown(() {
      UIDialog.removeAllDialogs();
    });

    test('UIDialogAlert renders the text and the button', () async {
      var dialog = UIDialogAlert('The message', 'OK');
      dialog.show();
      await testUISleep(ms: 100);

      var text = dialog.content!.text!;
      expect(text, contains('The message'));
      expect(text, contains('OK'));
    });

    test('UIDialogInput exposes the input field', () async {
      var dialog = UIDialogInput(
        'Name',
        'Send',
        value: 'initial',
        buttonCancelLabel: 'Cancel',
      );
      dialog.show();
      await testUISleep(ms: 100);

      expect(dialog.content!.text, contains('Name'));

      var input = dialog.getFieldElementTyped<web.HTMLInputElement>(
        UIDialogInput.dialogInputField,
        Web.HTMLInputElement,
      );

      expect(input, isNotNull);
      expect(input!.value, equals('initial'));
      expect(
        dialog.getField(UIDialogInput.dialogInputField),
        equals('initial'),
      );
    });

    test('UIDialogInput.ask returns the typed value', () async {
      var dialog = UIDialogInput('Name', 'Send');

      var future = dialog.ask();
      await testUISleep(ms: 100);

      var input = dialog.getFieldElementTyped<web.HTMLInputElement>(
        UIDialogInput.dialogInputField,
        Web.HTMLInputElement,
      )!;
      input.value = 'typed value';

      dialog.hide();

      expect(await future, equals('typed value'));
    });

    test('UIDialogInput.ask returns null when canceled', () async {
      var dialog = UIDialogInput('Name', 'Send');

      var future = dialog.ask();
      await testUISleep(ms: 100);

      dialog.cancel();

      expect(await future, isNull);
    });

    test('UIDialogLoading renders the text and the loading', () async {
      var dialog = UIDialogLoading(
        'Loading data',
        UILoadingType.ring,
        show: true,
      );
      await testUISleep(ms: 100);

      expect(dialog.isShowing, isTrue);
      expect(dialog.content!.text, contains('Loading data'));

      var loading = dialog.querySelectorNonTyped('.ui-loading');
      expect(loading, isNotNull);

      // The type class is suffixed with a color ID (e.g. `ui-loading-ring-_fff`):
      expect(
        loading!.classList.toIterable().any(
          (c) => c.toString().startsWith('ui-loading-ring'),
        ),
        isTrue,
        reason: 'Classes: ${loading.classList.value}',
      );
    });
  });
}

class _DialogRoot extends UIRoot {
  _DialogRoot(super.rootContainer) : super(id: 'dialog-root');

  @override
  UIComponent? renderContent() => null;
}
