@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
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

  // A language `<select>` in a `<ui-template>`, inside a
  // `<ui-dialog remove-on-hide="false">` opened by an `action="#id.show()"`,
  // as an app's top menu declares it: the option of the current locale
  // (`locale`, a context variable) must be the selected one, also after the
  // locale changes and the component renders again.
  group('ui-dialog with a locale select (ui-template)', () {
    late final _DialogRoot uiRoot;
    String? prevLocale;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _DialogRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
      prevLocale = Intl.defaultLocale;
    });

    tearDown(() {
      UIDialog.removeAllDialogs();
      Intl.defaultLocale = prevLocale;
    });

    /// The language menu, rendered in a new holder.
    Future<_LanguageMenu> renderMenu() async {
      var holder = web.HTMLDivElement();
      uiRoot.content!.append(holder);
      addTearDown(() => holder.remove());
      var menu = _LanguageMenu(holder);
      await menu.callRenderAndWait();
      await testUISleep(ms: 50);
      return menu;
    }

    /// Sets the preferred [locale] as the select's `locale()` action does,
    /// and waits for the root to render again for it (a changed locale
    /// clears it). Returns the current locale.
    Future<String?> setLocale(String locale) async {
      expect(await uiRoot.setPreferredLocale(locale), isTrue);
      await testUISleep(ms: 200);
      return UIRoot.getCurrentLocale();
    }

    /// Clicks the menu's button, as a user opening the dialog.
    Future<void> openDialog(_LanguageMenu menu) async {
      (menu.content!.querySelector('#lang_btn') as web.HTMLElement).click();
      await testUISleep(ms: 100);
    }

    /// The `#lang_dialog` elements in the page.
    List<web.HTMLElement> dialogs() => document
        .querySelectorAll('#lang_dialog')
        .toList()
        .cast<web.HTMLElement>();

    /// The `#lang_dialog` shown, if one (`UIDialog.hide` sets
    /// `display: none`).
    web.HTMLElement? shownDialog() =>
        dialogs().where((d) => d.style.display != 'none').firstOrNull;

    /// The value of the select of the dialog shown.
    String? shownSelectValue() => (shownDialog()?.querySelector(
      'select',
    ) as web.HTMLSelectElement?)?.value;

    test('selects the current locale', () async {
      Intl.defaultLocale = 'pt';

      var menu = await renderMenu();
      await openDialog(menu);

      expect(shownDialog(), isNotNull, reason: 'The dialog should show');
      expect(shownSelectValue(), equals('pt'));
    });

    test(
      'selects the new locale after it changes and the menu renders again',
      () async {
        Intl.defaultLocale = 'pt';

        var menu = await renderMenu();
        await openDialog(menu);
        expect(shownSelectValue(), equals('pt'));

        // Closed (kept in the page: `remove-on-hide="false"`):
        UIDialog.getAllDialogs().forEach((d) => d.hide());
        await testUISleep(ms: 50);

        Intl.defaultLocale = 'es';
        await menu.callRenderAndWait();
        await testUISleep(ms: 50);

        await openDialog(menu);

        expect(
          shownSelectValue(),
          equals('es'),
          reason: '`#lang_dialog` elements in the page: ${dialogs().length}',
        );
      },
    );

    test('opens the dialog of the current render', () async {
      Intl.defaultLocale = 'pt';

      var menu = await renderMenu();
      await openDialog(menu);
      UIDialog.getAllDialogs().forEach((d) => d.hide());
      await testUISleep(ms: 50);

      for (var i = 0; i < 3; i++) {
        await menu.callRenderAndWait();
        await testUISleep(ms: 50);
      }

      Intl.defaultLocale = 'es';
      await menu.callRenderAndWait();
      await testUISleep(ms: 50);

      await openDialog(menu);

      // No copy of an earlier render is left in the page:
      expect(dialogs().length, equals(1));

      var shown = dialogs().where((d) => d.style.display != 'none').toList();
      expect(shown.length, equals(1), reason: 'One dialog shown');
      expect(shownSelectValue(), equals('es'));
    });

    // The locale set as the select's `locale()` action sets it
    // (`UIRoot.setPreferredLocale`), with an app that only has messages for
    // some languages (`_DialogRoot.initializeLocale`).

    test(
      'a picked language is the current locale and the selected option',
      () async {
        expect(await setLocale('pt'), equals('pt'));

        var menu = await renderMenu();
        await openDialog(menu);
        expect(shownSelectValue(), equals('pt'));

        UIDialog.getAllDialogs().forEach((d) => d.hide());

        // The root renders again for the new locale, and the menu with it:
        expect(await setLocale('es'), equals('es'));

        menu = await renderMenu();
        await openDialog(menu);
        expect(shownSelectValue(), equals('es'));
        expect(dialogs().length, equals(1));
      },
    );

    test(
      'a regional locale (a browser\'s `pt-BR`) resolves to its language',
      () async {
        expect(await setLocale('pt_BR'), equals('pt'));

        var menu = await renderMenu();
        await openDialog(menu);
        expect(shownSelectValue(), equals('pt'));
      },
    );
  });
}

/// An app's language menu: a button opening a dialog with the locale select.
/// See also the `with the locales of an app` group.
class _LanguageMenu extends UIComponent {
  _LanguageMenu(super.parent);

  @override
  dynamic render() => '''
<div>
  <span id="lang_btn" action="#lang_dialog.show()" style="cursor: pointer">Lang</span>
  <ui-dialog id="lang_dialog" remove-on-hide="false">
    <ui-template>
      <select>
        <option value="en" selected="{{:locale=='en'}}true{{?}}false{{/}}">EN</option>
        <option value="pt" selected="{{:locale=='pt'}}true{{?}}false{{/}}">PT</option>
        <option value="es" selected="{{:locale=='es'}}true{{?}}false{{/}}">ES</option>
      </select>
    </ui-template>
  </ui-dialog>
</div>
''';
}

class _DialogRoot extends UIRoot {
  _DialogRoot(super.rootContainer) : super(id: 'dialog-root');

  /// The languages with messages, as an app's `msgs-<lang>.intl` files:
  /// only these (not `pt_BR`...) initialize.
  static const languages = {'en', 'pt', 'es'};

  /// As an app's `IntlMessages.autoDiscoverLocale`: its resource discovery
  /// adds the languages it has to the `LocalesManager`s to look up (which a
  /// locale must be in to initialize), then finds only those.
  @override
  Future<bool> initializeLocale(String locale) {
    for (var m in LocalesManager.instances()) {
      m.addLanguagesToLookup([for (var l in languages) IntlLocale(l)]);
    }
    return Future.value(languages.contains(locale));
  }

  @override
  UIComponent? renderContent() => null;
}
