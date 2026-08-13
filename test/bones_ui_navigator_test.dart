@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('Navigation', () {
    test('encodeRouteAndParameters', () {
      expect(Navigation.encodeRouteAndParameters('home', null), equals('home'));
      expect(Navigation.encodeRouteAndParameters('home', {}), equals('home'));
      expect(
        Navigation.encodeRouteAndParameters(' home ', {'a': '1'}),
        equals('home?a=1'),
      );
    });

    test('parameters are not URL-encoded for `,`', () {
      var encoded = Navigation.encodeParameters({'ids': '1,2,3'});
      expect(encoded, equals('ids=1,2,3'));
    });

    test('typed parameters', () {
      var navigation = Navigation('route', {
        'i': '10',
        'n': '1.5',
        'b': 'true',
        'l': '1, 2,3',
      });

      expect(navigation.isValid, isTrue);
      expect(navigation.parameter('i'), equals('10'));
      expect(navigation.parameter('x', 'def'), equals('def'));
      expect(navigation.parameterAsInt('i'), equals(10));
      expect(navigation.parameterAsNum('n'), equals(1.5));
      expect(navigation.parameterAsBool('b'), isTrue);
      expect(navigation.parameterAsIntList('l'), equals([1, 2, 3]));
    });

    test('an empty route is not valid', () {
      expect(Navigation('').isValid, isFalse);
    });
  });

  group('UINavigator.navigateOnClick', () {
    web.HTMLDivElement newElement() {
      var div = web.HTMLDivElement();
      document.body!.append(div);
      return div;
    }

    test('registers the route in the element', () {
      var div = newElement();

      var subscription = UINavigator.navigateOnClick(div, 'my-route', {
        'a': '1',
      });

      expect(subscription, isNotNull);
      expect(UINavigator.getNavigateOnClick(div), equals('my-route?a=1'));
      expect(div.style.cursor, equals('pointer'));

      subscription!.cancel();
    });

    test('a null route does not throw and clears a previous route', () {
      var div = newElement();

      var subscription = UINavigator.navigateOnClick(div, 'my-route');
      expect(UINavigator.getNavigateOnClick(div), equals('my-route'));
      subscription!.cancel();

      // Should not throw a null-check error:
      var subscription2 = UINavigator.navigateOnClick(div, null);

      expect(subscription2, isNull);
      expect(UINavigator.getNavigateOnClick(div), isNull);
      expect(div.style.cursor, isNot(equals('pointer')));
    });

    test('an empty route does not throw', () {
      var div = newElement();
      expect(UINavigator.navigateOnClick(div, ''), isNull);
      expect(UINavigator.getNavigateOnClick(div), isNull);
    });

    test('clearNavigateOnClick', () {
      var div = newElement();

      expect(
        UINavigator.clearNavigateOnClick(div),
        isFalse,
        reason: 'Nothing to clear yet',
      );

      UINavigator.navigateOnClick(div, 'my-route')!.cancel();

      expect(UINavigator.clearNavigateOnClick(div), isTrue);
      expect(UINavigator.getNavigateOnClick(div), isNull);
    });
  });
}
