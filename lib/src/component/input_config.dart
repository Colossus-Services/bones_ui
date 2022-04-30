import 'dart:html';

import 'package:collection/collection.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_component.dart';
import 'capture.dart';
import 'color_picker.dart';

typedef FieldValueProvider = dynamic Function(String field);

typedef FieldValueValidator = bool Function(String field, String? value);

typedef FieldValueNormalizer = String? Function(String field, String? value);

/// Configuration for an input.
class InputConfig {
  static List<InputConfig> listFromMap(Map map) {
    return map.entries
        .map((e) => InputConfig.from(e.value, '${e.key}'))
        .whereType<InputConfig>()
        .toList();
  }

  final String _id;
  late final String? _label;
  final String _type;
  String? value;
  final String? _placeholder;
  final Map<String, String>? _attributes;
  final Map<String, String>? _options;
  final bool _optional;

  final FieldValueProvider? _valueProvider;
  final FieldValueValidator? _valueValidator;
  final FieldValueNormalizer? _valueNormalizer;
  final Object? _invalidValueMessage;

  List<String> classes;

  String? style;

  static InputConfig? from(dynamic config, [String? id]) {
    if (config is List) {
      config = config.join(' ; ');
    }

    if (config is String) {
      config = parseFromInlineMap(config, RegExp(r'\s*[,;]\s*'),
          RegExp(r'\s*[=:]\s*'), parseString, parseString);
    }

    if (config is Map) {
      id ??= parseString(findKeyValue(config, ['id'], true));

      var label = parseString(findKeyValue(config, ['label'], true));
      var type = parseString(findKeyValue(config, ['type'], true), 'text');
      var value = parseString(findKeyValue(config, ['value'], true), '');
      var attributes = findKeyValue(config, ['attributes'], true);
      var classes = findKeyValue(config, ['class', 'classes'], true);
      var style = findKeyValue(config, ['style'], true);
      var options = findKeyValue(config, ['options'], true);
      var optional = parseBool(findKeyValue(config, ['optional'], true), false);

      if (attributes is Map) {
        attributes = asMapOfString(attributes);
      }

      if (options is Map) {
        options = asMapOfString(options);
      }

      return InputConfig(id!, label,
          type: type,
          value: value,
          attributes: attributes,
          options: options,
          optional: optional,
          classes: classes,
          style: style);
    }

    return null;
  }

  InputConfig(String id, String? label,
      {String? type = 'text',
      String? value = '',
      String? placeholder = '',
      Map<String, String>? attributes,
      Map<String, String>? options,
      bool? optional = false,
      Object? classes,
      String? style,
      FieldValueProvider? valueProvider,
      FieldValueValidator? valueValidator,
      FieldValueNormalizer? valueNormalizer,
      Object? invalidValueMessage})
      : _id = id,
        _type = type == null || type.isEmpty ? 'text' : type,
        value = value == null || value.isEmpty ? null : value,
        _placeholder =
            placeholder == null || placeholder.isEmpty ? null : placeholder,
        _optional = optional ?? false,
        _attributes = attributes,
        _options = options,
        _valueProvider = valueProvider,
        _valueValidator = valueValidator,
        _valueNormalizer = valueNormalizer,
        _invalidValueMessage = invalidValueMessage,
        classes = UIComponent.parseClasses(classes) {
    if (label == null || label.isEmpty) {
      if (this.value != null) {
        label = this.value!;
      } else {
        label = _type;
      }
    }

    if (id.isEmpty) throw ArgumentError('Invalid ID');
    if (label.isEmpty) throw ArgumentError('Invalid Label');

    _label = label;

    if (style != null) {
      style = style.trim();
      this.style = style.isNotEmpty ? style : null;
    }
  }

  String get id => _id;

  String get fieldName => _id;

  String? get label => _label;

  String get type => _type;

  String? get placeholder => _placeholder;

  Map<String, String>? get attributes => _attributes;

  Map<String, String>? get options => _options;

  bool get optional => _optional;

  bool get required => !_optional;

  FieldValueProvider? get valueProvider => _valueProvider;

  bool get hasValueValidator => _valueValidator != null;

