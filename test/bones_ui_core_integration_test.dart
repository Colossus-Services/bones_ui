@TestOn('browser')
library;

import 'dart:js_interop_unsafe';

import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_utils.dart' as utils;
import 'package:bones_ui/src/bones_ui_web.dart' as bui_web;
import 'package:logging/logging.dart' as logging;
import 'package:markdown/markdown.dart' as mk;
import 'package:intl_messages/intl_messages.dart' show IntlMessages;
import 'package:statistics/statistics.dart'
    show Decimal, DynamicInt, DynamicNumber;
import 'package:swiss_knife/swiss_knife.dart' show Dimension, ResourceContent;
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// Integration tests of the `Bones_UI` core (components, root, navigator,
/// async content, base providers, log, documents), against the real DOM.

/// Matches the same JS object as [expected] (JS `===`). With `dart2wasm`,
/// the same JS object can be wrapped by distinct Dart objects.
Matcher _sameJS(JSAny expected) => predicate<Object?>(
  (actual) => (actual as JSAny?).strictEquals(expected).toDart,
  'the same JS object as $expected',
);

/// A `div` attached to `document.body`, removed after the test.
web.HTMLDivElement _attachedDiv() {
  var div = web.HTMLDivElement();
  document.body!.appendChild(div);
  addTearDown(() => div.remove());
  return div;
}

