@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UIComponent', () {
    late final _TestRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _TestRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('onChildRendered receives the child component', () async {
      var parent = uiRoot.parentComponent;

      await parent.callRenderAndWait();
      await testUISleep(ms: 100);

      expect(
        parent.notifiedChildren,
        isNotEmpty,
        reason: '`onChildRendered` should have been called',
      );

      // The notified component must be the rendered child, never the parent
      // that is being notified:
      for (var c in parent.notifiedChildren) {
        expect(
          identical(c, parent),
          isFalse,
          reason: '`onChildRendered` received the parent instead of the child',
        );
      }

      expect(parent.notifiedChildren, contains(same(parent.child)));
    });

    test('appendStyle keeps previous declarations', () {
      var component = _StyledComponent(uiRoot.content);
      component.ensureRendered();

      var style = component.content!.style;
      expect(style.color, equals('red'));

      component.appendStyle('background-color: blue');

      expect(
        style.color,
        equals('red'),
        reason: 'The previous style entry was corrupted by the appended one',
      );
      expect(style.backgroundColor, equals('blue'));

      component.appendStyle('font-weight: bold');

      expect(style.color, equals('red'));
      expect(style.backgroundColor, equals('blue'));
      expect(style.fontWeight, equals('bold'));
    });

    test('appendClasses adds and removes (`!` prefix) classes', () {
      var component = _StyledComponent(uiRoot.content);
      component.ensureRendered();

      component.appendClasses('foo bar');
      expect(component.content!.classList.contains('foo'), isTrue);
      expect(component.content!.classList.contains('bar'), isTrue);

      component.appendClasses('!foo baz');
      expect(component.content!.classList.contains('foo'), isFalse);
      expect(component.content!.classList.contains('bar'), isTrue);
      expect(component.content!.classList.contains('baz'), isTrue);
    });

    test('getFieldsExtended prioritizes an `UIField` component', () async {
      var component = _FieldsComponent(uiRoot.content);
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var fields = component.getFieldsExtended();

      expect(fields.keys, contains('foo'));
      expect(
        fields['foo'],
        isA<_FieldComponent>(),
        reason:
            'An `UIField` component should win over a plain element '
            'with the same field name',
      );

      expect(fields['bar'], isA<_FieldComponent>());

      // The resolved value should come from the `UIField` component,
      // not from the text of the plain element:
      expect(component.getField('foo'), equals('component-foo'));
    });

    test('`onEventKeyPress` without a `key:action` delimiter', () async {
      var component = _KeyPressComponent(uiRoot.content, 'myAction');
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      expect(
        component.renderedElements,
        isNotEmpty,
        reason: 'A malformed `onEventKeyPress` should not break the render',
      );

      var input = component.querySelectorTyped<web.HTMLInputElement>(
        'input',
        Web.HTMLInputElement,
      );
      expect(input, isNotNull);

      input!.dispatchEvent(
        web.KeyboardEvent('keypress', web.KeyboardEventInit(key: 'x')),
      );

      expect(component.actions, equals(['myAction']));
    });

    test('`onEventKeyPress` with a `key:action` delimiter', () async {
      var component = _KeyPressComponent(uiRoot.content, 'x:myAction');
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var input = component.querySelectorTyped<web.HTMLInputElement>(
        'input',
        Web.HTMLInputElement,
      );
      expect(input, isNotNull);

      input!.dispatchEvent(
        web.KeyboardEvent('keypress', web.KeyboardEventInit(key: 'y')),
      );
      expect(component.actions, isEmpty, reason: 'Key `y` should be ignored');

      input.dispatchEvent(
        web.KeyboardEvent('keypress', web.KeyboardEventInit(key: 'x')),
      );
      expect(component.actions, equals(['myAction']));
    });

    test('focusField focuses the input inside the field component', () async {
      var component = _FieldsComponent(uiRoot.content);
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var focused = component.focusField('bar');
      expect(focused, isTrue);

      var input = component.querySelectorTyped<web.HTMLInputElement>(
        '#bar-input',
        Web.HTMLInputElement,
      );
      expect(input, isNotNull);

      // Note: `identical` is not reliable for JS interop wrappers on
      // `dart2wasm`, so the focused element is checked by containment + ID:
      var activeElement = document.activeElement;
      expect(
        component.content!.contains(activeElement),
        isTrue,
        reason: 'The focused element should be inside the component',
      );
      expect(
        activeElement?.id,
        equals('bar-input'),
        reason: 'The input of the field component should be focused',
      );
    });
  });
}

class _TestRoot extends UIRoot {
  _TestRoot(super.rootContainer) : super(id: 'test-root');

  late final _ParentComponent parentComponent = _ParentComponent(this);

  @override
  UIComponent? renderContent() => parentComponent;
}

class _ParentComponent extends UIComponent {
  final List<UIComponent> notifiedChildren = [];

  _ParentComponent(super.parent) : super(id: 'parent-component');

  late final _ChildComponent child = _ChildComponent(this);

  @override
  dynamic render() => child;

  @override
  void onChildRendered(UIComponent child) {
    notifiedChildren.add(child);
  }
}

class _ChildComponent extends UIComponent {
  _ChildComponent(super.parent) : super(id: 'child-component');

  @override
  dynamic render() => 'child content';
}

class _StyledComponent extends UIComponent {
  _StyledComponent(super.parent) : super(style: 'color: red');

  @override
  dynamic render() => 'styled';
}

/// Renders a plain element and an [UIField] component sharing the field
/// name `foo`, plus a field component named `bar`.
class _FieldsComponent extends UIComponent {
  _FieldsComponent(super.parent) : super(id: 'fields-component');

  @override
  dynamic render() => [
    // The plain element comes after the component with the same field name,
    // to check that the component is the one kept:
    _FieldComponent(this, 'foo', 'component-foo'),
    $div(attributes: {'field': 'foo'}, content: 'plain-foo'),
    _FieldComponent(this, 'bar', 'component-bar'),
  ];
}

class _FieldComponent extends UIComponent implements UIField<String> {
  @override
  final String fieldName;

  String? _value;

  _FieldComponent(super.parent, this.fieldName, this._value)
    : super(id: '$fieldName-field');

  @override
  String? getFieldValue() => _value;

  @override
  void setFieldValue(String? value) => _value = value;

  @override
  dynamic render() => $input(id: '$fieldName-input', type: 'text');
}

class _KeyPressComponent extends UIComponent {
  final String onEventKeyPress;

  final List<String> actions = [];

  _KeyPressComponent(super.parent, this.onEventKeyPress);

  @override
  dynamic render() =>
      $input(type: 'text', attributes: {'onEventKeyPress': onEventKeyPress});

  @override
  void action(String action) {
    actions.add(action);
  }
}