  bool validateValue(String? value) {
    var valueValidator = _valueValidator;
    if (valueValidator != null) {
      if (!valueValidator(fieldName, value)) {
        return false;
      }
    }

    if (required && _isEmptyValue(value)) {
      return false;
    }

    return true;
  }

  bool get hasValueNormalizer => _valueNormalizer != null;

  String? normalizeValue(String? value) {
    var valueNormalizer = _valueNormalizer;
    if (valueNormalizer != null) {
      return valueNormalizer(fieldName, value);
    }

    return value;
  }

  String? get invalidValueMessage {
    var value = _invalidValueMessage;
    if (value == null) return null;

    if (value is MessageBuilder) {
      return value.build();
    } else {
      return value.toString();
    }
  }

  dynamic renderInput([FieldValueProvider? fieldValueProvider]) {
    var inputID = id;
    var inputType = type;
    var inputValue = fieldValueProvider != null
        ? (fieldValueProvider(fieldName) ?? value)
        : value;

    Element? inputElement;
    UIComponent? inputComponent;
    Element? element;

    if (inputType == 'textarea') {
      inputElement = _renderTextArea(inputValue);
    } else if (inputType == 'select') {
      inputElement = _renderSelect(inputValue);
    } else if (inputType == 'image') {
      var capture = UIButtonCapturePhoto(null, text: label, fieldName: inputID);
      inputComponent = capture;
    } else if (inputType == 'color') {
      var picker = UIColorPickerInput(null,
          fieldName: inputID,
          placeholder: placeholder,
          value: inputValue,
          pickerWidth: 150,
          pickerHeight: 100);
      inputComponent = picker;
    } else if (inputType == 'path') {
      element = _renderInputPath(inputID, inputValue);
    } else if (inputType == 'html') {
      inputElement = createHTML(inputValue);
      inputElement.onClick.listen((event) {
        var value = inputElement!.getAttribute('element_value');
        if (isNotEmptyObject(value)) {
          inputElement.setAttribute('field_value', value!);
        }
      });
    } else {
      inputElement = _renderGenericInput(inputType, inputValue);
    }

    if (inputElement != null) {
      _configureElementStyle(inputElement);
      _configureInputElement(inputElement, inputID);
      _configureElementAttribute(inputElement);
      return inputElement;
    } else if (element != null) {
      var input = element.querySelector('input')!;
      _configureElementStyle(element);
      _configureInputElement(input, inputID);
      _configureElementAttribute(element);
      return element;
    } else if (inputComponent != null) {
      return inputComponent;
    }

    return null;
  }

  void _configureElementStyle(Element inputElement) {
    if (isNotEmptyObject(classes)) {
      inputElement.classes.addAll(classes);
    }

    if (isNotEmptyObject(style)) {
      var cssText = inputElement.style.cssText;
      inputElement.style.cssText =
          isNotEmptyObject(cssText) ? '$cssText ; $style' : style;
    }
  }

  void _configureElementAttribute(Element inputElement) {
    if (attributes != null && attributes!.isNotEmpty) {
      for (var attrKey in attributes!.keys) {
        var attrVal = attributes![attrKey];
        if (attrKey.isNotEmpty && attrVal!.isNotEmpty) {
          inputElement.setAttribute(attrKey, attrVal);
        }
      }
    }
  }

  void _configureInputElement(Element inputElement, String inputID) {
    inputElement.setAttribute('id', inputID);
    inputElement.setAttribute('name', inputID);
    inputElement.setAttribute('field', inputID);

    if (placeholder != null) {
      inputElement.setAttribute('placeholder', placeholder!);
    }
  }

  DivElement? _renderInputPath(String fieldName, String? inputValue) {
    var input = $input(style: 'width: auto', value: inputValue);
    DOMElement? button;

    var valueProvider = _valueProvider;

    if (valueProvider != null) {
      button = $button(
          classes: 'btn-sm btn-secondary',
          style: 'font-size: 80%',
          content: 'File')
        ..onClick.listen((_) async {
          var ret = valueProvider(fieldName) ?? '';
          dynamic value;
          if (ret is Future) {
            value = await ret;
          } else {
            value = ret;
          }
          value ??= '';

          var element = input.runtime.node as InputElement;
          element.value = '$value';
          element.dispatchEvent(Event('change'));
        });
    }

    var div = $div(content: [input, button])
        .buildDOM(generator: UIComponent.domGenerator);

    return div as DivElement?;
  }

