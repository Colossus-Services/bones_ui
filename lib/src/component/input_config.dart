import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'capture.dart';

typedef FieldValueProvider = dynamic Function(String field);

/// Configuration for an input.
class InputConfig {
  static List<InputConfig> listFromMap(Map map) {
    return map
        .map((k, v) => MapEntry(k, InputConfig.from(v, '$k')))
        .values
        .toList();
  }

  String _id;

  String _label;

  String _type;

  String _value;

  Map<String, String> _attributes;

  Map<String, String> _options;

  bool _optional;

  factory InputConfig.from(dynamic config, [String id]) {
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
      var options = findKeyValue(config, ['options'], true);
      var optional = parseBool(findKeyValue(config, ['optional'], true), false);

      if (attributes is Map) {
        attributes = asMapOfString(attributes);
      }

      if (options is Map) {
        options = asMapOfString(options);
      }

      return InputConfig(
        id,
        label,
        type: type,
        value: value,
        attributes: attributes,
        options: options,
        optional: optional,
      );
    }

    return null;
  }

  InputConfig(String id, String label,
      {String type = 'text',
      String value = '',
      Map<String, String> attributes,
      Map<String, String> options,
      bool optional = false}) {
    if (type == null || type.isEmpty) type = 'text';
    if (value == null || value.isEmpty) value = null;

    if (label == null || label.isEmpty) {
      if (value != null) {
        label = value;
      } else {
        label = type;
      }
    }

    id ??= label;

    if (id == null || id.isEmpty) throw ArgumentError('Invalid ID');
    if (label == null || label.isEmpty) throw ArgumentError('Invalid Label');

    _id = id;
    _label = label;
    _type = type;
    _value = value;

    _attributes = attributes;
    _options = options;

    _optional = optional;
  }

  String get id => _id;

  String get fieldName => _id;

  String get label => _label;

  String get type => _type;

  String get value => _value;

  set value(String value) => _value = value;

  Map<String, String> get attributes => _attributes;

  Map<String, String> get options => _options;

  bool get optional => _optional;

  bool get required => !_optional;

  dynamic renderInput([FieldValueProvider fieldValueProvider]) {
    var inputID = id;
    var inputType = type;
    var inputValue = fieldValueProvider != null
        ? (fieldValueProvider(fieldName) ?? value)
        : value;

    Element inputElement;
    UIComponent inputComponent;

    if (inputType == 'textarea') {
      inputElement = _render_textArea(inputValue);
    } else if (inputType == 'select') {
      inputElement = _render_select(inputValue);
    } else if (inputType == 'image') {
      var capture = UIButtonCapturePhoto(null, label, fieldName: inputID);
      inputComponent = capture;
    } else {
      inputElement = _render_generic_input(inputType, inputValue);
    }

    if (inputElement != null) {
      inputElement.classes.add('form-control');

      inputElement.setAttribute('name', inputID);
      inputElement.setAttribute('field', inputID);

      if (attributes != null && attributes.isNotEmpty) {
        for (var attrKey in attributes.keys) {
          var attrVal = attributes[attrKey];
          if (attrKey.isNotEmpty && attrVal.isNotEmpty) {
            inputElement.setAttribute(attrKey, attrVal);
          }
        }
      }

      return inputElement;
    } else if (inputComponent != null) {
      return inputComponent;
    }

    return null;
  }

  TextAreaElement _render_textArea(inputValue) {
    var textArea = TextAreaElement();
    textArea.value = inputValue;
    return textArea;
  }

  Element _render_generic_input(String inputType, inputValue) {
    var inputHtml = '''
      <input type="$inputType" ${inputValue != null ? 'value="$inputValue"' : ''}>
    ''';

    var input = createHTML(inputHtml);
    return input;
  }

  SelectElement _render_select(inputValue) {
    var select = SelectElement();

    if (options != null && options.isNotEmpty) {
      for (var optKey in options.keys) {
        var optVal = options[optKey];
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
}

/// Component that renders a table with inputs.
class UIInputTable extends UIComponent {
  final List<InputConfig> _inputs;

  UIInputTable(Element parent, this._inputs,
      {String inputErrorClass, dynamic classes})
      : _inputErrorClass = inputErrorClass,
        super(parent, classes: 'ui-infos-table', classes2: classes);

  String _inputErrorClass;

  String get inputErrorClass => _inputErrorClass;

  set inputErrorClass(String value) => _inputErrorClass = value;

  bool canHighlightInputs() =>
      _inputErrorClass == null || _inputErrorClass.isEmpty;

  int highlightEmptyInputs() {
    if (canHighlightInputs()) return -1;

    unhighlightErrorInputs();
    return forEachEmptyFieldElement(
        (fieldElement) => fieldElement.classes.add('ui-input-error'));
  }

  int unhighlightErrorInputs() {
    if (canHighlightInputs()) return -1;

    return forEachFieldElement(
        (fieldElement) => fieldElement.classes.remove('ui-input-error'));
  }

  bool highlightField(String fieldName) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.add(_inputErrorClass);
    return true;
  }

  bool unhighlightField(String fieldName) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.remove(_inputErrorClass);
    return true;
  }

  bool checkFields() {
    var ok = true;

    unhighlightErrorInputs();

    for (var i in _inputs) {
      if (i.required && isEmptyField(i.fieldName)) {
        highlightField(i.fieldName);
        ok = false;
      }
    }

    return ok;
  }

  @override
  dynamic render() {
    var table = TableElement();
    var tBody = table.createTBody();

    for (var input in _inputs) {
      var row = tBody.addRow();

      row.addCell()
        ..style.verticalAlign = 'middle'
        ..style.textAlign = 'right'
        ..innerHtml = '<label><b>${input.label}:&nbsp;</b></label>';

      var celInput = row.addCell()..style.textAlign = 'center';

      var inputRendered = input.renderInput(getPreviousRenderedFieldValue);

      if (inputRendered is Element) {
        celInput.children.add(inputRendered);
      } else if (inputRendered is UIComponent) {
        var div = createDiv();
        celInput.children.add(div);

        inputRendered.setParent(div);
        inputRendered.render();
      }
    }

    return table;
  }

  @override
  void posRender() {
    var fields = getFieldsElementsMap();

    if (fields != null && fields.isNotEmpty) {
      for (var entry in fields.entries) {
        //var fieldName = entry.key ;
        var elem = entry.value;

        elem.onChange.listen((e) {
          //updateRenderedFieldValue(fieldName) ;
          updateRenderedFieldElementValue(elem);
          onChange.add(elem);
        });
      }
    }
  }
}