void main() {
  late final _CoreRoot uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _CoreRoot(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  group('bones_ui_utils', () {
    test('stackTraceSafe', () {
      expect(utils.stackTraceSafe().toString(), isNotEmpty);
    });

    test('isEmptyValue', () {
      expect(utils.isEmptyValue(null), isTrue);
      expect(utils.isEmptyValue(''), isTrue);
      expect(utils.isEmptyValue(<int>[]), isTrue);
      expect(utils.isEmptyValue(<String, int>{}), isTrue);
      expect(utils.isEmptyValue('a'), isFalse);
      expect(utils.isEmptyValue([1]), isFalse);
      expect(utils.isEmptyValue({'a': 1}), isFalse);
      expect(utils.isEmptyValue(0), isFalse);
    });

    test('containsIntlMessage', () {
      expect(utils.containsIntlMessage('Hi {{intl:name}}!'), isTrue);
      expect(utils.containsIntlMessage('Hi {{name}}!'), isFalse);
      expect(utils.containsIntlMessage('{{intl:x'), isFalse);
    });

    test('resolveToText', () {
      expect(utils.resolveToText(null), isNull);
      expect(utils.resolveToText('a'), equals('a'));
      expect(utils.resolveToText(['a', null, 'b']), equals('ab'));
      expect(utils.resolveToText(<Object?>[null]), isNull);
      expect(
        utils.resolveToText(web.HTMLSpanElement()..textContent = 'span'),
        equals('span'),
      );
      expect(utils.resolveToText($div(content: 'dom')), equals('dom'));
      expect(utils.resolveToText(123), equals('123'));
    });

    test('yeld', () async {
      var sw = Stopwatch()..start();
      await utils.yeld(ms: 20);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(15));
    });
  });

  group('bones_ui_web', () {
    test('uiChildren / hasUIChildren', () {
      var div = web.HTMLDivElement()..innerHTML = '<b>1</b><i>2</i>'.toJS;
      expect(div.uiChildren.length, equals(2));
      expect(div.hasUIChildren, isTrue);
      expect(web.HTMLDivElement().hasUIChildren, isFalse);
    });

    test('resolveFieldName', () {
      var field = web.HTMLDivElement()..setAttribute('field', ' f1 ');
      expect(field.resolveFieldName()!.key, equals('f1'));

      var emptyField = web.HTMLDivElement()..setAttribute('field', ' ');
      expect(emptyField.resolveFieldName(), isNull);

      for (var e in <web.Element>[
        web.HTMLInputElement(),
        web.HTMLTextAreaElement(),
        web.HTMLButtonElement(),
        web.HTMLSelectElement(),
      ]) {
        e.setAttribute('name', 'n');
        expect(e.resolveFieldName()!.key, equals('n'), reason: e.tagName);
      }

      var named = web.HTMLDivElement()..setAttribute('name', 'n');
      expect(named.resolveFieldName(), isNull, reason: 'not an input');

      expect(
        (web.HTMLInputElement()..setAttribute('name', '')).resolveFieldName(),
        isNull,
      );
    });

    test('setValue', () {
      var input = web.HTMLInputElement();
      input.setValue('abc');
      expect(input.value, equals('abc'));
      input.setValue(null);
      expect(input.value, isEmpty);

      var checkbox = web.HTMLInputElement()..type = 'checkbox';
      checkbox.setValue('true');
      expect(checkbox.checked, isTrue);
      checkbox.setValue('x');
      expect(checkbox.checked, isFalse);

      var select = web.HTMLSelectElement()
        ..appendChild(
          web.HTMLOptionElement()
            ..value = 'a'
            ..label = 'Alpha',
        )
        ..appendChild(
          web.HTMLOptionElement()
            ..value = 'B'
            ..label = 'Beta',
        );

      select.setValue('B');
      expect(select.selectedIndex, equals(1));
      select.setValue(' a ');
      expect(select.selectedIndex, equals(0), reason: 'trimmed, ignore case');
      select.setValue('beta');
      expect(select.selectedIndex, equals(1), reason: 'by label');
      select.setValue('none');
      expect(select.selectedIndex, equals(-1));
      select.setValue('a');
      select.setValue(null);
      expect(select.selectedIndex, equals(-1));

      var div = web.HTMLDivElement();
      div.setValue('text');
      expect(div.textContent, equals('text'));
    });

    test('isTextInput', () {
      expect(web.HTMLInputElement().isTextInput, isTrue);
      expect(web.HTMLTextAreaElement().isTextInput, isTrue);
      expect(web.HTMLDivElement().isTextInput, isFalse);
    });

    test('navigation helpers', () {
      expect(bui_web.navigationURL(), equals(window.location.href));
      expect(bui_web.navigationIsOnline(), isA<bool>());
      expect(bui_web.navigationIsSecureContext(), isTrue);

      var div = _attachedDiv()..id = 'core-query';
      expect(bui_web.documentQuerySelector('#core-query'), _sameJS(div));
      expect(bui_web.documentQuerySelectorAll('#core-query').length, equals(1));
    });

    test('navigationOnChangeRoute', () async {
      var calls = <List<String?>>[];
      bui_web.navigationOnChangeRoute((o, n) => calls.add([o, n]));

      window.dispatchEvent(
        web.HashChangeEvent(
          'hashchange',
          web.HashChangeEventInit(oldURL: 'http://a/#x', newURL: 'http://a/#y'),
        ),
      );
      expect(calls.last, equals(['http://a/#x', 'http://a/#y']));
    });
  });

  group('bones_ui_extension', () {
    test('resolveElementValue of inputs', () {
      expect(
        (web.HTMLInputElement()..value = 'v').resolveElementValue(),
        equals('v'),
      );
      expect(
        (web.HTMLTextAreaElement()..value = 'ta').resolveElementValue(),
        equals('ta'),
      );

      var checkbox = web.HTMLInputElement()
        ..type = 'checkbox'
        ..value = 'on-value';
      expect(checkbox.resolveElementValue(), isNull);
      checkbox.checked = true;
      expect(checkbox.resolveElementValue(), equals('on-value'));

      var radio = web.HTMLInputElement()
        ..type = 'radio'
        ..value = 'r'
        ..checked = true;
      expect(radio.resolveInputElementValue(), equals('r'));

      var file = web.HTMLInputElement()..type = 'file';
      expect(file.resolveInputElementValue(), isEmpty);

      var select = web.HTMLSelectElement()
        ..multiple = true
        ..appendChild(web.HTMLOptionElement()..value = 'a')
        ..appendChild(web.HTMLOptionElement()..value = 'b');
      expect(select.resolveElementValue(), isEmpty);
      (select.options.item(0) as web.HTMLOptionElement).selected = true;
      (select.options.item(1) as web.HTMLOptionElement).selected = true;
      expect(select.resolveElementValue(), equals('a,b'));

      expect(web.HTMLDivElement().resolveInputElementValue(), isNull);
    });

    test('resolveElementValue of other elements', () {
      var div = web.HTMLDivElement()..textContent = 'text';
      expect(div.resolveElementValue(resolveUIComponents: false), 'text');
      expect(
        div.resolveElementValue(
          allowTextAsValue: false,
          resolveUIComponents: false,
        ),
        isNull,
      );

      div.setAttribute('field_value', 'fv');
      expect(div.resolveElementValue(resolveUIComponents: false), 'fv');
      expect(div.elementValue, equals('fv'));
      expect(div.isElementValueEmpty, isFalse);

      var blank = web.HTMLDivElement()..textContent = '  ';
      expect(blank.isElementValueEmpty, isFalse);
      expect(blank.isElementValueEmptyTrimmed, isTrue);

      expect([div, blank].elementsValues, equals(['fv', '  ']));
    });

    test('resolveElementValue of UIField / UIFieldMap components', () {
      var field = _FieldComponent(uiRoot.content, 'fx', 'the-value');
      field.ensureRendered();
      expect(
        field.content!.resolveElementValue(uiComponent: field),
        equals('the-value'),
      );

      var fieldMap = _FieldMapComponent(uiRoot.content);
      fieldMap.ensureRendered();
      expect(
        fieldMap.content!.resolveElementValue(uiComponent: fieldMap),
        contains('a'),
      );
    });

    test('uiComponent / uiComponents', () {
      var component = _TextComponent(uiRoot.content, '<b>inner</b>');
      component.ensureRendered();

      // The component that has the element as child:
      var inner = component.content!.querySelector('b')!;
      expect(inner.uiComponent, same(component));
      expect([inner].uiComponents, equals([component]));
      expect(
        inner.resolveUIComponent(parentUIComponent: component),
        same(component),
      );

      // A component's own content is a child of its container:
      expect(component.content!.uiComponent, same(uiRoot));
    });

    test('listenAndTrackSubscription / trackSubscription', () {
      var component = _TextComponent(uiRoot.content, 'x');
      component.ensureRendered();
      var button = web.HTMLButtonElement();
      component.content!.appendChild(button);

      var clicks = 0;
      var sub = button.onClick.listenAndTrackSubscription(
        (_) => clicks++,
        component: component,
        element: button,
      );
      button.click();
      expect(clicks, equals(1));

      var sub2 = button.onClick.listen((_) => clicks++);
      expect(sub2.trackSubscription(component, button), same(sub2));
      button.click();
      expect(clicks, equals(3));

      sub.cancel();
      sub2.cancel();
    });
  });

  group('bones_ui_base', () {
    test('UIEventHandler: add / fire / remove / clear', () {
      var handler = _EventHandler();
      var calls = <String>[];

      handler.addEventListener('a', (e, p) => calls.add('a1:$e:$p'));
      handler.addEventListener('a', (e, p) => calls.add('a2:$e'));
      handler.addEventListener('b', (e, p) => calls.add('b:$e'));
      expect(handler.eventListeners.map((e) => e.key), equals(['a', 'b']));

      handler.fireEvent('a', 1, [2]);
      handler.fireEvent('b', 3);
      handler.fireEvent('none', 0);
      expect(calls, equals(['a1:1:[2]', 'a2:1', 'b:3']));

      handler.removeEventListener('a');
      handler.fireEvent('a', 9);
      expect(calls.length, equals(3));

      handler.clearEventListeners();
      handler.fireEvent('b', 9);
      expect(calls.length, equals(3));
      expect(handler.eventListeners, isEmpty);
    });

    test('UIEventHandler: a throwing listener is caught', () {
      var handler = _EventHandler();
      handler.addEventListener('e', (e, p) => throw StateError('boom'));
      expect(() => handler.fireEvent('e', 1), returnsNormally);
    });

    test('UIEventHandler: tracked DOM listeners', () {
      var handler = _EventHandler();
      var button = web.HTMLButtonElement();
      var clicks = 0;

      var reg = handler.addTrackedEventListener(
        button,
        EventType.click,
        (MouseEvent _) => clicks++,
      );
      button.click();
      expect(clicks, equals(1));

      expect(handler.untrackRegisteredEventListener(reg), isTrue);
      expect(handler.untrackRegisteredEventListener(reg), isFalse);

      handler.trackRegisteredEventListener(reg);
      var reg2 = EventType.click.addEventListener(
        button,
        (MouseEvent _) => clicks++,
      );
      handler.trackAllRegisteredEventListeners([reg2]);
      handler.trackAllRegisteredEventListeners([]);

      button.click();
      expect(clicks, equals(3));

      handler.cancelRegisteredEventListeners();
      handler.cancelRegisteredEventListeners(); // no-op
      button.click();
      expect(clicks, equals(3));
    });

    test('isComponentInDOM / canBeInDOM', () async {
      expect(isComponentInDOM(null), isFalse);
      expect(canBeInDOM(null), isFalse);

      var attached = _attachedDiv();
      expect(isComponentInDOM(attached), isTrue);
      expect(isComponentInDOM(web.HTMLDivElement()), isFalse);
      expect(isComponentInDOM([web.HTMLDivElement(), attached]), isTrue);
      expect(isComponentInDOM([web.HTMLDivElement()]), isFalse);
      expect(isComponentInDOM('x'), isFalse);

      var component = _TextComponent(uiRoot.content, 'in-dom');
      component.ensureRendered();
      expect(isComponentInDOM(component), isTrue);

      var asyncContent = UIAsyncContent.future(Future.value('loaded'), '...');
      await asyncContent.onLoadContent.first;
      expect(isComponentInDOM(asyncContent), isFalse);
      attached.appendChild(asyncContent.content as web.Node);
      expect(isComponentInDOM(asyncContent), isTrue);

      expect(canBeInDOM(attached), isTrue);
      expect(canBeInDOM(component), isTrue);
      expect(canBeInDOM(asyncContent), isTrue);
      expect(canBeInDOM([]), isTrue);
      expect(canBeInDOM('x'), isFalse);
    });

    test('TextProvider', () {
      expect(TextProvider.from(null), isNull);
      var p = TextProvider.fromText('t');
      expect(TextProvider.from(p), same(p));
      expect(TextProvider.from('s')!.text, equals('s'));
      expect(TextProvider.from(() => 'f')!.text, equals('f'));
      expect(TextProvider.from(42)!.text, equals('42'));
      expect(
        TextProvider.from(web.HTMLSpanElement()..textContent = 'el')!.text,
        equals('el'),
      );
      expect(
        TextProvider.from(ElementProvider.fromHTML('<b>h</b>'))!.text,
        equals('h'),
      );
      // Regression: the error message interpolated `this`, whose `toString`
      // calls `text` again: a stack overflow instead of a `StateError`.
      expect(() => TextProvider.fromObject(null).text, throwsStateError);
      expect(TextProvider.fromObject(null).toString, throwsStateError);

      var count = 0;
      var single = TextProvider.fromFunction(() => 'v${++count}')
        ..singleCall = true;
      expect(single.text, equals('v1'));
      expect(single.text, equals('v1'));
      expect(single.toString(), equals('v1'));

      expect(TextProvider.accepts(null), isFalse);
      expect(TextProvider.accepts(p), isTrue);
      expect(TextProvider.accepts('s'), isTrue);
      expect(TextProvider.accepts(() => ''), isTrue);
      expect(TextProvider.accepts(web.HTMLDivElement()), isTrue);
      expect(TextProvider.accepts(42), isFalse);
    });

    test('ElementProvider', () {
      expect(ElementProvider.from(null), isNull);
      expect(ElementProvider.from(42), isNull);

      var fromHtml = ElementProvider.from('<p>para</p>')!;
      expect(fromHtml.element!.tagName.toLowerCase(), equals('p'));
      expect(fromHtml.elementAsHTML, equals('<p>para</p>'));
      expect(ElementProvider.from(fromHtml), same(fromHtml));

      var div = web.HTMLDivElement();
      expect(ElementProvider.from(div)!.element, _sameJS(div));

      var component = _TextComponent(uiRoot.content, 'cmp');
      var fromComponent = ElementProvider.from(component)!;
      expect(fromComponent.element!.textContent, equals('cmp'));

      var fromDOMNode = ElementProvider.from($span(content: 'node'))!;
      expect(fromDOMNode.element!.textContent, equals('node'));

      expect(ElementProvider.accepts(null), isFalse);
      expect(ElementProvider.accepts(fromHtml), isTrue);
      expect(ElementProvider.accepts('x'), isTrue);
      expect(ElementProvider.accepts(div), isTrue);
      expect(ElementProvider.accepts(component), isTrue);
      expect(ElementProvider.accepts($div()), isTrue);
      expect(ElementProvider.accepts(42), isFalse);
      expect(fromHtml.toString(), contains('ElementProvider'));
    });

    test('CSSProvider', () {
      expect(CSSProvider.from(null), isNull);
      expect(CSSProvider.from(42), isNull);

      var fromHtml = CSSProvider.from('<div style="width: 3px"></div>')!;
      expect(fromHtml.cssAsString, contains('width: 3px'));
      expect(CSSProvider.from(fromHtml), same(fromHtml));

      var component = _TextComponent(uiRoot.content, 'c', style: 'height: 4px');
      expect(CSSProvider.from(component)!.css.style, contains('height'));

      var fromDOMNode = CSSProvider.from($div(style: 'color: red'))!;
      expect(fromDOMNode.cssAsString, contains('color'));

      expect(CSSProvider.accepts(null), isFalse);
      expect(CSSProvider.accepts(fromHtml), isTrue);
      expect(CSSProvider.accepts('x'), isTrue);
      expect(CSSProvider.accepts(web.HTMLDivElement()), isTrue);
      expect(CSSProvider.accepts(component), isTrue);
      expect(CSSProvider.accepts($div()), isTrue);
      expect(CSSProvider.accepts(42), isFalse);
      expect(fromHtml.toString(), contains('CSSProvider'));
    });

    // Regression: `window.orientation` is `undefined` in desktop browsers,
    // and reading it as an `int` threw a `TypeError` on every
    // `deviceorientation` event.
    test('UIDeviceOrientation', () {
      var calls = 0;
      UIDeviceOrientation.listen((e, p) => calls++);
      expect(UIDeviceOrientation.isLandscape(), isA<bool>());

      window.dispatchEvent(web.DeviceOrientationEvent('deviceorientation'));
      window.dispatchEvent(web.DeviceOrientationEvent('deviceorientation'));

      // The orientation (`undefined` → `null`) didn't change:
      expect(calls, equals(0));
    });
  });

  group('UIConsole', () {
    setUp(() {
      UIConsole.enable();
      UIConsole.clear();
    });

    tearDown(() {
      UIConsole.hide();
      document.querySelector('#${UIConsole.buttonId}')?.remove();
      UIConsole.clear();
      UIConsole.disable();
    });

    test('log / error / logs / head / allLogs', () {
      expect(UIConsole.get()!.enabled, isTrue);

      UIConsole.log('first <tag>');
      UIConsole.error('an error', 'the exception', StackTrace.current);
      UIConsole.error('only msg');

      var logs = UIConsole.logs();
      expect(logs.first, contains('first <tag>'));
      expect(logs.any((l) => l.contains('ERROR')), isTrue);
      expect(logs.any((l) => l.contains('the exception')), isTrue);
      expect(UIConsole.head(1).single, contains('first'));
      expect(UIConsole.head(1000).length, equals(logs.length));
      expect(UIConsole.allLogs(), contains('first &lt;tag&gt;'));
    });

    // Regression: `tail` started at a negative index (RangeError) when there
    // were fewer logs than `tailSize` (e.g. `tail()` with less than 100 logs).
    test('tail with fewer logs than tailSize', () {
      UIConsole.log('a');
      UIConsole.log('b');
      expect(UIConsole.tail().length, equals(2));
      expect(UIConsole.tail(1).single, contains('b'));
    });

    test('disabled console does not keep logs', () {
      UIConsole.disable();
      UIConsole.log('not kept');
      expect(UIConsole.logs(), isEmpty);
      expect(UIConsole.get()!.enabled, isFalse);
    });

    test('limit', () {
      var console = UIConsole.get()!;
      var prev = console.limit;
      addTearDown(() => console.limit = prev);

      console.limit = 1;
      expect(console.limit, equals(10), reason: 'minimum limit');

      for (var i = 0; i < 20; i++) {
        UIConsole.log('l$i');
      }
      expect(UIConsole.logs().length, lessThanOrEqualTo(11));
    });

    test('show / hide / copy / buttons', () {
      UIConsole.log('shown');
      expect(UIConsole.isShowing(), isFalse);

      UIConsole.show();
      expect(UIConsole.isShowing(), isTrue);
      var consoleDiv = document.querySelector('#UIConsole')!;
      expect(consoleDiv.textContent, contains('shown'));

      var buttons = consoleDiv.querySelectorAll('span').toElements();
      web.Element button(String text) =>
          buttons.firstWhere((e) => e.textContent == text);

      var pre =
          consoleDiv.querySelector('div[style*="overflow"]') as web.HTMLElement;
      var fontSize = pre.style.fontSize;
      (button('[ + ]') as web.HTMLElement).click();
      expect(pre.style.fontSize, isNot(equals(fontSize)));
      (button('[ - ]') as web.HTMLElement).click();
      (button('[ - ]') as web.HTMLElement).click();

      expect(() => UIConsole.copy(), returnsNormally);

      (button('[X]') as web.HTMLElement).click();
      expect(UIConsole.isShowing(), isFalse);
    });

    test('button / displayButton / checkAutoEnable', () {
      var button = UIConsole.button();
      expect(button.id, equals(UIConsole.buttonId));
      document.body!.appendChild(button);
      addTearDown(() => button.remove());

      button.click();
      expect(UIConsole.isShowing(), isTrue);
      button.click();
      expect(UIConsole.isShowing(), isFalse);
      button.remove();

      UIConsole.displayButton();
      UIConsole.displayButton(); // already displayed
      expect(
        document.querySelectorAll('#${UIConsole.buttonId}').length,
        equals(1),
      );
      document.querySelector('#${UIConsole.buttonId}')!.remove();

      UIConsole.enable();
      UIConsole.checkAutoEnable();
      expect(document.querySelector('#${UIConsole.buttonId}'), isNotNull);
    });

    test('JS `UIConsole` function', () {
      globalContext.callMethod('UIConsole'.toJS, 'from-js'.toJS);
      expect(UIConsole.logs().any((l) => l.contains('JS> from-js')), isTrue);
    });

    test('logging records are logged', () {
      var logger = logging.Logger('core_test');
      logger.info('info message');
      logger.severe('severe message', StateError('err'), StackTrace.current);

      var logs = UIConsole.logs();
      expect(logs.any((l) => l.contains('info message')), isTrue);
      expect(logs.any((l) => l.contains('severe message')), isTrue);
    });
  });

  group('UIDocument', () {
    test('getLanguageByExtension', () {
      expect(getLanguageByExtension(' '), isNull);
      expect(getLanguageByExtension('.'), isNull);
      expect(getLanguageByExtension('xyz'), isNull);
      var cases = {
        'dart': 'dart',
        '.MD': 'markdown',
        'markdown': 'markdown',
        'cpp': 'cpp',
        'diff': 'diff',
        'awk': 'awk',
        'bash': 'bash',
        'sh': 'shell',
        'shell': 'shell',
        'swift': 'swift',
        'yaml': 'yaml',
        'xml': 'xml',
        'sql': 'sql',
        'json': 'json',
        'java': 'java',
        'rb': 'ruby',
        'ruby': 'ruby',
        'r': 'r',
        'php': 'php',
        'css': 'css',
        'htm': 'html',
        'html': 'html',
        'txt': 'text',
        'text': 'text',
        'pl': 'perl',
        'perl': 'perl',
        'py': 'python',
        'python': 'python',
      };
      for (var e in cases.entries) {
        expect(getLanguageByExtension(e.key), equals(e.value), reason: e.key);
      }
    });

    test('URLLink', () {
      var link = URLLink('http://x', '_blank');
      expect(link.url, equals('http://x'));
      expect(link.target, equals('_blank'));
      expect(link.toString(), contains('_blank'));
    });

    Future<UIDocument> renderDocument(
      String file,
      String content, {
      mk.ExtensionSet? markdownExtensionSet,
    }) async {
      var doc = UIDocument(
        uiRoot.content,
        ResourceContent.fromURI(file, content),
        markdownExtensionSet: markdownExtensionSet,
      );
      await doc.callRenderAndWait();
      await testUISleep(ms: 100);
      return doc;
    }

    test('markdown, with `markdownExtensionSet`', () async {
      var doc = await renderDocument(
        'doc.md',
        '# Title\n\n~~strike~~',
        markdownExtensionSet: mk.ExtensionSet.gitHubWeb,
      );

      expect(doc.markdownExtensionSet, same(mk.ExtensionSet.gitHubWeb));
      expect(doc.content!.querySelector('h1')!.textContent, equals('Title'));
      expect(
        doc.content!.querySelector('del'),
        isNotNull,
        reason: 'GitHub strikethrough extension',
      );

      doc.markdownExtensionSet = mk.ExtensionSet.none;
      expect(doc.markdownExtensionSet, same(mk.ExtensionSet.none));
    });

    test('html, text and json', () async {
      var html = await renderDocument('doc.html', '<p id="doc-p">html</p>');
      expect(html.content!.querySelector('#doc-p'), isNotNull);

      // Regression: a text document was inserted as HTML (`<text>` became an
      // element and its content was lost).
      var text = await renderDocument('doc.txt', 'plain <text> & more');
      var pre = text.content!.querySelector('pre')!;
      expect(pre.textContent, contains('plain <text> & more'));
      expect(pre.children.length, equals(0));

      var json = await renderDocument('doc.json', '{"a": 1}');
      expect(json.content!.textContent, contains('a'));

      var unknown = await renderDocument('doc.xyz', 'raw');
      expect(unknown.content!.textContent, contains('raw'));
    });

    test('resourceContent setter / renderPropertiesProvider', () async {
      var doc = await renderDocument('a.md', '# A');
      expect(doc.renderPropertiesProvider()['uri'].toString(), 'a.md');

      doc.resourceContent = ResourceContent.fromURI('b.md', '# B');
      await testUISleep(ms: 200);
      expect(doc.resourceContent!.uri.toString(), equals('b.md'));
      expect(doc.content!.querySelector('h1')?.textContent, equals('B'));
    });

    test('generated from a `ui-document` tag', () async {
      var component = _DOMNodeComponent(
        uiRoot.content,
        $tag('ui-document', attributes: {'type': 'md'}, content: '# Tag'),
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 300);

      var doc = component.content!.querySelector('.ui-document');
      expect(doc, isNotNull);
      expect(doc!.textContent, contains('Tag'));
    });
  });

  group('UIAsyncContent', () {
    test('provider with `refreshInterval`', () async {
      var calls = 0;
      var asyncContent = UIAsyncContent.provider(
        () => Future.value('<b>v${++calls}</b>'),
        'loading',
        refreshInterval: Duration(milliseconds: 50),
        properties: {'p': 1},
      );

      expect(asyncContent.refreshInterval, Duration(milliseconds: 50));
      expect(asyncContent.hasAutoRefresh, isTrue);
      expect(asyncContent.properties, equals({'p': 1}));

      await asyncContent.onLoadContent.first;
      expect(asyncContent.isLoaded, isTrue);
      expect(asyncContent.loadTime, isNotNull);
      expect(asyncContent.elapsedLoadTime, greaterThanOrEqualTo(0));

      // Not in the DOM: refreshes are ignored.
      await testUISleep(ms: 200);
      var callsNotInDOM = calls;

      // In the DOM: refreshed periodically.
      _attachedDiv().appendChild(asyncContent.content as web.Node);
      asyncContent.refresh();
      await testUISleep(ms: 300);
      expect(calls, greaterThan(callsNotInDOM));

      asyncContent.stop();
      expect(asyncContent.stopped, isTrue);
    });

    test('future with `refreshInterval`: refresh is ignored', () async {
      var asyncContent = UIAsyncContent.future(
        Future.value('x'),
        'loading',
        refreshInterval: Duration(milliseconds: 20),
      );
      expect(asyncContent.refreshInterval, Duration(milliseconds: 20));
      await asyncContent.onLoadContent.first;
      asyncContent.refresh();
      asyncContent.refreshAsync();
      await testUISleep(ms: 50);
      expect(asyncContent.loadCount, equals(1));
      expect(asyncContent.isExpired, isTrue);
      asyncContent.stop();
    });

    test('validity, properties and locale', () async {
      var asyncContent = UIAsyncContent.future(
        Future.value('x'),
        null,
        properties: {'a': 1},
      );

      expect(UIAsyncContent.isValid(null), isFalse);
      expect(UIAsyncContent.isValidLocale(null), isFalse);
      expect(asyncContent.equalsProperties({'a': 1}), isTrue);
      expect(asyncContent.equalsCurrentLocale(), isTrue);
      expect(asyncContent.equalsLocale(asyncContent.locale ?? ''), isTrue);
      expect(UIAsyncContent.isValid(asyncContent, {'a': 1}), isTrue);
      expect(UIAsyncContent.isNotValidLocale(asyncContent), isFalse);

      expect(UIAsyncContent.isNotValid(asyncContent, {'a': 2}), isTrue);
      expect(asyncContent.stopped, isTrue, reason: 'invalid content stops');
    });

    test('maxIgnoredRefreshCount', () {
      var asyncContent = UIAsyncContent.future(Future.value('x'), null);
      asyncContent.maxIgnoredRefreshCount = 0;
      expect(asyncContent.maxIgnoredRefreshCount, equals(1));
      asyncContent.maxIgnoredRefreshCount = 5;
      expect(asyncContent.maxIgnoredRefreshCount, equals(5));
    });

    test('reset', () async {
      var calls = 0;
      var asyncContent = UIAsyncContent.provider(
        () => Future.value('v${++calls}'),
        'loading',
      );
      await asyncContent.onLoadContent.first;
      expect(calls, equals(1));

      asyncContent.reset(false);
      expect(asyncContent.isLoaded, isFalse);
      await testUISleep(ms: 20);
      expect(calls, equals(1));

      asyncContent.reset();
      await testUISleep(ms: 50);
      expect(calls, equals(2));
      expect(asyncContent.isLoaded, isTrue);
      expect(asyncContent.toString(), contains('isLoaded: true'));
    });

    test('a provider returning null', () async {
      var asyncContent = UIAsyncContent.provider(() => null, 'loading');
      expect(asyncContent.isLoaded, isTrue);
      expect(asyncContent.isOK, isTrue);
    });

    test('error content functions', () async {
      var withError = UIAsyncContent.future(
        Future.error(StateError('e1')),
        'loading',
        errorContent: (Object? e) => 'failed: $e',
      );
      await withError.onLoadContent.first;
      expect((withError.content as web.Element).textContent, contains('e1'));

      var noArgs = UIAsyncContent.future(
        Future.error(StateError('e2')),
        'loading',
        errorContent: () => 'failed',
      );
      await noArgs.onLoadContent.first;
      expect((noArgs.content as web.Element).textContent, equals('failed'));

      var noErrorContent = UIAsyncContent.future(
        Future.error(StateError('e3')),
        'loading',
      );
      await noErrorContent.onLoadContent.first;
      expect(
        (noErrorContent.content as web.Element).textContent,
        equals('loading'),
      );
    });

    test('content with another UIAsyncContent is an error', () async {
      var inner = UIAsyncContent.future(Future.value('x'), null);
      var outer = UIAsyncContent.future(Future.value([inner]), null);
      await outer.onLoadContent.first;
      expect(outer.isWithError, isTrue);
      expect(outer.error, isA<StateError>());
    });

    test('Map content is inspected', () async {
      var asyncContent = UIAsyncContent.future(
        Future.value({'k': web.HTMLDivElement()}),
        null,
      );
      await asyncContent.onLoadContent.first;
      expect(asyncContent.isOK, isTrue);
    });
  });
  group('UIComponent (3.1.0 changes)', () {
    test('`generator:` handles the component attributes', () {
      var component = _GenComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.setAttribute('title', 'T1'), isTrue);
      expect(component.getAttribute('title'), equals('T1'));
      expect(component.appendAttribute('title', 'T2'), isTrue);
      expect(component.getAttribute('TITLE'), equals('T2'));
      expect(component.clearAttribute('title'), isTrue);
      expect(component.getAttribute('title'), isNull);

      // Without a generator, unknown attributes aren't handled:
      var plain = _TextComponent(uiRoot.content, 'x');
      expect(plain.setAttribute('title', 'x'), isFalse);
      expect(plain.appendAttribute('title', 'x'), isFalse);
      expect(plain.clearAttribute('title'), isFalse);
      expect(plain.getAttribute('title'), isNull);
      expect(plain.getAttribute(' '), isNull);
      expect(plain.setAttribute(null, 'x'), isFalse);
    });

    test('parseStyle / parseClasses', () {
      expect(UIComponent.parseStyle(null), isEmpty);
      expect(
        UIComponent.parseStyle('color: red ;  width: 1px;'),
        equals(['color: red', 'width: 1px']),
      );
      expect(
        UIComponent.parseStyle(['a: 1', 'b: 2; c: 3']),
        equals(['a: 1', 'b: 2', 'c: 3']),
      );

      expect(UIComponent.parseClasses(null), isEmpty);
      expect(UIComponent.parseClasses(null, null), isEmpty);
      expect(UIComponent.parseClasses('a b,c;d'), equals(['a', 'b', 'c', 'd']));
      expect(UIComponent.parseClasses('a a'), equals(['a']));
      expect(UIComponent.parseClasses(null, 'x x y'), equals(['x', 'y']));
      expect(
        UIComponent.parseClasses('a b', ['c', 'a']),
        equals(['a', 'b', 'c']),
      );
      expect(UIComponent.parseClasses('', 'z'), equals(['z']));
      expect(UIComponent.parseClasses('z', ''), equals(['z']));
      expect(UIComponent.parseClasses('', ''), isEmpty);
    });

    test('focusField of an element or an UIField component', () async {
      var component = _FieldsFormComponent(uiRoot.content);
      await component.callRenderAndWait();

      expect(component.focusField(null), isFalse);
      expect(component.focusField('none'), isFalse);

      expect(component.focusField('name'), isTrue);
      expect(
        document.activeElement,
        _sameJS(component.querySelectorNonTyped('input[name="name"]')!),
      );

      expect(component.focusField('comp'), isTrue);
      expect(
        document.activeElement,
        _sameJS(component.querySelectorNonTyped('#comp-input')!),
      );
    });

    test('UIRoot.onFinishRender is notified after rendering', () async {
      var finished = uiRoot.onFinishRender.first;
      _TextComponent(uiRoot.content, 'x').callRender();
      expect(await finished.timeout(Duration(seconds: 3)), same(uiRoot));
    });
  });

  group('UIComponent', () {
    test('render types', () async {
      Future<_AnyRender> render(Object? Function() renderer) async {
        var c = _AnyRender(uiRoot.content, renderer);
        await c.callRenderAndWait();
        return c;
      }

      var html = await render(() => ['<b>b1</b>', '<i>i1</i>']);
      expect(html.content!.innerHTML.dartify(), contains('<b>b1</b>'));

      var node = await render(() => $span(id: 'n1', content: 'node'));
      expect(node.content!.querySelector('#n1'), isNotNull);

      var function = await render(
        () =>
            () => '<u>fn</u>',
      );
      expect(function.content!.textContent, equals('fn'));

      var list = await render(
        () => [
          web.HTMLSpanElement()..textContent = 'a',
          [$b(content: 'b')],
          <Object>{'<i>c</i>'},
          null,
        ],
      );
      expect(list.content!.textContent, equals('abc'));

      // Regression: a `Map` (documented as "rendered as JSON") rendered
      // nothing, when it had no renderable keys/values.
      var json = await render(() => {'k': 'v'});
      expect(json.content!.textContent, contains('"k"'));
      expect(json.content!.textContent, contains('"v"'));

      // A `Map` with renderable entries renders them:
      var elemMap = await render(
        () => {'x': web.HTMLSpanElement()..textContent = 'entry'},
      );
      expect(elemMap.content!.textContent, equals('entry'));

      var asDOM = await render(() => _AsDOM());
      expect(asDOM.content!.textContent, equals('as-dom'));

      var empty = await render(() => null);
      expect(empty.content!.childNodes.length, equals(0));

      var unsupported = await render(() => 3.14);
      expect(unsupported.content!.childNodes.length, equals(0));
    });

    test('render a Future: loading, then loaded or error', () async {
      var completer = Completer<Object?>();
      var c = _AnyRender(uiRoot.content, () => completer.future);
      c.callRender();
      await testUISleep(ms: 20);
      expect(c.renderedElementsAsync, isTrue);
      expect(c.isLoadingUIAsyncContent, isTrue);

      completer.complete('<b>done</b>');
      await testUISleep(ms: 100);
      expect(c.content!.textContent, contains('done'));

      var failing = _AnyRender(
        uiRoot.content,
        () => Future<Object?>.error(StateError('failed')),
      );
      failing.callRender();
      await testUISleep(ms: 100);
      expect(failing.isRenderedWithError, isTrue);
      expect(failing.content!.textContent, contains('failed'));
    });

    test('render lifecycle: refresh / clear / delete / hide / show', () async {
      var c = _CountingComponent(uiRoot.content);
      expect(c.isRendered, isFalse);

      await c.callRenderAndWait();
      expect(c.isRendered, isTrue);
      expect(c.renderCount, greaterThanOrEqualTo(1));
      expect(c.renders, equals(1));
      expect(c.preRenders, equals(1));
      expect(c.posRenders, equals(1));
      expect(c.isInDOM, isTrue);

      c.refresh();
      expect(c.renders, equals(2));

      c.requestRefresh();
      c.requestRefresh(); // ignored: already pending
      await testUISleep(ms: 20);
      expect(c.renders, equals(3));

      c.requestRefresh(delay: Duration(milliseconds: 20));
      await testUISleep(ms: 80);
      expect(c.renders, equals(4));

      c.refreshInternal();
      expect(c.renders, equals(5));

      c.ensureRendered();
      expect(c.renders, equals(5));
      c.ensureRendered(true);
      expect(c.renders, equals(6));

      c.callRenderAsync();
      await testUISleep(ms: 20);
      expect(c.renders, equals(7));

      c.hide();
      expect(c.isShowing, isFalse);
      expect(c.content!.style.display, equals('none'));
      c.hide();
      c.show();
      expect(c.isShowing, isTrue);
      expect(c.content!.style.display, isNot(equals('none')));

      c.clear();
      expect(c.isRendered, isFalse);
      expect(c.content!.childNodes.length, equals(0));
      c.refresh(); // not rendered: ignored
      expect(c.renders, equals(7));
      c.refresh(forceRender: true);
      expect(c.renders, equals(8));

      c.delete();
      expect(c.content!.isConnected, isFalse);
    });

    test('onRender / waiteRender / callRenderAndWait', () async {
      var c = _CountingComponent(uiRoot.content);
      var onRender = c.onRender.first;
      expect(await c.callRenderAndWait(), isTrue);
      expect(await onRender, same(c));

      var wait = c.waiteRender(timeout: Duration.zero);
      c.refresh();
      expect(await wait, isTrue);

      expect(
        await c.waiteRender(timeout: Duration(milliseconds: 10)),
        isFalse,
        reason: 'timeout',
      );
    });

    test('preserveRender', () async {
      var c = _CountingComponent(uiRoot.content, preserveRender: true);
      await c.callRenderAndWait();
      expect(c.renders, equals(1));

      c.callRender();
      expect(c.renders, equals(1), reason: 'preserved');
      expect(c.preserveRenderCount, equals(1));
      expect(c.content!.textContent, equals('render 1'));

      c.callRender(clearPreservedRender: true);
      expect(c.renders, equals(2));

      c.clearPreservedRender();
      c.callRender();
      expect(c.renders, equals(3));

      // `refresh` clears the component, so it renders again:
      c.refresh();
      expect(c.renders, equals(4));
    });

    test('id / click / classes / style attributes', () {
      var c = _CountingComponent(uiRoot.content, id: ' my-id ');
      c.ensureRendered();
      expect(c.id, equals('my-id'));
      expect(c.content!.id, equals('my-id'));

      c.setID(10);
      expect(c.id, equals(10));
      expect(c.content!.id, equals('10'));
      c.setID(' ');
      expect(c.id, isNull);
      expect(c.content!.hasAttribute('id'), isFalse);

      expect(c.appendAttribute('id', 'id2'), isTrue);
      expect(c.id, equals('id2'));

      var clicks = 0;
      c.content!.onClick.listen((_) => clicks++);
      c.click();
      expect(clicks, equals(1));

      expect(c.setAttribute('class', 'a b'), isTrue);
      expect(c.getAttribute('class'), equals('a b'));
      expect(c.appendAttribute('class', 'c'), isTrue);
      expect(c.getAttribute('class'), equals('a b c'));
      expect(c.clearAttribute('class'), isTrue);
      expect(c.getAttribute('class'), isEmpty);

      expect(c.setAttribute('style', 'color: red; width: 2px'), isTrue);
      expect(c.getAttribute('style'), contains('width: 2px'));
      expect(c.appendAttribute('style', 'height: 3px'), isTrue);
      expect(c.getAttribute('style'), contains('height: 3px'));
      expect(c.setAttribute('style', null), isTrue, reason: 'clears');
      expect(c.getAttribute('style'), isEmpty);

      expect(c.setAttributes([]), isTrue);
      expect(c.setAttributes([DOMAttribute.from('class', 'x')!]), isTrue);
      expect(c.getAttribute('class'), equals('x'));
      expect(c.appendAttributes([]), isFalse);
      expect(c.appendAttributes([DOMAttribute.from('class', 'y')!]), isTrue);
      expect(c.getAttribute('class'), equals('x y'));
    });

    test('navigate / data-source attributes', () {
      var c = _CountingComponent(uiRoot.content);
      c.ensureRendered();

      expect(c.setAttribute('navigate', 'route-a'), isTrue);
      expect(c.getAttribute('navigate'), equals('route-a'));
      expect(c.appendAttribute('navigate', 'route-b'), isTrue);
      expect(c.getAttribute('navigate'), equals('route-b'));
      expect(c.clearAttribute('navigate'), isTrue);
      expect(c.getAttribute('navigate'), isNull);

      expect(c.hasDataSource, isFalse);
      expect(c.dataSource, isNull);
      expect(c.getAttribute('data-source'), isEmpty);
      c.dataSourceCall = null;
      expect(c.clearAttribute('data-source'), isTrue);
      expect(c.dataSourceCallString, isEmpty);
      expect(c.setData({'a': 1}), isFalse);
      expect(c.applyData({'a': 1}), isFalse);
      c.refreshDataSource();
    });

    test(
      'parseAttributeValueAsString / List, isRenderable, copyRenderable',
      () {
        expect(
          UIComponent.parseAttributeValueAsStringList('a, b;c'),
          equals(['a', 'b', 'c']),
        );
        expect(UIComponent.parseAttributeValueAsString('a b'), equals('a b'));
        expect(UIComponent.parseAttributeValueAsString('a'), equals('a'));
        // Regression: an empty value failed a null check (the parsed list is
        // `null`), also breaking `setAttribute('style'|'class', '')`.
        expect(UIComponent.parseAttributeValueAsString(''), isEmpty);
        var c = _TextComponent(uiRoot.content, 'x', style: 'width: 1px');
        c.appendClasses('k');
        expect(c.setAttribute('style', ''), isTrue);
        expect(c.getAttribute('style'), isEmpty);
        expect(c.setAttribute('class', ''), isTrue);
        expect(c.getAttribute('class'), isEmpty);

        expect(
          UIComponent.parseAttributeValueAsString('a;b', '|', ';'),
          equals('a|b'),
        );

        var div = web.HTMLDivElement();
        expect(UIComponent.isRenderable(null), isFalse);
        expect(UIComponent.isRenderable(div), isTrue);
        expect(UIComponent.isRenderable('x'), isFalse);

        expect(UIComponent.copyRenderable('s'), equals('s'));
        expect(UIComponent.copyRenderable(div), _sameJS(div));
        expect(UIComponent.copyRenderable(42), isNull);
        var component = _TextComponent(uiRoot.content, 'x');
        expect(UIComponent.copyRenderable(component, div), _sameJS(div));
        expect(UIComponent.copyRenderable(component, 'x'), isNull);
      },
    );

    test('actions: `action` / `onEventClick` attributes', () async {
      var c = _ActionComponent(uiRoot.content);
      await c.callRenderAndWait();

      (c.querySelectorNonTyped('#act')! as web.HTMLElement).click();
      (c.querySelectorNonTyped('#evt')! as web.HTMLElement).click();

      expect(c.actions, equals(['do-action', 'do-click']));

      // Navigate attribute registered as "navigate on click":
      var nav = c.querySelectorNonTyped('#nav')!;
      expect(UINavigator.getNavigateOnClick(nav), equals('some-route'));
    });

    test('resolveTextIntl', () {
      var c = _TextComponent(uiRoot.content, 'x');
      var prev = uiRoot.intlMessageResolver;
      addTearDown(() => uiRoot.intlMessageResolver = prev);

      expect(c.resolveTextIntl('no messages'), equals('no messages'));

      uiRoot.intlMessageResolver = null;
      expect(c.resolveTextIntl('Hi {{intl:who}}!'), equals('Hi who!'));

      uiRoot.intlMessageResolver = (String key, [Map? params]) => 'X-$key';
      expect(c.resolveTextIntl('Hi {{intl:who}}!'), equals('Hi X-who!'));
      expect(c.resolveTextIntl('{{int:a}} {{intl:b}}'), equals('X-a X-b'));
    });

    test('refreshOnNavigate', () async {
      var c = _CountingComponent(uiRoot.content);
      await c.callRenderAndWait();
      expect(c.refreshOnNavigate, isFalse);

      c.refreshOnNavigate = true;
      c.refreshOnNavigate = true;
      expect(c.refreshOnNavigate, isTrue);

      var renders = c.renders;
      UINavigator.onNavigate.add('some-route');
      await testUISleep(ms: 50);
      expect(c.renders, greaterThan(renders));

      c.refreshOnNavigate = false;
      expect(c.refreshOnNavigate, isFalse);
    });

    test('dispose / recycle', () async {
      var c = _CountingComponent(uiRoot.content);
      await c.callRenderAndWait();
      c.domTreeMap;

      c.dispose();
      expect(c.isDisposed, isTrue);
      expect(c.disposeCount, equals(1));
      expect(c.renderedElements, isNull);
      expect(c.domTreeMapIfInitialized, isNull);

      c.ensureRendered();
      expect(c.isDisposed, isFalse, reason: 'recycled on render');
      expect(c.domTreeMapIfInitialized, isNotNull);
    });

    test('addTo / insertTo / setParent', () async {
      var c = _CountingComponent(null);
      var parent = _attachedDiv()
        ..appendChild(web.HTMLSpanElement())
        ..appendChild(web.HTMLSpanElement());

      c.addTo(parent);
      expect(c.parent, _sameJS(parent));
      expect(parent.lastElementChild, _sameJS(c.content!));

      c.insertTo(0, parent);
      expect(parent.firstElementChild, _sameJS(c.content!));

      var parent2 = _attachedDiv();
      expect(c.setParent(parent2), _sameJS(parent2));
      expect(c.content!.parentElement, _sameJS(parent2));
      expect(c.setParent(parent2), _sameJS(parent2), reason: 'same parent');
    });

    test('subComponent shares the domTreeMap', () {
      var parent = _TextComponent(uiRoot.content, 'p');
      var sub = _SubComponent(parent.content, parent);
      expect(identical(sub.domTreeMap, parent.domTreeMap), isTrue);
    });

    test('not accessible: renders nothing and redirects', () async {
      var c = _DeniedComponent(uiRoot.content);
      await c.callRenderAndWait();
      expect(c.isRendered, isTrue);
      expect(c.content!.childNodes.length, equals(0));
    });

    test('locale and device size', () async {
      var c = _CountingComponent(uiRoot.content);
      expect(c.deviceSizeChangedFromLastRender(), isFalse);
      await c.callRenderAndWait();
      expect(c.localeChangedFromLastRender, isFalse);
      expect(c.deviceSizeChangedFromLastRender(), isFalse);
      expect(c.deviceSizeChangedFromLastRender(onlyWidth: true), isFalse);
      expect(c.deviceSizeChangedFromLastRender(onlyHeight: true), isFalse);
      c.refreshIfLocaleChanged();
      expect(UIComponent.isAnyComponentRendering, isFalse);
    });

    test('find components and rendered elements', () async {
      var parent = _ParentComponent(uiRoot.content);
      await parent.callRenderAndWait();
      await testUISleep(ms: 50);

      var child = parent.child;
      expect(parent.subUIComponents, contains(child));
      expect(parent.subUIComponentsDeeply, contains(child));

      expect(parent.findUIComponentByID('#child-c'), same(child));
      expect(parent.findUIComponentByID(''), isNull);
      expect(parent.findUIComponentByID('none'), isNull);

      expect(parent.findUIComponentByContent(child.content), same(child));
      expect(parent.findUIComponentByContent(null), isNull);
      expect(parent.findUIComponentByContent(parent.content), same(parent));

      var childSpan = child.content!.querySelector('span')!;
      expect(parent.findUIComponentByChild(childSpan), same(child));
      expect(parent.findUIComponentByChild(null), isNull);
      expect(parent.findUIComponentByChild(web.HTMLDivElement()), isNull);

      expect(parent.getRenderedElementById('child-c'), same(child));
      expect(parent.getRenderedElementById('p-span'), isNotNull);
      expect(parent.getRenderedElementById('none', true), isNull);
      expect(
        parent.getRenderedUIComponentById<_ChildComponent>('child-c'),
        same(child),
      );
      expect(parent.getRenderedUIComponentById(null), isNull);
      expect(parent.getRenderedUIComponentsByIds(['child-c']), equals([child]));
      expect(parent.getRenderedUIComponentsByIds([]), isEmpty);
      expect(
        parent.getRenderedUIComponentByType<_ChildComponent>(true),
        equals([child]),
      );
      expect(
        parent.getAllRenderedElements((e) => e is UIComponent, true),
        contains(child),
      );
      expect(parent.getRenderedElementValueById('p-input'), equals('iv'));
      expect(parent.getRenderedElementValueById('none'), isNull);
      expect(parent.renderedElements, isNotEmpty);
    });

    test('content children queries', () async {
      var c = _AnyRender(
        uiRoot.content,
        () => '<div class="q"><p class="q">1</p><p>2</p></div>',
      );
      await c.callRenderAndWait();

      expect(c.getContentChildren().length, equals(3));
      expect(c.getContentChildren(deep: false).length, equals(1));
      expect(
        c.getContentChildren(filter: (e) => e.classList.contains('q')).length,
        equals(2),
      );
      expect(c.findChildDeep((e) => e.tagName == 'P').length, equals(2));
      expect(
        c.findInContentChildDeep((e) => e.textContent == '2')!.tagName,
        equals('P'),
      );
      expect(c.findInContentChildDeep((e) => false), isNull);

      expect(c.querySelectorNonTyped(null), isNull);
      expect(c.querySelectorNonTyped('p'), isNotNull);
      expect(c.selectElementNonTyped('.q'), isNotNull);
      expect(c.querySelectorTyped('p', Web.Element), isNotNull);
      expect(c.querySelectorTyped('p', Web.HTMLParagraphElement), isNotNull);
      expect(c.querySelectorTyped('', Web.Element), isNull);
      expect(c.selectElementTyped('div', Web.HTMLDivElement), isNotNull);
      expect(c.querySelectorAllNonTyped('p').length, equals(2));
      expect(c.querySelectorAllNonTyped(null), isEmpty);
      expect(c.selectElementsNonTyped('.q').length, equals(2));
      expect(
        c.querySelectorAllTyped('p', Web.HTMLParagraphElement).length,
        equals(2),
      );
      expect(c.querySelectorAllTyped('', Web.HTMLParagraphElement), isEmpty);
      expect(
        c.selectElementsTyped('p', Web.HTMLParagraphElement).length,
        equals(2),
      );

      expect(c.setContentNodes([web.HTMLSpanElement()..id = 's1']), isTrue);
      expect(c.content!.children.length, equals(1));
      expect(c.appendToContent([web.HTMLSpanElement()]), isTrue);
      expect(c.content!.children.length, equals(2));
      expect(c.clearContent(), isTrue);
      expect(c.content!.childNodes.length, equals(0));
    });

    test('fields', () async {
      var c = _FieldsFormComponent(uiRoot.content);
      await c.callRenderAndWait();

      expect(c.getFieldsNames(), containsAll(['name', 'age', 'g_1', 'g_2']));
      expect(c.hasEmptyField(), isFalse);

      c.setField('name', 'Joe');
      c.setField('age', 42);
      c.setField('none', 'x');
      expect(c.getField('name'), equals('Joe'));
      expect(c.getField(null, 'def'), equals('def'));
      expect(c.getField('none', 'def'), equals('def'));
      expect(c.getPreviousRenderedFieldValue('name'), equals('Joe'));

      expect(c.getFieldAs<String>('name'), equals('Joe'));
      expect(c.getFieldAs<int>('age'), equals(42));
      expect(c.getFieldAs<double>('age'), equals(42.0));
      expect(c.getFieldAs<num>('age'), equals(42));
      expect(c.getFieldAs<bool>('g_1'), isNull, reason: 'unchecked');
      expect(c.getFieldAs<Decimal>('age'), isNotNull);
      expect(c.getFieldAs<DynamicInt>('age'), isNotNull);
      expect(c.getFieldAs<DynamicNumber>('age'), isNotNull);
      expect(c.getFieldAs<List>('age'), isNull);
      expect(c.getFieldAs<int>('none'), isNull);

      c.setField('g_1', 'true');
      var fields = c.getFields();
      expect(fields['name'], equals('Joe'));
      expect(fields['g_1'], equals('1'));
      expect(fields['g_2'], isNull);
      // Regression: an `UIField` component was resolved to the component that
      // has it as child (not an `UIField`), so its value was `''`.
      expect(fields['comp'], equals('comp-value'));
      expect(c.getFields(fields: ['name']).keys, equals(['name']));
      expect(c.getFields(ignoreFields: ['name']).containsKey('name'), isFalse);

      expect(c.getEmptyFields(), contains('g_2'));
      expect(c.isEmptyField('g_2'), isTrue);
      expect(c.isEmptyField('name'), isFalse);
      expect(c.isEmptyField(null), isFalse);

      expect(c.getFieldsGroupCheckedKeys<int>('g_'), equals([1]));
      expect(c.getFieldsGroupChecks<int>('g_'), equals({1: true, 2: false}));
      expect(c.getFieldsGroupKeysByPrefix<int>('g_'), equals([1, 2]));
      expect(
        c.getFieldsGroupByPrefix<int, String>('g_'),
        equals({1: '1', 2: ''}),
      );
      expect(c.getFieldsGroupValuesByPrefix<String>('g_'), equals(['1', '']));
      expect(
        c.getFieldsGroupListByPrefix<int, String>('g_'),
        equals({
          1: ['1'],
          2: [''],
        }),
      );

      expect(c.getFieldElementNonTyped('name'), isNotNull);
      expect(
        c.getFieldElementTyped('name', Web.HTMLInputElement)!.value,
        equals('Joe'),
      );
      expect(c.getFieldElements('name').length, equals(1));
      expect(c.getFieldElementByValue('name', 'Joe'), isNotNull);
      expect(c.getFieldElementByValue('name', 'x'), isNull);

      var comp = c.getFieldComponent('comp');
      expect(comp, isA<_FieldComponent>());
      expect(c.getComponentFieldName(comp!), equals('comp'));
      expect(
        c.getComponentFieldName(c.getFieldElementNonTyped('name')!),
        equals('name'),
      );
      expect(c.getComponentFieldName(42), isNull);
      expect(c.getFieldExtended<String>('comp'), equals('comp-value'));
      expect(c.getFieldExtended<String>('none', 'd'), equals('d'));

      expect(c.getFieldsComponents(), isNotEmpty);
      expect(c.getFieldsExtended(fields: ['name']).keys, equals(['name']));

      c.updateRenderedFieldValue('age');
      expect(c.getPreviousRenderedFieldValue('age'), equals('42'));
      c.updateRenderedFieldElementValue(c.getFieldElementNonTyped('name')!);
      c.updateRenderedFieldElementValue(web.HTMLDivElement());

      var elements = <String>[];
      expect(
        c.forEachFieldElement((e) => elements.add(e.tagName)),
        greaterThan(0),
      );
      expect(c.forEachFieldComponent((e) {}), greaterThan(0));
      expect(c.forEachEmptyFieldElement((e) {}), greaterThan(0));
      expect(c.forEachEmptyFieldComponent((e) {}), greaterThan(0));

      expect(
        c.selectElementsNonTypedValues('input[type="text"]'),
        containsPair('name', 'Joe'),
      );
      expect(
        c.selectElementsTypedValues('input', Web.HTMLInputElement),
        containsPair('age', '42'),
      );
    });
  });

  group('UIRoot', () {
    test('render: no null entries (menu/footer optional)', () {
      expect(uiRoot.render().length, equals(3));

      uiRoot.withMenu = false;
      uiRoot.withFooter = false;
      addTearDown(() {
        uiRoot.withMenu = true;
        uiRoot.withFooter = true;
      });

      var rendered = uiRoot.render();
      expect(rendered.length, equals(1));
      expect(rendered.single, isA<UIComponent>());
    });

    test('`Screen` dimension parser', () {
      var screen = window.screen;
      var dimension = Dimension.from(screen)!;
      expect(dimension.width, equals(screen.width));
      expect(dimension.height, equals(screen.height));
    });

    test('instance', () {
      expect(UIRoot.getInstance(), same(uiRoot));
      expect(uiRoot.uiRoot, same(uiRoot));
      expect(uiRoot.uiRootComponent, same(uiRoot));
      expect(uiRoot.isTest, isTrue);
      expect(uiRoot.isClosed, isFalse);
      expect(uiRoot.renderLoading(), isNull);
      expect(UIRootComponent.getInstances(), contains(uiRoot));
      expect(uiRoot.isAnyComponentRendering, isFalse);
      expect(uiRoot.getLocalesManager(), isNotNull);
      expect(uiRoot.initializeLocale('en'), completion(isFalse));
      expect(uiRoot.onPreDefineLocale('en'), completion(isFalse));
      expect(uiRoot.isReady(), isNull);
    });

    test('intlMessageResolver', () {
      var prev = uiRoot.intlMessageResolver;
      addTearDown(() => uiRoot.intlMessageResolver = prev);

      var messages = IntlMessages.package('core_test');
      uiRoot.intlMessageResolver = messages;
      expect(uiRoot.intlMessageResolver, isNotNull);

      uiRoot.intlMessageResolver = (String key, [Map? params]) => 'm-$key';
      expect(uiRoot.intlMessageResolver!('k'), equals('m-k'));
    });

    test('onResize', () {
      var count = uiRoot.resizeEvents.length;
      window.dispatchEvent(web.Event('resize'));
      expect(uiRoot.resizeEvents.length, equals(count + 1));
    });

    test('components tree', () async {
      var c = _TextComponent(uiRoot.content, '<b>in-tree</b>');
      await c.callRenderAndWait();

      expect(uiRoot.getUIComponentByContent(c.content), same(c));
      expect(uiRoot.getUIComponentByContent(null), isNull);
      expect(
        uiRoot.getUIComponentByContent(c.content, includePurgedEntries: true),
        same(c),
      );
      expect(
        uiRoot.getUIComponentByChild(c.content!.querySelector('b')),
        same(c),
      );
      expect(uiRoot.getSubUIComponentsByElement(null), isNull);
      expect(uiRoot.getSubUIComponentsByElement(uiRoot.content), contains(c));
      expect(uiRoot.getSubUIComponentsByElement(web.HTMLDivElement()), isNull);

      uiRoot.purgeUIComponentsTree();
      await uiRoot.purgeRoot();
      expect(uiRoot.getUIComponentByContent(c.content), same(c));
    });

    test('locales', () async {
      expect(UIRoot.getCurrentLocale(), anyOf(isNull, isA<String>()));
      expect(uiRoot.getPreferredLocale(), anyOf(isNull, isA<String>()));
      expect(uiRoot.getInitializedLocales(), isA<List<String>>());

      var changed = uiRoot.onChangeLocale.first;
      var locale = uiRoot.getPreferredLocale() ?? 'en';
      await uiRoot.setPreferredLocale(locale);
      expect(await changed.timeout(Duration(seconds: 3)), same(uiRoot));
    });
  });

  group('UINavigator', () {
    late _NavComponent nav;

    setUpAll(() async {
      nav = _NavComponent(uiRoot.content, ['home', 'page', 'secret']);
      await nav.callRenderAndWait();
    });

    test('navigateTo / currentNavigation / onNavigate', () async {
      var navigated = UINavigator.onNavigate.first;
      UINavigator.navigateTo('page', parameters: {'id': '1'});
      expect(await navigated.timeout(Duration(seconds: 3)), equals('page'));

      expect(UINavigator.currentRoute, equals('page'));
      expect(UINavigator.currentRouteParameters, equals({'id': '1'}));
      expect(UINavigator.currentNavigation!.routeAndParameters, 'page?id=1');
      expect(UINavigator.hasRoute, isTrue);
      expect(UINavigator.getCurrentRoute(defaultRoute: 'x'), equals('page'));
      expect(UINavigator.equalsToCurrentRoute('page'), isTrue);
      expect(
        UINavigator.equalsToCurrentRoute('page', parameters: {'id': '1'}),
        isTrue,
      );
      expect(
        UINavigator.equalsToCurrentRoute('page', parameters: {'id': '2'}),
        isFalse,
      );
      expect(window.location.href, contains('#page?id=1'));

      await testUISleep(ms: 50);
      expect(nav.currentRoute, equals('page'));
      expect(nav.content!.textContent, contains('page'));
    });

    test('route with query string and parametersProvider', () async {
      UINavigator.navigateTo('home?a=1', parameters: {'b': '2'});
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('home'));
      expect(UINavigator.currentRouteParameters, equals({'a': '1', 'b': '2'}));

      UINavigator.navigateToAsync('page', parametersProvider: () => {'p': 'v'});
      await testUISleep(ms: 100);
      expect(UINavigator.currentRouteParameters, equals({'p': 'v'}));
    });

    test('navigate / navigateAsync with Navigation', () async {
      UINavigator.navigate(Navigation(''));
      UINavigator.navigateAsync(Navigation(''));

      UINavigator.navigate(Navigation('home', {'n': '1'}));
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('home'));

      UINavigator.navigateAsync(Navigation('page'), force: true);
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('page'));
    });

    test('back route `<` and history', () async {
      UINavigator.navigateTo('home', force: true);
      await testUISleep(ms: 100);
      UINavigator.navigateTo('page', parameters: {'x': '1'});
      await testUISleep(ms: 100);

      expect(UINavigator.navigationHistory, isNotEmpty);
      expect(UINavigator.navigationHistory.last.route, equals('home'));

      UINavigator.navigateTo('<');
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('home'));

      expect(UINavigator.initialRoute, anyOf(isNull, isA<String>()));
      expect(UINavigator.initialNavigation, anyOf(isNull, isA<Navigation>()));
    });

    test('denied route redirects', () async {
      UINavigator.navigateTo('secret');
      await testUISleep(ms: 300);
      expect(UINavigator.currentRoute, equals('home'));
    });

    test('navigateToMainRoute', () async {
      UINavigator.navigateTo('page', force: true);
      await testUISleep(ms: 100);

      // Logged, in a logged route: stays.
      expect(
        UINavigator.navigateToMainRoute(
          () => true,
          'home',
          'login',
          (r) => r == 'page',
        ),
        isFalse,
      );

      // Not logged, in a logged route: goes to the not logged main route.
      expect(
        UINavigator.navigateToMainRoute(
          () => false,
          'page',
          'home',
          (r) => r == 'page',
        ),
        isTrue,
      );
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('home'));

      // Logged, in a not logged route: goes to the logged main route.
      expect(
        UINavigator.navigateToMainRoute(
          () => true,
          'page',
          'home',
          (r) => r == 'page',
        ),
        isTrue,
      );
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('page'));
    });

    test('URL hash change', () async {
      window.location.hash = '#home?h=1';
      await testUISleep(ms: 200);
      expect(UINavigator.currentRoute, equals('home'));
      expect(UINavigator.currentRouteParameters, equals({'h': '1'}));
    });

    test('`uiconsole` route', () async {
      window.location.hash = '#uiconsole?enable=0';
      await testUISleep(ms: 200);
      expect(UIConsole.get()!.enabled, isFalse);

      window.location.hash = '#uiconsole';
      await testUISleep(ms: 200);
      var button = document.querySelector('#${UIConsole.buttonId}');
      expect(button, isNotNull);
      button!.remove();
      UIConsole.disable();

      UINavigator.navigateTo('home', force: true);
      await testUISleep(ms: 100);
    });

    test('urlFilter', () async {
      UINavigator.urlFilter = (url) => url.replaceFirst('#alias', '#page');
      addTearDown(() => UINavigator.urlFilter = null);

      window.location.hash = '#alias';
      await testUISleep(ms: 200);
      expect(UINavigator.currentRoute, equals('page'));
    });

    test('refreshNavigation', () async {
      var renders = nav.renders;
      UINavigator.get().refreshNavigation(true);
      UINavigator.get().refreshNavigationAsync(true);
      await testUISleep(ms: 100);
      expect(nav.renders, greaterThanOrEqualTo(renders));
    });

    test('status and routes', () {
      expect(UINavigator.isOnline, isNot(UINavigator.isOffline));
      expect(UINavigator.isSecureContext, isTrue);

      expect(UINavigator.navigableRoutes, containsAll(['home', 'page']));
      expect(UINavigator.navigableRoutesAndNames, containsPair('home', 'Home'));
      expect(UINavigator.navigables, contains(nav));
      expect(UINavigator.get().findNavigable('page'), same(nav));
      expect(UINavigator.get().findNavigable('nope'), isNull);
      expect(UINavigator.get().selectNavigables(), isNotEmpty);
      expect(UINavigator.get().selectNavigables(uiRoot.content), isNotEmpty);
    });

    test('findElementNavigableRoutes', () {
      var div = web.HTMLDivElement()
        ..innerHTML = '<a navigate="r1"></a><div><a navigate="r2"></a><b navigate="r1"></b></div>'
            .toJS;
      expect(
        UINavigator.get().findElementNavigableRoutes(div),
        equals(['r1', 'r2']),
      );
    });

    test('navigateOnClick navigates', () async {
      var div = _attachedDiv();
      var sub = UINavigator.navigateOnClick(div, 'page', {'c': '1'});
      addTearDown(() => sub?.cancel());
      expect(
        UINavigator.navigateOnClick(div, 'page', {'c': '1'}),
        isNull,
        reason: 'already registered',
      );

      div.click();
      await testUISleep(ms: 100);
      expect(UINavigator.currentRoute, equals('page'));
      expect(UINavigator.currentRouteParameters, equals({'c': '1'}));
    });

    // Regression: `parameterAsNumList`/`parameterAsBoolList` threw a
    // `TypeError` (from `swiss_knife`'s inline-list parsers).
    test('Navigation lists', () {
      var navigation = Navigation('r', {
        's': 'a, b',
        'n': '1, 2.5',
        'b': 'true,false',
      });
      expect(navigation.parameterAsStringList('s'), equals(['a', 'b']));
      expect(navigation.parameterAsNumList('n'), equals([1, 2.5]));
      expect(navigation.parameterAsBoolList('b'), equals([true, false]));
      expect(navigation.toString(), contains('route: r'));

      var empty = Navigation('r');
      expect(empty.parameter('x', 'd'), equals('d'));
      expect(empty.parameterAsInt('x', 1), equals(1));
      expect(empty.parameterAsNum('x', 2), equals(2));
      expect(empty.parameterAsBool('x', true), isTrue);
      expect(empty.parameterAsStringList('x', ['d']), equals(['d']));
      expect(empty.parameterAsIntList('x', [1]), equals([1]));
      expect(empty.parameterAsNumList('x', [1]), equals([1]));
      expect(empty.parameterAsBoolList('x', [true]), equals([true]));
    });

    test('UINavigableComponent routes', () {
      expect(nav.routesAndNames, containsPair('page', 'Page'));
      expect(nav.menuRoutes, isNot(contains('secret')));
      expect(nav.menuRoutesAndNames.keys, isNot(contains('secret')));
      expect(nav.findRoutes, isFalse);

      var wildcard = _WildcardNav(uiRoot.content);
      expect(wildcard.findRoutes, isTrue);
      expect(wildcard.canNavigateTo('dynamic-route'), isTrue);
      expect(wildcard.routes, contains('dynamic-route'));
      expect(wildcard.canNavigateTo('unknown'), isFalse);
      expect(wildcard.updateRoutes(['x']), isTrue);
      expect(wildcard.updateRoutes(['x']), isFalse);

      wildcard.setRoutes(['a']);
      expect(wildcard.routes, equals(['a']));
      wildcard.setRoutes(null);
      expect(wildcard.routes, isEmpty);
    });

    // Regression: `UINavigableContent.render` didn't call
    // `notifyChangeRoute`, so its `onChangeRoute` never fired.
    test('UINavigableContent', () async {
      var content = _NavContent(uiRoot.content);
      var routes = <String>[];
      content.onChangeRoute.listen(routes.add);

      await content.callRenderAndWait();
      expect(content.content!.textContent, equals('headc1foot'));
      expect(
        (content.content!.firstElementChild! as web.HTMLElement).style.height,
        equals('10px'),
      );

      expect(content.navigateTo('c2', {'q': '1'}), isTrue);
      expect(content.navigateTo('c2', {'q': '1'}), isTrue, reason: 'same');
      expect(content.navigateTo('nope'), isFalse);
      await testUISleep(ms: 50);

      expect(content.content!.textContent, contains('c2'));
      expect(routes, equals(['c1', 'c2']));
    });
  });

  group('UIComponentInternals', () {
    test('construct / content / refresh', () async {
      var c = _LateComponent();
      expect(c.content, isNull);

      var internals = c.componentInternals;
      internals.setContent(web.HTMLDivElement() as web.HTMLElement);
      internals.construct(
        false,
        true,
        'cls',
        null,
        'comp-cls',
        'color: red',
        null,
        null,
        false,
      );
      expect(internals.getContent()!.classList.contains('cls'), isTrue);
      expect(internals.getContent()!.classList.contains('comp-cls'), isTrue);

      c.callRender();
      expect(c.renders, equals(1));
      internals.refreshInternal();
      expect(c.renders, equals(2));

      internals.parseAttributes(c.content!.children.asListViewFixed);
      internals.ensureAllRendered([c]);
    });
  });

  // Keep last: closes the `UIRoot`.
  group('UIRoot.close', () {
    test('close', () async {
      var closed = uiRoot.onClose.first;
      expect(await uiRoot.close(), isTrue);
      expect(await uiRoot.close(), isFalse);
      expect(uiRoot.isClosed, isTrue);
      expect(await closed, same(uiRoot));

      var rendered = uiRoot.render();
      expect((rendered.single as web.Element).textContent, equals('CLOSED'));
    });
  });
}