  TextAreaElement _renderTextArea(inputValue) {
    var textArea = TextAreaElement();
    textArea.value = inputValue;
    return textArea;
  }

  Element _renderGenericInput(String? inputType, inputValue) {
    var input = InputElement()
      ..type = inputType ?? 'text'
      ..value = inputValue ?? ''
      ..style.width = '100%';

    return input;
  }

  SelectElement _renderSelect(inputValue) {
    var select = SelectElement();

    if (options != null && options!.isNotEmpty) {
      for (var optKey in options!.keys) {
        var optVal = options![optKey];
        var selected = false;

        if (optKey.endsWith('*')) {
          optKey = optKey.substring(0, optKey.length - 1);
          selected = true;
        }

        if (optVal == null || optVal.isEmpty) {
          optVal = optKey;
        }

        var optionElement = OptionElement(data: optVal, value: optKey);

        if (selected) {
          optionElement.selected = selected;
        }

        select.add(optionElement, null);
      }
    } else if (inputValue != null && inputValue.isNotEmpty) {
      select.innerHtml = '$inputValue';
    }

    return select;
  }

  List<Element> renderElementsWithInputValues(String html,
      [FieldValueProvider? fieldValueProvider]) {
    var inputID = id;
    var inputType = type;
    var inputValue = fieldValueProvider != null
        ? (fieldValueProvider(fieldName) ?? value)
        : value;

    var elements = <Element>[];

    var keys = <String?>[];

    if (inputType == 'select') {
      if (options != null && options!.isNotEmpty) {
        keys = options!.keys
            .map((k) => k.replaceFirst(RegExp(r'\s*\*\s*$'), ''))
            .toList();
      } else if (inputValue != null && inputValue.isNotEmpty) {
        var select = SelectElement()..innerHtml = '$inputValue';
        keys = select.options.map((opt) => opt.value).toList();
      }
    } else {
      keys.add(inputValue);
    }

    for (var key in keys) {
      String? renderHtml = html;

      if (html.contains('{{') && html.contains('}}')) {
        renderHtml = buildStringPattern(html, {inputID: key});
      }

      var elem = createHTML(renderHtml);

      elem.setAttribute('element_value', key!);
      elements.add(elem);
    }

    return elements;
  }
}

/// Component that renders a table with inputs.
class UIInputTable extends UIComponent {
  final List<InputConfig> _inputs;
  final bool showLabels;
  final bool showInvalidMessages;

  final List _extraRows;

  final List<String> _inputsClasses;

  final String? inputErrorClass;
  final String? invalidValueClass;

  UIInputTable(Element? parent, this._inputs,
      {List? extraRows,
      this.actionListenerComponent,
      this.actionListener,
      this.inputErrorClass,
      this.invalidValueClass,
      this.showLabels = true,
      this.showInvalidMessages = true,
      dynamic classes,
      dynamic style,
      dynamic inputsClasses})
      : _extraRows = extraRows ?? [],
        _inputsClasses = UIComponent.parseClasses(inputsClasses),
        super(parent,
            componentClass: 'ui-infos-table', classes: classes, style: style);

  List<String> get inputsClasses => _inputsClasses;

  String get highlightClass => inputErrorClass ?? 'ui-input-error';

  bool canHighlightInputs() =>
      inputErrorClass == null || inputErrorClass!.isEmpty;

  int highlightEmptyInputs() {
    if (canHighlightInputs()) return -1;

    unhighlightErrorInputs();

    var highlightClass = this.highlightClass;

    return forEachEmptyFieldElement(
        (fieldElement) => fieldElement.classes.add(highlightClass));
  }

  int unhighlightErrorInputs() {
    if (canHighlightInputs()) return -1;

    var highlightClass = this.highlightClass;

    return forEachFieldElement((fieldElement) {
      fieldElement.classes.remove(highlightClass);
      var fieldName = getElementFieldName(fieldElement);
      _hideInvalidMessage(fieldName);
    });
  }

  bool highlightField(String? fieldName, {String? invalidValueMessage}) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.add(highlightClass);

