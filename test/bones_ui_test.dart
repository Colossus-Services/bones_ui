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

      expect(myHome?.text, contains('- uiRoot: MyRoot'));
      expect(myHome?.text, contains('- uiRootComponent: MyRoot'));

      var btn1 = uiRoot.selectExpected<web.ButtonElement>('*');
      expect(btn1, isA<web.ButtonElement>());
      expect(btn1.text, equals('Go to: contact'));

      btn1.click();
      await testUISleep(ms: 200);

      expect(uiRoot.querySelector('#my-home'), isNull);
      expect(uiRoot.querySelector('#my-contact'), isNotNull);

      var myContact1 = uiRoot.querySelector<web.DivElement>('#my-contact');

      expect(myContact1!.text, contains('Loading...'));
      expect(myContact1.text, isNot(contains('foo@mail.com')));

      expect(isComponentInDOM(myContact1), isTrue);
      expect(canBeInDOM(myContact1), isTrue);
      expect(canBeInDOM(myContact1.text), isFalse);

      var uiContact1 = uiRoot.getUIComponentByContent(myContact1);
      expect(uiContact1, isA<MyContact>());

      await testUISleep(ms: 1200);

      var myContact2 = uiRoot.querySelector<web.DivElement>('#my-contact');
      expect(myContact2, isA<web.DivElement>());

      expect(myContact2?.text, contains('foo@mail.com'));
      expect(isComponentInDOM(myContact1), isTrue);

      expect(myContact1.text, contains('* uiRoot: MyRoot'));
      expect(myContact1.text, contains('* uiRootComponent: MyRoot'));

      var uiContact2 = uiRoot.getUIComponentByContent(myContact2);
      expect(uiContact2, isA<MyContact>());

      expect(uiRoot.getUIComponentByContent(myContact1), isA<MyContact>());

      expect(identical(uiContact1, uiContact2), isTrue);

      var btn2 = uiRoot.selectExpected<web.ButtonElement>('*');
      expect(btn2, isA<web.ButtonElement>());
      expect(btn2.text, equals('Go to: home'));

      btn2.click();
      await testUISleep(ms: 200);

      expect(uiRoot.querySelector('#my-contact'), isNull);
      expect(isComponentInDOM(myContact1), isFalse);
      expect(canBeInDOM(myContact1), isTrue);

      var myHome2 = uiRoot.querySelector('#my-home');
      expect(myHome2, isA<web.DivElement>());
    });
  });
}

class MyRoot extends UIRoot {
  MyRoot(super.rootContainer) : super(id: 'MyRoot');

  late final _myContent = MyContent(this);

  @override
  UIComponent? renderContent() => _myContent;
}

class MyContent extends UINavigableContent {
  MyContent(Object? parent)
      : super(parent, ['home', 'contact'], id: 'MyContent');

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
  render() => '<h1>Home</h1>'
      '<p>Hello world!<br>'
      '<hr>'
      '- uiRoot: ${uiRoot?.id} <br>'
      '- uiRootComponent: ${uiRootComponent?.id} '
      '<hr>'
      '<button navigate="contact">Go to: contact</button>';
}

class MyContact extends UIComponent {
  MyContact(super.parent) : super(id: 'my-contact');

  @override
  renderLoading() => 'Loading...';

  @override
  render() {
    return Future.delayed(Duration(milliseconds: 1000), _myRender);
  }

  _myRender() => $div(content: [
        $tag('h1', content: 'Contact'),
        $p(),
        $span(content: 'foo@mail.com'),
        $hr(),
        $div(content: ['* uiRoot: ', uiRoot?.id]),
        $div(content: ['* uiRootComponent: ', uiRootComponent?.id]),
        $hr(),
        $button(attributes: {'navigate': 'home'}, content: 'Go to: home'),
      ]);
}