class _CoreRoot extends UIRoot {
  _CoreRoot(super.rootContainer) : super(id: 'core-root');

  bool withMenu = true;

  bool withFooter = true;

  final List<Event> resizeEvents = [];

  @override
  UIComponent? renderMenu() =>
      withMenu ? _TextComponent(content, 'menu', id: 'root-menu') : null;

  @override
  UIComponent? renderContent() =>
      _TextComponent(content, 'root content', id: 'root-content');

  @override
  UIComponent? renderFooter() =>
      withFooter ? _TextComponent(content, 'footer', id: 'root-footer') : null;

  @override
  void onResize(Event e) => resizeEvents.add(e);

  @override
  web.Element? renderClosed() => web.HTMLDivElement()..textContent = 'CLOSED';
}

class _EventHandler extends UIEventHandler {}

class _TextComponent extends UIComponent {
  final String text;

  _TextComponent(super.parent, this.text, {super.id, super.style});

  @override
  dynamic render() => text;
}

class _DOMNodeComponent extends UIComponent {
  final DOMNode node;

  _DOMNodeComponent(super.parent, this.node);

  @override
  dynamic render() => node;
}

class _FieldComponent extends UIComponent implements UIField<String> {
  @override
  final String fieldName;

  String? _value;

  _FieldComponent(super.parent, this.fieldName, this._value);

