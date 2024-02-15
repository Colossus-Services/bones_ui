import 'dart:html';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';
import '../bones_ui_web.dart';

/// A component that renders a multi-selection input.
class UIMultiSelection extends UIComponent implements UIField<List<String?>> {
  static final UIComponentGenerator<UIMultiSelection> generator =
      UIComponentGenerator<UIMultiSelection>('ui-multi-selection', 'div',
          'ui-multi-selection', 'display: inline-block',
          (parent, attributes, contentHolder, contentNodes) {
    var jsonConfig = parseJSON(contentHolder?.text, {});
    if (jsonConfig is! Map) jsonConfig = {};
    return UIMultiSelection(parent, jsonConfig['options']);
  }, [
    UIComponentAttributeHandler<UIMultiSelection, dynamic>('options',
        parser: parseJSON,
        getter: (c) => c._options,
        setter: (c, v) => c._options = v is Map
            ? v
            : (parseFromInlineMap(parseString(v), RegExp(r'\s*[,;]\s*'),
                    RegExp(r'\s*[:=]\s*')) ??
                {}),
        cleaner: (c) => c._options = null),
    UIComponentAttributeHandler<UIMultiSelection, dynamic>('multi-selection',
        parser: parseBool,
        getter: (c) => c.multiSelection,
        setter: (c, v) => c.multiSelection = v as bool?,
        cleaner: (c) => c.multiSelection = null)
  ], hasChildrenElements: false, contentAsText: false);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  @override
  final String fieldName;

  Map? _options;

  bool? multiSelection;

  final List _initialSelections;

  final bool allowInputValue;

  final int optionsPanelMargin;

  final String separator;

  final bool autoInputFontShrink;

  late InteractionCompleter _optionsPanelInteractionCompleter;

  late InteractionCompleter _inputInteractionCompleter;

  final EventStream<UIMultiSelection> onSelect = EventStream();

  UIMultiSelection(super.parent, Map? options,
      {this.fieldName = 'multi-selection',
      this.multiSelection = true,
      List? selections,
      this.allowInputValue = false,
      this.optionsPanelMargin = 20,
      this.separator = ' ; ',
      this.autoInputFontShrink = true,
      Duration? selectionMaxDelay,
      super.classes,
      super.style})
      : _options = options ?? {},
        _initialSelections = selections ?? [],
        super(
            componentClass: 'ui-multi-selection',
            renderOnConstruction: false,
            generator: generator) {
    _optionsPanelInteractionCompleter = InteractionCompleter('optionsPanel',
        triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
        functionToTrigger: _notifySelection);

    if (allowInputValue) {
      _inputInteractionCompleter = InteractionCompleter('input',
          triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
          functionToTrigger: _notifyInput);
    } else {
      _inputInteractionCompleter = InteractionCompleterDummy();
    }

    callRender();
  }

  Duration get selectionMaxDelay =>
      _optionsPanelInteractionCompleter.triggerDelay;

  Map get options => Map.from(_options!);

  set options(Map value) {
    _options = value;
    requestRefresh();
  }

  @override
  bool setData(data) {
    return _setDataOptions(data);
  }

  bool _setDataOptions(data) {
    var options = _parseDataOptions(data);

    if (isEqualsDeep(_options, options)) {
      return false;
    }

    _options = options;

    return true;
  }

  Map _parseDataOptions(data) {
    if (isEmptyObject(data)) {
      return {};
    } else if (data is Map) {
      return data;
    } else if (data is List) {
      if (data.length == 1 && data[0] is Map) {
        return data[0];
      } else {
        return Map.fromEntries(data.map((e) {
          return parseMapEntryOfStrings(e, RegExp(r'\s*[:=]\s*'))!;
        }));
      }
    } else {
      return {};
    }
  }

  void addOption(dynamic key, dynamic value) => _options![key] = value;

  dynamic getOption(dynamic key) => _options![key];

  bool containsOption(dynamic key) => _options!.containsKey(key);

  dynamic removeOption(dynamic key) => _options!.remove(key);

  @override
  List<String?> getFieldValue() {
    if (allowInputValue && !hasSelection) {
      var value = inputValue;
      if (isNotEmptyObject(value)) {
        return [inputValue];
      } else {
        return [];
      }
    }
    return selectedIDs;
  }

  @override
  void setFieldValue(List<String?>? value) {
    if (value == null) {
      _uncheckAllImpl(false);
    } else {
      setCheckedElements(value);
    }
  }

