@TestOn('browser')
library;

import 'dart:math' as math;

import 'package:bones_ui/src/bones_ui_layout.dart';
import 'package:test/test.dart';

void main() {
  group('UILayout', () {
    setUp(() {});

    test('test expression', () {
      var expStr = '#foo[this.i].center.x';

      var context = {
        'i': 0,
        'x': [10, 20],
        'cos': math.cos,
        'sin': math.sin,
      };

      var elementsAccess = [];

      final evaluator = UILayoutEvaluator(
        (String id, bool all) {
          elementsAccess.add(id);
          var list = [
            {
              'center': {'x': 11, 'y': 22},
            },
            {
              'center': {'x': 111, 'y': 222},
            },
          ];
          return all ? list : list[0];
        },
        (dynamic elem, String property) {
          return elem is Map ? elem[property] : null;
        },
      );

      print(evaluator.toString());

      var r = evaluator.processLayout(expStr, context, 'px');

      print('elementsAccess: $elementsAccess');
      print('r: $r');

      expect(r, equals('11px'));
      expect(elementsAccess, equals(['foo', '_']));
    });

    UILayoutEvaluator newEvaluator() => UILayoutEvaluator(
      (String id, bool all) => null,
      (dynamic elem, String property) => elem is Map ? elem[property] : null,
    );

    test('unit arithmetic (same unit)', () {
      var evaluator = newEvaluator();
      expect(evaluator.processLayout('10px + 5px', {}), equals('15px'));
      expect(evaluator.processLayout('20px - 8px', {}), equals('12px'));
      expect(evaluator.processLayout('10px * 3', {}), equals('30px'));
    });

    test('unit arithmetic with context variable', () {
      var evaluator = newEvaluator();
      var r = evaluator.processLayout('10px + x', {'x': 5});
      expect(r, equals('15px'));
    });

    test('applies fallback unit to plain number result', () {
      var evaluator = newEvaluator();
      expect(evaluator.processLayout('2 + 3', {}, 'px'), equals('5px'));
      // A value that already carries a unit must not get a second one.
      expect(evaluator.processLayout('2px + 3px', {}, 'px'), equals('5px'));
    });

    test('mixed units are rejected', () {
      var evaluator = newEvaluator();
      expect(
        () => evaluator.processLayout('10px + 5em', {}),
        throwsUnsupportedError,
      );
    });

    test('returns default value for unresolvable element', () {
      var evaluator = newEvaluator();
      var r = evaluator.processLayout('#missing.center.x', {}, 'px', 'fallback');
      expect(r, equals('fallback'));
    });
  });
}
