import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'capture.dart';

typedef FieldValueProvider = dynamic Function(String? field);

/// Configuration for an input.
class InputConfig {
  static List<InputConfig> listFromMap(Map map) {
    return map.entries
        .map((e) => InputConfig.from(e.value, '${e.key}'))
        .whereType<InputConfig>()
        .toList();
  }

  String? _id;

  String? _label;

  String? _type;

  String? value;

  String? _placeholder;

  Map<String, String>? _attributes;

  List<String> classes = ['form-control'];

  String? style;

  Map<String, String>? _options;

  bool? _optional;

  FieldValueProvider? _valueProvider;

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
      this.value = '',
      String? placeholder = '',
      Map<String, String>? attributes,
      Map<String, String>? options,
      bool? optional = false,
      List<String>? classes,
      String? style,
      FieldValueProvider? valueProvider}) {
    if (type == null || type.isEmpty) type = 'text';
    if (value == null || value!.isEmpty) value = null;
    if (placeholder == null || placeholder.isEmpty) placeholder = null;

    if (label == null || label.isEmpty) {
      if (value != null) {
        label = value!;
      } else {
        label = type;
      }
    }

    if (id.isEmpty) throw ArgumentError('Invalid ID');
    if (label.isEmpty) throw ArgumentError('Invalid Label');

    _id = id;
    _label = label;
    _type = type;

    _placeholder = placeholder;

    _attributes = attributes;
    _options = options;

    _optional = optional;
    _valueProvider = valueProvider;

    if (classes != null) {
      classes.removeWhere((e) => e.isEmpty);
      this.classes = classes;
    }

    if (style != null) {
      style = style.trim();
      this.style = style.isNotEmpty ? style : null;
    }
  }

  String? get id => _id;

  String? get fieldName => _id;

  String? get label => _label;

  String? get type => _type;

  String? get placeholder => _placeholder;

  Map<String, String>? get attributes => _attributes;

  Map<String, String>? get options => _options;

  bool? get optional => _optional;

  bool get required => !_optional!;

  FieldValueProvider? get valueProvider => _valueProvider;

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
          fieldName: inputID!,
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
      _configureInputElement(inputElement, inputID!);
      _configureElementAttribute(inputElement);
      return inputElement;
    } else if (element != null) {
      var input = element.querySelector('input')!;
      _configureElementStyle(element);
      _configureInputElement(input, inputID!);
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

  DivElement? _renderInputPath(String? fieldName, String? inputValue) {
    var input = $input(style: 'width: auto', value: inputValue);
    DOMElement? button;

    if (_valueProvider != null) {
      button = $button(
          classes: 'btn-sm btn-secondary',
          style: 'font-size: 80%',
          content: 'File')
        ..onClick.listen((_) async {
          if (_valueProvider != null) {
            var ret = _valueProvider!(fieldName) ?? '';
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
          }
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

  UIInputTable(Element? parent, this._inputs,
      {this.actionListenerComponent,
      this.actionListener,
      this.inputErrorClass,
      bool? showLabels,
      dynamic classes,
      dynamic style})
      : showLabels = showLabels ?? true,
        super(parent,
            componentClass: 'ui-infos-table', classes: classes, style: style);

  String? inputErrorClass;

  bool canHighlightInputs() =>
      inputErrorClass == null || inputErrorClass!.isEmpty;

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

  bool highlightField(String? fieldName) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.add(inputErrorClass!);
    return true;
  }

  bool unhighlightField(String fieldName) {
    if (canHighlightInputs()) return false;

    var fieldElement = getFieldElement(fieldName);
    if (fieldElement == null) return false;

    fieldElement.classes.remove(inputErrorClass);
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
    var form = FormElement();

    form.autocomplete = 'off';

    var table = TableElement();
    var tBody = table.createTBody();

    for (var input in _inputs) {
      var row = tBody.addRow();

      if (showLabels) {
        row.addCell()
          ..style.verticalAlign = 'top'
          ..style.textAlign = 'right'
          ..innerHtml =
              '<label for="${input.id}"><b>${input.label}:&nbsp;</b></label>';
      }

      var celInput = row.addCell()..style.textAlign = 'left';

      var inputRendered = input.renderInput(getPreviousRenderedFieldValue);

      if (inputRendered is Element) {
        celInput.children.add(inputRendered);
      } else if (inputRendered is UIComponent) {
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
    }

    form.append(table);

    return form;
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
