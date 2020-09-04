import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// A component that renders a multi-selection input.
class UIMultiSelection extends UIComponent implements UIField<List<String>> {
  static final UIComponentGenerator<UIMultiSelection> GENERATOR =
      UIComponentGenerator<UIMultiSelection>('ui-multi-selection', 'div',
          'ui-multi-selection', 'display: inline-block',
          (parent, attributes, contentHolder, contentNodes) {
    var jsonConfig = parseJSON(contentHolder.text, {});
    return UIMultiSelection(parent, jsonConfig['options']);
  }, [
    UIComponentAttributeHandler<UIMultiSelection, dynamic>('options',
        parser: parseJSON,
        getter: (c) => c._options,
        setter: (c, v) => c._options = v ?? '',
        cleaner: (c) => c._options = null)
  ], hasChildrenElements: false, contentAsText: false);

  static void register() {
    UIComponent.registerGenerator(GENERATOR);
  }

  Map _options;

  final bool _multiSelection;
  final bool _allowInputValue;

  final int optionsPanelMargin;

  final String separator;

  InteractionCompleter _optionsPanelInteractionCompleter;

  InteractionCompleter _inputInteractionCompleter;

  final EventStream<UIMultiSelection> onSelect = EventStream();

  UIMultiSelection(Element parent, Map options,
      {bool multiSelection = true,
      bool allowInputValue,
      this.optionsPanelMargin = 20,
      this.separator = ' ; ',
      Duration selectionMaxDelay,
      dynamic classes,
      dynamic style})
      : _options = options ?? {},
        _multiSelection = multiSelection ?? true,
        _allowInputValue = allowInputValue ?? false,
        super(parent,
            componentClass: 'ui-multi-selection',
            classes: classes,
            style: style,
            renderOnConstruction: true) {
    _optionsPanelInteractionCompleter = InteractionCompleter('optionsPanel',
        triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
        functionToTrigger: _notifySelection);

    if (_allowInputValue) {
      _inputInteractionCompleter = InteractionCompleter('input',
          triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
          functionToTrigger: _notifyInput);
    } else {
      _inputInteractionCompleter = InteractionCompleterDummy();
    }
  }

  Duration get selectionMaxDelay =>
      _optionsPanelInteractionCompleter.triggerDelay;

  Map get options => Map.from(_options);

