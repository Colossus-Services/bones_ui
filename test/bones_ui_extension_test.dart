@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

void main() {
  group('UIElementExtension', () {
    late final _ExtensionRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _ExtensionRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    group('resolveInputElementValue', () {
      test('`input` text', () {
        var input = web.HTMLInputElement()
          ..type = 'text'
          ..value = 'the value';

        expect(input.resolveInputElementValue(), equals('the value'));
        expect(input.elementValue, equals('the value'));
        expect(input.isElementValueEmpty, isFalse);
      });

      test('`textarea`', () {
        var textArea = web.HTMLTextAreaElement()..value = 'multi\nline';
        expect(textArea.resolveInputElementValue(), equals('multi\nline'));
      });

      test('`input` checkbox', () {
        var checkbox = web.HTMLInputElement()
          ..type = 'checkbox'
          ..value = 'yes';

        expect(
          checkbox.resolveInputElementValue(),
          isNull,
          reason: 'An unchecked checkbox has no value',
        );

        checkbox.checked = true;
        expect(checkbox.resolveInputElementValue(), equals('yes'));
      });

      test('`input` radio', () {
        var radio = web.HTMLInputElement()
          ..type = 'radio'
          ..value = 'option-a';

        expect(radio.resolveInputElementValue(), isNull);

        radio.checked = true;
        expect(radio.resolveInputElementValue(), equals('option-a'));
      });

      test('`select` with a selected option', () {
        var select = web.HTMLSelectElement();
        select.appendHTML('<option value="a">A</option>');
        select.appendHTML('<option value="b">B</option>');

        // The first option is selected by default:
        expect(select.resolveInputElementValue(), equals('a'));

        select.value = 'b';
        expect(select.resolveInputElementValue(), equals('b'));
      });

      test('a non-input element has no input value', () {
        var div = web.HTMLDivElement()..text = 'text';
        expect(div.resolveInputElementValue(), isNull);
      });
    });

    group('resolveElementValue', () {
      test('falls back to the `field_value` attribute', () {
        var div = web.HTMLDivElement()..text = 'the text';
        div.setAttribute('field_value', 'the attribute value');

        expect(div.resolveElementValue(), equals('the attribute value'));
      });

      test('falls back to the text when allowed', () {
        var div = web.HTMLDivElement()..text = 'the text';

        expect(div.resolveElementValue(), equals('the text'));
        expect(
          div.resolveElementValue(allowTextAsValue: false),
          isNot(equals('the text')),
        );
      });

      test('resolves through an `UIField` component', () async {
        var component = _ValueComponent(uiRoot.content, 'the-field-value');
        await component.callRenderAndWait();

        var value = component.content!.resolveElementValue(
          uiComponent: component,
        );
        expect(value, equals('the-field-value'));
      });

      test('resolves through an `UIFieldMap` component', () async {
        var component = _MapValueComponent(uiRoot.content);
        await component.callRenderAndWait();

        var value = component.content!.resolveElementValue(
          uiComponent: component,
        );
        expect(value, contains('a'));
        expect(value, contains('1'));
      });

      test('does not throw for a detached element', () {
        var div = web.HTMLDivElement()..text = 'detached';
        expect(div.resolveElementValue(), equals('detached'));
        expect(div.uiComponent, isNull);
      });
    });

    group('UIIterableElementExtension', () {
      test('elementsValues of a list of inputs', () {
        var inputs = [
          web.HTMLInputElement()
            ..type = 'text'
            ..value = 'v1',
          web.HTMLInputElement()
            ..type = 'text'
            ..value = 'v2',
        ];

        expect(inputs.elementsValues, equals(['v1', 'v2']));
      });

      test('uiComponents of unmapped elements', () {
        var elements = [web.HTMLDivElement(), web.HTMLDivElement()];
        expect(elements.uiComponents, equals([null, null]));
      });
    });

    test('isElementValueEmptyTrimmed', () {
      var blank = web.HTMLInputElement()
        ..type = 'text'
        ..value = '   ';

      expect(blank.isElementValueEmpty, isFalse);
      expect(blank.isElementValueEmptyTrimmed, isTrue);

      var empty = web.HTMLInputElement()
        ..type = 'text'
        ..value = '';

      expect(empty.isElementValueEmpty, isTrue);
      expect(empty.isElementValueEmptyTrimmed, isTrue);
    });
  });
}

class _ExtensionRoot extends UIRoot {
  _ExtensionRoot(super.rootContainer) : super(id: 'extension-root');

  @override
  UIComponent? renderContent() => null;
}

class _ValueComponent extends UIComponent implements UIField<String> {
  String? _value;

  _ValueComponent(super.parent, this._value);

  @override
  String get fieldName => 'the-field';

  @override
  String? getFieldValue() => _value;

  @override
  void setFieldValue(String? value) => _value = value;

  @override
  dynamic render() => 'ignored text';
}

class _MapValueComponent extends UIComponent implements UIFieldMap<String> {
  _MapValueComponent(super.parent);

  @override
  Map<String, String> getFieldMap() => {'a': '1'};

  @override
  dynamic render() => 'ignored text';
}