  InputElement? _input;
  DivElement? _optionsPanel;

  List<InputElementBase> _checkElements = [];

  bool? isCheckedByID(dynamic id) {
    if (id == null) return null;
    var checkElem = _getCheckElement('$id');
    return _isChecked(checkElem);
  }

  bool? isCheckedByLabel(dynamic label) {
    var id = getLabelID(label);
    return isCheckedByID(id);
  }

  void _notifyInput() {
    if (!allowInputValue) return;

    if (hasInputValue) {
      onChange.add(this);
    }
  }

  void _notifySelection() {
    onSelect.add(this);

    onChange.add(this);
  }

  void checkByID(dynamic id, bool check) {
    _checkByIDImpl(id, check, false, true);
  }

  void _checkByIDImpl(
      dynamic id, bool? check, bool fromCheckElement, bool notify) {
    if (id == null) return;

    if (!fromCheckElement) {
      _setCheck(_getCheckElement('$id'), check);
    }

    if (notify) {
      _optionsPanelInteractionCompleter.interact();
    }
  }

  bool get isAllChecked {
    if (_checkElements.isEmpty) return false;
    var firstNotChecked =
        _checkElements.firstWhereOrNull((e) => !_isChecked(e)!);
    return firstNotChecked == null;
  }

  bool get isAllUnchecked {
    if (_checkElements.isEmpty) return true;
    var firstChecked = _checkElements.firstWhereOrNull((e) => _isChecked(e)!);
    return firstChecked == null;
  }

  void checkAll() {
    _checkAllImpl(true);
  }

  void _checkAllImpl(bool notify) {
    _checkAllElements(true);
    _updateElementText();

    if (notify) {
      _optionsPanelInteractionCompleter.interact();
    }
  }

  void uncheckAll() {
    _uncheckAllImpl(true);
  }

  void _uncheckAllImpl(bool notify) {
    if (_getSelectedElements().isEmpty) return;

    _checkAllElements(false);
    _updateElementText();

    if (notify) {
      _optionsPanelInteractionCompleter.interact();
    }
  }

  void setCheckedElements(List ids) {
    _uncheckAllImpl(false);
    checkAllByID(ids, true);
  }

  void checkAllByID(List ids, bool check) {
    if (ids.isEmpty) return;

    for (var id in ids) {
      _checkByIDImpl(id, check, false, false);
    }

    _updateElementText();
    _optionsPanelInteractionCompleter.interact();
  }

  void checkByLabel(dynamic label, bool check) {
    checkByID(getLabelID(label), check);
  }

  dynamic getIDLabel(dynamic id) {
    return _options![id];
  }

  dynamic getLabelID(dynamic label) {
    var entry = _options!.entries.firstWhereOrNull((e) => e.value == label);
    return entry?.key;
  }

  List<MapEntry> getOptionsEntriesFiltered(dynamic pattern) {
    if (pattern == null) return _options!.entries.toList();

    if (pattern is String) {
      var patternStr = pattern;
      patternStr = patternStr.trim().toLowerCase();
      if (patternStr.isEmpty || patternStr == '*') {
        return _options!.entries.toList();
      }
      return _options!.entries
          .where((e) => '${e.value}'.toLowerCase().contains(patternStr))
          .toList();
    } else if (pattern is RegExp) {
      var patternRegExp = pattern;
      return _options!.entries
          .where((e) => patternRegExp.hasMatch('${e.value}'))
          .toList();
    } else {
      return [];
    }
  }

  List<InputElementBase> _getSelectedElements() {
    return _checkElements.where((e) => _isChecked(e) ?? false).toList();
  }

  List<InputElementBase> _getUnSelectedElements() {
    return _checkElements.where((e) => !(_isChecked(e) ?? false)).toList();
  }

  InputElementBase? _getCheckElement(String id) {
    return _checkElements.firstWhereOrNull((e) => e.value == id);
  }

  void _checkAllElements(bool check) {
    for (var e in _checkElements) {
      _setCheck(e, check);
    }
  }

  String? get inputValue => _input?.value;

  bool get hasInputValue => isNotEmptyObject(inputValue);

  bool get hasSelection {
    return _getSelectedElements().isNotEmpty;
  }

  String? get firstSelectedID {
    var ids = selectedIDs;
    return ids.isNotEmpty ? ids[0] : null;
  }

  List<String?> get selectedIDs {
    return _getSelectedElements().map((e) => e.value).toList();
  }

