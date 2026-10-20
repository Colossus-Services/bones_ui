import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';
import '../bones_ui_web.dart';

/// A component that renders a multi-selection input.
class UIMultiSelection extends UIComponent implements UIField<List<String?>> {
  static final UIComponentGenerator<UIMultiSelection> generator =
      UIComponentGenerator<UIMultiSelection>(
        'ui-multi-selection',
        'div',
        'ui-multi-selection',
        'display: inline-block',
        (parent, attributes, contentHolder, contentNodes) {
          var jsonConfig = parseJSON(contentHolder?.textContent, {});
          if (jsonConfig is! Map) jsonConfig = {};
          return UIMultiSelection(parent, jsonConfig['options']);
        },
        [
          UIComponentAttributeHandler<UIMultiSelection, dynamic>(
            'options',
            parser: _parseOptionsAttribute,
            getter: (c) => c._options,
            setter: (c, v) => c._options = v is Map
                ? v
                : (parseFromInlineMap(
                        parseString(v),
                        RegExp(r'\s*[,;]\s*'),
                        RegExp(r'\s*[:=]\s*'),
                      ) ??
                      {}),
            // Empty, not `null`: the option accessors expect `_options`.
            cleaner: (c) => c._options = {},
          ),
          UIComponentAttributeHandler<UIMultiSelection, dynamic>(
            'multi-selection',
            parser: parseBool,
            getter: (c) => c.multiSelection,
            setter: (c, v) => c.multiSelection = v as bool?,
            cleaner: (c) => c.multiSelection = null,
          ),
        ],
        hasChildrenElements: false,
        contentAsText: false,
      );

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  /// Keeps an inline map (`a: A ; b: B`) for the `options` setter: `parseJSON`
  /// threw for it, so these options were never set.
  static Object? _parseOptionsAttribute(Object? value) {
    if (value is String && !isEncodedJSONMap(value)) return value;
    return parseJSON(value);
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

  static int _instanceCount = 0;

  /// This instance's ID (its single-selection radio group).
  final int _instanceID = ++_instanceCount;

  UIMultiSelection(
    super.parent,
    Map? options, {
    this.fieldName = 'multi-selection',
    this.multiSelection = true,
    List? selections,
    this.allowInputValue = false,
    this.optionsPanelMargin = 20,
    this.separator = ' ; ',
    this.autoInputFontShrink = true,
    Duration? selectionMaxDelay,
    super.classes,
    super.style,
  }) : _options = options ?? {},
       _initialSelections = selections ?? [],
       super(
         componentClass: 'ui-multi-selection',
         renderOnConstruction: false,
         generator: generator,
       ) {
    _optionsPanelInteractionCompleter = InteractionCompleter(
      'optionsPanel',
      triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
      functionToTrigger: _notifySelection,
    );

    if (allowInputValue) {
      _inputInteractionCompleter = InteractionCompleter(
        'input',
        triggerDelay: selectionMaxDelay ?? Duration(seconds: 10),
        functionToTrigger: _notifyInput,
      );
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

  bool _setDataOptions(Object? data) {
    var options = _parseDataOptions(data);

    if (isEqualsDeep(_options, options)) {
      return false;
    }

    _options = options;

    return true;
  }

  Map _parseDataOptions(Object? data) {
    if (isEmptyObject(data)) {
      return {};
    } else if (data is Map) {
      return data;
    } else if (data is List) {
      if (data.length == 1 && data[0] is Map) {
        return data[0];
      } else {
        return Map.fromEntries(
          data.map((e) {
            return parseMapEntryOfStrings(e, RegExp(r'\s*[:=]\s*'))!;
          }),
        );
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

  HTMLInputElement? _input;
  HTMLDivElement? _optionsPanel;

  List<HTMLInputElement> _checkElements = [];

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
    dynamic id,
    bool? check,
    bool fromCheckElement,
    bool notify,
  ) {
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
    var firstNotChecked = _checkElements.firstWhereOrNull(
      (e) => !_isChecked(e)!,
    );
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

  List<HTMLInputElement> _getSelectedElements() {
    return _checkElements.where((e) => _isChecked(e) ?? false).toList();
  }

  List<HTMLInputElement> _getUnSelectedElements() {
    return _checkElements.where((e) => !(_isChecked(e) ?? false)).toList();
  }

  HTMLInputElement? _getCheckElement(String id) {
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

  void _autoAdjustInputFont(HTMLInputElement input, String text) {
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

    var textDim = measureText(
      text,
      fontFamily: inputComputedStyle.fontFamily,
      fontSize: inputComputedStyle.fontSize,
      bold: inputComputedStyle.fontStyle == 'bold',
    );

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
      var input = _input = HTMLInputElement()
        ..classList.add('ui-multi-selection-input')
        ..type = 'text';

      input
        ..style.padding = '5px 10px'
        ..style.border = '1px solid #ccc'
        ..style.width = '100%'
        ..style.color = 'inherit';

      //style="cursor: pointer; padding: 5px 10px; border: 1px solid #ccc; width: 100%"

      // Its look (background, alignment, padding) is a default the app's CSS
      // can override ([_optionsPanelCSS]):
      addCSSCode(_optionsPanelCSS);

      _optionsPanel = HTMLDivElement()
        ..style.display = 'none'
        ..style.position = 'absolute'
        ..style.left = '0px'
        ..style.top = '0px';

      _optionsPanel!.classList.add('shadow');
      _optionsPanel!.classList.add('p-2');
      _optionsPanel!.classList.add('ui-multi-selection-options-menu');

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
          _optionsPanel!,
          e.targetTouches.toIterable().map((t) => t.target as UINode),
        );
        if (!overDivOptions && _isShowing()) {
          _toggleDivOptions(true);
        }
      });
    }

    // Shown, it stays shown in the `body` (not rendered into the component):
    // re-attached and re-positioned in [posRender] (a render clearing the
    // rendered elements takes it out of the `body`).
    var keepShown = _isShowing() && document.body != null;
    _reattachOptionsPanel = keepShown;

    if (!keepShown) {
      _optionsPanel!.style.maxHeight = '60vh';
    }
    _optionsPanel!.style.overflowY = 'auto';

    var checksList = _renderPanelOptions();
    _checkElements = checksList;

    _updateElementText();

    return keepShown ? [_input] : [_input, _optionsPanel];
  }

  /// Whether [posRender] re-attaches the options panel shown during [render].
  bool _reattachOptionsPanel = false;

  @override
  void posRender() {
    if (_reattachOptionsPanel) {
      _reattachOptionsPanel = false;

      if (_isShowing()) {
        if (_isInputShown) {
          _attachOptionsPanel();
          _updateDivOptionsPosition();
        } else {
          _hideOptionsPanelQuietly();
        }
      }
    }

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
    return Rectangle(
      window.scrollX + rect.left,
      window.scrollY + rect.top,
      rect.width,
      rect.height,
    );
  }

  void _updateDivOptionsPosition() {
    var inputVPRect = _input!.getBoundingClientRect().toRectangle();
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
    var freeViewportHeightBelow = (window.innerHeight - inputVPY) - 10;

    var upward =
        freeViewportHeightBelow < 130 && freeViewportHeightUpward > 130;

    if (upward) {
      y = inputY;
    }

    _optionsPanel!
      ..style.position = 'absolute'
      ..style.left = '${x}px'
      ..style.top = '${y}px'
      ..style.width = '${inputW}px'
      ..style.zIndex = '999999999'
      ..style.transform = upward ? 'translate(0% , -100%)' : ''
      ..style.maxHeight =
          '${upward ? freeViewportHeightUpward : freeViewportHeightBelow}px';

    // Page coordinates are relative to the document only while the panel's
    // containing block is (a `body` not positioned, nor transformed):
    // corrected by where the shown panel landed.
    if (_isShowing()) {
      var panelVPRect = _optionsPanel!.getBoundingClientRect();
      var dx = inputVPRect.left - panelVPRect.left;
      var dy = upward
          ? inputVPRect.top - panelVPRect.bottom
          : inputVPRect.bottom - panelVPRect.top;

      if (dx.abs() >= 0.5 || dy.abs() >= 0.5) {
        _optionsPanel!
          ..style.left = '${x + dx}px'
          ..style.top = '${y + dy}px';
      }
    }
  }

  dynamic _toggleDivOptions([bool? requestedHide]) {
    bool hide;
    if (requestedHide != null) {
      hide = requestedHide;
    } else {
      var showing = _isShowing();
      hide = showing;
    }

    // Not shown for an input out of the document (a removed component):
    if (!hide && !_input!.isConnected) {
      hide = true;
    }

    if (hide) {
      _optionsPanel!.style.display = 'none';
      _detachOptionsPanel();
      _updateElementText();

      if (_input!.isConnected) {
        _optionsPanelInteractionCompleter.triggerIfHasInteraction();
      } else {
        // A removed component: its pending selection isn't notified, on any
        // hide (e.g. a `mouseleave` the browser fires when the removed
        // input was under the pointer, before the visibility check).
        _optionsPanelInteractionCompleter.cancel();
      }
    } else {
      _attachOptionsPanel();
      // Shown before positioned: its position is checked by where it landed.
      _optionsPanel!.style.display = '';
      _updateDivOptionsPosition();
    }
  }

  /// The inherited properties the options panel keeps from the component
  /// while shown in the `body` (passed as `--ui-multi-selection-<property>`).
  static const _optionsPanelInheritedStyle = [
    'color',
    'font-family',
    'font-size',
    'font-style',
    'font-weight',
    'line-height',
    'letter-spacing',
    'direction',
  ];

  /// The options panel's default style, in `:where` (no specificity): any
  /// app rule styling `.ui-multi-selection-options-menu` takes precedence
  /// (as inline styles it couldn't be overridden). In the `body`, the
  /// component's inherited properties apply the same way, as inheritance
  /// would inside it.
  static final String _optionsPanelCSS = [
    ':where(.ui-multi-selection-options-menu) {',
    '  background-color: rgba(255, 255, 255, 0.90);',
    '  text-align: left;',
    '  padding: 4px;',
    '}',
    ':where(body > .ui-multi-selection-options-menu) {',
    for (var property in _optionsPanelInheritedStyle)
      '  $property: var(--ui-multi-selection-$property);',
    '}',
  ].join('\n');

  /// While the options panel is shown in the `body`: hides it if the input
  /// leaves the document (the component removed, e.g. by a new render of its
  /// parent) or isn't displayed (an ancestor with `display: none`, e.g. a
  /// hidden dialog), where no `mouseleave` would hide it. Inside the
  /// component it was hidden with it.
  Timer? _optionsPanelVisibilityCheck;

  static const _optionsPanelVisibilityCheckInterval = Duration(
    milliseconds: 250,
  );

  void _checkOptionsPanelVisibility() {
    var input = _input;
    if (input == null || !input.isConnected) {
      // A removed component: its pending selection isn't notified.
      _optionsPanelInteractionCompleter.cancel();
      _hideOptionsPanelQuietly();
    } else if (!_isInputShown) {
      _overElement = false;
      _overDivOptions = false;
      _toggleDivOptions(true);
    }
  }

  /// Whether the input is in the document and displayed (has a box).
  bool get _isInputShown {
    var input = _input;
    return input != null &&
        input.isConnected &&
        input.getClientRects().length > 0;
  }

  /// Hides the options panel, back in the component, without notifying a
  /// pending selection (for a component being removed or re-rendered).
  void _hideOptionsPanelQuietly() {
    _overElement = false;
    _overDivOptions = false;
    _optionsPanel?.style.display = 'none';
    _detachOptionsPanel();
  }

  /// Shows the options panel attached to the document's `body`, positioned
  /// in page coordinates ([_updateDivOptionsPosition]). Inside the component,
  /// an ancestor that is the containing block of absolute elements
  /// (`position`, `transform`, `filter`, `backdrop-filter`...) displaced it,
  /// and one with `overflow` clipped it. It keeps the component's font and
  /// color, which it inherited there ([_optionsPanelCSS]).
  void _attachOptionsPanel() {
    var panel = _optionsPanel!;
    var body = document.body;
    if (body == null || panel.parentNode == body) return;

    var computedStyle = (content ?? _input!).getComputedStyle();

    for (var property in _optionsPanelInheritedStyle) {
      panel.style.setProperty(
        '--ui-multi-selection-$property',
        computedStyle.getPropertyValue(property),
      );
    }

    body.appendChild(panel);

    _optionsPanelVisibilityCheck?.cancel();
    _optionsPanelVisibilityCheck = Timer.periodic(
      _optionsPanelVisibilityCheckInterval,
      (_) => _checkOptionsPanelVisibility(),
    );
  }

  /// Returns the options panel (hidden) to the component, after the input,
  /// from the `body` (or out of the document, taken by a render clearing the
  /// rendered elements); removes it if the input is no longer in the
  /// document.
  void _detachOptionsPanel() {
    _optionsPanelVisibilityCheck?.cancel();
    _optionsPanelVisibilityCheck = null;

    var panel = _optionsPanel;
    if (panel == null) return;

    for (var property in _optionsPanelInheritedStyle) {
      panel.style.removeProperty('--ui-multi-selection-$property');
    }

    // Already in the component:
    if (panel.parentNode != document.body && panel.isConnected) return;

    var input = _input;
    var inputParent = input?.parentNode;
    if (input != null && inputParent != null && input.isConnected) {
      inputParent.insertBefore(panel, input.nextSibling);
    } else {
      panel.remove();
    }
  }

  @override
  void dispose() {
    // Not left shown in the `body`:
    _hideOptionsPanelQuietly();
    super.dispose();
  }

  bool _isShowing() =>
      _optionsPanel!.style.display == '' || _optionsPanel!.style.display == '';

  bool? _setCheck(HTMLInputElement? elem, bool? check) {
    if (elem == null) return null;

    switch (elem.type.toLowerCase()) {
      case 'checkbox':
      case 'radio':
        {
          return elem.checked = check ?? false;
        }

      default:
        return null;
    }
  }

  bool? _isChecked(HTMLInputElement? elem) {
    if (elem == null) return null;

    switch (elem.type.toLowerCase()) {
      case 'checkbox':
      case 'radio':
        {
          return elem.checked;
        }

      default:
        return null;
    }
  }

  dynamic _updateOptionsPanel() {
    var checksList = _renderPanelOptions();
    _checkElements = checksList;
  }

  String _optionsSignature(
    List<MapEntry<dynamic, dynamic>> entries,
    List<MapEntry<dynamic, dynamic>> entriesFiltered,
  ) {
    var str = StringBuffer();

    str.write('$multiSelection\n');

    for (var entry in entries) {
      str.write('${entry.key}=');
      str.write('${entry.value}&');
    }

    // Separates the lists: otherwise filtering the last options (moving them
    // to the filtered list) keeps the same signature and isn't rendered.
    str.write('\n');

    for (var entry in entriesFiltered) {
      str.write('${entry.key}=');
      str.write('${entry.value}&');
    }

    return str.toString();
  }

  List<List<MapEntry<dynamic, dynamic>>> _optionsEntriesOrder() {
    var entries = _options!.entries.toList();

    var entriesFiltered = <MapEntry<dynamic, dynamic>>[];

    var inputValue = _input!.value;

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

  List<HTMLInputElement> _renderPanelOptions() {
    var entriesOrder = _optionsEntriesOrder();

    var entries = entriesOrder[0];
    var entriesFiltered = entriesOrder[1];

    var optionsSignature = _optionsSignature(entries, entriesFiltered);

    if (_renderedPanelOptionsSignature == optionsSignature) {
      return _checkElements;
    }

    _renderedPanelOptionsSignature = optionsSignature;

    _optionsPanel!.clear();

    if (_options!.isEmpty) {
      _optionsPanel!.appendChild(
        createHTML(
          html:
              '''
          <div style="text-align: center; width: 100%">
            <i>${IntlBasicDictionary.msg('no_options')}</i>
          </div>
          ''',
        ),
      );
      return [];
    }

    var checksList = <HTMLInputElement>[];

    var table = HTMLTableElement()..style.borderCollapse = 'collapse';
    var tbody = table.createTBody();

    _optionsPanel!.appendChild(table);

    if (entriesFiltered.isNotEmpty) {
      for (var optEntry in entriesFiltered) {
        _renderOptionsPanelEntry(tbody, checksList, optEntry, true);
      }

      if (entries.isNotEmpty) {
        var tr = tbody.appendRow();
        var td = tr.appendCell()..colSpan = 2;
        td.append(HTMLHRElement());
      }
    }

    for (var optEntry in entries) {
      _renderOptionsPanelEntry(tbody, checksList, optEntry, false);
    }

    if (isNotEmptyObject(inputValue)) {
      _optionsPanel!.scrollTop = 0;
    } else {
      var firstCheckedElement = checksList.firstWhereOrNull(
        (e) => _isChecked(e)!,
      );

      if (firstCheckedElement != null) {
        _scrollToElement(_optionsPanel, firstCheckedElement);
      }
    }

    return checksList;
  }

  void _scrollToElement(Element? parent, Element element) {
    element.scrollIntoView(
      {'behavior': 'smooth', 'block': 'center', 'inline': 'center'}.toJSDeep,
    );
  }

  void _renderOptionsPanelEntry(
    HTMLTableSectionElement tbody,
    List<HTMLInputElement> checksList,
    MapEntry optEntry,
    bool filtered,
  ) {
    var optKey = '${optEntry.key}';
    var optValue = '${optEntry.value}';

    var check =
        isCheckedByID(optKey) ??
        (_initialSelections.contains(optKey) ||
            _initialSelections.contains(optEntry.key));

    HTMLInputElement checkElem;

    if (multiSelection!) {
      var input = HTMLInputElement()..type = 'checkbox';
      input.checked = check;
      checkElem = input;
    } else {
      // A radio group per instance: in the `body`, the options of instances
      // in and out of a `<form>` would share a group (unchecking each
      // other's).
      var input = HTMLInputElement()
        ..type = 'radio'
        ..name = '__MultiSelection__$_instanceID';
      input.checked = check;
      checkElem = input;
    }

    checkElem.value = optKey;
    checkElem.setAttribute('opt_label', optValue);

    var row = tbody.appendRow();

    var cell1 = row.appendCell()
      ..style.padding = '2px 6px 2px 2px'
      ..style.verticalAlign = 'top';

    cell1.appendChild(checkElem);

    checksList.add(checkElem);

    var label = HTMLLabelElement();
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

    var cell2 = row.appendCell()..style.textAlign = 'left';

    cell2.appendChild(HTMLSpanElement()..innerHTML = '&nbsp;'.toJS);
    cell2.appendChild(label);
  }

  void _onOptionsPanelMouseMove(MouseEvent e) {
    _optionsPanelInteractionCompleter.interact(noTriggering: true);
    _inputInteractionCompleter.interact(noTriggering: true);
  }
}
