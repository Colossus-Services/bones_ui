@TestOn('browser')
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
        'sin': math.sin
      };

      var elementsAccess = [];

      final evaluator = UILayoutEvaluator((String id, bool all) {
        elementsAccess.add(id);
        var list = [
          {
            'center': {'x': 11, 'y': 22}
          },
          {
            'center': {'x': 111, 'y': 222}
          }
        ];
        return all ? list : list[0];
      }, (dynamic elem, String property) {
        return elem[property];
      });

      print(evaluator.toString());

      var r = evaluator.processLayout(expStr, context, 'px');

      print('elementsAccess: $elementsAccess');
      print('r: $r');

      expect(r, equals('11px'));
      expect(elementsAccess, equals(['foo', '_']));
    });
  });
}
