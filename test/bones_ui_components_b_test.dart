@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_layout.dart';
import 'package:bones_ui/src/component/template.dart';
import 'package:expressions/expressions.dart';
import 'package:swiss_knife/swiss_knife.dart' show MimeType;
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// Integration tests (real DOM) for `input_config.dart`,
/// `multi_selection.dart`, `masonry.dart`, `capture.dart`, `template.dart`,
/// `bui.dart` and `bones_ui_layout.dart`.
void main() {
  late final _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  /// A container attached to the root, removed after the test.
  web.HTMLDivElement newHolder() {
    var holder = web.HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    return holder;
  }

  group('InputConfig', () {
    // `attributes`, `options`, `inputRender`, `valueProvider`,
    // `valueValidator`, `valueNormalizer` and `invalidValueMessage` are now
    // Dart 3.12 private named parameters (`this._x`): callers still pass the
    // public names.
    test('private named parameters keep their public names', () {
      String? validated;

      var config = InputConfig(
        'f1',
        'Field 1',
        attributes: {'data-x': '1'},
        options: {'a': 'A'},
        inputRender: (c) => web.HTMLInputElement()..value = 'rendered',
        valueProvider: (field) => 'provided:$field',
        valueValidator: (field, value) {
          validated = value;
          return value == 'ok';
        },
        valueNormalizer: (field, value) =>
            value is String ? value.trim() : value,
        invalidValueMessage: 'Invalid!',
      );

      expect(config.attributes, equals({'data-x': '1'}));
      expect(config.options, equals({'a': 'A'}));
      expect(config.valueProvider!('x'), equals('provided:x'));

      expect(config.hasValueValidator, isTrue);
      expect(config.validateValue('ok'), isTrue);
      expect(config.validateValue('no'), isFalse);
      expect(validated, equals('no'));

      expect(config.hasValueNormalizer, isTrue);
      expect(config.normalizeValue('  a  '), equals('a'));

      expect(config.invalidValueMessage, equals('Invalid!'));

      var rendered = config.renderInput() as web.HTMLInputElement;
      expect(rendered.value, equals('rendered'));
      expect(rendered.getAttribute('data-x'), equals('1'));
    });

    test('defaults', () {
      var config = InputConfig('f', null);

      expect(config.id, equals('f'));
      expect(config.fieldName, equals('f'));
      expect(config.label, equals('text'), reason: 'Label defaults to type');
      expect(config.type, equals('text'));
      expect(config.value, isNull);
      expect(config.placeholder, isNull);
      expect(config.attributes, isNull);
      expect(config.options, isNull);
      expect(config.optional, isFalse);
      expect(config.required, isTrue);
      expect(config.hasValueValidator, isFalse);
      expect(config.hasValueNormalizer, isFalse);
      expect(config.normalizeValue(' x '), equals(' x '));
      expect(config.invalidValueMessage, isNull);

      // Required:
      expect(config.validateValue(''), isFalse);
      expect(config.validateValue('x'), isTrue);

      expect(InputConfig('f', 'L', optional: true).validateValue(null), isTrue);

      // The label defaults to the value:
      expect(InputConfig('f', '', value: 'v').label, equals('v'));

      expect(() => InputConfig('', 'L'), throwsArgumentError);
    });

    test('from a Map, a String and a List', () {
      var fromMap = InputConfig.from({
        'id': 'a',
        'label': 'A',
        'type': 'select',
        'value': 'x',
        'checked': 'true',
        'precision': '2',
        'options': {'x': 'X'},
        'attributes': {'k': 'v'},
        'optional': true,
        'class': 'c1 c2',
        'style': ' color: red ',
        'labelStyle': 'font-size: 8px',
        'labelVerticalAlign': 'middle',
      })!;

      expect(fromMap.id, equals('a'));
      expect(fromMap.label, equals('A'));
      expect(fromMap.type, equals('select'));
      expect(fromMap.value, equals('x'));
      expect(fromMap.checked, isTrue);
      expect(fromMap.precision, equals(2));
      expect(fromMap.options, equals({'x': 'X'}));
      expect(fromMap.attributes, equals({'k': 'v'}));
      expect(fromMap.optional, isTrue);
      expect(fromMap.classes, equals(['c1', 'c2']));
      expect(fromMap.style, equals('color: red'));
      expect(fromMap.labelStyle, equals('font-size: 8px'));
      expect(fromMap.labelVerticalAlign, equals('middle'));

      var fromString = InputConfig.from(
        'id: n ; label: Name ; type: textarea',
      )!;
      expect(fromString.id, equals('n'));
      expect(fromString.label, equals('Name'));
      expect(fromString.type, equals('textarea'));

      var fromList = InputConfig.from(['id: l', 'type: decimal'])!;
      expect(fromList.id, equals('l'));
      expect(fromList.type, equals('decimal'));

      expect(InputConfig.from(42), isNull);

      var list = InputConfig.listFromMap({
        'first': 'label: First',
        'second': {'label': 'Second', 'type': 'password'},
      });
      expect(list.map((e) => e.id), equals(['first', 'second']));
      expect(list.last.type, equals('password'));
    });

    test('renderInput: generic input with style, classes and attributes', () {
      var config = InputConfig(
        'name',
        'Name',
        value: 'Joe',
        placeholder: 'Your name',
        classes: 'c1',
        style: 'color: red',
        attributes: {'data-a': '1', 'data-empty': ''},
      );

      var input = config.renderInput() as web.HTMLInputElement;

      expect(input.type, equals('text'));
      expect(input.value, equals('Joe'));
      expect(input.id, equals('name'));
      expect(input.getAttribute('name'), equals('name'));
      expect(input.getAttribute('field'), equals('name'));
      expect(input.getAttribute('placeholder'), equals('Your name'));
      expect(input.classList.contains('c1'), isTrue);
      expect(input.style.color, equals('red'));
      expect(input.style.width, equals('100%'));
      expect(input.getAttribute('data-a'), equals('1'));
      expect(input.hasAttribute('data-empty'), isFalse);

      // A `fieldValueProvider` value has priority:
      var input2 = config.renderInput(
        fieldValueProvider: (f) => 'Ana',
      ) as web.HTMLInputElement;
      expect(input2.value, equals('Ana'));

      // Falls back to the configured value:
      var input3 = config.renderInput(
        fieldValueProvider: (f) => null,
      ) as web.HTMLInputElement;
      expect(input3.value, equals('Joe'));
    });

    test('renderInput: a `Future` value is not allowed', () {
      var config = InputConfig('f', 'F');
      expect(
        () => config.renderInput(fieldValueProvider: (f) => Future.value('x')),
        throwsStateError,
      );
    });

    test('renderInput: checkbox', () {
      var input =
          InputConfig('c', 'C', type: 'checkbox', checked: true).renderInput()
              as web.HTMLInputElement;
      expect(input.type, equals('checkbox'));
      expect(input.checked, isTrue);
      expect(input.value, equals('true'));

      var input2 =
          InputConfig(
                'c',
                'C',
                type: 'checkbox',
                checked: false,
                value: 'yes',
              ).renderInput()
              as web.HTMLInputElement;
      expect(input2.checked, isFalse);
      expect(input2.value, equals('yes'));
    });

    test('renderInput: textarea', () {
      var textArea =
          InputConfig('t', 'T', type: 'textarea', value: 'text').renderInput()
              as web.HTMLTextAreaElement;
      expect(textArea.value, equals('text'));
      expect(textArea.id, equals('t'));
    });

    test('renderInput: decimal precision', () {
      String step(int? precision) {
        var input =
            InputConfig(
                  'd',
                  'D',
                  type: 'decimal',
                  value: '1.5',
                  precision: precision,
                ).renderInput()
                as web.HTMLInputElement;
        expect(input.type, equals('number'));
        expect(input.value, equals('1.5'));
        return input.step;
      }

      expect(step(0), equals('1'));
      expect(step(1), equals('0.1'));
      expect(step(2), equals('0.01'));
      expect(step(3), equals('0.001'));
      expect(step(-1), equals('any'));
      expect(step(null), equals(''));
    });

    test('renderInput: select', () {
      var select =
          InputConfig(
                's',
                'S',
                type: 'select',
                options: {'a': 'A', 'b*': 'B', 'c': ''},
              ).renderInput()
              as web.HTMLSelectElement;

      var options = select.options.toList();
      expect(options.map((o) => o.value), equals(['a', 'b', 'c']));
      expect(options.map((o) => o.text), equals(['A', 'B', 'c']));
      expect(select.value, equals('b'), reason: '`*` marks the selected');

      var select2 =
          InputConfig(
                's',
                'S',
                type: 'select',
                value: 'c',
                options: {'a': 'A', 'c': 'C'},
              ).renderInput()
              as web.HTMLSelectElement;
      expect(select2.value, equals('c'), reason: 'Selected by value');

      // Without options, the value is the HTML of the options:
      var select3 =
          InputConfig(
                's',
                'S',
                type: 'select',
                value: '<option value="x">X</option>',
              ).renderInput()
              as web.HTMLSelectElement;
      expect(select3.options.toList().single.value, equals('x'));
    });

    test('renderInput: html', () {
      var config = InputConfig(
        'h',
        'H',
        type: 'html',
        value: '<div element_value="42">content</div>',
      );

      var element = config.renderInput() as web.HTMLElement;
      expect(element.textContent, equals('content'));
      expect(element.getAttribute('field'), equals('h'));

      element.click();
      expect(element.getAttribute('field_value'), equals('42'));
    });

    test('renderInput: color and image components', () {
      var color = InputConfig(
        'color',
        'Color',
        type: 'color',
        value: '#ff0000',
      ).renderInput();
      expect(color, isA<UIColorPickerInput>());
      expect((color as UIColorPickerInput).fieldName, equals('color'));

      var image = InputConfig('photo', 'Photo', type: 'image').renderInput();
      expect(image, isA<UIButtonCapturePhoto>());
      expect((image as UIButtonCapturePhoto).fieldName, equals('photo'));
    });

    test('renderInput: path', () {
      var div =
          InputConfig('p', 'P', type: 'path', value: '/tmp').renderInput()
              as web.HTMLDivElement;

      var input = div.querySelector('input') as web.HTMLInputElement;
      expect(input.value, equals('/tmp'));
      expect(input.getAttribute('field'), equals('p'));
      expect(div.querySelector('button'), isNull, reason: 'No valueProvider');
    });

    group('renderInput with an `inputRender`', () {
      // `obj.isA<HTMLInputElement>()` (Dart 3.12 `Object?.isA`):
      test('an input element is configured', () {
        var config = InputConfig(
          'r',
          'R',
          placeholder: 'ph',
          inputRender: (c) => web.HTMLInputElement()..value = 'v',
        );
        var input = config.renderInput() as web.HTMLInputElement;
        expect(input.value, equals('v'));
        expect(input.id, equals('r'));
        expect(input.getAttribute('placeholder'), equals('ph'));
      });

      test('an element containing an input', () {
        var config = InputConfig(
          'r',
          'R',
          classes: 'wrapped',
          inputRender: (c) =>
              web.HTMLDivElement()..append(web.HTMLInputElement()),
        );
        var div = config.renderInput() as web.HTMLDivElement;
        expect(div.classList.contains('wrapped'), isTrue);
        expect(div.querySelector('input')!.id, equals('r'));
      });

      test('an element without an input is returned as is', () {
        var config = InputConfig(
          'r',
          'R',
          classes: 'no',
          inputRender: (c) => web.HTMLSpanElement()..textContent = 's',
        );
        var span = config.renderInput() as web.HTMLSpanElement;
        expect(span.classList.contains('no'), isFalse);
        expect(span.textContent, equals('s'));
      });

      test('a DOMElement, a UIComponent and null', () {
        var dom = $span(content: 'x');
        expect(
          InputConfig('r', 'R', inputRender: (c) => dom).renderInput(),
          same(dom),
        );

        var component = _PlainComponent(null);
        expect(
          InputConfig('r', 'R', inputRender: (c) => component).renderInput(),
          same(component),
        );

        expect(
          InputConfig('r', 'R', inputRender: (c) => null).renderInput(),
          isNull,
        );
      });

      test('an unsupported object throws', () {
        expect(
          () => InputConfig('r', 'R', inputRender: (c) => 42).renderInput(),
          throwsStateError,
        );
      });
    });
  });

  group('validators and normalizers', () {
    test('field validators', () {
      expect(fieldEmailValidator('f', 'joe@mail.com'), isTrue);
      expect(fieldEmailValidator('f', 'joe'), isFalse);
      expect(fieldEmailValidator('f', null), isFalse);

      expect(fieldURLValidator('f', 'https://example.com/x'), isTrue);
      expect(fieldURLValidator('f', 'nope'), isFalse);
      expect(fieldURLValidator('f', null), isFalse);

      expect(
        fieldURLDataBase64Validator('f', 'data:text/plain;base64,aGk='),
        isTrue,
      );
      expect(fieldURLDataBase64Validator('f', 'aGk='), isFalse);
      expect(fieldURLDataBase64Validator('f', null), isFalse);
    });

    test('FieldLengthValidator', () {
      var v = FieldLengthValidator(minLength: 2, maxLength: 4);
      expect(v.validate('f', 'a'), isFalse);
      expect(v.validate('f', 'ab'), isTrue);
      expect(v.validate('f', 'abcd'), isTrue);
      expect(v.validate('f', 'abcde'), isFalse);
      expect(v.validate('f', null), isFalse);

      var range = FieldLengthValidator.range(1);
      expect(range.minLength, equals(1));
      expect(range.maxLength, isNull);
      expect(range.validate('f', 'a' * 100), isTrue);
    });

    test('normalizers and groups', () {
      expect(fieldNormalizerTrim('f', ' a '), equals('a'));
      expect(fieldNormalizerTrim('f', 1), equals(1));
      expect(fieldNormalizerTrim('f', null), isNull);
      expect(fieldNormalizerLowerCase('f', 'AbC'), equals('abc'));
      expect(fieldNormalizerLowerCase('f', 1), equals(1));
      expect(fieldNormalizerLowerCase('f', null), isNull);
      expect(fieldNormalizerUpperCase('f', 'AbC'), equals('ABC'));
      expect(fieldNormalizerUpperCase('f', 1), equals(1));
      expect(fieldNormalizerUpperCase('f', null), isNull);

      var normalizer = FieldNormalizerGroup([
        fieldNormalizerTrim,
        fieldNormalizerLowerCase,
      ]);
      expect(normalizer.normalize('f', '  AB  '), equals('ab'));

      var validator = FieldValidatorGroup([
        FieldLengthValidator(minLength: 3).validate,
        fieldEmailValidator,
      ]);
      expect(validator.validate('f', 'a@b.co'), isTrue);
      expect(validator.validate('f', 'abcd'), isFalse);
      expect(validator.validate('f', 'a@'), isFalse);
    });
  });

  group('UIInputTable', () {
    Future<UIInputTable> newTable(
      List<InputConfig> inputs, {
      List? extraRows,
      String? inputErrorClass,
      String? invalidValueClass,
      bool showLabels = true,
      Object? tableClasses,
      String? tableStyle,
      Object? inputsClasses,
      void Function(String)? actionListener,
      UIComponent? actionListenerComponent,
    }) async {
      var table = UIInputTable(
        newHolder(),
        inputs,
        extraRows: extraRows,
        inputErrorClass: inputErrorClass,
        invalidValueClass: invalidValueClass,
        showLabels: showLabels,
        tableClasses: tableClasses,
        tableStyle: tableStyle,
        inputsClasses: inputsClasses,
        actionListener: actionListener,
        actionListenerComponent: actionListenerComponent,
        scrollToInvalidElement: false,
      );
      await table.callRenderAndWait();
      return table;
    }

    test('renders a form with labels and inputs', () async {
      var table = await newTable(
        [
          InputConfig('name', 'Name', value: 'Joe'),
          InputConfig(
            'bio',
            'Bio',
            type: 'textarea',
            labelStyle: 'color: blue',
            labelVerticalAlign: 'middle',
          ),
          InputConfig(
            'kind',
            'Kind',
            type: 'select',
            options: {'a': 'A', 'b': 'B'},
          ),
        ],
        tableClasses: 'tbl',
        tableStyle: 'border: 1px solid',
        inputsClasses: 'inp',
      );

      var content = table.content!;
      var form = content.querySelector('form') as web.HTMLFormElement;
      expect(form.autocomplete, equals('off'));

      var tableElem = content.querySelector('table') as web.HTMLTableElement;
      expect(tableElem.classList.contains('tbl'), isTrue);
      expect(tableElem.style.border, contains('1px'));

      var labels = content.querySelectorAll('label').toElements();
      expect(labels.map((e) => e.textContent!.trim()), [
        'Name:',
        'Bio:',
        'Kind:',
      ]);
      expect(labels.first.getAttribute('for'), equals('name'));

      var labelCell = labels[1].parentElement as web.HTMLElement;
      expect(labelCell.style.verticalAlign, equals('middle'));
      expect(labelCell.style.color, equals('blue'));

      expect(table.getField('name'), equals('Joe'));
      expect(content.querySelector('#name')!.classList.contains('inp'), isTrue);
      expect(content.querySelector('#__invalid_msg__name'), isNotNull);

      expect(table.getInputConfig('bio')!.type, equals('textarea'));
      expect(table.getInputConfig('none'), isNull);
    });

    test('without labels', () async {
      var table = await newTable([
        InputConfig('name', 'Name'),
      ], showLabels: false);
      expect(table.content!.querySelectorAll('label').length, equals(0));
    });

    test('renders a component input (color picker)', () async {
      var table = await newTable([
        InputConfig('color', 'Color', type: 'color', value: '#00ff00'),
      ], inputsClasses: 'inp');

      var picker = table.content!.querySelector('.ui-color-picker');
      expect(picker, isNotNull);
      expect(table.content!.querySelector('input[field="color"]'), isNotNull);
    });

    test(
      '`inputsClasses` are applied to a component input',
      () async {
        var table = await newTable([
          InputConfig('color', 'Color', type: 'color'),
        ], inputsClasses: 'inp');
        var picker = table.content!.querySelector('.ui-color-picker')!;
        expect(picker.classList.contains('inp'), isTrue);
      },
      skip:
          'BUG?: `UIInputTable.render` adds the `inputsClasses` to a '
          "component input's content, but they're lost (also when added "
          'after `ensureRendered`); the classes are reset elsewhere',
    );

    test('a path input with a value provider button', () async {
      var table = await newTable([
        InputConfig(
          'p',
          'P',
          type: 'path',
          value: '/tmp',
          valueProvider: (field) => Future.value('/chosen/$field'),
        ),
      ]);

      var input = table.getFieldElementNonTyped('p') as web.HTMLInputElement;
      expect(input.value, equals('/tmp'));

      var changes = 0;
      input.addEventListenerTyped(EventType.change, (_) => changes++);

      (table.content!.querySelector('button') as web.HTMLElement).click();
      await testUISleep(ms: 50);

      expect(input.value, equals('/chosen/p'));
      expect(changes, equals(1));
    });

    test('renders a DOMElement input', () async {
      var table = await newTable([
        InputConfig(
          'dom',
          'Dom',
          inputRender: (c) => $input(attributes: {'field': 'dom'}, value: 'x'),
        ),
      ]);
      expect(table.getField('dom'), equals('x'));
    });

    // Regression: only the element children of an extra row's cells were
    // moved, so their text was lost (`['cell 1']` rendered an empty cell).
    test('extra rows keep their cells text', () async {
      var table = await newTable(
        [InputConfig('name', 'Name')],
        extraRows: [
          ['cell 1', 'cell 2'],
          [$td(content: 'td row')],
          [
            ['g1', 'g2'],
            ['g3', 'g4'],
          ],
          $tr(cells: ['node row']),
          '<table><tr class="r1"><td>html <b>row</b></td></tr></table>',
          '   ',
          null,
        ],
      );

      var rows = table.content!
          .querySelectorAll('tr')
          .toElements()
          .map((e) => e.textContent)
          .toList();

      expect(rows, contains('cell 1cell 2'));
      expect(rows, contains('td row'));
      expect(rows, contains('g1g2'));
      expect(rows, contains('g3g4'));
      expect(rows, contains('node row'));
      expect(rows, contains('html row'));

      var r1 = table.content!.querySelector('tr.r1')!;
      expect(r1.querySelector('b')!.textContent, equals('row'));
    });

    // Regression: `row is List<HTMLTableRowElement>` can't tell JS interop
    // types apart, so a list of non-table elements was added as table rows
    // and crashed (`Null check operator used on a null value`).
    test('extra rows of non-table elements', () async {
      var table = await newTable(
        [InputConfig('name', 'Name')],
        extraRows: ['<span class="s1">x</span><b class="b1">y</b>'],
      );

      var span = table.content!.querySelector('span.s1')!;
      var b = table.content!.querySelector('b.b1')!;
      expect(span.parentElement!.tagName, equals('TD'));
      expect(b.parentElement!.tagName, equals('TD'));
      expect(span.parentElement!.parentElement!.textContent, equals('xy'));
    });

    test(
      'an extra row as a bare `<tr>` HTML string',
      () async {
        var table = await newTable(
          [InputConfig('name', 'Name')],
          extraRows: ['<tr class="r1"><td>html row</td></tr>'],
        );
        expect(table.content!.querySelector('tr.r1'), isNotNull);
      },
      skip:
          'BUG? (dom_builder): `\$html("<tr>...</tr>")` throws '
          "`LateInitializationError: Local 'parsed' has not been initialized`",
    );

    test('checkFields, highlight and invalid messages', () async {
      var table = await newTable(
        [
          InputConfig(
            'email',
            'Email',
            valueValidator: fieldEmailValidator,
            invalidValueMessage: 'Bad email',
          ),
          InputConfig('opt', 'Opt', optional: true),
        ],
        inputErrorClass: 'err',
        invalidValueClass: 'invalid-msg',
      );

      var emailElem = table.getFieldElementNonTyped('email')!;
      var msg = table.content!.querySelector('#__invalid_msg__email')!;
      expect(msg.classList.contains('invalid-msg'), isTrue);

      // Empty required field: highlighted, no message.
      expect(table.checkFields(), isFalse);
      expect(emailElem.classList.contains('err'), isTrue);
      expect(msg.textContent, isEmpty);

      table.setField('email', 'nope');
      expect(table.checkFields(), isFalse);
      expect(msg.textContent, equals('Bad email'));
      expect(msg.hidden, isFalse);

      table.setField('email', 'joe@mail.com');
      expect(table.checkFields(), isTrue);
      expect(emailElem.classList.contains('err'), isFalse);
      expect(msg.hidden, isTrue);

      expect(table.highlightField('email', invalidValueMessage: 'X'), isTrue);
      expect(emailElem.classList.contains('err'), isTrue);
      expect(msg.textContent, equals('X'));
      expect(table.unhighlightField('email'), isTrue);
      expect(emailElem.classList.contains('err'), isFalse);
      expect(msg.textContent, isEmpty);

      expect(table.highlightField('none'), isFalse);
      expect(table.unhighlightField('none'), isFalse);

      table.setField('email', '');
      expect(table.highlightEmptyInputs(), equals(2));
      expect(emailElem.classList.contains('err'), isTrue);
      expect(table.unhighlightErrorInputs(), equals(2));
      expect(emailElem.classList.contains('err'), isFalse);
    });

    test('without an `inputErrorClass` nothing is highlighted', () async {
      var table = await newTable([
        InputConfig('email', 'Email', valueValidator: fieldEmailValidator),
      ]);

      expect(table.highlightClass, equals('ui-input-error'));
      expect(table.highlightEmptyInputs(), equals(-1));
      expect(table.unhighlightErrorInputs(), equals(-1));
      expect(table.highlightField('email'), isFalse);
      expect(table.unhighlightField('email'), isFalse);
      expect(table.checkFields(), isFalse);
    });

    test(
      'checkFields shows the invalid message without an inputErrorClass',
      () async {
        var table = await newTable([
          InputConfig(
            'email',
            'Email',
            valueValidator: fieldEmailValidator,
            invalidValueMessage: 'Bad email',
          ),
        ]);
        table.setField('email', 'nope');
        expect(table.checkFields(), isFalse);
        var msg = table.content!.querySelector('#__invalid_msg__email')!;
        expect(msg.textContent, equals('Bad email'));
      },
      skip:
          'BUG?: `canHighlightInputs()` is `true` when there is no '
          '`inputErrorClass`, and then highlighting/invalid messages are '
          'skipped (the default `highlightClass` "ui-input-error" is never '
          'used)',
    );

    test('normalizeFields', () async {
      var table = await newTable([
        InputConfig(
          'name',
          'Name',
          value: '  Joe  ',
          valueNormalizer: fieldNormalizerTrim,
        ),
        InputConfig('other', 'Other', value: ' x '),
      ]);

      expect(table.normalizeFields(), equals(1));
      expect(table.getField('name'), equals('Joe'));
      expect(table.getField('other'), equals(' x '));
      expect(table.normalizeFields(), equals(0));
    });

    test('actions and trigger delay', () async {
      var actions = <String>[];
      var listenerComponent = _ActionComponent(null);

      var table = await newTable(
        [InputConfig('name', 'Name')],
        actionListener: actions.add,
        actionListenerComponent: listenerComponent,
      );

      table.action('save');
      expect(actions, equals(['save']));
      expect(listenerComponent.actions, equals(['save']));

      table.onChangeTriggerDelay = Duration(milliseconds: 100);
      expect(table.onChangeTriggerDelay, equals(Duration(milliseconds: 500)));
      table.onChangeTriggerDelay = Duration(seconds: 3);
      expect(table.onChangeTriggerDelay, equals(Duration(seconds: 3)));
    });

    test('change, action and focus listeners', () async {
      var changes = <Object?>[];
      var textActions = <Object?>[];
      var checkActions = <Object?>[];

      var table = await newTable([
        InputConfig(
          'name',
          'Name',
          onChangeListener: changes.add,
          onActionListener: textActions.add,
        ),
        InputConfig(
          'accept',
          'Accept',
          type: 'checkbox',
          onActionListener: checkActions.add,
        ),
      ]);

      var tableChanges = <Object?>[];
      table.onChange.listen(tableChanges.add);
      var focused = <Object?>[];
      table.onInputFocus.listen(focused.add);

      var name = table.getFieldElementNonTyped('name') as web.HTMLInputElement;
      name.value = 'Ana';
      name.dispatchEvent(web.Event('change'));
      await testUISleep(ms: 10);

      expect(changes.length, equals(1));
      expect(tableChanges.length, greaterThanOrEqualTo(1));
      expect(table.getPreviousRenderedFieldValue('name'), equals('Ana'));

      name.dispatchEvent(
        web.KeyboardEvent('keyup', web.KeyboardEventInit(key: 'Enter')),
      );
      expect(textActions.length, equals(1));

      name.dispatchEvent(web.Event('focus'));
      await testUISleep(ms: 10);
      expect(focused.length, equals(1));

      (table.getFieldElementNonTyped('accept') as web.HTMLElement).click();
      expect(checkActions.length, equals(1));
    });
  });

  group('UIMultiSelection', () {
    Future<UIMultiSelection> newSelection({
      Map? options,
      bool multiSelection = true,
      List? selections,
      bool allowInputValue = false,
    }) async {
      var selection = UIMultiSelection(
        newHolder(),
        options ?? {'a': 'Alpha', 'b': 'Beta', 'c': 'Gamma'},
        multiSelection: multiSelection,
        selections: selections,
        allowInputValue: allowInputValue,
        selectionMaxDelay: Duration(milliseconds: 50),
      );
      await selection.callRenderAndWait();
      return selection;
    }

    web.HTMLInputElement input(UIMultiSelection s) =>
        s.content!.querySelector('.ui-multi-selection-input')
            as web.HTMLInputElement;

    web.HTMLElement panel(UIMultiSelection s) =>
        s.content!.querySelector('.ui-multi-selection-options-menu')
            as web.HTMLElement;

    test('renders the options as checkboxes', () async {
      var selection = await newSelection(selections: ['b']);

      var checks = panel(selection).querySelectorAll('input').toElements();
      expect(checks.length, equals(3));
      expect(
        checks.every((e) => (e as web.HTMLInputElement).type == 'checkbox'),
        isTrue,
      );

      expect(selection.selectedIDs, equals(['b']));
      expect(selection.selectedLabels, equals(['Beta']));
      expect(selection.unselectedIDs, equals(['a', 'c']));
      expect(selection.unselectedLabels, equals(['Alpha', 'Gamma']));
      expect(selection.firstSelectedID, equals('b'));
      expect(selection.hasSelection, isTrue);
      expect(input(selection).value, equals('Beta'));
      expect(selection.getFieldValue(), equals(['b']));
      expect(selection.fieldName, equals('multi-selection'));
    });

    test('check / uncheck by ID and label', () async {
      var selection = await newSelection();

      expect(selection.isAllUnchecked, isTrue);
      expect(selection.isCheckedByID('a'), isFalse);
      expect(selection.isCheckedByID(null), isNull);
      expect(selection.isCheckedByID('none'), isNull);

      selection.checkByID('a', true);
      selection.checkByLabel('Gamma', true);
      expect(selection.selectedIDs, equals(['a', 'c']));
      expect(selection.isCheckedByLabel('Gamma'), isTrue);

      selection.checkAll();
      expect(selection.isAllChecked, isTrue);
      expect(input(selection).value, equals('*'));

      selection.uncheckAll();
      expect(selection.isAllUnchecked, isTrue);
      expect(selection.selectedIDs, isEmpty);
      expect(input(selection).value, isEmpty);

      selection.checkAllByID(['a', 'b'], true);
      expect(selection.selectedLabels, equals(['Alpha', 'Beta']));
      expect(input(selection).value, equals('Alpha ; Beta'));

      selection.setFieldValue(['c']);
      expect(selection.selectedIDs, equals(['c']));

      selection.setFieldValue(null);
      expect(selection.selectedIDs, isEmpty);

      selection.setCheckedElements(['b']);
      expect(selection.getFieldValue(), equals(['b']));
    });

    test(
      'onSelect / onChange are notified after the selection delay',
      () async {
        var selection = await newSelection();

        var selects = 0;
        var changes = 0;
        selection.onSelect.listen((_) => selects++);
        selection.onChange.listen((_) => changes++);

        selection.checkByID('a', true);
        expect(selects, equals(0));

        await testUISleep(ms: 300);
        expect(selects, equals(1));
        expect(changes, equals(1));
        expect(selection.selectionMaxDelay, equals(Duration(milliseconds: 50)));
      },
    );

    test('clicking a check element or its label', () async {
      var selection = await newSelection();

      var check = panel(selection).querySelector('input') as web.HTMLElement;
      check.click();
      expect(selection.selectedIDs, equals(['a']));

      var label = panel(selection).querySelector('label') as web.HTMLElement;
      label.click();
      expect(selection.selectedIDs, isEmpty);
    });

    test('single selection (radio)', () async {
      var selection = await newSelection(multiSelection: false);

      var checks = panel(selection).querySelectorAll('input').toElements();
      expect(
        checks.every((e) => (e as web.HTMLInputElement).type == 'radio'),
        isTrue,
      );

      selection.checkByID('a', true);
      selection.checkByID('b', true);
      expect(selection.selectedIDs, equals(['b']));
    });

    test('options access and filtering', () async {
      var selection = await newSelection();

      expect(selection.options.keys, equals(['a', 'b', 'c']));
      expect(selection.getOption('a'), equals('Alpha'));
      expect(selection.containsOption('b'), isTrue);
      expect(selection.getIDLabel('c'), equals('Gamma'));
      expect(selection.getLabelID('Beta'), equals('b'));
      expect(selection.getLabelID('None'), isNull);

      selection.addOption('d', 'Delta');
      expect(selection.containsOption('d'), isTrue);
      expect(selection.removeOption('d'), equals('Delta'));

      List keys(Object? p) =>
          selection.getOptionsEntriesFiltered(p).map((e) => e.key).toList();

      expect(keys(null), equals(['a', 'b', 'c']));
      expect(keys('*'), equals(['a', 'b', 'c']));
      expect(keys('  '), equals(['a', 'b', 'c']));
      expect(keys('ta'), equals(['b']));
      expect(keys('A'), equals(['a', 'b', 'c']));
      expect(keys(RegExp(r'^G')), equals(['c']));
      expect(keys(42), isEmpty);

      selection.options = {'x': 'X'};
      expect(selection.options, equals({'x': 'X'}));
    });

    // `_setDataOptions(Object? data)` / `_parseDataOptions(Object? data)`.
    test('setData accepts a Map, a List and empty data', () async {
      var selection = await newSelection();

      expect(selection.setData({'k': 'K'}), isTrue);
      expect(selection.options, equals({'k': 'K'}));
      expect(selection.setData({'k': 'K'}), isFalse, reason: 'Unchanged');

      expect(selection.setData(['x: X', 'y=Y']), isTrue);
      expect(selection.options, equals({'x': 'X', 'y': 'Y'}));

      expect(
        selection.setData([
          {'m': 'M'},
        ]),
        isTrue,
      );
      expect(selection.options, equals({'m': 'M'}));

      expect(selection.setData(null), isTrue);
      expect(selection.options, isEmpty);
      expect(selection.setData(''), isFalse);
      expect(selection.setData(42), isFalse);
    });

    test('no options', () async {
      var selection = await newSelection(options: {});
      expect(panel(selection).textContent, isNotEmpty);
      expect(selection.selectedIDs, isEmpty);
      expect(selection.isAllChecked, isFalse);
      expect(selection.isAllUnchecked, isTrue);
    });

    // Regression: the options panel signature concatenated the unfiltered and
    // filtered entries without a separator, so filtering the last option
    // ("Gamma") kept the same signature and the panel wasn't re-rendered.
    test('typing filters the options and shows the panel', () async {
      var selection = await newSelection();

      var inputElem = input(selection);
      inputElem.value = 'gam';
      inputElem.dispatchEvent(web.KeyboardEvent('keyup'));

      expect(panel(selection).style.display, equals(''));
      var labels = panel(selection).querySelectorAll('label').toElements();
      expect(labels.first.textContent, equals('Gamma'));
      expect(panel(selection).querySelector('hr'), isNotNull);

      inputElem.click();
      expect(inputElem.value, isEmpty);
    });

    test('input value (allowInputValue)', () async {
      var selection = await newSelection(allowInputValue: true);

      var inputElem = input(selection);
      inputElem.value = 'free text';
      expect(selection.inputValue, equals('free text'));
      expect(selection.hasInputValue, isTrue);
      expect(selection.getFieldValue(), equals(['free text']));

      inputElem.value = '';
      expect(selection.getFieldValue(), isEmpty);

      selection.checkByID('a', true);
      expect(selection.getFieldValue(), equals(['a']));

      var changes = 0;
      selection.onChange.listen((_) => changes++);
      inputElem.value = 'typed';
      inputElem.dispatchEvent(web.KeyboardEvent('keyup'));
      expect(selection.hasSelection, isFalse, reason: 'Typing unchecks');
      await testUISleep(ms: 300);
      expect(changes, greaterThanOrEqualTo(1));
    });

    // Regression: the `options` attribute was parsed with `parseJSON`, which
    // threw for an inline map (`a: A ; b: B`), so the options were never set.
    test('generated from HTML', () async {
      UIMultiSelection.register();

      var component = _HTMLComponent(
        newHolder(),
        '<ui-multi-selection options="a: A ; b: B" multi-selection="false">'
        '</ui-multi-selection>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 20);

      // Checked in the DOM (`getContentUIComponent` doesn't find it with
      // dart2wasm):
      var panel = component.content!.querySelector(
        '.ui-multi-selection-options-menu',
      )!;
      var labels = panel.querySelectorAll('label').toElements();
      expect(labels.map((e) => e.textContent), equals(['A', 'B']));

      var checks = panel.querySelectorAll('input').toElements();
      expect(
        checks.map((e) => (e as web.HTMLInputElement).type),
        equals(['radio', 'radio']),
        reason: '`multi-selection="false"`',
      );
    });
  });

  group('Masonry', () {
    web.HTMLDivElement box(int w, int h, [String text = '']) =>
        web.HTMLDivElement()
          ..style.width = '${w}px'
          ..style.height = '${h}px'
          ..textContent = text;

    test('MasonryItem from Element, DOMElement, UIComponent and others', () {
      var element = box(40, 30);
      var fromElement = MasonryItem.from(element);
      expect(fromElement.width, equals(40));
      expect(fromElement.height, equals(30));
      expect(fromElement.checkChangedDimension(), isFalse);

      element.style.width = '50px';
      expect(fromElement.checkChangedDimension(), isTrue);
      fromElement.updateDimensions();
      expect(fromElement.width, equals(50));

      var fromDOM = MasonryItem.from($div(style: 'width: 20px; height: 10px'));
      expect(fromDOM.width, equals(20));
      expect(fromDOM.height, equals(10));

      var component = _BoxComponent(null, 25, 15);
      component.ensureRendered();
      var fromComponent = MasonryItem.from(component);
      expect(fromComponent.width, equals(25));
      expect(fromComponent.height, equals(15));

      var fromOther = MasonryItem.from('text');
      expect(fromOther.width, equals(0));
      expect(fromOther.height, equals(0));

      var fromNull = MasonryItem.from(null);
      expect(fromNull.width, isNull);
      expect(fromNull.height, isNull);
    });

    // Regression: the dimension of an item holding a `DOMElement` cast the
    // style `CSSEntry` to a `String`, which always threw a `TypeError`.
    test('MasonryItem of a DOMElement updates its dimensions', () {
      var item = MasonryItem($div(style: 'width: 30px; height: 40px'), 1, 1);
      expect(item.checkChangedDimension(), isTrue);
      item.updateDimensions();
      expect(item.width, equals(30));
      expect(item.height, equals(40));
      expect(item.checkChangedDimension(), isFalse);

      var attrItem = MasonryItem(
        $div(attributes: {'width': '12', 'height': '8.5px'}),
        0,
        0,
      )..updateDimensions();
      expect(attrItem.width, equals(12));
      expect(attrItem.height, equals(8));

      var noSize = MasonryItem($div(), 5, 5)..updateDimensions();
      expect(noSize.width, isNull);
      expect(noSize.height, isNull);
    });

    test('UIMasonry renders all items in lines', () async {
      var holder = newHolder()
        ..style.width = '400px'
        ..style.height = '300px';

      var items = [
        MasonryItem.fromElement(box(100, 100, 'i1')),
        MasonryItem.fromElement(box(100, 100, 'i2')),
        MasonryItem.fromElement(box(200, 100, 'i3')),
        MasonryItem.fromElement(box(100, 200, 'i4')),
        MasonryItem.fromElement(box(100, 100, 'i5')),
      ];

      var masonry = UIMasonry(
        holder,
        items,
        itemsMargin: 2,
        scrollbarColors: ['#ff0000', '#00ff00'],
      );
      await masonry.callRenderAndWait();
      await testUISleep(ms: 150);

      expect(masonry.masonryWidthSize, equals(100));
      expect(masonry.masonryHeightSize, equals(100));
      expect(masonry.masonryWidthSizeWithItemsMargin, equals(102));
      expect(masonry.width, equals('100%'));
      expect(masonry.height, equals('100%'));
      expect(masonry.itemsMargin, equals(2));

      var content = masonry.content!;
      var blocks = content.querySelectorAll('.ui-masonry-block').toElements();
      expect(blocks.length, equals(5));
      expect(content.querySelectorAll('.ui-masonry-line').length, isNonZero);
      expect(content.textContent, contains('i1'));
      expect(content.textContent, contains('i5'));

      var text = content.textContent!;
      for (var i = 1; i <= 5; i++) {
        expect(text, contains('i$i'));
      }
    });

    test('UIMasonry with DOMElement and UIComponent items', () async {
      var holder = newHolder()
        ..style.width = '300px'
        ..style.height = '200px';

      var masonry = UIMasonry(
        holder,
        [
          MasonryItem(
            $div(style: 'width: 50px; height: 50px', content: 'dom'),
            50,
            50,
          ),
          MasonryItem(_BoxComponent(null, 50, 50), 50, 50),
          MasonryItem('<b>html</b>', 50, 50),
        ],
        masonryWidthSize: 50,
        masonryHeightSize: 50,
      );
      await masonry.callRenderAndWait();
      await testUISleep(ms: 150);

      var text = masonry.content!.textContent!;
      expect(text, contains('dom'));
      expect(text, contains('box'));
      expect(text, contains('html'));
    });

    // Regression: the GCD cache (`CachedComputation`) cast its parameters to
    // `Parameters2<List<int>, double>`, which always threw with 2+ distinct
    // item dimensions.
    test('UIMasonry dimensions and tolerance', () async {
      var masonry = UIMasonry(
        newHolder(),
        [
          MasonryItem.fromElement(box(90, 60)),
          MasonryItem.fromElement(box(60, 90)),
        ],
        width: '200px',
        height: '',
      );

      expect(masonry.width, equals('200px'));
      expect(masonry.height, equals('100%'), reason: 'Empty is ignored');

      expect(masonry.computeMasonryWidthSize(0), equals(30));
      expect(masonry.computeMasonryHeightSize(0), equals(30));
      expect(masonry.computeMasonryWidthSize(0), equals(30), reason: 'Cached');
      expect(masonry.computeMasonryWidthSize(5), equals(10));
      expect(masonry.computeMasonryWidthSize(80), equals(80));

      var withTolerance = UIMasonry(newHolder(), [
        MasonryItem.fromElement(box(100, 10)),
        MasonryItem.fromElement(box(205, 10)),
      ], dimensionTolerance: 0.1);
      // The largest size (from 110 = 100 * 1.1) whose remainders are within
      // the 10% tolerance for both 100 and 205:
      expect(withTolerance.computeMasonryWidthSize(0), equals(107));

      var clipped = UIMasonry(
        newHolder(),
        [],
        dimensionTolerance: 50,
        itemsMargin: 5000,
      );
      expect(clipped.dimensionTolerance, equals(10), reason: 'Clipped');
      expect(clipped.itemsMargin, equals(1000), reason: 'Clipped');

      masonry.masonryWidthSize = 40;
      expect(masonry.masonryWidthSize, equals(40));
      masonry.masonryHeightSize = 5;
      expect(masonry.masonryHeightSize, isNot(equals(5)));

      var single = UIMasonry(newHolder(), [
        MasonryItem.fromElement(box(70, 20)),
      ]);
      expect(single.computeMasonryWidthSize(0), equals(70));
      expect(single.computeMasonryHeightSize(0), equals(20));

      var empty = UIMasonry(newHolder(), []);
      expect(empty.computeMasonryWidthSize(0), equals(10));
    });
  });

  group('UICapture', () {
    web.File textFile(String name, String content, [String type = '']) =>
        web.File(
          <JSAny>[content.toJS].toJS,
          name,
          web.FilePropertyBag(type: type),
        );

    Uint8List pngBytes(int w, int h) {
      var canvas = web.HTMLCanvasElement()
        ..width = w
        ..height = h;
      var ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.fillStyle = 'red'.toJS;
      ctx.fillRect(0, 0, w, h);
      var dataURL = canvas.toDataURL('image/png');
      return base64.decode(dataURL.split(',')[1]);
    }

    web.File pngFile(int w, int h) => web.File(
      <JSAny>[pngBytes(w, h).toJS].toJS,
      'photo.png',
      web.FilePropertyBag(type: 'image/png'),
    );

    Future<void> selectFile(UICapture capture, web.File file) async {
      var input = capture.getInputCapture() as web.HTMLInputElement;
      var dataTransfer = web.DataTransfer();
      dataTransfer.items.add(file);
      input.files = dataTransfer.files;

      var captured = capture.onCapture.first;
      input.dispatchEvent(web.Event('change'));
      await captured.timeout(Duration(seconds: 10));
    }

    test('renderHidden per capture type and accepted extensions', () {
      String hidden(CaptureType type) =>
          UIButtonCapture(null, 'x', type, fieldName: 'f').renderHidden();

      expect(hidden(CaptureType.photo), contains("accept='image/*'"));
      expect(hidden(CaptureType.photo), contains("capture='environment'"));
      expect(hidden(CaptureType.photoSelfie), contains("capture='user'"));
      expect(hidden(CaptureType.photoFile), isNot(contains('capture=')));
      expect(hidden(CaptureType.video), contains("accept='video/*'"));
      expect(hidden(CaptureType.videoSelfie), contains("capture='user'"));
      expect(hidden(CaptureType.videoFile), contains("accept='video/*'"));
      expect(hidden(CaptureType.audioRecord), contains("accept='audio/*'"));
      expect(hidden(CaptureType.audioFile), contains("accept='audio/*'"));
      expect(hidden(CaptureType.json), contains("accept='application/json'"));
      expect(hidden(CaptureType.file), isNot(contains('accept=')));
      expect(hidden(CaptureType.file), contains('field="f"'));

      expect(CaptureType.photoSelfie.isPhoto, isTrue);
      expect(CaptureType.videoFile.isVideo, isTrue);
      expect(CaptureType.audioRecord.isAudio, isTrue);
      expect(CaptureType.file.isPhoto, isFalse);

      var capture = UIButtonCapture(null, 'x', CaptureType.photoFile);
      expect(capture.acceptFilesExtensions, isNull);
      expect(capture.removeAcceptFileExtension('png'), isFalse);
      expect(capture.containsAcceptFileExtension('png'), isFalse);

      capture.addAcceptFileExtension('.PNG');
      capture.addAcceptFileExtension('jpg');
      capture.addAcceptFileExtension('  ');
      expect(capture.acceptFilesExtensions, equals({'png', 'jpg'}));
      expect(capture.containsAcceptFileExtension('png'), isTrue);
      expect(capture.renderHidden(), contains("accept='image/*,.png,.jpg'"));

      expect(capture.removeAcceptFileExtension('jpg'), isTrue);
      expect(capture.removeAcceptFileExtension(''), isFalse);
      capture.clearAcceptFilesExtensions();
      expect(capture.acceptFilesExtensions, isNull);

      var file = UIButtonCapture(null, 'x', CaptureType.file)
        ..addAcceptFileExtension('csv');
      expect(file.renderHidden(), contains("accept='.csv'"));
    });

    test('UIButtonCapture reads a selected file', () async {
      var capture = UIButtonCapture(newHolder(), 'Upload', CaptureType.file);
      await capture.callRenderAndWait();

      expect(capture.content!.textContent, contains('Upload'));
      expect(capture.hasSelectedFile, isFalse);
      expect(capture.getInputFile(), isNull);

      var dataEvents = 0;
      capture.onCaptureData.listen((_) => dataEvents++);

      await selectFile(capture, textFile('notes.txt', 'hello', 'text/plain'));

      expect(dataEvents, equals(1));
      expect(capture.hasSelectedFile, isTrue);
      expect(capture.selectedFile!.name, equals('notes.txt'));
      expect(capture.getInputFile()!.name, equals('notes.txt'));
      expect(capture.selectedFileDataAsString, equals('hello'));
      expect(
        capture.selectedFileDataAsArrayBuffer,
        equals(utf8.encode('hello')),
      );
      expect(capture.getFieldValue(), startsWith('data:'));
      expect(capture.isFileImage(), isFalse);
      expect(capture.isFileVideo(), isFalse);
      expect(capture.isFileAudio(), isFalse);
      expect(capture.getImageFileReader(), isNull);
      expect(capture.getVideoFileReader(), isNull);
      expect(capture.getAudioFileReader(), isNull);

      // The file name is shown in the button:
      expect(capture.content!.textContent, contains('notes.txt'));

      capture.setWideButton();
      expect(capture.content!.style.width, equals('80%'));
      capture.setNormalButton();
      expect(capture.content!.style.width, isEmpty);
    });

    test('UIButtonCapturePhoto reads, scales and shows a photo', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        text: 'Photo',
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.dataUrlBase64,
        captureMaxWidth: 10,
        fontSize: '12px',
      );
      capture.photoScaleMimeType = 'image/png';
      await capture.callRenderAndWait();

      expect(
        (capture.content!.querySelector(
          'span',
        ) as web.HTMLElement).style.fontSize,
        equals('12px'),
      );

      await selectFile(capture, pngFile(20, 10));

      expect(capture.isFileImage(), isTrue);

      var dataURL = capture.selectedFileDataAsDataURLBase64!;
      expect(dataURL, startsWith('data:image/png;base64,'));

      var img = web.HTMLImageElement()..src = dataURL;
      await img.decode().toDart;
      expect(img.naturalWidth, equals(10));
      expect(img.naturalHeight, equals(5));

      var shown = capture.content!.querySelector('img.ui-capture-img');
      expect(shown, isNotNull);

      var reader = capture.getImageFileReader()!;
      var loaded = await reader.onLoadImage.first.timeout(
        Duration(seconds: 10),
      );
      expect(loaded.src, startsWith('data:image/png'));
    });

    test('UIButtonCapturePhoto crops to an aspect ratio', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.base64,
        captureAspectRatio: 1,
      );
      await capture.callRenderAndWait();

      await selectFile(capture, pngFile(20, 10));

      var img = web.HTMLImageElement()
        ..src = capture.selectedFileDataAsURLOrDataURLBase64!;
      await img.decode().toDart;
      expect(img.naturalWidth, equals(10));
      expect(img.naturalHeight, equals(10));
    });

    test('UIButtonCapturePhoto with a photo editor', () async {
      var edited = false;
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        editCapture: true,
        photoEditor: (image) {
          edited = true;
          return image;
        },
      );
      await capture.callRenderAndWait();

      await selectFile(capture, pngFile(4, 4));

      expect(edited, isTrue);
      expect(capture.selectedFileDataAsArrayBuffer, isNotEmpty);
    });

    test('UIButtonCapturePhoto with initial data', () async {
      var bytes = pngBytes(3, 3);
      var capture = UIButtonCapturePhoto(
        newHolder(),
        buttonContent: 'Content',
        selectedFileData: bytes,
      );
      capture.onlyShowSelectedImageInButton = true;
      capture.selectedImageClasses = ['extra'];
      capture.selectedImageStyle = 'border: 1px solid';
      await capture.callRenderAndWait();

      var img = capture.content!.querySelector('img.ui-capture-img')!;
      expect(img.classList.contains('extra'), isTrue);
      expect((img as web.HTMLElement).style.border, contains('1px'));

      capture.setWideButton();
      expect(capture.content!.style.width, equals('80%'));
      capture.setNormalButton();
      expect(capture.content!.style.width, isEmpty);

      var noText = UIButtonCapturePhoto(newHolder());
      await noText.callRenderAndWait();
      expect(noText.content!.textContent, contains('Photo'));
    });

    test('data formats', () {
      UIButtonCapturePhoto capture(CaptureDataFormat format) =>
          UIButtonCapturePhoto(null, captureDataFormat: format);

      var string = capture(CaptureDataFormat.string)..selectedFileData = 'hey!';
      expect(string.selectedFileData, equals('hey!'));
      expect(
        string.selectedFileDataAsBase64,
        equals(base64.encode(utf8.encode('hey!'))),
      );

      var url = capture(CaptureDataFormat.url)
        ..selectedFileData = 'https://example.com/x.png';
      expect(url.selectedFileDataAsDataURLBase64, 'https://example.com/x.png');
      expect(
        url.selectedFileDataAsURLOrDataURLBase64,
        'https://example.com/x.png',
      );

      var blob = capture(CaptureDataFormat.urlOrBlobUrl)
        ..selectedFileData = Uint8List.fromList([1, 2, 3]);
      expect(blob.selectedFileData as String, startsWith('blob:'));

      var utf = capture(CaptureDataFormat.string)..setDataEncodingToUTF8();
      expect(utf.dataEncoding, equals(utf8));
      utf.dataEncoding = null;
      expect(utf.dataEncoding, equals(latin1));
    });
  });

  // Regression: the `variables` were never applied. A parsed `{{x}}` is a
  // `TemplateNode` (and `<b>{{x}}</b>` an element containing one), for which
  // `hasUnresolvedTemplate` is `false`, so the template path wasn't used; and
  // JSON variables were parsed as a query string (`isJSONMap` of a `String`).
  group('ui-template', () {
    test('renders a template with attribute variables', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-template variables=\'{"who":"World"}\'>'
        '<b>Hello {{who}}</b>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      expect(component.content!.querySelector('b')!.textContent, 'Hello World');
    });

    test('renders a top level template text', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-template variables="n=7">n={{n}}</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      expect(
        component.content!.querySelector('.ui-template')!.textContent,
        equals('n=7'),
      );
    });

    test('renders a template with query string variables', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-template class="tpl" variables="a=1&b=2">'
        '<i>{{a}}-{{b}}</i>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var div = component.content!.querySelector('div.tpl')!;
      expect(div.querySelector('i')!.textContent, equals('1-2'));
    });

    test('renders plain content', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-template><span class="plain">plain</span></ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      expect(
        component.content!.querySelector('span.plain')!.textContent,
        'plain',
      );
    });

    test('isGeneratedElement / revert', () {
      var generator = UITemplateElementGenerator();
      expect(generator.tag, equals('ui-template'));
      expect(generator.hasChildrenElements, isFalse);
      expect(generator.usesContentHolder, isFalse);

      var div = web.HTMLDivElement()
        ..className = 'ui-template x'
        ..textContent = 'txt';
      expect(generator.isGeneratedElement(div), isTrue);
      expect(generator.isGeneratedElement(web.HTMLSpanElement()), isFalse);

      var reverted = generator.revert(
        UIComponent.domGenerator,
        null,
        null,
        null,
        div,
      )!;
      expect(reverted.tag, equals('ui-template'));
      expect(reverted.buildHTML(), contains('txt'));

      expect(
        generator.revert(
          UIComponent.domGenerator,
          null,
          null,
          null,
          web.HTMLSpanElement(),
        ),
        isNull,
      );

      expect(
        generator.parseAttributeVariables({
          'variables': DOMAttribute.from('variables', '{"a":1}')!,
        }),
        equals({'a': 1}),
      );
      expect(generator.parseAttributeVariables({}), isNull);
      expect(generator.getDataSourceResponse({}), isNull);
    });
  });

  group('BUI', () {
    // Regression: the constructor cast the `String?`-returning resolvers to
    // functions returning `String`, which always threw a `TypeError`.
    test('BUIRender renders a String source', () async {
      var changes = 0;
      var render = BUIRender(
        newHolder(),
        source: '<bui><div id="bui-hello">Hello</div></bui>',
      )..onChangeSource.listen((_) => changes++);
      await testUISleep(ms: 50);

      var root = render.renderedRoot!;
      expect(root.classList.contains('bui-root'), isTrue);
      expect(root.classList.contains('bui'), isTrue);
      expect(root.querySelector('#bui-hello')!.textContent, equals('Hello'));
      expect(render.renderViewportElement, isNotNull);
      expect(render.renderContainer, isNotNull);
      expect(render.renderedTreeMap, isNotNull);
      expect(
        render.getMappedDOMNodeInTreeMap(root.querySelector('#bui-hello')),
        isNotNull,
      );

      render.source = '<bui><b>Changed</b></bui>';
      await testUISleep(ms: 10);
      expect(changes, equals(1));
      render.source = '<bui><b>Changed</b></bui>';
      await testUISleep(ms: 10);
      expect(changes, equals(1), reason: 'Same source');

      render.refresh();
      await testUISleep(ms: 50);
      expect(render.renderedRoot!.querySelector('b')!.textContent, 'Changed');
    });

    // `buildHTML` omits commented elements (dom_builder 3.1.0): a commented
    // node of the source is not rendered, and it's dropped when the source is
    // rebuilt from the rendered tree.
    test('rebuildSourceFromDOMTreeMap / updateSourceFromDOMTreeMap', () async {
      var render = BUIRender(
        newHolder(),
        source: $div(
          content: [
            $span(content: 'shown'),
            $span(content: 'hidden', commented: true),
          ],
        ),
      );
      await testUISleep(ms: 50);

      var text = render.renderedRoot!.textContent;
      expect(text, contains('shown'));
      expect(text, isNot(contains('hidden')));

      expect(render.rebuildSourceFromDOMTreeMap(), isTrue);
      expect(render.source, equals('<div><span>shown</span></div>'));

      render.source = $div(
        content: [
          $span(content: 'a'),
          $span(content: 'b', commented: true),
        ],
      );
      render.refresh();
      await testUISleep(ms: 50);

      render.updateSourceFromDOMTreeMap();
      expect(render.source, contains('<span>a</span>'));
      expect(render.source, isNot(contains('b')));
    });

    test('BUIRenderSource conversions', () async {
      var render = BUIRender(newHolder(), source: 7);
      await testUISleep(ms: 50);
      var source = render.renderSource!;

      expect(source.isNotNull, isTrue);
      expect(source.sourceAsHTML, equals('7'));
      expect(source.sourceAsDOMElement, isNotNull);
      expect(source.sourceAsElement!.textContent, equals('7'));

      render.source = true;
      expect(source.sourceAsHTML, equals('true'));
      expect(source.sourceAsElement!.textContent, equals('true'));
      expect(source.sourceAsDOMElement!.buildHTML(), contains('true'));

      render.source = $p(content: 'dom');
      expect(source.sourceAsHTML, contains('<p>dom</p>'));
      expect(source.sourceAsElement!.textContent, equals('dom'));
      expect(source.sourceAsDOMElement!.tag, equals('p'));

      var element = web.HTMLDivElement()..innerHTML = '<i>el</i>'.toJS;
      render.source = element;
      expect(source.sourceAsHTML, contains('<i>el</i>'));
      expect(source.sourceAsElement, isNotNull);
      expect(source.sourceAsDOMElement!.buildHTML(), contains('el'));
      expect(source.sourceAsDOMTreeMap.rootDOMNode, isNotNull);

      render.source = null;
      expect(source.isNull, isTrue);
      expect(source.sourceAsHTML, isEmpty);
      expect(source.sourceAsElement, isNull);
      expect(source.sourceAsDOMElement, isNull);

      render.source = Object();
      expect(() => source.sourceAsHTML, throwsStateError);
      expect(() => source.sourceAsElement, throwsStateError);
      expect(() => source.sourceAsDOMElement, throwsStateError);

      // `render` stays registered as a navigable: a later (asynchronous)
      // navigation would render the invalid source and fail the suite.
      render.source = null;

      var other = BUIRenderSource(
        UIComponent.domGenerator,
        () => null,
        () {},
        () {},
      );
      other.source = 'x';
      var other2 = BUIRenderSource(
        UIComponent.domGenerator,
        () => null,
        () {},
        () {},
      );
      other2.source = 'x';
      expect(other.isSameSource(other2), isTrue);
      expect(other.isSameSource(other), isTrue);
      other2.source = 'y';
      expect(other.isSameSource(other2), isFalse);
      expect(other.toString(), equals('x'));
      expect(other.intlPath, isNull);
      expect(other.hasIntlPath, isFalse);
      expect(other.isIntlLoaded, isFalse);
      expect(other.hasIntlLoadedAny, isFalse);
      expect(await other.ensureIntlMessagesLoaded(), isFalse);
      expect(other.getIntlMessages(), isNull);

      other.source = '<bui intl="texts">{{intl:hello}}</bui>';
      expect(other.intlPath, equals('texts'));
      expect(other.hasIntlPath, isTrue);
    });

    test('resolveIntl and parseBUIAttribute', () {
      expect(
        BUIRenderSource.resolveIntl(null, 'a {{intl:x}} b'),
        equals('a  b'),
      );
      expect(BUIRenderSource.resolveIntl(null, 'plain'), equals('plain'));

      expect(
        parseBUIAttribute('<bui route="r" name="N">x</bui>', 'route'),
        equals('r'),
      );
      expect(parseBUIAttribute('<div route="r"></div>', 'route'), isNull);
      expect(parseBUIAttribute('no tag', 'route'), isNull);
      expect(parseBUIAttribute(null, 'route'), isNull);
    });

    test('BUIView', () {
      var view = BUIView(
        buiCode:
            '<bui route="home" name="Home" intl="t" hide-from-menu="true">'
            'x</bui>',
      );
      expect(view.route, equals('home'));
      expect(view.name, equals('Home'));
      expect(view.intl, equals('t'));
      expect(view.isHideFromMenu, isTrue);
      expect(view.intlMessagesLoader, isNotNull);
      expect(view.toString(), contains('<bui'));

      var named = BUIView(name: 'Only Name', buiCode: '<bui>x</bui>');
      expect(named.route, equals('Only Name'));
      expect(named.intl, isNull);
      expect(named.intlMessagesLoader, isNull);
      expect(named.isHideFromMenu, isFalse);

      view
        ..route = 'r2'
        ..name = 'N2'
        ..intl = 'i2'
        ..buiCode = '<bui>y</bui>';
      expect(view.route, equals('r2'));
      expect(view.name, equals('N2'));
      expect(view.intl, equals('i2'));
      expect(view.buiCode, equals('<bui>y</bui>'));

      expect(BUIView.toViewsMap(null), isEmpty);
    });

    // Regression: `routes`/`menuRoutes` cast a `List<String?>` to
    // `List<String>`, which always threw a `TypeError`.
    test('BUIViewProvider routes and views', () {
      var provider = BUIViewProvider(
        'app',
        navbar: BUIView(name: 'navbar', buiCode: '<bui>nav</bui>'),
        headers: [BUIView(route: 'h1', buiCode: '<bui>header</bui>')],
        footers: [BUIView(route: 'f1', buiCode: '<bui>footer</bui>')],
        views: [
          BUIView(route: 'home', name: 'Home', buiCode: '<bui>home</bui>'),
          BUIView(buiCode: '<bui route="secret" hide-from-menu="true">s</bui>'),
        ],
      );

      expect(provider.routes, equals(['home', 'secret']));
      expect(provider.menuRoutes, equals(['home']));
      expect(
        provider.routesAndNames,
        equals({'home': 'Home', 'secret': 'secret'}),
      );
      expect(provider.menuRoutesAndNames, equals({'home': 'Home'}));
      expect(provider.getRouteName('home'), equals('Home'));
      expect(provider.getNavbar()!.buiCode, contains('nav'));
      expect(provider.getHeader('h1'), isNotNull);
      expect(provider.getFooter('f1'), isNotNull);
      expect(provider.containsView('home'), isTrue);
      expect(provider.getMainView()!.route, equals('home'));

      provider.addView(BUIView(route: 'main', buiCode: '<bui>main</bui>'));
      expect(provider.getMainView()!.route, equals('main'));

      provider.addFileViewContent(null, 'views/navbar.bui', '<bui>nav2</bui>');
      expect(provider.navbar!.buiCode, contains('nav2'));
      provider.addFileViewContent(null, 'views/page.bui', '<bui>page</bui>');
      expect(provider.containsView('page'), isTrue);
      provider.addFileViewContent('headers', 'h2.bui', '<bui>h2</bui>');
      expect(provider.getHeader('h2'), isNotNull);
      provider.addFileViewContent('footers', 'f2.bui', '<bui>f2</bui>');
      expect(provider.getFooter('f2'), isNotNull);
      provider.addFileViewContent('other', 'o.bui', '<bui>o</bui>');
      expect(provider.containsView('o'), isTrue);

      var empty = BUIViewProvider('empty');
      expect(empty.getMainView(), isNull);
      expect(empty.routes, isEmpty);
    });

    test('BUIViewProvider from a manifest and a ZIP', () async {
      var fromJSON = await BUIViewProvider.fromManifestContent(
        jsonEncode({
          'name': 'app',
          'views': {'home': '<bui route="home">\nHome</bui>'},
        }),
      );
      expect(fromJSON!.name, equals('app'));
      expect(fromJSON.getView('home')!.buiCode, contains('Home'));

      var fromYAML = await BUIViewProvider.fromManifestContent(
        'name: app2\nviews:\n  home: "<bui route=\\"home\\">\\nY</bui>"\n',
      );
      expect(fromYAML!.name, equals('app2'));
      expect(fromYAML.getView('home')!.buiCode, contains('Y'));

      expect(await BUIViewProvider.fromManifestContent('{a: ['), isNull);
      expect(await BUIViewProvider.fromManifestTree(null), isNull);

      var archive = Archive()
        ..addFile(
          ArchiveFile.string('app/views/home.bui', '<bui>zip home</bui>'),
        )
        ..addFile(
          ArchiveFile.string('app/views/navbar.bui', '<bui>zip nav</bui>'),
        )
        ..addFile(
          ArchiveFile.string('app/views/headers/h.bui', '<bui>zip h</bui>'),
        )
        ..addFile(
          ArchiveFile.string('app/views/footers/f.bui', '<bui>zip f</bui>'),
        )
        ..addFile(ArchiveFile.string('app/assets/logo.txt', 'logo'))
        ..addFile(ArchiveFile.string('app/.hidden', 'x'));
      var bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      var fromZip = BUIViewProvider.fromZipBytes('zip', bytes);
      expect(fromZip.getView('home')!.buiCode, contains('zip home'));
      expect(fromZip.navbar!.buiCode, contains('zip nav'));
      expect(fromZip.getHeader('h'), isNotNull);
      expect(fromZip.getFooter('f'), isNotNull);
      expect(fromZip.dataAssets!.contains('logo.txt'), isTrue);

      expect(
        BUIRender.assetPathResolver(fromZip.dataAssets, 'assets/logo.txt'),
        startsWith('blob:'),
      );
      expect(
        BUIRender.assetPathResolver(fromZip.dataAssets, '/assets/none.txt'),
        equals('/assets/none.txt'),
      );
      expect(BUIRender.assetPathResolver(null, 'assets/x'), equals('assets/x'));
      expect(BUIRender.assetPathResolver(fromZip.dataAssets, ''), equals(''));
      expect(
        BUIRender.assetPathResolver(fromZip.dataAssets, 'other/x'),
        equals('other/x'),
      );
    });

    test('BUIRender with a view provider and data assets', () async {
      var dataAssets = DataAssets()
        ..putContent('a.txt', 'asset', MimeType.parse('text/plain')!);

      var provider = BUIViewProvider(
        'app',
        navbar: BUIView(name: 'navbar', buiCode: '<bui><nav>NAV</nav></bui>'),
        views: [
          BUIView(route: 'home', buiCode: '<bui><p id="v-home">HOME</p></bui>'),
          BUIView(
            route: 'other',
            buiCode: '<bui><p id="v-other">OTHER</p></bui>',
          ),
        ],
      );

      var render = BUIRender(
        newHolder(),
        viewProvider: provider,
        dataAssets: dataAssets,
      );
      await testUISleep(ms: 100);

      expect(render.viewProvider, same(provider));
      expect(render.dataAssets, same(dataAssets));
      expect(render.routes, containsAll(['home', 'other']));
      expect(render.getRouteName('home'), equals('home'));
      expect(render.isRouteHiddenFromMenu('home'), isFalse);
      expect(render.canHandleNewRoute('other'), isTrue);
      expect(render.canHandleNewRoute('none'), isFalse);
      expect(render.canHandleNewRoute(''), isTrue);
      expect(render.navbar, isNotNull);

      var content = render.content!;
      expect(content.querySelector('.ui-render-navbar'), isNotNull);
      expect(content.querySelector('#v-home'), isNotNull);

      // A refresh keeps a single navbar:
      render.refresh();
      await testUISleep(ms: 100);
      expect(content.querySelectorAll('.ui-render-navbar').length, equals(1));
      expect(content.querySelector('#v-home'), isNotNull);

      render.setCurrentRoute('other');
      expect(provider.currentRoute, equals('other'));
      render.setCurrentRoute(null);
      expect(provider.currentRoute, equals('home'));
    });

    test('BUIElementGenerator', () {
      var generator = BUIElementGenerator();
      expect(generator.tag, equals('bui'));

      var div = web.HTMLDivElement()
        ..className = 'bui'
        ..textContent = 't';
      expect(generator.isGeneratedElement(div), isTrue);
      expect(generator.isGeneratedElement(web.HTMLDivElement()), isFalse);

      var reverted = generator.revert(
        UIComponent.domGenerator,
        null,
        null,
        null,
        div,
      )!;
      expect(reverted.tag, equals('bui'));
      expect(reverted.buildHTML(), contains('t'));
      expect(
        generator.revert(
          UIComponent.domGenerator,
          null,
          null,
          null,
          web.HTMLSpanElement(),
        ),
        isNull,
      );
    });
  });

  group('UILayout', () {
    /// A `relative` container (in the DOM) holding [children].
    web.HTMLDivElement newContainer(List<web.HTMLElement> children) {
      var container = web.HTMLDivElement()
        ..style.position = 'relative'
        ..style.width = '200px'
        ..style.height = '100px';
      for (var e in children) {
        container.append(e);
      }
      uiRoot.content!.append(container);
      addTearDown(() => container.remove());
      return container;
    }

    web.HTMLDivElement ref(String id, int left, int top) => web.HTMLDivElement()
      ..id = id
      ..style.position = 'absolute'
      ..style.left = '${left}px'
      ..style.top = '${top}px'
      ..style.width = '10px'
      ..style.height = '10px';

    // `_getElementProperty` resolves element properties with
    // `elem.isHTMLElement`:
    test('element properties in expressions', () {
      var element = web.HTMLDivElement()
        ..style.width = '20px'
        ..style.height = '20px';
      newContainer([ref('lref', 30, 40), element]);

      var layout = UILayout(
        uiRoot,
        element,
        'x(#lref.x + 5); y(#lref.y * 2); width(#lref.width + 2); '
        'height(#lref.height)',
      );

      expect(layout.isRegistered, isTrue);
      expect(element.style.left, equals('35px'));
      expect(element.style.top, equals('80px'));
      expect(element.style.width, equals('12px'));
      expect(element.style.height, equals('10px'));
    });

    test('center, index and indexbyid', () {
      var element = web.HTMLDivElement()
        ..style.width = '10px'
        ..style.height = '10px';
      newContainer([ref('cref', 20, 20), element]);

      UILayout(uiRoot, element, 'x(#cref.center.x); y(index * 10)');
      expect(element.style.left, equals('25px'));
      expect(element.style.top, equals('10px'));

      // Regression: a negative number got no unit (`-1`, an invalid value).
      UILayout(uiRoot, element, 'y(indexbyid)');
      expect(element.style.top, equals('-1px'));

      UILayout(uiRoot, element, 'x(-5)');
      expect(element.style.left, equals('-5px'));

      element.id = 'withid';
      UILayout(uiRoot, element, 'y(indexbyid * 10)');
      expect(element.style.top, equals('0px'));
    });

    // Regression: `#id[n]` indexed a JS `NodeList` dynamically, which threw
    // a `NoSuchMethodError` with dart2wasm.
    test('an element by index (`#id[n]`)', () {
      var element = web.HTMLDivElement();
      newContainer([ref('iref', 10, 0), ref('iref', 30, 0), element]);

      UILayout(uiRoot, element, 'x(#iref[1].x + 5)');
      expect(element.style.left, equals('35px'));

      UILayout(uiRoot, element, 'x(#iref[0].x)');
      expect(element.style.left, equals('10px'));

      UILayout(uiRoot, element, 'x(#iref[5].x)');
      expect(element.style.left, equals('0px'));
    });

    test('`*` centers and fills', () {
      var element = web.HTMLDivElement()
        ..style.width = '20px'
        ..style.height = '10px';
      newContainer([element]);

      UILayout(uiRoot, element, 'x(*); y(*)');
      expect(element.style.left, equals('90px'));
      expect(element.style.top, equals('45px'));

      UILayout(uiRoot, element, 'width(*); height(*)');
      expect(element.style.width, equals('200px'));
      expect(element.style.height, equals('100px'));
    });

    test('a `#id` value copies the reference style', () {
      var element = web.HTMLDivElement();
      newContainer([ref('sref', 12, 34), element]);

      UILayout(uiRoot, element, 'x(#sref); y(#sref); width(#sref)');
      expect(element.style.left, equals('12px'));
      expect(element.style.top, equals('34px'));
      expect(element.style.width, equals('10px'));

      UILayout(uiRoot, element, 'x(#nothing); width(#nothing)');
      expect(element.style.left, equals('0px'));
      expect(element.style.width, equals('0px'));
    });

    test('centerx / centery', () {
      var element = web.HTMLDivElement()
        ..style.width = '20px'
        ..style.height = '10px';
      newContainer([element]);

      UILayout(uiRoot, element, 'centerx(100px); centery(50px)');
      expect(element.style.left, equals('90px'));
      expect(element.style.top, equals('45px'));
    });

    test('detached elements are not registered', () {
      var element = web.HTMLDivElement();
      var layout = UILayout(uiRoot, element, 'x(10px)');
      expect(layout.isRegistered, isFalse);
      expect(element.style.left, isEmpty);

      newContainer([element]);
      layout.refresh();
      expect(layout.isRegistered, isTrue);
      expect(element.style.left, equals('10px'));

      UILayout.refreshAll();
      UILayout.checkInstances();
      expect(UILayout.someInstanceNeedsRefresh(), isFalse);
      expect(layout.needsRefresh, isFalse);

      element.remove();
      UILayout.checkInstances();
      expect(layout.isRegistered, isFalse);
    });

    test('unknown and malformed commands are ignored', () {
      var element = web.HTMLDivElement();
      newContainer([element]);

      UILayout(uiRoot, element, 'x(1px); nope(2px); single; y(3px; ;');
      expect(element.style.left, equals('1px'));
      expect(element.style.top, isEmpty);
    });
  });

  group('UILayoutEvaluator', () {
    UILayoutEvaluator newEvaluator([Map<String, dynamic>? elements]) =>
        UILayoutEvaluator(
          (id, all) => elements?[id],
          (elem, property) => elem is Map ? elem[property] : null,
        );

    test('unit arithmetic and unary operators', () {
      var evaluator = newEvaluator();
      expect(evaluator.processLayout('10px / 4', {}), equals('2.5px'));
      expect(evaluator.processLayout('-(10px)', {}), equals('-10px'));
      expect(evaluator.processLayout('-x', {'x': 3}), equals('-3'));
      expect(evaluator.processLayout('-x', {'x': 3}, 'px'), equals('-3px'));
      expect(evaluator.processLayout('1.5em * 3', {}), equals('4.5em'));
      expect(evaluator.processLayout('X + 1', {'x': 2}), equals('3'));
    });

    test('element and map members', () {
      var evaluator = newEvaluator({
        'foo': {
          'bar': {'baz': 7},
        },
      });

      expect(evaluator.processLayout('#foo.bar.baz', {}, 'px'), equals('7px'));
      expect(evaluator.processLayout('#foo.bar.baz + 1', {}), equals('8'));
      expect(evaluator.processLayout('#none.x', {}, 'px', 'd'), equals('d'));
      expect(
        evaluator.processLayout('m.k', {
          'm': {'k': 5},
        }),
        equals('5'),
      );
      expect(
        evaluator.processLayout('l[1]', {
          'l': [4, 5],
        }),
        equals('5'),
      );
      expect(
        evaluator.processLayout('l[9]', {
          'l': [4, 5],
        }),
        isNull,
      );
      expect(evaluator.isPrimitiveValue(true), isTrue);
      expect(evaluator.isPrimitiveValue(null), isFalse);
      expect(evaluator.isPrimitiveValue([1]), isFalse);
      expect(
        evaluator.processLayout('l', {
          'l': [1],
        }),
        equals([1]),
      );
    });

    // The `ValueUnitExpression` operators take `dynamic` operands.
    test('ValueUnitExpression', () {
      var v = ValueUnitExpression(10, 'px');
      expect(v.toString(), equals('10px'));
      expect(v.valueAsLiteral.value, equals(10));

      expect((v + 5).toString(), equals('15px'));
      expect((v - 4).toString(), equals('6px'));
      expect((v * 2).toString(), equals('20px'));
      expect((v / 4).toString(), equals('2.5px'));
      expect((v ~/ 3).toString(), equals('3px'));

      var em = ValueUnitExpression(1, 'em');
      expect(ValueUnitExpression.getUnit(v, v), equals('px'));
      expect(ValueUnitExpression.getUnit(v, Literal(1)), equals('px'));
      expect(ValueUnitExpression.getUnit(Literal(1), em), equals('em'));
      expect(ValueUnitExpression.getUnit(null, null), isNull);
      expect(() => ValueUnitExpression.getUnit(v, em), throwsUnsupportedError);

      var elementExpression = ElementExpression('e', Identifier('p'));
      expect(elementExpression.toString(), equals('e.p'));
      expect(elementExpression.toTokenString(), equals('e.p'));
      expect(ElementExpression('e', null).toString(), equals('e'));
    });

    test('indexing a non-list element and unary members', () {
      var evaluator = newEvaluator({
        'one': {'v': 3},
      });
      expect(evaluator.processLayout('#one[0].v', {}, 'px'), equals('3px'));
      expect(evaluator.processLayout('-#one.v', {}, 'px'), equals('-3px'));
      expect(evaluator.processLayout('-(2 + 3)', {}), equals('-5'));
      expect(evaluator.processLayout('(1 + 2) * 3', {}), equals('9'));
    });
  });

  group('more UIInputTable extra rows', () {
    test('rows of DOMNode rows, a table node and mixed lists', () async {
      var table = UIInputTable(
        newHolder(),
        [InputConfig('name', 'Name')],
        extraRows: [
          [
            $tr(cells: ['r1']),
            $tr(cells: ['r2']),
          ],
          $table(
            body: [
              $tr(cells: ['t1']),
            ],
          ),
          [$td(content: 'd1'), $td(content: 'd2')],
          [
            'm1',
            ['m2'],
          ],
          42,
        ],
      );
      await table.callRenderAndWait();

      var rows = table.content!
          .querySelectorAll('tr')
          .toElements()
          .map((e) => e.textContent)
          .toList();
      expect(rows, containsAll(['r1', 'r2', 't1', 'd1d2']));
      expect(rows.any((r) => r!.contains('m2')), isTrue);
    });
  });

  group('more UIMultiSelection', () {
    test('mouse enter / leave show and hide the options panel', () async {
      var selection = UIMultiSelection(newHolder(), {
        'a': 'A',
        'b': 'B',
      }, selectionMaxDelay: Duration(milliseconds: 50));
      await selection.callRenderAndWait();

      var input = selection.content!.querySelector(
        '.ui-multi-selection-input',
      ) as web.HTMLElement;
      var panel = selection.content!.querySelector(
        '.ui-multi-selection-options-menu',
      ) as web.HTMLElement;

      expect(panel.style.display, equals('none'));

      input.dispatchEvent(web.MouseEvent('mouseenter'));
      expect(panel.style.display, equals(''));

      input.dispatchEvent(web.MouseEvent('mouseleave'));
      panel.dispatchEvent(web.MouseEvent('mouseenter'));
      panel.dispatchEvent(web.MouseEvent('mousemove'));
      await testUISleep(ms: 60);
      expect(panel.style.display, equals(''), reason: 'Over the panel');

      panel.dispatchEvent(web.MouseEvent('mouseleave'));
      expect(panel.style.display, equals('none'));

      // Hiding the panel triggers the pending selection:
      var selects = 0;
      selection.onSelect.listen((_) => selects++);
      input.dispatchEvent(web.MouseEvent('mouseenter'));
      selection.checkByID('b', true);
      input.dispatchEvent(web.MouseEvent('mouseleave'));
      await testUISleep(ms: 100);
      expect(panel.style.display, equals('none'));
      expect(selects, greaterThanOrEqualTo(1));
      expect(
        (selection.content!.querySelector(
          '.ui-multi-selection-input',
        ) as web.HTMLInputElement).value,
        equals('B'),
      );
    });

    test('many selected labels shrink the input font', () async {
      var holder = newHolder()..style.width = '120px';
      var options = {
        for (var i = 0; i < 8; i++) 'k$i': 'A long option label $i',
      };
      var selection = UIMultiSelection(
        holder,
        options,
        selectionMaxDelay: Duration(milliseconds: 50),
      );
      await selection.callRenderAndWait();

      selection.checkAllByID(['k0', 'k1', 'k2', 'k3'], true);

      var input = selection.content!.querySelector(
        '.ui-multi-selection-input',
      ) as web.HTMLInputElement;
      expect(input.value, contains('A long option label 0'));
      expect(input.style.fontSize, endsWith('%'));
    });
  });

  group('more Masonry', () {
    web.HTMLDivElement box(int w, int h, String text) => web.HTMLDivElement()
      ..style.width = '${w}px'
      ..style.height = '${h}px'
      ..textContent = text;

    test('groups smaller items to fill a line', () async {
      var holder = newHolder()
        ..style.width = '300px'
        ..style.height = '400px';

      var masonry = UIMasonry(
        holder,
        [
          MasonryItem.fromElement(box(200, 200, 'A')),
          MasonryItem.fromElement(box(100, 100, 'B')),
          MasonryItem.fromElement(box(100, 100, 'C')),
          MasonryItem.fromElement(box(100, 100, 'D')),
          MasonryItem.fromElement(box(300, 100, 'F')),
        ],
        masonryWidthSize: 100,
        masonryHeightSize: 100,
      );
      await masonry.callRenderAndWait();
      await testUISleep(ms: 150);

      var content = masonry.content!;
      expect(content.querySelectorAll('.ui-masonry-block').length, equals(5));

      // Two 1x1 items are grouped (stacked) next to the 2x2 item:
      var group = content.querySelector('.ui-masonry-group');
      expect(group, isNotNull);
      expect(group!.querySelectorAll('.ui-masonry-block').length, equals(2));

      var text = content.textContent!;
      for (var t in ['A', 'B', 'C', 'D', 'F']) {
        expect(text, contains(t));
      }
    });

    test('refreshes when an item dimension changes', () async {
      var holder = newHolder()
        ..style.width = '300px'
        ..style.height = '300px';

      var element = box(100, 100, 'grow');
      var masonry = UIMasonry(
        holder,
        [MasonryItem.from(element), MasonryItem.from(box(100, 100, 'other'))],
        masonryWidthSize: 100,
        masonryHeightSize: 100,
      );
      await masonry.callRenderAndWait();
      await testUISleep(ms: 150);

      element.style.width = '200px';
      expect(masonry.checkChangedDimension(), isTrue);
      masonry.updateDimensions();
      expect(masonry.checkChangedDimension(), isFalse);
      masonry.refresh();
      await testUISleep(ms: 150);

      var block = masonry.content!
          .querySelectorAll('.ui-masonry-block')
          .toElements()
          .firstWhere((e) => e.textContent!.contains('grow'));
      expect((block as web.HTMLElement).style.width, equals('200px'));
    });
  });

  group('more UICapture', () {
    UIButtonCapturePhoto capture(CaptureDataFormat format) =>
        UIButtonCapturePhoto(null, captureDataFormat: format);

    const text = 'hi';
    final textBase64 = base64.encode(utf8.encode(text));
    final dataUrl = 'data:text/plain;base64,$textBase64';

    // A blob URL (`urlOrBlobUrl`) can't be converted back to its content
    // synchronously, so it's not in these round trips.
    final convertibleFormats = CaptureDataFormat.values
        .where((f) => f != CaptureDataFormat.urlOrBlobUrl)
        .toList();

    // Regression: the base64 of a data URL (`dataUrlBase64`/`url` formats) was
    // its decoded content (`DataURLBase64.payload` instead of
    // `payloadBase64`).
    test('conversions from a data URL', () {
      for (var format in convertibleFormats) {
        var c = capture(format)..selectedFileData = dataUrl;
        expect(c.selectedFileDataAsString, equals(text), reason: '$format');
        expect(
          c.selectedFileDataAsBase64,
          equals(textBase64),
          reason: '$format',
        );
        expect(
          c.selectedFileDataAsArrayBuffer,
          equals(utf8.encode(text)),
          reason: '$format',
        );
      }
    });

    test('conversions from bytes', () {
      var bytes = Uint8List.fromList(utf8.encode(text));
      for (var format in convertibleFormats) {
        var c = capture(format)..selectedFileData = bytes;
        expect(
          c.selectedFileDataAsArrayBuffer,
          equals(bytes),
          reason: '$format',
        );
        expect(c.selectedFileDataAsString, equals(text), reason: '$format');
      }

      var url = capture(CaptureDataFormat.url)..selectedFileData = bytes;
      expect(url.selectedFileDataAsURLOrDataURLBase64, startsWith('data:'));
      expect(url.getFieldValue(), startsWith('data:'));

      for (var data in <Object>[bytes, dataUrl, textBase64]) {
        var blob = capture(CaptureDataFormat.urlOrBlobUrl)
          ..selectedFileData = data;
        expect(blob.selectedFileData as String, startsWith('blob:'));
      }
    });

    test('conversions from a base64 string', () {
      for (var format in convertibleFormats) {
        var c = capture(format)..selectedFileData = textBase64;
        expect(
          c.selectedFileDataAsBase64,
          equals(textBase64),
          reason: '$format',
        );
      }
    });

    test('conversions from plain text', () {
      // Not base64 (`!`), so encoded as UTF-8:
      const plain = 'hello!';
      var arrayBuffer = capture(CaptureDataFormat.arrayBuffer)
        ..selectedFileData = plain;
      expect(arrayBuffer.selectedFileDataAsString, equals(plain));

      var base64Capture = capture(CaptureDataFormat.base64)
        ..selectedFileData = plain;
      expect(base64Capture.selectedFileDataAsString, equals(plain));

      var dataUrlCapture = capture(CaptureDataFormat.dataUrlBase64)
        ..selectedFileData = plain;
      expect(dataUrlCapture.selectedFileDataAsString, equals(plain));
      expect(
        dataUrlCapture.selectedFileDataAsDataURLBase64,
        startsWith('data:text/plain'),
      );

      var url = capture(CaptureDataFormat.url)..selectedFileData = 'x!';
      expect(url.selectedFileData, equals('x!'));

      var blobUrl = capture(CaptureDataFormat.urlOrBlobUrl)
        ..selectedFileData = 'https://e.com/a.png';
      expect(blobUrl.selectedFileData, equals('https://e.com/a.png'));

      var blobPlain = capture(CaptureDataFormat.urlOrBlobUrl)
        ..selectedFileData = 'y!';
      expect(blobPlain.selectedFileData, equals('y!'));
    });

    test('latin1 fallback for invalid UTF-8', () {
      var c = capture(CaptureDataFormat.string)
        ..selectedFileData = Uint8List.fromList([0xE9]);
      expect(c.selectedFileDataAsString, equals('é'));
    });

    test('setFieldValue', () {
      var c = capture(CaptureDataFormat.base64);
      c.setFieldValue(textBase64);
      expect(c.hasSelectedFileData, isTrue);
      c.setFieldValue(null);
      expect(c.hasSelectedFileData, isFalse);
      expect(c.getFieldValue(), isNull);
      expect(c.selectedFileDataAsDataURLBase64, isNull);
      expect(c.selectedFileDataAsURLOrDataURLBase64, isNull);
    });

    test('video and audio file readers', () async {
      Future<UICapture> selected(CaptureType type, web.File file) async {
        var c = UIButtonCapture(newHolder(), 'x', type);
        await c.callRenderAndWait();
        var input = c.getInputCapture() as web.HTMLInputElement;
        var dataTransfer = web.DataTransfer();
        dataTransfer.items.add(file);
        input.files = dataTransfer.files;
        return c;
      }

      web.File file(String name, String type) => web.File(
        <JSAny>['data'.toJS].toJS,
        name,
        web.FilePropertyBag(type: type),
      );

      var video = await selected(
        CaptureType.videoFile,
        file('v.mp4', 'video/mp4'),
      );
      expect(video.isFileVideo(), isTrue);
      var videoElement = await video
          .getVideoFileReader()!
          .onLoadVideo
          .first
          .timeout(Duration(seconds: 10));
      expect(videoElement.querySelector('source'), isNotNull);

      var audio = await selected(
        CaptureType.audioFile,
        file('a.mp3', 'audio/mpeg'),
      );
      expect(audio.isFileAudio(), isTrue);
      var audioElement = await audio
          .getAudioFileReader()!
          .onLoadAudio
          .first
          .timeout(Duration(seconds: 10));
      expect(audioElement.querySelector('source'), isNotNull);

      var loaded = await URLFileReader(file('t.txt', 'text/plain'))
          .onLoadData
          .first
          .timeout(Duration(seconds: 10));
      expect(loaded, startsWith('data:text/plain'));
    });
  });

  group('more ui-template', () {
    test('context Future and Function variables, with a loading', () async {
      var context = UIComponent.domGenerator.domContext!;
      var completer = Completer<String>();
      context.putVariable('slowValue', completer.future);
      context.putVariable('fnValue', () => 'from-fn');
      addTearDown(() {
        context.putVariable('slowValue', null);
        context.putVariable('fnValue', null);
      });

      var component = _HTMLComponent(
        newHolder(),
        '<ui-template loading-type="ring">'
        '<b class="slow">{{slowValue}}</b><i class="fn">{{fnValue}}</i>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 20);

      var content = component.content!;
      expect(content.querySelector('.slow'), isNull, reason: 'Loading');

      completer.complete('done');
      await testUISleep(ms: 50);

      expect(content.querySelector('.slow')!.textContent, equals('done'));
      expect(content.querySelector('.fn')!.textContent, equals('from-fn'));
    });

    test('revert with a tree map and resolveAttributeVariables', () {
      var generator = UITemplateElementGenerator();

      var div = web.HTMLDivElement()..className = 'ui-template';
      var treeMap = UIComponent.domGenerator.createDOMTreeMap();
      var domNode = $div(content: $span(content: 'mapped'));
      treeMap.map(domNode, div);

      var reverted = generator.revert(
        UIComponent.domGenerator,
        treeMap,
        null,
        null,
        div,
      )!;
      expect(reverted.buildHTML(), contains('mapped'));

      var variables = <String, dynamic>{};
      generator.resolveAttributeVariables({
        'variables': DOMAttribute.from('variables', 'x=1&y=2')!,
      }, variables);
      expect(variables, equals({'x': '1', 'y': '2'}));

      expect(generator.getDataSourceResponse({'data-source': 'nope'}), isNull);
    });
  });

  group('more BUI', () {
    test('named header and footer elements from the view provider', () async {
      var provider = BUIViewProvider(
        'app',
        headers: [
          BUIView(
            route: 'top',
            buiCode: '<bui><b class="hdr">HEADER</b></bui>',
          ),
        ],
        footers: [
          BUIView(
            route: 'end',
            buiCode: '<bui><i class="ftr">FOOTER</i></bui>',
          ),
        ],
        views: [
          BUIView(
            route: 'home',
            buiCode:
                '<bui><header name="top"></header><p>BODY</p>'
                '<footer name="end"></footer><div name="x"></div></bui>',
          ),
        ],
      );

      var render = BUIRender(newHolder(), viewProvider: provider);
      await testUISleep(ms: 100);

      var content = render.content!;
      expect(content.querySelector('.hdr')!.textContent, equals('HEADER'));
      expect(content.querySelector('.ftr')!.textContent, equals('FOOTER'));
      expect(content.textContent, contains('BODY'));
    });

    test('main view fallbacks', () {
      BUIView view(String route) =>
          BUIView(route: route, buiCode: '<bui>$route</bui>');

      expect(
        BUIViewProvider(
          'a',
          views: [view('x'), view('home')],
        ).getMainView()!.route,
        equals('home'),
      );
      expect(
        BUIViewProvider(
          'a',
          views: [view('x'), view('root')],
        ).getMainView()!.route,
        equals('root'),
      );
      expect(
        BUIViewProvider(
          'a',
          views: [view('x'), view('y')],
        ).getMainView()!.route,
        equals('x'),
      );
    });

    test('manifest with inline headers and footers', () async {
      var provider = (await BUIViewProvider.fromManifestTree({
        'name': 'm',
        'views': {'home': '<bui route="home">\nH</bui>'},
        'headers': {'h': '<bui route="h">\nHH</bui>'},
        'footers': {'f': '<bui route="f">\nFF</bui>'},
      }))!;

      expect(provider.getView('home'), isNotNull);
      expect(provider.getHeader('h')!.buiCode, contains('HH'));
      expect(provider.getFooter('f')!.buiCode, contains('FF'));
    });

    test('BUIManifest and BUIManifestRender', () async {
      var manifestJSON = jsonEncode({
        'name': 'app',
        'views': {'home': '<bui route="home">\n<p class="m-home">M</p></bui>'},
      });

      var manifest = BUIManifest.from(manifestJSON)!;
      expect(BUIManifest.from(manifest), same(manifest));
      expect(BUIManifest.from(null), isNull);
      expect(BUIManifest.from(''), isNull);
      expect(BUIManifest.from(42), isNull);

      expect(await manifest.getManifestContent(), equals(manifestJSON));
      expect((await manifest.getManifestTree())!['name'], equals('app'));
      var viewProvider = (await manifest.getViewProvider())!;
      expect(viewProvider.getView('home'), isNotNull);

      expect(BUIManifest.parseTree<Map>('a: 1')!['a'], equals(1));
      expect(BUIManifest.parseTree<Map>('{"a": 2}')!['a'], equals(2));

      var render = BUIManifestRender(
        newHolder(),
        manifestJSON,
        loadingType: UILoadingType.ring,
        loadingContent: 'Loading...',
      );
      await render.callRenderAndWait();
      await testUISleep(ms: 200);

      expect(render.manifest, isNotNull);
      expect(render.buiRender, isNotNull);
      expect(render.viewProviderBase, isNotNull);
      expect(render.content!.querySelector('.m-home'), isNotNull);
    });
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'components-b-root');

  @override
  UIComponent? renderContent() => null;
}

class _PlainComponent extends UIComponent {
  _PlainComponent(super.parent);

  @override
  dynamic render() => 'plain';
}

class _HTMLComponent extends UIComponent {
  final String html;

  _HTMLComponent(super.parent, this.html);

  @override
  dynamic render() => html;
}

class _BoxComponent extends UIComponent {
  final int w;
  final int h;

  _BoxComponent(super.parent, this.w, this.h);

  @override
  dynamic render() {
    content!
      ..style.width = '${w}px'
      ..style.height = '${h}px';
    return 'box';
  }
}

class _ActionComponent extends UIComponent {
  final List<String> actions = [];

  _ActionComponent(super.parent);

  @override
  void action(String action) => actions.add(action);

  @override
  dynamic render() => '';
}
