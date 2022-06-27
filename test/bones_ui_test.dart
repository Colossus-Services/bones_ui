@TestOn('browser')
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:test/test.dart';

void main() {
  group('Components', () {
    final rootContainer = DivElement();
    late final MyRoot root;

    setUpAll(() {
      root = MyRoot(rootContainer);
    });

    test('initialize', () async {
      root.initialize();
      await root.onFinishRender.first;

      var myHome = rootContainer.querySelector('#my-home');
      expect(myHome, isA<DivElement>());

      expect(myHome?.text, contains('Hello world'));
    });
  });
}

class MyRoot extends UIRoot {
  MyRoot(Element? rootContainer) : super(rootContainer);

  @override
  UIComponent? renderContent() => MyHome(content!);
}

class MyHome extends UIComponent {
  MyHome(Element? parent) : super(parent, id: 'my-home');

  @override
  render() => '<h1>Home</h1><p> Hello world!';
}
