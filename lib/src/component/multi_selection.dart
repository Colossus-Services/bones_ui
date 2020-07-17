import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// A component that renders a multi-selection input.
class UIMultiSelection extends UIComponent implements UIField<List<String>> {
  Map _options;

  final bool _multiSelection;

  final String width;

  final int optionsPanelMargin;

  final String separator;

  final Duration selectionMaxDelay;

  final EventStream<UIMultiSelection> onSelect = EventStream();

  UIMultiSelection(Element parent, Map options,
      {bool multiSelection = true,
      this.width,
      this.optionsPanelMargin = 20,
      this.separator = ' ; ',
      Duration selectionMaxDelay,
      dynamic classes})
      : _options = options ?? {},
        _multiSelection = multiSelection ?? true,
        selectionMaxDelay = selectionMaxDelay ?? Duration(seconds: 10),
        super(parent,
            classes: 'ui-multi-selection',
            classes2: classes,
            renderOnConstruction: true);

  Map get options => Map.from(_options);

  set options(Map value) {
    _options = value ?? {};
    refresh();
  }

  void addOption(dynamic key, dynamic value) => _options[key] = value;

  dynamic getOption(dynamic key) => _options[key];

  bool containsOption(dynamic key) => _options.containsKey(key);

  dynamic removeOption(dynamic key) => _options.remove(key);

  bool get isMultiSelection => _multiSelection;

  @override
  List<String> getFieldValue() {
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

  bool _needToNotifySelection = false;

  void _notifySelection(bool delayed) {
    if (!_needToNotifySelection) return;

    if (delayed) {
      var moveElapsed =
          DateTime.now().millisecondsSinceEpoch - _onDivOptionsLastMouseMove;
      var maxDelay =
          selectionMaxDelay != null ? selectionMaxDelay.inMilliseconds : 200;
      if (moveElapsed < maxDelay) {
        _notifySelectionDelayed();
        return;
      }
    }

    _needToNotifySelection = false;

    onSelect.add(this);

    onChange.add(this);
  }

  void _notifySelectionDelayed() {
    if (!_needToNotifySelection) return;

    var maxDelay =
        selectionMaxDelay != null ? selectionMaxDelay.inMilliseconds : 200;
    if (maxDelay < 200) maxDelay = 200;

    var moveElapsed =
        DateTime.now().millisecondsSinceEpoch - _onDivOptionsLastMouseMove;
    var timeUntilMaxDelay = maxDelay - moveElapsed;

    var delay =
        timeUntilMaxDelay < 100 ? 100 : Math.min(timeUntilMaxDelay, maxDelay);

    Future.delayed(Duration(milliseconds: delay), () => _notifySelection(true));
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
      _needToNotifySelection = true;
      _notifySelectionDelayed();
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
      _needToNotifySelection = true;
      _notifySelectionDelayed();
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
      _needToNotifySelection = true;
      _notifySelectionDelayed();
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
    _needToNotifySelection = true;
    _notifySelectionDelayed();
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
        .map((e) => e.getAttribute('opt_label'))
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

    String text;

    if (isAllChecked) {
      text = '*';
    } else {
      var sep = separator ?? ' ; ';
      text = selectedLabels.join(sep);
    }

    _input.value = text;
  }

  @override
  dynamic render() {
    if (_input == null) {
      _input = InputElement()..type = 'text';

      _input.style.padding = '5px 10px';
      _input.style.border = '1px solid #ccc';

      if (isNotEmptyObject(width)) {
        _input.style.width = width;
      }

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
        _updateOptionsPanel();
        _toggleDivOptions(false);
      });

      _input.onClick.listen((e) {
        _input.value = '';
        _toggleDivOptions(false);
      });

      _input.onMouseEnter.listen((e) => _mouseEnter(_input));
      _input.onMouseLeave.listen((e) => _mouseLeave(_input));

      _optionsPanel.onMouseEnter.listen((e) => _mouseEnter(_optionsPanel));
      _optionsPanel.onMouseLeave.listen((e) => _mouseLeave(_optionsPanel));

      _optionsPanel.onMouseMove.listen((e) => _onDivOptionsMouseMove(e));

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
    _optionsPanel.style.overflowY = 'scroll';

    var checksList = _renderPanelOptions(_input, _optionsPanel);
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
    var elemW = _input.borderEdge.width;
    var w = elemW;

    var x = _input.offset.left;
    var xPadding = (elemW - w) / 2;
    x += xPadding;

    var y = _input.offset.top + _input.offset.height;

    _optionsPanel
      ..style.position = 'absolute'
      ..style.left = '${x}px'
      ..style.top = '${y}px'
      ..style.width = '${w}px'
      ..style.zIndex = '999999999';
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
      _notifySelection(false);
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
    var checksList = _renderPanelOptions(_input, _optionsPanel);
    _checkElements = checksList;
  }

  List<InputElementBase> _renderPanelOptions(
      InputElement input, DivElement optionsPanel) {
    optionsPanel.children.clear();

    if (_options.isEmpty) {
      optionsPanel.append(createHTML(''' 
          <div style="text-align: center; width: 100%">
            <i>${IntlBasicDictionary.msg('no_options')}</i>
          </div>
          '''));
      return [];
    }

    var checksList = <InputElementBase>[];

    var entries =
        List.from(_options.entries).cast<MapEntry<dynamic, dynamic>>();

    var entriesFiltered = <MapEntry<dynamic, dynamic>>[];

    var inputValue = input.value;

    if (inputValue.isNotEmpty) {
      entriesFiltered = getOptionsEntriesFiltered(inputValue);

      if (entriesFiltered.isEmpty && inputValue.length > 1) {
        var elementValue2 = inputValue.substring(0, inputValue.length - 1);
        entriesFiltered = getOptionsEntriesFiltered(elementValue2);
      }

      entriesFiltered
          .forEach((e1) => entries.removeWhere((e2) => e2.key == e1.key));
    }

    var table = TableElement()..style.borderCollapse = 'collapse';
    var tbody = table.createTBody();

    optionsPanel.children.add(table);

    if (entriesFiltered.isNotEmpty) {
      for (var optEntry in entriesFiltered) {
        _renderDivOptionsEntry(tbody, checksList, optEntry, true);
      }

      var tr = tbody.addRow();
      var td = tr.addCell()..colSpan = 2;
      td.append(HRElement());
    }

    for (var optEntry in entries) {
      _renderDivOptionsEntry(tbody, checksList, optEntry, false);
    }

    if (isNotEmptyObject(inputValue)) {
      optionsPanel.scrollTop = 0;
    } else {
      var firstCheckedElement =
          checksList.firstWhere((e) => _isChecked(e), orElse: () => null);

      if (firstCheckedElement != null) {
        _scrollToElement(optionsPanel, firstCheckedElement);
      }
    }

    return checksList;
  }

  void _scrollToElement(Element parent, Element element) {
    element.scrollIntoView(ScrollAlignment.CENTER);
  }

  void _renderDivOptionsEntry(TableSectionElement tbody,
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

  int _onDivOptionsLastMouseMove = 0;

  void _onDivOptionsMouseMove(MouseEvent e) {
    _onDivOptionsLastMouseMove = DateTime.now().millisecondsSinceEpoch;
  }
}
