import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// A component that renders a multi-selection input.
class UIMultiSelection extends UIComponent implements UIField<List<String>> {
  final Map _options;

  final bool multiSelection;

  final String width;

  final int optionsPanelMargin;

  final String separator;

  final Duration selectionMaxDelay;

  final EventStream<UIMultiSelection> onSelect = EventStream();

  UIMultiSelection(Element parent, this._options,
      {this.multiSelection,
      this.width,
      this.optionsPanelMargin = 20,
      this.separator = ' ; ',
      Duration selectionMaxDelay,
      dynamic classes})
      : selectionMaxDelay = selectionMaxDelay ?? Duration(seconds: 10),
        super(parent,
            classes: 'ui-multi-selection',
            classes2: classes,
            renderOnConstruction: true);

  @override
  List<String> getFieldValue() {
    return getSelectedIDs();
  }

  InputElement _element;

  DivElement _divOptions;

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

  bool isAllChecked() {
    if (_checkElements.isEmpty) return false;
    var firstNotChecked =
        _checkElements.firstWhere((e) => !_isChecked(e), orElse: () => null);
    return firstNotChecked == null;
  }

  bool isAllUnchecked() {
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
      pattern = pattern.trim();
      if (pattern.isEmpty || pattern == '*') return _options.entries.toList();
      return _options.entries
          .where((e) => '${e.value}'.toLowerCase().contains(pattern))
          .toList();
    } else if (pattern is RegExp) {
      return _options.entries
          .where((e) => pattern.hasMatch('${e.value}'))
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

  bool hasSelection() {
    return _getSelectedElements().isNotEmpty;
  }

  List<String> getSelectedIDs() {
    return _getSelectedElements().map((e) => e.value).toList();
  }

  List<String> getSelectedLabels() {
    return _getSelectedElements()
        .map((e) => e.getAttribute('opt_label'))
        .toList();
  }

  List<String> getUnselectedIDs() {
    return _getUnSelectedElements().map((e) => e.value).toList();
  }

  List<String> getUnselectedLabels() {
    return _getUnSelectedElements()
        .map((e) => e.getAttribute('opt_label'))
        .toList();
  }

  void _updateElementText() {
    if (_element == null) return;

    String text;

    if (isAllChecked()) {
      text = '*';
    } else {
      var sep = separator ?? ' ; ';
      text = getSelectedLabels().join(sep);
    }

    _element.value = text;
  }

  @override
  dynamic render() {
    if (_element == null) {
      _element = InputElement()..type = 'text';

      _element.style.padding = '5px 10px';
      _element.style.border = '1px solid #ccc';

      if (width != null) {
        _element.style.width = width;
      }

      //style="cursor: pointer; padding: 5px 10px; border: 1px solid #ccc; width: 100%"

      _divOptions = DivElement()
        ..style.display = 'none'
        ..style.backgroundColor = 'rgba(255,255,255, 0.90)'
        ..style.position = 'absolute'
        ..style.left = '0px'
        ..style.top = '0px'
        ..style.textAlign = 'left'
        ..style.padding = '4px';

      _divOptions.classes.add('shadow');
      _divOptions.classes.add('p-2');
      _divOptions.classes.add('ui-multiselection-options-menu');

      window.onResize.listen((e) => _updateDivOptionsPosition());

      _element.onKeyUp.listen((e) {
        _updateDivOptions();
        _toggleDivOptions(false);
      });

      _element.onClick.listen((e) {
        _element.value = '';
        _toggleDivOptions(false);
      });

      _element.onMouseEnter.listen((e) => _mouseEnter(_element));
      _element.onMouseLeave.listen((e) => _mouseLeave(_element));

      _divOptions.onMouseEnter.listen((e) => _mouseEnter(_divOptions));
      _divOptions.onMouseLeave.listen((e) => _mouseLeave(_divOptions));

      _divOptions.onMouseMove.listen((e) => _onDivOptionsMouseMove(e));

      _divOptions.onTouchEnter.listen((e) => _mouseEnter(_element));
      _divOptions.onTouchLeave.listen((e) => _mouseLeave(_element));

      window.onTouchStart.listen((e) {
        if (_divOptions == null) return;

        var overDivOptions = nodeTreeContainsAny(
            _divOptions, e.targetTouches.map((t) => t.target));
        if (!overDivOptions && _isShowing()) {
          _toggleDivOptions(true);
        }
      });
    }

    var checksList = _renderDivOptions(_element, _divOptions);
    _checkElements = checksList;

    return [_element, _divOptions];
  }

  bool _overElement = false;

  bool _overDivOptions = false;

  void _mouseEnter(Element elem) {
    if (elem == _element) {
      _overElement = true;
    } else {
      _overDivOptions = true;
    }

    _updateDivOptionsView();
  }

  void _mouseLeave(Element elem) {
    if (elem == _element) {
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
    var elemW = _element.borderEdge.width;
    var w = elemW;

    var x = _element.offset.left;
    var xPadding = (elemW - w) / 2;
    x += xPadding;

    var y = _element.offset.top + _element.offset.height;

    _divOptions
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
      _divOptions.style.display = 'none';
      _updateElementText();
      _notifySelection(false);
    } else {
      _divOptions.style.display = null;
    }
  }

  bool _isShowing() =>
      _divOptions.style.display == null || _divOptions.style.display == '';

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

  dynamic _updateDivOptions() {
    var checksList = _renderDivOptions(_element, _divOptions);
    _checkElements = checksList;
  }

  dynamic _renderDivOptions(InputElement element, DivElement divOptions) {
    divOptions.children.clear();

    // ignore: omit_local_variable_types
    List<InputElementBase> checksList = [];

    // ignore: omit_local_variable_types
    List<MapEntry<dynamic, dynamic>> entries =
        List.from(_options.entries).cast();
    // ignore: omit_local_variable_types
    List<MapEntry<dynamic, dynamic>> entriesFiltered = [];

    var elementValue = element.value;

    if (elementValue.isNotEmpty) {
      entriesFiltered = getOptionsEntriesFiltered(elementValue);

      if (entriesFiltered.isEmpty && elementValue.length > 1) {
        var elementValue2 = elementValue.substring(0, elementValue.length - 1);
        entriesFiltered = getOptionsEntriesFiltered(elementValue2);
      }

      entriesFiltered
          .forEach((e1) => entries.removeWhere((e2) => e2.key == e1.key));
    }

    var table = TableElement();

    var tbody = table.createTBody();

    divOptions.children.add(table);

    for (var optEntry in entriesFiltered) {
      _renderDivOptionsEntry(tbody, checksList, optEntry);
    }

    for (var optEntry in entries) {
      _renderDivOptionsEntry(tbody, checksList, optEntry);
    }

    return checksList;
  }

  void _renderDivOptionsEntry(TableSectionElement tbody,
      List<InputElementBase> checksList, MapEntry optEntry) {
    var optKey = '${optEntry.key}';
    var optValue = '${optEntry.value}';

    var check = isCheckedByID(optKey) ?? false;

    InputElementBase checkElem;

    if (multiSelection) {
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
