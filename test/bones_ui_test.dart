@TestOn('browser')
import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'dart:html' as web;

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

      expect(uiRoot.querySelector('#my-contact'), isNull);

      var myHome = uiRoot.querySelector('#my-home');
      expect(myHome, isA<web.DivElement>());

      expect(myHome?.text, contains('Hello world'));

      var btn1 = uiRoot.selectExpected<web.ButtonElement>('*');
      expect(btn1, isA<web.ButtonElement>());
      expect(btn1.text, equals('Go to: contact'));

      btn1.click();
      await testUISleep(ms: 200);

      expect(uiRoot.querySelector('#my-home'), isNull);
      expect(uiRoot.querySelector('#my-contact'), isNotNull);

      {
        var myContact = uiRoot.querySelector<web.DivElement>('#my-contact');
        expect(myContact?.text, isNot(contains('foo@mail.com')));
      }

      await testUISleep(ms: 1200);

      {
        var myContact = uiRoot.querySelector<web.DivElement>('#my-contact');
        expect(myContact, isA<web.DivElement>());

        expect(myContact?.text, contains('foo@mail.com'));
      }

      var btn2 = uiRoot.selectExpected<web.ButtonElement>('*');
      expect(btn2, isA<web.ButtonElement>());
      expect(btn2.text, equals('Go to: home'));

      btn2.click();
      await testUISleep(ms: 200);

      expect(uiRoot.querySelector('#my-contact'), isNull);

      var myHome2 = uiRoot.querySelector('#my-home');
      expect(myHome2, isA<web.DivElement>());
    });
  });
}

class MyRoot extends UIRoot {
  MyRoot(super.rootContainer);

  late final _myContent = MyContent(this);

  @override
  UIComponent? renderContent() => _myContent;
}

class MyContent extends UINavigableContent {
  MyContent(Object? parent) : super(parent, ['home', 'contact']);

  @override
  renderRoute(String? route, Map<String, String>? parameters) {
    switch (route) {
      case 'contact':
        return MyContact(this);
      case 'home':
      default:
        return MyHome(this);
    }
  }
}

class MyHome extends UIComponent {
  MyHome(super.parent) : super(id: 'my-home');

  @override
  render() =>
      '<h1>Home</h1><p>Hello world!<br><hr><button navigate="contact">Go to: contact</button>';
}

class MyContact extends UIComponent {
  MyContact(super.parent) : super(id: 'my-contact');

  @override
  render() {
    return Future.delayed(Duration(milliseconds: 1000), _myRender);
  }

  _myRender() => $div(content: [
        $tag('h1', content: 'Contact'),
        $p(),
        $span(content: 'foo@mail.com'),
        $hr(),
        $button(attributes: {'navigate': 'home'}, content: 'Go to: home'),
      ]);
}
