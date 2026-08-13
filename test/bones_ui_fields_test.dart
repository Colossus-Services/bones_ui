@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UIComponent.parseClasses/parseStyle', () {
    test('parses classes from a String, a List and nested Lists', () {
      expect(UIComponent.parseClasses('a b'), equals(['a', 'b']));
      expect(UIComponent.parseClasses('a,b;c'), equals(['a', 'b', 'c']));
      expect(UIComponent.parseClasses(['a', 'b']), equals(['a', 'b']));
      expect(
        UIComponent.parseClasses([
          'a',
          ['b', 'c'],
        ]),
        equals(['a', 'b', 'c']),
      );
    });

    test('merges and deduplicates two class sources', () {
      expect(UIComponent.parseClasses('a b', 'b c'), equals(['a', 'b', 'c']));
      expect(UIComponent.parseClasses('a a'), equals(['a']));
      expect(UIComponent.parseClasses(null, 'a'), equals(['a']));
      expect(UIComponent.parseClasses(null, null), isEmpty);
    });

    test('ignores empty entries', () {
      expect(UIComponent.parseClasses('  a  ,, b '), equals(['a', 'b']));
      expect(UIComponent.parseClasses(''), isEmpty);
    });

    test('parses style entries', () {
      expect(
        UIComponent.parseStyle('color: red; background: blue'),
        equals(['color: red', 'background: blue']),
      );
      expect(UIComponent.parseStyle(''), isEmpty);
    });
  });

  group('UIComponent attributes', () {
    late final _FieldsRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _FieldsRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('get/set/clear the `style` attribute', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.setAttribute('style', 'color: red'), isTrue);
      expect(component.getAttribute('style'), contains('color'));
      expect(component.content!.style.color, equals('red'));

      expect(component.clearAttribute('style'), isTrue);
      expect(component.content!.style.color, equals(''));
    });

    test('get/set the `class` attribute', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.setAttribute('class', 'a b'), isTrue);
      expect(component.content!.classList.contains('a'), isTrue);
      expect(component.content!.classList.contains('b'), isTrue);
      expect(component.getAttribute('class'), contains('a'));

      // `setAttribute` replaces the previous classes:
      component.setAttribute('class', 'c');
      expect(component.content!.classList.contains('a'), isFalse);
      expect(component.content!.classList.contains('c'), isTrue);

      // `appendAttribute` keeps them:
      component.appendAttribute('class', 'd');
      expect(component.content!.classList.contains('c'), isTrue);
      expect(component.content!.classList.contains('d'), isTrue);
    });

    test('the `id` attribute is set through `appendAttribute`', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.appendAttribute('id', 'the-id'), isTrue);
      expect(component.id, equals('the-id'));
      expect(component.content!.id, equals('the-id'));

      component.setID(null);
      expect(component.id, isNull);
      expect(component.content!.id, equals(''));
    });

    test('the `navigate` attribute', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.setAttribute('navigate', 'my-route'), isTrue);
      expect(component.getAttribute('navigate'), equals('my-route'));

      expect(component.clearAttribute('navigate'), isTrue);
      expect(component.getAttribute('navigate'), isNull);
    });

    test('`setAttribute` with a null value clears it', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      component.setAttribute('class', 'a');
      expect(component.content!.classList.contains('a'), isTrue);

      expect(component.setAttribute('class', null), isTrue);
      expect(component.content!.classList.contains('a'), isFalse);
    });

    test('an unknown attribute is not set without a generator', () {
      var component = _PlainComponent(uiRoot.content);
      component.ensureRendered();

      expect(component.setAttribute('unknown', 'x'), isFalse);
      expect(component.getAttribute('unknown'), isNull);
      expect(component.clearAttribute('unknown'), isFalse);
      expect(component.setAttribute(null, 'x'), isFalse);
      expect(component.setAttribute('  ', 'x'), isFalse);
    });
  });

  group('UIComponent fields', () {
    late final _FieldsRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _FieldsRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    Future<_FormComponent> newForm() async {
      var form = _FormComponent(uiRoot.content);
      await form.callRenderAndWait();
      await testUISleep(ms: 50);
      return form;
    }

    test('getFields returns all the field values', () async {
      var form = await newForm();

      var fields = form.getFields();

      expect(fields['name'], equals('Joe'));
      expect(fields['age'], equals('42'));
      expect(fields['accept'], isNull, reason: 'Unchecked checkbox');
    });

    test('getFieldsNames and getFieldsElements', () async {
      var form = await newForm();

      expect(form.getFieldsNames(), containsAll(['name', 'age', 'accept']));
      expect(form.getFieldsElements().length, greaterThanOrEqualTo(3));
      expect(form.hasEmptyField(), isFalse);
    });

    test('getField and getFieldAs convert the value', () async {
      var form = await newForm();

      expect(form.getField('name'), equals('Joe'));
      expect(form.getField('nope', 'def'), equals('def'));
      expect(form.getField(null, 'def'), equals('def'));

      expect(form.getFieldAs<int>('age'), equals(42));
      expect(form.getFieldAs<double>('age'), equals(42.0));
      expect(form.getFieldAs<num>('age'), equals(42));
      expect(form.getFieldAs<String>('name'), equals('Joe'));
      expect(form.getFieldAs<int>('nope'), isNull);
    });

    test('setField updates the element value', () async {
      var form = await newForm();

      form.setField('name', 'Ana');

      expect(form.getField('name'), equals('Ana'));
      expect(form.getPreviousRenderedFieldValue('name'), equals('Ana'));
    });

    test('getFieldElement / getFieldElementByValue', () async {
      var form = await newForm();

      var elem = form.getFieldElementNonTyped('name');
      expect(elem, isNotNull);

      var typed = form.getFieldElementTyped<web.HTMLInputElement>(
        'name',
        Web.HTMLInputElement,
      );
      expect(typed, isNotNull);
      expect(typed!.value, equals('Joe'));

      expect(form.getFieldElementByValue('name', 'Joe'), isNotNull);
      expect(form.getFieldElementByValue('name', 'nope'), isNull);
    });

    test('isEmptyField and getEmptyFields', () async {
      var form = await newForm();

      expect(form.isEmptyField('name'), isFalse);
      expect(form.isEmptyField('accept'), isTrue);
      expect(form.isEmptyField(null), isFalse);

      expect(form.getEmptyFields(), contains('accept'));
      expect(form.getEmptyFields(), isNot(contains('name')));
    });

    test('forEach over fields', () async {
      var form = await newForm();

      var count = form.forEachFieldElement((_) {});
      expect(count, greaterThanOrEqualTo(3));

      var emptyCount = form.forEachEmptyFieldElement((_) {});
      expect(emptyCount, equals(1));
    });

    test('fields filtered by `fields`/`ignoreFields`', () async {
      var form = await newForm();

      expect(form.getFields(fields: ['name']).keys, equals(['name']));
      expect(
        form.getFields(ignoreFields: ['name']).keys,
        isNot(contains('name')),
      );
    });
  });

  group('UIComponent fields group by prefix', () {
    late final _FieldsRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _FieldsRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    Future<_GroupComponent> newGroup() async {
      var group = _GroupComponent(uiRoot.content);
      await group.callRenderAndWait();
      await testUISleep(ms: 50);
      return group;
    }

    test('getFieldsGroupByPrefix', () async {
      var group = await newGroup();

      var map = group.getFieldsGroupByPrefix<String, String>('item_');

      expect(map['a'], equals('1'));
      expect(map['b'], equals('2'));
      expect(map.containsKey('other'), isFalse);
    });

    test('getFieldsGroupByPrefix with typed values', () async {
      var group = await newGroup();

      var map = group.getFieldsGroupByPrefix<String, int>('item_');

      expect(map['a'], equals(1));
      expect(map['b'], equals(2));
    });

    test('getFieldsGroupKeysByPrefix / ValuesByPrefix', () async {
      var group = await newGroup();

      expect(
        group.getFieldsGroupKeysByPrefix<String>('item_'),
        containsAll(['a', 'b']),
      );
      expect(
        group.getFieldsGroupValuesByPrefix<String>('item_'),
        containsAll(['1', '2']),
      );
    });

    test('getFieldsGroupChecks / CheckedKeys', () async {
      var group = await newGroup();

      var checks = group.getFieldsGroupChecks<String>('check_');

      expect(checks['x'], isTrue);
      expect(checks['y'], isFalse);

      expect(group.getFieldsGroupCheckedKeys<String>('check_'), equals(['x']));
    });

    test('getFieldsGroupEntriesByPrefix with a filter', () async {
      var group = await newGroup();

      var entries = group.getFieldsGroupEntriesByPrefix<String, String>(
        'item_',
        filter: (k, v) => k == 'a',
      );

      expect(entries.length, equals(1));
      expect(entries.single.key, equals('a'));
    });
  });
}

class _FieldsRoot extends UIRoot {
  _FieldsRoot(super.rootContainer) : super(id: 'fields-root');

  @override
  UIComponent? renderContent() => null;
}

class _PlainComponent extends UIComponent {
  _PlainComponent(super.parent);

  @override
  dynamic render() => 'plain';
}

class _FormComponent extends UIComponent {
  _FormComponent(super.parent);

  @override
  dynamic render() =>
      '<input field="name" type="text" value="Joe">'
      '<input field="age" type="text" value="42">'
      '<input field="accept" type="checkbox" value="yes">';
}

class _GroupComponent extends UIComponent {
  _GroupComponent(super.parent);

  @override
  dynamic render() =>
      '<input field="item_a" type="text" value="1">'
      '<input field="item_b" type="text" value="2">'
      '<input field="other" type="text" value="3">'
      '<input field="check_x" type="checkbox" value="true" checked>'
      '<input field="check_y" type="checkbox" value="true">';
}