  @override
  String? getFieldValue() => _value;

  @override
  void setFieldValue(String? value) => _value = value;

  @override
  dynamic render() => $input(id: '$fieldName-input', type: 'text');
}

class _FieldMapComponent extends UIComponent implements UIFieldMap<String> {
  _FieldMapComponent(super.parent);

  @override
  Map<String, String> getFieldMap() => {'a': '1'};

  @override
  dynamic render() => 'map';
}

class _GenComponent extends UIComponent {
  static final UIComponentGenerator<_GenComponent> _generator =
      UIComponentGenerator<_GenComponent>(
        'core-gen',
        'div',
        'core-gen',
        '',
        (parent, attributes, contentHolder, contentNodes) =>
            _GenComponent(parent),
        [
          UIComponentAttributeHandler<_GenComponent, String>(
            'title',
            parser: (v) => v?.toString(),
            getter: (c) => c.title,
            setter: (c, v) => c.title = v,
            cleaner: (c) => c.title = null,
          ),
        ],
      );

  String? title;

  _GenComponent(super.parent) : super(generator: _generator);

  @override
  dynamic render() => 'gen';
}

class _AnyRender extends UIComponent {
  final Object? Function() renderer;

  _AnyRender(super.parent, this.renderer);

  @override
  dynamic render() => renderer();