  List<String?> get selectedLabels {
    return _getSelectedElements()
        .map((e) => htmlToText(e.getAttribute('opt_label')!))
        .toList();
  }

  List<String?> get unselectedIDs {
    return _getUnSelectedElements().map((e) => e.value).toList();
  }

  List<String?> get unselectedLabels {
    return _getUnSelectedElements()
        .map((e) => e.getAttribute('opt_label'))
        .toList();
  }

  void _updateElementText() {
    var input = _input;
    if (input == null) return;

    input.style.fontSize = '';

    if (isAllChecked) {
      input.value = '*';
    } else {
      var labels = selectedLabels;

      if (isNotEmptyObject(labels) || !allowInputValue) {
        var sep = separator;
        var text = selectedLabels.join(sep);
        input.value = text;

        _autoAdjustInputFont(input, text);
      }
    }
  }

  void _autoAdjustInputFont(InputElement input, String text) {
    if (!autoInputFontShrink) return;

    input.style.fontSize = '';

    var inputWidth = input.offsetWidth;
    if (inputWidth <= 0) return;

    var inputComputedStyle = input.getComputedStyle();

    var paddingLeft =
        CSSLength.parse(inputComputedStyle.paddingLeft)?.value ?? 0;
    var paddingRight =
        CSSLength.parse(inputComputedStyle.paddingRight)?.value ?? 0;

    inputWidth -= (paddingLeft + paddingRight).toInt();

    var textDim = measureText(text,
        fontFamily: inputComputedStyle.fontFamily,
        fontSize: inputComputedStyle.fontSize,
        bold: inputComputedStyle.fontStyle == 'bold');

    var textWidth = textDim?.width ?? text.length * 16;

    if (textWidth > inputWidth) {
      var fontSize = '80%';

      for (var r = 0.95; r >= 0.60; r -= 0.05) {
        var w = textWidth * r;
        fontSize = "${(r * 100).toInt()}%";
        if (w < inputWidth) break;
      }

      input.style.fontSize = fontSize;
    }
  }

  @override
  dynamic render() {
    if (_input == null) {
      var input = _input = InputElement()
        ..classes.add('ui-multi-selection-input')
        ..type = 'text';

      input
        ..style.padding = '5px 10px'
        ..style.border = '1px solid #ccc'
        ..style.width = '100%'
        ..style.color = 'inherit';

      //style="cursor: pointer; padding: 5px 10px; border: 1px solid #ccc; width: 100%"

      _optionsPanel = DivElement()
        ..style.display = 'none'
        ..style.backgroundColor = 'rgba(255,255,255, 0.90)'
        ..style.position = 'absolute'
        ..style.left = '0px'
        ..style.top = '0px'
        ..style.textAlign = 'left'
        ..style.padding = '4px';

      _optionsPanel!.classes.add('shadow');
      _optionsPanel!.classes.add('p-2');
      _optionsPanel!.classes.add('ui-multi-selection-options-menu');

      window.onResize.listen((e) => _updateDivOptionsPosition());

      _input!.onKeyUp.listen((e) {
        if (allowInputValue) {
          if (hasSelection) {
            uncheckAll();
          }
          _optionsPanelInteractionCompleter.interact(noTriggering: true);
          _inputInteractionCompleter.interact();
        }

        _updateOptionsPanel();

        _toggleDivOptions(false);
      });

      _input!.onClick.listen((e) {
        if (hasSelection || !allowInputValue) {
          _input!.value = '';
        }
        _toggleDivOptions(false);
      });

      _input!.onMouseEnter.listen((e) => _mouseEnter(_input));
      _input!.onMouseLeave.listen((e) => _mouseLeave(_input));

      _optionsPanel!.onMouseEnter.listen((e) => _mouseEnter(_optionsPanel));
      _optionsPanel!.onMouseLeave.listen((e) => _mouseLeave(_optionsPanel));

      _optionsPanel!.onMouseMove.listen((e) => _onOptionsPanelMouseMove(e));

      _optionsPanel!.onTouchEnter.listen((e) => _mouseEnter(_input));
      _optionsPanel!.onTouchLeave.listen((e) => _mouseLeave(_input));

      window.onTouchStart.listen((e) {
        if (_optionsPanel == null) return;

        var overDivOptions = nodeTreeContainsAny(
            _optionsPanel!, e.targetTouches!.map((t) => t.target as UINode));
        if (!overDivOptions && _isShowing()) {
          _toggleDivOptions(true);
        }
      });
    }

    _optionsPanel!.style.maxHeight = '60vh';
    _optionsPanel!.style.overflowY = 'auto';

    var checksList = _renderPanelOptions();
    _checkElements = checksList;

    _updateElementText();

    return [_input, _optionsPanel];
  }

