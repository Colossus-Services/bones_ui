@TestOn('browser')
import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

void main() {
  group('UIRoot', () {
    late final MyRoot uiRoot;

    setUpAll(() async {
      uiRoot =
          await initializeTestUIRoot((rootContainer) => MyRoot(rootContainer));
    });

    test('basic', () async {
      await uiRoot.callRenderAndWait();
      await testUISleep(ms: 100);

      var myHome = uiRoot.querySelector('#my-home');
      expect(myHome, isA<DivElement>());

      expect(myHome?.text, contains('Hello world'));
    });
  });
}

class MyRoot extends UIRoot {
  MyRoot(super.rootContainer);

  @override
  UIComponent? renderContent() => MyHome(content!);
}

class MyHome extends UIComponent {
  MyHome(super.parent) : super(id: 'my-home');

  @override
  render() => '<h1>Home</h1><p> Hello world!';
}