  @override
  dynamic renderLoading() => 'loading...';
}

class _AsDOM implements AsDOMElement {
  @override
  DOMElement get asDOMElement => $span(content: 'as-dom');
}

class _CountingComponent extends UIComponent {
  int renders = 0;
  int preRenders = 0;
  int posRenders = 0;

  _CountingComponent(super.parent, {super.preserveRender, super.id});

  @override
  void preRender() => preRenders++;

  @override
  void posRender() => posRenders++;

  @override
  dynamic render() {
    renders++;
    return '<span>render $renders</span>';
  }
}

class _ActionComponent extends UIComponent {
  final List<String> actions = [];

  _ActionComponent(super.parent);

  @override
  dynamic render() => [
    $button(id: 'act', attributes: {'action': 'do-action'}, content: 'a'),
    $button(id: 'evt', attributes: {'onEventClick': 'do-click'}, content: 'b'),
    $span(id: 'nav', attributes: {'navigate': 'some-route'}, content: 'n'),
  ];

  @override
  void action(String action) => actions.add(action);
}

class _SubComponent extends UIComponent {
  _SubComponent(super.parent, UIComponent parentComponent)
    : super.subComponent(parentComponent: parentComponent);

  @override
  dynamic render() => 'sub';
}

class _DeniedComponent extends UIComponent {
  _DeniedComponent(super.parent);