  @override
  void posRender() {
    // For adjustment after attach element to DOM (after input have dimensions):
    if (autoInputFontShrink) {
      Future.delayed(Duration(milliseconds: 50), () => _updateElementText());
    }
  }

  bool _overElement = false;

  bool _overDivOptions = false;

  void _mouseEnter(Element? elem) {
    if (elem == _input) {
      _overElement = true;
    } else {
      _overDivOptions = true;
    }

    _updateDivOptionsView();
  }

  void _mouseLeave(Element? elem) {
    if (elem == _input) {
      _overElement = false;
      // Give some delay (allow mouse enter on panel before leave input).
      _updateDivOptionsViewAsync();
    } else {
      _overDivOptions = false;
      _updateDivOptionsView();
    }
  }

  void _updateDivOptionsViewAsync() {
    Future.delayed(Duration(milliseconds: 30), () => _updateDivOptionsView());
  }

  void _updateDivOptionsView() {
    if (_overElement || _overDivOptions) {
      _toggleDivOptions(false);
    } else {
      _toggleDivOptions(true);
    }
  }

  Rectangle<num> _appendScrollCoords(Rectangle<num> rect) {
    return Rectangle(window.scrollX + rect.left, window.scrollY + rect.top,
        rect.width, rect.height);
  }

  void _updateDivOptionsPosition() {
    var inputVPRect = _input!.getBoundingClientRect();
    var inputRect = _appendScrollCoords(inputVPRect);

    var inputW = inputRect.width;
    var inputHeight = inputRect.height;

    //var inputVPX = inputVPRect.left;
    var inputVPY = inputVPRect.top;
    var inputX = inputRect.left;
    var inputY = inputRect.top;

    var x = inputX;
    var y = inputY + inputHeight;

    var freeViewportHeightUpward = inputVPY - 10;
    var freeViewportHeightBelow = (window.innerHeight! - inputVPY) - 10;

    _optionsPanel!
      ..style.position = 'absolute'
      ..style.left = '${x}px'
      ..style.top = '${y}px'
      ..style.width = '${inputW}px'
      ..style.zIndex = '999999999'
      ..style.transform = ''
      ..style.maxHeight = '${freeViewportHeightBelow}px';

    if (freeViewportHeightBelow < 130 && freeViewportHeightUpward > 130) {
      _optionsPanel!
        ..style.top = '${inputY}px'
        ..style.transform = 'translate(0% , -100%)'
        ..style.maxHeight = '${freeViewportHeightUpward}px';
    }
  }

  dynamic _toggleDivOptions([bool? requestedHide]) {
    _updateDivOptionsPosition();

    bool hide;
    if (requestedHide != null) {
      hide = requestedHide;
    } else {
      var showing = _isShowing();
      hide = showing;
    }

    if (hide) {
      _optionsPanel!.style.display = 'none';
      _updateElementText();
      _optionsPanelInteractionCompleter.triggerIfHasInteraction();
    } else {
      _optionsPanel!.style.display = '';
    }
  }

  bool _isShowing() =>
      _optionsPanel!.style.display == '' || _optionsPanel!.style.display == '';

  bool? _setCheck(InputElementBase? elem, bool? check) {
    if (elem is CheckboxInputElement) {
      return elem.checked = check;
    } else if (elem is RadioButtonInputElement) {
      return elem.checked = check;
    } else {
      return null;
    }
  }

  bool? _isChecked(InputElementBase? elem) {
    if (elem is CheckboxInputElement) {
      return elem.checked;
    } else if (elem is RadioButtonInputElement) {
      return elem.checked;
    } else {
      return null;
    }
  }

  dynamic _updateOptionsPanel() {
    var checksList = _renderPanelOptions();
    _checkElements = checksList;
  }

  String _optionsSignature(List<MapEntry<dynamic, dynamic>> entries,
      List<MapEntry<dynamic, dynamic>> entriesFiltered) {
    var str = StringBuffer();

    str.write('$multiSelection\n');

    for (var entry in entries) {
      str.write('${entry.key}=');
      str.write('${entry.value}&');
    }

    for (var entry in entriesFiltered) {
      str.write('${entry.key}=');
      str.write('${entry.value}&');
    }

    return str.toString();
  }