  set options(Map value) {
    _options = value ?? {};
    refresh();
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
          return parseMapEntry(e, RegExp(r'\s*[:=]\s*'));
        }));
      }
    } else {
      return {};
    }
  }

  void addOption(dynamic key, dynamic value) => _options[key] = value;

  dynamic getOption(dynamic key) => _options[key];

  bool containsOption(dynamic key) => _options.containsKey(key);

  dynamic removeOption(dynamic key) => _options.remove(key);

  bool get isMultiSelection => _multiSelection;

  bool get allowInputValue => _allowInputValue;

  @override
  List<String> getFieldValue() {
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

  InputElement _input;
  DivElement _optionsPanel;

  List<InputElementBase> _checkElements = [];

  bool isCheckedByID(dynamic id) {
    if (id == null) return null;
    var checkElem = _getCheckElement('$id');
    return _isChecked(checkElem);
  }

  bool isCheckedByLabel(dynamic label) {
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
      dynamic id, bool check, bool fromCheckElement, bool notify) {
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
        _checkElements.firstWhere((e) => !_isChecked(e), orElse: () => null);
    return firstNotChecked == null;
  }

  bool get isAllUnchecked {
    if (_checkElements.isEmpty) return true;
    var firstChecked =
        _checkElements.firstWhere((e) => _isChecked(e), orElse: () => null);
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
    if (ids == null || ids.isEmpty) return;

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
    return _options[id];
  }

  dynamic getLabelID(dynamic label) {
    var entry = _options.entries
        .firstWhere((e) => e.value == label, orElse: () => null);
    return entry != null ? entry.key : null;
  }

  List<MapEntry> getOptionsEntriesFiltered(dynamic pattern) {
    if (pattern == null) return _options.entries.toList();

    if (pattern is String) {
      var patternStr = pattern;
      patternStr = patternStr.trim().toLowerCase();
      if (patternStr.isEmpty || patternStr == '*') {
        return _options.entries.toList();
      }
      return _options.entries
          .where((e) => '${e.value}'.toLowerCase().contains(patternStr))
          .toList();
    } else if (pattern is RegExp) {
      var patternRegExp = pattern;
      return _options.entries
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

  InputElementBase _getCheckElement(String id) {
    return _checkElements.firstWhere((e) => e.value == id, orElse: () => null);
  }

  void _checkAllElements(bool check) {
    _checkElements.forEach((e) => _setCheck(e, check));
  }

  String get inputValue => _input?.value;

  bool get hasInputValue => isNotEmptyObject(inputValue);

  bool get hasSelection {
    return _getSelectedElements().isNotEmpty;
  }

  String get firstSelectedID {
    var ids = selectedIDs;
    return ids.isNotEmpty ? ids[0] : null;
  }

  List<String> get selectedIDs {
    return _getSelectedElements().map((e) => e.value).toList();
  }

  List<String> get selectedLabels {
    return _getSelectedElements()
        .map((e) => htmlToText(e.getAttribute('opt_label')))
        .toList();
  }

  List<String> get unselectedIDs {
    return _getUnSelectedElements().map((e) => e.value).toList();
  }

  List<String> get unselectedLabels {
    return _getUnSelectedElements()
        .map((e) => e.getAttribute('opt_label'))
        .toList();
  }

  void _updateElementText() {
    if (_input == null) return;

    if (isAllChecked) {
      _input.value = '*';
    } else {
      var labels = selectedLabels;

      if (isNotEmptyObject(labels) || !allowInputValue) {
        var sep = separator ?? ' ; ';
        _input.value = selectedLabels.join(sep);
      }
    }
  }

  @override
  dynamic render() {
    if (_input == null) {
      _input = InputElement()..type = 'text';

      _input.style.padding = '5px 10px';
      _input.style.border = '1px solid #ccc';
      _input.style.width = '100%';
      _input.style.backgroundColor = 'inherit';
      _input.style.color = 'inherit';

      //style="cursor: pointer; padding: 5px 10px; border: 1px solid #ccc; width: 100%"

      _optionsPanel = DivElement()
        ..style.display = 'none'
        ..style.backgroundColor = 'rgba(255,255,255, 0.90)'
        ..style.position = 'absolute'
        ..style.left = '0px'
        ..style.top = '0px'
        ..style.textAlign = 'left'
        ..style.padding = '4px';

      _optionsPanel.classes.add('shadow');
      _optionsPanel.classes.add('p-2');
      _optionsPanel.classes.add('ui-multiselection-options-menu');

      window.onResize.listen((e) => _updateDivOptionsPosition());

      _input.onKeyUp.listen((e) {
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

      _input.onClick.listen((e) {
        if (hasSelection || !allowInputValue) {
          _input.value = '';
        }
        _toggleDivOptions(false);
      });

      _input.onMouseEnter.listen((e) => _mouseEnter(_input));
      _input.onMouseLeave.listen((e) => _mouseLeave(_input));

      _optionsPanel.onMouseEnter.listen((e) => _mouseEnter(_optionsPanel));
      _optionsPanel.onMouseLeave.listen((e) => _mouseLeave(_optionsPanel));

      _optionsPanel.onMouseMove.listen((e) => _onOptionsPanelMouseMove(e));

      _optionsPanel.onTouchEnter.listen((e) => _mouseEnter(_input));
      _optionsPanel.onTouchLeave.listen((e) => _mouseLeave(_input));

      window.onTouchStart.listen((e) {
        if (_optionsPanel == null) return;

        var overDivOptions = nodeTreeContainsAny(
            _optionsPanel, e.targetTouches.map((t) => t.target));
        if (!overDivOptions && _isShowing()) {
          _toggleDivOptions(true);
        }
      });
    }

    _optionsPanel.style.maxHeight = '60vh';
    _optionsPanel.style.overflowY = 'auto';

    var checksList = _renderPanelOptions();
    _checkElements = checksList;

    return [_input, _optionsPanel];
  }

  bool _overElement = false;

  bool _overDivOptions = false;

  void _mouseEnter(Element elem) {
    if (elem == _input) {
      _overElement = true;
    } else {
      _overDivOptions = true;
    }

    _updateDivOptionsView();
  }

  void _mouseLeave(Element elem) {
    if (elem == _input) {
      _overElement = false;
    } else {
      _overDivOptions = false;
    }

    _updateDivOptionsView();
  }

  void _updateDivOptionsView() {
    if (_overElement || _overDivOptions) {
      _toggleDivOptions(false);
    } else {
      _toggleDivOptions(true);
    }
  }

  void _updateDivOptionsPosition() {
    var inputRect = _input.getBoundingClientRect();

    var w = inputRect.width;

    var x = inputRect.left;
    var inputY = inputRect.top;
    var y = inputY + inputRect.height;

    var freeViewportHeightUpward = inputY - 10;
    var freeViewportHeightBelow = (window.innerHeight - y) - 10;

    _optionsPanel
      ..style.position = 'absolute'
      ..style.left = '${x}px'
      ..style.top = '${y}px'
      ..style.width = '${w}px'
      ..style.zIndex = '999999999'
      ..style.transform = null
      ..style.maxHeight = '${freeViewportHeightBelow}px';

    if (freeViewportHeightBelow < 130 && freeViewportHeightUpward > 130) {
      _optionsPanel
        ..style.top = '${inputY}px'
        ..style.transform = 'translate(0% , -100%)'
        ..style.maxHeight = '${freeViewportHeightUpward}px';
    }
  }

  dynamic _toggleDivOptions(bool requestedHide) {
    _updateDivOptionsPosition();

    var hide;

    if (requestedHide != null) {
      hide = requestedHide;
    } else {
      var showing = _isShowing();
      hide = showing;
    }

    if (hide) {
      _optionsPanel.style.display = 'none';
      _updateElementText();
      _optionsPanelInteractionCompleter.triggerIfHasInteraction();
    } else {
      _optionsPanel.style.display = null;
    }
  }

  bool _isShowing() =>
      _optionsPanel.style.display == null || _optionsPanel.style.display == '';

  bool _setCheck(InputElementBase elem, bool check) {
    if (elem is CheckboxInputElement) {
      return elem.checked = check;
    } else if (elem is RadioButtonInputElement) {
      return elem.checked = check;
    } else {
      return null;
    }
  }

  bool _isChecked(InputElementBase elem) {
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

    entries.forEach((entry) {
      str.write('${entry.key}');
      str.write('${entry.value}');
    });

    entriesFiltered.forEach((entry) {
      str.write('${entry.key}');
      str.write('${entry.value}');
    });

    return str.toString();
  }

  List<List<MapEntry<dynamic, dynamic>>> _optionsEntriesOrder() {
    var entries =
        List.from(_options.entries).cast<MapEntry<dynamic, dynamic>>();

    var entriesFiltered = <MapEntry<dynamic, dynamic>>[];

    var inputValue = _input.value;

    if (inputValue.isNotEmpty) {
      entriesFiltered = getOptionsEntriesFiltered(inputValue);

      if (entriesFiltered.isEmpty && inputValue.length > 1) {
        var elementValue2 = inputValue.substring(0, inputValue.length - 1);
        entriesFiltered = getOptionsEntriesFiltered(elementValue2);
      }

      entriesFiltered
          .forEach((e1) => entries.removeWhere((e2) => e2.key == e1.key));
    }

    return [entries, entriesFiltered];
  }

  String _renderedPanelOptionsSignature;

  List<InputElementBase> _renderPanelOptions() {
    var entriesOrder = _optionsEntriesOrder();

    var entries = entriesOrder[0];
    var entriesFiltered = entriesOrder[1];

    var optionsSignature = _optionsSignature(entries, entriesFiltered);

    if (_renderedPanelOptionsSignature == optionsSignature) {
      return _checkElements;
    }

    _renderedPanelOptionsSignature = optionsSignature;

    _optionsPanel.children.clear();

    if (_options.isEmpty) {
      _optionsPanel.append(createHTML(''' 
          <div style="text-align: center; width: 100%">
            <i>${IntlBasicDictionary.msg('no_options')}</i>
          </div>
          '''));
      return [];
    }

    var checksList = <InputElementBase>[];

    var table = TableElement()..style.borderCollapse = 'collapse';
    var tbody = table.createTBody();

    _optionsPanel.children.add(table);

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
      _optionsPanel.scrollTop = 0;
    } else {
      var firstCheckedElement =
          checksList.firstWhere((e) => _isChecked(e), orElse: () => null);

      if (firstCheckedElement != null) {
        _scrollToElement(_optionsPanel, firstCheckedElement);
      }
    }

    return checksList;
  }

  void _scrollToElement(Element parent, Element element) {
    element.scrollIntoView(ScrollAlignment.CENTER);
  }

  void _renderOptionsPanelEntry(TableSectionElement tbody,
      List<InputElementBase> checksList, MapEntry optEntry, bool filtered) {
    var optKey = '${optEntry.key}';
    var optValue = '${optEntry.value}';

    var check = isCheckedByID(optKey) ?? false;

    InputElementBase checkElem;

    if (isMultiSelection) {
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

    cell2.children.add(label);
  }

  void _onOptionsPanelMouseMove(MouseEvent e) {
    _optionsPanelInteractionCompleter.interact(noTriggering: true);
    _inputInteractionCompleter.interact(noTriggering: true);
  }
}
