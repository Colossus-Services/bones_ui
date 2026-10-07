@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:test/test.dart';

void main() {
  // `<html lang>` follows the locale: an app can change its language without
  // a reload, so it must be set on every locale definition, not only once.
  group('UIRoot `<html lang>`', () {
    late final _LangRoot uiRoot;
    String? prevLocale;

    String? htmlLang() => document.documentElement!.getAttribute('lang');

    setUpAll(() async {
      prevLocale = Intl.defaultLocale;
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _LangRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    tearDownAll(() {
      Intl.defaultLocale = prevLocale;
    });

    test('is set at start-up', () {
      var locale = UIRoot.getCurrentLocale();
      expect(locale, isNotNull);
      expect(htmlLang(), equals(locale!.replaceAll('_', '-')));
    });

    test('follows a locale change', () async {
      expect(await uiRoot.setPreferredLocale('pt'), isTrue);
      await testUISleep(ms: 100);
      expect(htmlLang(), equals('pt'));

      expect(await uiRoot.setPreferredLocale('es'), isTrue);
      await testUISleep(ms: 100);
      expect(htmlLang(), equals('es'));
    });

    test('`setDocumentLang` writes a BCP 47 tag', () {
      uiRoot.setDocumentLang('pt_BR');
      expect(htmlLang(), equals('pt-BR'));

      uiRoot.setDocumentLang(' fr ');
      expect(htmlLang(), equals('fr'));

      // Nothing to set: keeps the previous one.
      uiRoot.setDocumentLang(null);
      uiRoot.setDocumentLang('');
      expect(htmlLang(), equals('fr'));
    });

    test('`setDocumentLang` can be overridden', () async {
      uiRoot.definedLocales.clear();

      expect(await uiRoot.setPreferredLocale('pt'), isTrue);
      await testUISleep(ms: 100);

      expect(uiRoot.definedLocales, contains('pt'));
      expect(htmlLang(), equals('pt'));
    });
  });
}

class _LangRoot extends UIRoot {
  _LangRoot(super.rootContainer) : super(id: 'lang-root');

  static const languages = {'en', 'pt', 'es'};

  /// The locales [setDocumentLang] was called with (an override).
  final List<String?> definedLocales = [];

  @override
  void setDocumentLang(String? locale) {
    definedLocales.add(locale);
    super.setDocumentLang(locale);
  }

  /// As an app's `IntlMessages.autoDiscoverLocale`: only the languages it
  /// has messages for initialize.
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