  List<List<MapEntry<dynamic, dynamic>>> _optionsEntriesOrder() {
    var entries = _options!.entries.toList();

    var entriesFiltered = <MapEntry<dynamic, dynamic>>[];

    var inputValue = _input!.value!;

    if (inputValue.isNotEmpty) {
      entriesFiltered = getOptionsEntriesFiltered(inputValue);

      if (entriesFiltered.isEmpty && inputValue.length > 1) {
        var elementValue2 = inputValue.substring(0, inputValue.length - 1);
        entriesFiltered = getOptionsEntriesFiltered(elementValue2);
      }

      for (var e1 in entriesFiltered) {
        entries.removeWhere((e2) => e2.key == e1.key);
      }
    }

    return [entries, entriesFiltered];
  }

  String? _renderedPanelOptionsSignature;

  List<InputElementBase> _renderPanelOptions() {
    var entriesOrder = _optionsEntriesOrder();

    var entries = entriesOrder[0];
    var entriesFiltered = entriesOrder[1];

    var optionsSignature = _optionsSignature(entries, entriesFiltered);

    if (_renderedPanelOptionsSignature == optionsSignature) {
      return _checkElements;
    }

    _renderedPanelOptionsSignature = optionsSignature;

    _optionsPanel!.children.clear();

    if (_options!.isEmpty) {
      _optionsPanel!.append(createHTML('''
          <div style="text-align: center; width: 100%">
            <i>${IntlBasicDictionary.msg('no_options')}</i>
          </div>
          '''));
      return [];
    }

    var checksList = <InputElementBase>[];

    var table = TableElement()..style.borderCollapse = 'collapse';
    var tbody = table.createTBody();

    _optionsPanel!.children.add(table);

    if (entriesFiltered.isNotEmpty) {
      for (var optEntry in entriesFiltered) {
        _renderOptionsPanelEntry(tbody, checksList, optEntry, true);
      }

      if (entries.isNotEmpty) {
        var tr = tbody.addRow();
        var td = tr.addCell()..colSpan = 2;
        td.append(HRElement());
      }
    }

    for (var optEntry in entries) {
      _renderOptionsPanelEntry(tbody, checksList, optEntry, false);
    }

    if (isNotEmptyObject(inputValue)) {
      _optionsPanel!.scrollTop = 0;
    } else {
      var firstCheckedElement =
          checksList.firstWhereOrNull((e) => _isChecked(e)!);

      if (firstCheckedElement != null) {
        _scrollToElement(_optionsPanel, firstCheckedElement);
      }
    }

    return checksList;
  }

  void _scrollToElement(Element? parent, Element element) {
    element.scrollIntoView(ScrollAlignment.CENTER);
  }

  void _renderOptionsPanelEntry(TableSectionElement tbody,
      List<InputElementBase> checksList, MapEntry optEntry, bool filtered) {
    var optKey = '${optEntry.key}';
    var optValue = '${optEntry.value}';

    var check = isCheckedByID(optKey) ??
        (_initialSelections.contains(optKey) ||
            _initialSelections.contains(optEntry.key));

    InputElementBase checkElem;

    if (multiSelection!) {
      var input = CheckboxInputElement();
      input.checked = check;
      checkElem = input;
    } else {
      var input = RadioButtonInputElement()..name = '__MultiSelection__';
      input.checked = check;
      checkElem = input;
    }

    checkElem.value = optKey;
    checkElem.setAttribute('opt_label', optValue);

    var row = tbody.addRow();

    var cell1 = row.addCell()
      ..style.padding = '2px 6px 2px 2px'
      ..style.verticalAlign = 'top';

    cell1.children.add(checkElem);

    checksList.add(checkElem);

    var label = LabelElement();
    setElementInnerHTML(label, optValue);

    checkElem.onClick.listen((e) {
      _updateElementText();
      _checkByIDImpl(optKey, _isChecked(checkElem), true, true);
    });

    label.onClick.listen((e) {
      checkElem.click();
      _updateElementText();
      _checkByIDImpl(optKey, _isChecked(checkElem), true, true);
    });

    var cell2 = row.addCell()..style.textAlign = 'left';

    cell2.children.add(SpanElement()..innerHtml = '&nbsp;');
    cell2.children.add(label);
  }

  void _onOptionsPanelMouseMove(MouseEvent e) {
    _optionsPanelInteractionCompleter.interact(noTriggering: true);
    _inputInteractionCompleter.interact(noTriggering: true);
  }
}
