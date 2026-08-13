@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UIAsyncContent', () {
    UIAsyncContent newAsyncContent(Object? loadingContent) =>
        UIAsyncContent.future(Future.value('loaded'), loadingContent);

    /// Casts [o] to an [web.HTMLElement], failing the test if it's not one.
    web.HTMLElement asHTMLElement(Object? o) {
      expect(
        o.asJSAny.isA<web.HTMLElement>(),
        isTrue,
        reason: 'Not an `HTMLElement`: <<$o>> (${o.runtimeType})',
      );
      return o as web.HTMLElement;
    }

    test('HTML with a single root node resolves to that node', () {
      var asyncContent = newAsyncContent('<b>bold</b>');
      var content = asHTMLElement(asyncContent.loadingContent);

      expect(content.tagName.toLowerCase(), equals('b'));
      expect(content.text, equals('bold'));
    });

    test('HTML with multiple root nodes is wrapped in an element', () {
      var asyncContent = newAsyncContent('<b>bold</b><i>italic</i>');

      Object? content = asyncContent.loadingContent;
      expect(
        content,
        isNot(isA<String>()),
        reason: 'A multi-root HTML content should be converted to an element',
      );

      var element = asHTMLElement(content);
      expect(element.children.length, equals(2));
      expect(element.text, equals('bolditalic'));
    });

    test('plain text is wrapped in a `span`', () {
      var asyncContent = newAsyncContent('just text');

      Object? content = asyncContent.loadingContent;
      expect(content.asJSAny.isA<web.HTMLSpanElement>(), isTrue);
      expect(asHTMLElement(content).text, equals('just text'));
    });

    test('an element is kept as is', () {
      var div = web.HTMLDivElement()..text = 'the div';
      var asyncContent = newAsyncContent(div);

      expect(identical(asyncContent.loadingContent, div), isTrue);
    });

    test('loads the content of the `Future`', () async {
      var asyncContent = UIAsyncContent.future(
        Future.delayed(Duration(milliseconds: 50), () => '<b>ok</b><i>!</i>'),
        'loading...',
      );

      expect(asyncContent.isLoaded, isFalse);
      expect(asyncContent.loadCount, equals(0));

      await testUISleep(ms: 300);

      expect(asyncContent.isLoaded, isTrue);
      expect(asyncContent.isOK, isTrue);
      expect(asyncContent.isWithError, isFalse);
      expect(asyncContent.loadCount, equals(1));

      expect(asHTMLElement(asyncContent.content).text, equals('ok!'));
    });

    test('an error in the `Future` exposes the error content', () async {
      var asyncContent = UIAsyncContent.future(
        Future.delayed(
          Duration(milliseconds: 50),
          () => throw StateError('the error'),
        ),
        'loading...',
        errorContent: 'failed!',
      );

      await testUISleep(ms: 300);

      expect(asyncContent.isLoaded, isTrue);
      expect(asyncContent.isOK, isFalse);
      expect(asyncContent.isWithError, isTrue);
      expect(asyncContent.error, isA<StateError>());

      expect(asHTMLElement(asyncContent.content).text, equals('failed!'));
    });
  });
}