    if (showInvalidMessages && !_isEmptyValue(invalidValueMessage)) {
      var msg = content!.querySelector('#__invalid_msg__$fieldName');
      if (msg != null) {
        msg.text = invalidValueMessage!;
        msg.hidden = false;
      }
    }

    return true;
  }

  bool unhighlightField(String fieldName) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.remove(highlightClass);

    _hideInvalidMessage(fieldName);

    return true;
  }

  void _hideInvalidMessage(String? fieldName) {
    if (!showInvalidMessages || fieldName == null || fieldName.isEmpty) return;

    var msg = content!.querySelector('#__invalid_msg__$fieldName');
    if (msg != null) {
      msg.hidden = true;
      msg.text = '';
    }
  }

  bool checkFields() {
    normalizeFields();

    var ok = true;

    unhighlightErrorInputs();

    for (var input in _inputs) {
      var fieldName = input.fieldName;
      var fieldValue = getFieldElementValue(fieldName);
      var fieldOk = input.validateValue(fieldValue);

      if (!fieldOk) {
        var invalidValueMessage =
            _isEmptyValue(fieldValue) ? null : input.invalidValueMessage;

        highlightField(fieldName, invalidValueMessage: invalidValueMessage);

        if (ok) {
          var element = getFieldElement(fieldName);
          if (element != null) {
            scrollToElement(element);
          }
        }

        ok = false;
      }
    }

    return ok;
  }

  int normalizeFields() {
    var normalizeCount = 0;

    for (var input in _inputs.where((e) => e.hasValueNormalizer)) {
      var fieldName = input.fieldName;
      var fieldValue = getFieldElementValue(fieldName);
      var fieldValue2 = input.normalizeValue(fieldValue);

      if (fieldValue2 != fieldValue) {
        setField(fieldName, fieldValue2);
        ++normalizeCount;
      }
    }

    return normalizeCount;
  }

  @override
  dynamic render() {
    var form = FormElement();
    form.autocomplete = 'off';

    var table = TableElement();
    var tBody = table.createTBody();

    for (var input in _inputs) {
      var row = tBody.addRow();

      if (showLabels) {
        var label = input.label ?? '';

        var cell = row.addCell()
          ..style.verticalAlign = 'top'
          ..style.textAlign = 'right';

        if (label.isNotEmpty) {
          if (label.contains('{{') && label.contains('}}')) {
            var domLabel = $label(
                classes: 'form-check-label',
                forID: input.id,
                style: 'font-weight: bold',
                content: [label, ':', '&nbsp;']);
            var dom = domLabel.buildDOM(generator: UIComponent.domGenerator)
                as LabelElement;
            cell.children.add(dom);
          } else {
            cell.appendHtml(
                '<label class="form-check-label" for="${input.id}"><b>$label:&nbsp;</b></label>');
          }
        }
      }

      var celInput = row.addCell()..style.textAlign = 'left';

      var inputRendered = input.renderInput(getPreviousRenderedFieldValue);

      if (inputRendered is Element) {
        if (_inputsClasses.isNotEmpty) {
          inputRendered.classes.addAll(_inputsClasses);
        }

        celInput.children.add(inputRendered);
      } else if (inputRendered is UIComponent) {
        if (_inputsClasses.isNotEmpty) {
          inputRendered.content?.classes.addAll(_inputsClasses);
        }

        var div = createDiv();
        celInput.children.add(div);

        inputRendered.setParent(div);
        inputRendered.ensureRendered();

        if (inputRendered is UIColorPickerInput) {
          inputRendered.onFocus.listen((_) {
            onInputFocus.add(inputRendered);
          });
        }
      }

      if (showInvalidMessages) {
        var msg = DivElement()
          ..id = '__invalid_msg__${input.fieldName}'
          ..hidden = true;

        var invalidValueClass = this.invalidValueClass;
        if (invalidValueClass != null) {
          msg.classes.add(invalidValueClass);
        }

        celInput.children.add(msg);
      }
    }

    for (var r in _extraRows) {
      var row = _resolveRow(r);
      if (row == null) continue;

      if (row is TableRowElement) {
        _addTableRow(table, row);
      } else if (row is List<TableRowElement>) {
        for (var r in row) {
          _addTableRow(table, r);
        }
      } else if (row is List<TableCellElement>) {
        var tr = table.addRow();

        for (var cell in row) {
          _addTableRowCell(tr, cell);
        }
      } else if (row is List<Element>) {
        var tr = table.addRow();

        for (var cell in row) {
          var td = tr.addCell();
          td.children.add(cell);
        }
      }
    }

    form.append(table);

    return form;
  }

  void _addTableRow(TableElement table, TableRowElement row) {
    var tr = table.addRow();

    tr.attributes.addAll(row.attributes);

    for (var cell in row.cells) {
      _addTableRowCell(tr, cell);
    }
  }

  void _addTableRowCell(TableRowElement tr, TableCellElement cell) {
    var td = tr.addCell();
    td.attributes.addAll(cell.attributes);

    var children = cell.children.toList();
    cell.children.clear();

    td.children.addAll(children);
  }

  Object? _resolveRow(Object? row) {
    if (row == null) return null;

    List<DOMNode?>? nodes;

    if (row is String) {
      row = row.trim();
      if (row.isEmpty) return null;
      nodes = $html(row);
    } else if (row is DOMNode) {
      nodes = <DOMNode>[row];
    } else if (row is List) {
      if (row.every((n) => n is DOMNode)) {
        nodes = row.whereType<DOMNode>().toList();
      } else if (row.every((n) => n is String)) {
        nodes = [$tr(cells: row)];
      } else if (row.every((n) => n is List)) {
        nodes = row.map((cells) => $tr(cells: cells)).toList();
      } else {
        nodes = row.map((cells) => $tr(cells: cells)).toList();
      }
    }

    if (nodes == null) return null;

    nodes = nodes.whereNotNull().toList();
    if (nodes.isEmpty) return null;

    TABLEElement? table;

    if (nodes.every((n) => n is TABLEElement)) {
      table = nodes.first as TABLEElement;
    } else if (nodes.every((n) => n is TRowElement)) {
      table = $table(body: nodes);
    } else if (nodes.every((n) => n is TDElement)) {
      table = $table(body: [$tr(cells: nodes)]);
    }

    if (table != null) {
      var dom =
          table.buildDOM(generator: UIComponent.domGenerator) as TableElement;
      var trs = dom.rows.toList();
      if (trs.isEmpty) return null;
      return trs.length == 1 ? trs.first : trs;
    }

    var div = $div(content: nodes);
    var dom = div.buildDOM(generator: UIComponent.domGenerator) as DivElement;
    return dom.children.toList();
  }

  /// Redirects [action] calls to an [UIComponent].
  UIComponent? actionListenerComponent;

  /// Function to call when an [action] is triggered.
  void Function(String)? actionListener;

  @override
  void action(String action) {
    if (actionListener != null) {
      actionListener!(action);
    }
    if (actionListenerComponent != null) {
      actionListenerComponent!.action(action);
    }
  }

  static Duration defaultOnChangeTriggerDelay = Duration(seconds: 2);

  Duration _onChangeTriggerDelay = defaultOnChangeTriggerDelay;

  Duration get onChangeTriggerDelay => _onChangeTriggerDelay;

  set onChangeTriggerDelay(Duration value) {
    if (value.inMilliseconds < 500) {
      value = Duration(milliseconds: 500);
    }
    _onChangeTriggerDelay = value;
  }

  EventStream<dynamic> onInputFocus = EventStream();

  @override
  void posRender() {
    var fields = getFieldsElementsMap();

    if (fields.isNotEmpty) {
      for (var entry in fields.entries) {
        var fieldName = entry.key;
        var elem = entry.value;

        var interactionCompleter = InteractionCompleter('field:$fieldName',
            triggerDelay: _onChangeTriggerDelay);

        elem.onFocus.listen((event) {
          var element = event.target;
          if (element is Element) {
            onInputFocus.add(element);
          }
        });

        elem.onChange.listen((e) {
          interactionCompleter.cancel();
          updateRenderedFieldElementValue(elem);
          onChange.add(elem);
        });

        elem.onKeyUp.listen((event) {
          interactionCompleter.interact();
        });

        interactionCompleter.onComplete.listen((e) {
          updateRenderedFieldElementValue(elem);
          onChange.add(elem);
        });
      }
    }
  }
}

bool _isEmptyValue(String? value) => value == null || value.isEmpty;
