@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_utils.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('isEmptyValue', () {
    test('null, empty collections and empty strings are empty', () {
      expect(isEmptyValue(null), isTrue);
      expect(isEmptyValue(''), isTrue);
      expect(isEmptyValue([]), isTrue);
      expect(isEmptyValue(<String, int>{}), isTrue);
    });

    test('non-empty values', () {
      expect(isEmptyValue('x'), isFalse);
      expect(isEmptyValue(' '), isFalse);
      expect(isEmptyValue([1]), isFalse);
      expect(isEmptyValue({'a': 1}), isFalse);
      expect(isEmptyValue(0), isFalse, reason: '`0` stringifies to `0`');
      expect(isEmptyValue(false), isFalse);
    });
  });

  group('containsIntlMessage', () {
    test('detects an `{{intl:...}}` message', () {
      expect(containsIntlMessage('{{intl:key}}'), isTrue);
      expect(containsIntlMessage('before {{intl:key}} after'), isTrue);
    });

    test('rejects a text without a message', () {
      expect(containsIntlMessage(''), isFalse);
      expect(containsIntlMessage('plain text'), isFalse);
      expect(containsIntlMessage('{{intl:key'), isFalse);
    });
  });

  group('resolveToText', () {
    test('null and String', () {
      expect(resolveToText(null), isNull);
      expect(resolveToText('text'), equals('text'));
    });

    test('an Iterable is joined and nulls are dropped', () {
      expect(resolveToText(['a', 'b']), equals('ab'));
      expect(resolveToText(['a', null, 'b']), equals('ab'));
      expect(resolveToText([]), isNull);
      expect(resolveToText([null]), isNull);
    });

    test('an element resolves to its text', () {
      var div = web.HTMLDivElement()..text = 'the text';
      expect(resolveToText(div), equals('the text'));
    });

    test('a DOMElement resolves to its text', () {
      expect(resolveToText($div(content: 'dom text')), equals('dom text'));
    });

    test('any other object resolves via toString', () {
      expect(resolveToText(42), equals('42'));
      expect(resolveToText(true), equals('true'));
    });
  });

  group('stackTraceSafe / yeld', () {
    test('stackTraceSafe never throws', () {
      expect(stackTraceSafe(), isA<StackTrace>());
    });

    test('yeld resumes after the delay', () async {
      var done = false;
      var future = yeld(ms: 5).then((_) => done = true);

      expect(done, isFalse);
      await future;
      expect(done, isTrue);
    });
  });

  group('getLanguageByExtension', () {
    test('maps the known extensions', () {
      expect(getLanguageByExtension('dart'), equals('dart'));
      expect(getLanguageByExtension('md'), equals('markdown'));
      expect(getLanguageByExtension('markdown'), equals('markdown'));
      expect(getLanguageByExtension('html'), equals('html'));
      expect(getLanguageByExtension('htm'), equals('html'));
      expect(getLanguageByExtension('json'), equals('json'));
      expect(getLanguageByExtension('txt'), equals('text'));
      expect(getLanguageByExtension('py'), equals('python'));
      expect(getLanguageByExtension('rb'), equals('ruby'));
    });

    test('normalizes the extension', () {
      expect(getLanguageByExtension('  MD  '), equals('markdown'));
      expect(getLanguageByExtension('.md'), equals('markdown'));
    });

    test('returns null for an unknown or empty extension', () {
      expect(getLanguageByExtension('unknown'), isNull);
      expect(getLanguageByExtension(''), isNull);
      expect(getLanguageByExtension('   '), isNull);
      expect(getLanguageByExtension('...'), isNull);
    });
  });

  group('URLLink', () {
    test('holds the url and the target', () {
      var link = URLLink('https://foo.com', '_blank');

      expect(link.url, equals('https://foo.com'));
      expect(link.target, equals('_blank'));
      expect(link.toString(), contains('https://foo.com'));

      expect(URLLink('https://bar.com').target, isNull);
    });
  });

  group('isComponentInDOM / canBeInDOM', () {
    late final _UtilsRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _UtilsRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('a detached element is not in the DOM', () {
      var div = web.HTMLDivElement();

      expect(isComponentInDOM(div), isFalse);
      expect(canBeInDOM(div), isTrue);
    });

    test('an attached element is in the DOM', () {
      var div = web.HTMLDivElement();
      uiRoot.content!.append(div);

      expect(isComponentInDOM(div), isTrue);
    });

    test('a rendered component is in the DOM', () async {
      var component = _UtilsComponent(uiRoot.content);
      await component.callRenderAndWait();

      expect(isComponentInDOM(component), isTrue);
      expect(canBeInDOM(component), isTrue);
    });

    test('a List is checked recursively', () {
      var attached = web.HTMLDivElement();
      uiRoot.content!.append(attached);

      expect(isComponentInDOM([web.HTMLDivElement(), attached]), isTrue);
      expect(isComponentInDOM([web.HTMLDivElement()]), isFalse);
      expect(isComponentInDOM([]), isFalse);
      expect(canBeInDOM([]), isTrue);
    });

    test('non-renderable values', () {
      expect(isComponentInDOM(null), isFalse);
      expect(canBeInDOM(null), isFalse);
      expect(canBeInDOM('text'), isFalse);
      expect(canBeInDOM(42), isFalse);
    });
  });
}

class _UtilsRoot extends UIRoot {
  _UtilsRoot(super.rootContainer) : super(id: 'utils-root');

  @override
  UIComponent? renderContent() => null;
}

class _UtilsComponent extends UIComponent {
  _UtilsComponent(super.parent);

  @override
  dynamic render() => '<div>utils</div>';
}