  @override
  bool isAccessible() => false;

  @override
  String? deniedAccessRoute() => 'home';

  @override
  dynamic render() => 'never';
}

class _ParentComponent extends UIComponent {
  _ParentComponent(super.parent) : super(id: 'parent-c');

  late final _ChildComponent child = _ChildComponent(content);

  @override
  dynamic render() => [
    $span(id: 'p-span', content: 'ps'),
    $input(id: 'p-input', value: 'iv'),
    child,
  ];
}

class _ChildComponent extends UIComponent {
  _ChildComponent(super.parent) : super(id: 'child-c');

  @override
  dynamic render() => $span(content: 'child');
}

class _FieldsFormComponent extends UIComponent {
  _FieldsFormComponent(super.parent);

  @override
  dynamic render() => [
    $input(type: 'text', name: 'name'),
    $input(type: 'text', name: 'age'),
    $checkbox(name: 'g_1', value: '1'),
    $checkbox(name: 'g_2', value: '2'),
    _FieldComponent(content, 'comp', 'comp-value'),
  ];
}

class _NavComponent extends UINavigableComponent {
  int renders = 0;

  _NavComponent(super.parent, super.routes);

  @override
  String? getRouteName(String route) =>
      route[0].toUpperCase() + route.substring(1);

  @override
  bool isRouteHiddenFromMenu(String route) => route == 'secret';

  @override
  bool isAccessibleRoute(String route) => route != 'secret';

  @override
  String? deniedAccessRouteOfRoute(String route) => 'home';

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    renders++;
    return 'route: $route';
  }
}

class _WildcardNav extends UINavigableComponent {
  _WildcardNav(Object? parent) : super(parent, ['*']);

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      route == 'dynamic-route' || route == '' || route == null
      ? 'dynamic'
      : null;
}

class _NavContent extends UINavigableContent {
  _NavContent(Object? parent) : super(parent, ['c1', 'c2'], topMargin: 10);

  @override
  dynamic renderRouteHead(String? route, Map<String, String>? parameters) =>
      'head';

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      '$route';

  @override
  dynamic renderRouteFoot(String? route, Map<String, String>? parameters) =>
      'foot';
}

class _LateComponent extends UIComponent {
  int renders = 0;

  _LateComponent() : super(null, construct: false);

  @override
  dynamic render() {
    renders++;
    return 'late';
  }
}
