import 'dart:async';
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:dom_builder/dom_builder_dart_html.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_layout.dart';

/*
final LoggerFactory _loggerFactory = LoggerFactory(name: 'Bones_UI') ;

final Logger logger = _loggerFactory.get();

final Logger loggerIgnoreBonesUI = _loggerFactory.get(
    printer: PrettyPrinter(printTime: true)
      ..ignorePackage('bones_ui')
      ..ignorePackage('bones_ui_bootstrap'));
*/

// Temporary logger. Will be replaced by `logger`.
class _Logger {
  void i(dynamic msg) {
    msg = _format(msg);
    print(msg);
  }

  void e(dynamic msg, dynamic e, StackTrace s) {
    msg = _format(msg, true);
    _error(msg);
    if (e != null) {
      _error(e.toString());
    }
    if (s != null) {
      _error(formatStackTrace(s));
    }
  }

  void _error(msg) {
    window.console.error(msg);
  }

  dynamic _format(dynamic msg, [bool error = false]) {
    if (msg is List) {
      return msg.map((e) => _format(msg));
    } else if (msg is String) {
      var str = StringBuffer(error ? '\n' : '');

      str.write('┌-------------------------------------------------\n');

      var lines = msg.split('\n');

      for (var line in lines) {
        str.write('| ');
        str.write(line);
        str.write('\n');
      }

      str.write('└-------------------------------------------------\n');

      return str.toString();
    } else {
      return msg;
    }
  }

  String formatStackTrace(StackTrace stackTrace) {
    var lines = stackTrace.toString().split('\n');

    var formatted = <String>[];
    var count = 0;

    var length = lines.length;
    for (var i = 0; i < length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;
      formatted.add('#$count   ${line.replaceFirst(RegExp(r'#\d+\s+'), '')}');
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }
}

final _Logger logger = _Logger();
final _Logger loggerIgnoreBonesUI = _Logger();

typedef UIEventListener = void Function(dynamic event, List params);

abstract class UIEventHandler extends EventHandlerPrivate {
  void registerEventListener(String type, UIEventListener listener) {
    _registerEventListener(type, listener);
  }

  void fireEvent(String type, dynamic event, [List params]) {
    _fireEvent(type, event, params);
  }
}

abstract class EventHandlerPrivate {
  final Map<String, List<UIEventListener>> _eventListeners = {};

  void _registerEventListener(String type, UIEventListener listener) {
    var events = _eventListeners[type];
    if (events == null) _eventListeners[type] = events = [];
    events.add(listener);
  }

  void _fireEvent(String type, dynamic event, [List params]) {
    var eventListeners = _eventListeners[type];

    if (eventListeners != null) {
      try {
        for (var listener in eventListeners) {
          listener(event, params);
        }
      } catch (exception, stackTrace) {
        UIConsole.error(
            'Error firing event: type: $type ; event: $event ; params: $params',
            exception,
            stackTrace);
      }
    }
  }
}

/// A console output int the UI.
///
/// Useful for web development, allowing access to console output
/// directly in the UI.
class UIConsole {
  static UIConsole _instance;

  static UIConsole get() {
    _instance ??= UIConsole._internal();
    return _instance;
  }

  bool _enabled = false;

  final List<String> _logs = [];

  int _limit = 10000;

  UIConsole._internal() {
    mapJSUIConsole();
  }

  static bool _mapJSUIConsole = false;

  static void mapJSUIConsole() {
    if (_mapJSUIConsole) return;
    _mapJSUIConsole = true;

    try {
      mapJSFunction('UIConsole', (o) {
        UIConsole.log('JS> $o');
      });
    } catch (e) {
      UIConsole.error("Can't mapJSFunction: UIConsole", e);
    }
  }

  bool get enabled => _enabled;

  int get limit => _limit;

  set limit(int l) {
    if (l < 10) l = 10;
    _limit = l;
  }

  static void enable() {
    get()._enable();
  }

  static final String SESSION_KEY_UIConsole_enabled = '__UIConsole__enabled';

  void _enable() {
    _enabled = true;

    window.sessionStorage[SESSION_KEY_UIConsole_enabled] = '1';
  }

  static void checkAutoEnable() {
    if (window.sessionStorage[SESSION_KEY_UIConsole_enabled] == '1') {
      displayButton();
    }
  }

  static void disable() {
    get()._disable();
  }

  void _disable() {
    _enabled = false;

    window.sessionStorage[SESSION_KEY_UIConsole_enabled] = '0';
  }

  static List<String> logs() {
    return get()._getLogs();
  }

  List<String> _getLogs() {
    return List.from(_logs).cast();
  }

  static List<String> tail([int tailSize = 100]) {
    return get()._tail(tailSize);
  }

  List<String> _tail([int tailSize = 100]) {
    // ignore: omit_local_variable_types
    List<String> list = [];

    for (var i = _logs.length - tailSize; i < _logs.length; ++i) {
      list.add(_logs[i]);
    }

    return list;
  }

  static List<String> head([int headSize = 100]) {
    return get()._head(headSize);
  }

  List<String> _head([int headSize = 100]) {
    // ignore: omit_local_variable_types
    List<String> list = [];

    if (headSize > _logs.length) headSize = _logs.length;

    for (var i = 0; i < headSize; ++i) {
      list.add(_logs[i]);
    }

    return list;
  }

  static void error(dynamic msg, [dynamic exception, StackTrace trace]) {
    return get()._error(msg, exception, trace);
  }

  void _error(dynamic msg, [dynamic exception, StackTrace trace]) {
    if (!_enabled) {
      if (exception != null) {
        msg += ' >> $exception';
      }

      window.console.error(msg);

      if (trace != null) {
        window.console.error(trace.toString());
      }

      return;
    }

    var now = DateTime.now();
    var log = 'ERROR> $now>  $msg';

    if (exception != null) {
      log += ' >> $exception';
    }

    _logs.add(log);

    if (trace != null) {
      _logs.add(trace.toString());
    }

    while (_logs.length > _limit) {
      _logs.remove(0);
    }

    if (msg is String) {
      window.console.error(log);
    } else {
      window.console.error(msg);
    }

    if (trace != null) {
      window.console.error(trace.toString());
    }
  }

  static void log(dynamic msg) {
    return get()._log(msg);
  }

  void _log(dynamic msg) {
    if (!_enabled) {
      loggerIgnoreBonesUI.i(msg);
      return;
    }

    var now = DateTime.now();
    var log = '$now>  $msg';

    _logs.add(log);

    while (_logs.length > _limit) {
      _logs.remove(0);
    }

    loggerIgnoreBonesUI.i(msg);
  }

  static String allLogs() {
    return get()._allLogs();
  }

  String _allLogs() {
    var allLogs = _logs.join('\n');

    allLogs = allLogs.replaceAll('<', '&lt;');
    allLogs = allLogs.replaceAll('>', '&gt;');

    return allLogs;
  }

  static void clear() {
    return get()._clear();
  }

  void _clear() {
    _logs.clear();
  }

  static bool isShowing() {
    return get()._isShowing();
  }

  bool _isShowing() {
    return querySelector('#UIConsole') != null;
  }

  static void hide() {
    return get()._hide();
  }

  void _hide() {
    var prevConsoleDiv = querySelector('#UIConsole');

    if (prevConsoleDiv != null) {
      prevConsoleDiv.remove();
    }
  }

  static void show() {
    return get()._show();
  }

  DivElement _contentClipboard;

  void _show() {
    _enable();

    _hide();

    var consoleDiv = DivElement();
    consoleDiv.id = 'UIConsole';

    consoleDiv.style
      ..position = 'absolute'
      ..width = '100%'
      ..height = '100%'
      ..left = '0px'
      ..top = '0px'
      ..padding = '6px 6px 7px 6px'
      ..color = '#ffffff'
      ..backgroundColor = 'rgba(0,0,0, 0.90)'
      ..zIndex = '9999999999';

    var contentClipboard = createDivInline();

    contentClipboard.style
      ..width = '0px'
      ..height = '0px'
      ..lineHeight = '0px';

    consoleDiv.children.add(contentClipboard);

    var allLogs = _allLogs();

    var consoleButtons = DivElement();

    var buttonClose = Element.span()..text = '[X]';
    buttonClose.style.cursor = 'pointer';
    buttonClose.onClick.listen((m) => hide());

    var buttonCopy = Element.span()..text = '[Copy All]';
    buttonCopy.style.cursor = 'pointer';
    buttonCopy.onClick.listen((m) => copy());

    var buttonZoomIn = Element.span()..text = '[ + ]';
    buttonZoomIn.style.cursor = 'zoom-in';

    var buttonZoomOut = Element.span()..text = '[ - ]';
    buttonZoomOut.style.cursor = 'zoom-out';

    var buttonClear = Element.span()..text = '[Clear]';
    buttonClear.style.cursor = 'pointer';

    consoleButtons.children.add(buttonClose);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonCopy);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonZoomIn);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonZoomOut);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonClear);

    var consoleText = DivElement();
    consoleText.style.fontSize = '$_fontSize%';
    consoleText.style.overflow = 'scroll';

    var html = '<pre>\n'
        '${allLogs}'
        '</pre>';

    setElementInnerHTML(consoleText, html);

    buttonClear.onClick.listen((m) {
      if (window.confirm('Clear UIConsole?')) {
        clear();
        consoleText.text = '';
      }
    });

    buttonZoomIn.onClick.listen((m) {
      _changeFontSize(consoleText, 1.05);
    });

    buttonZoomOut.onClick.listen((m) {
      _changeFontSize(consoleText, 0.95);
    });

    consoleDiv.children.add(consoleButtons);
    consoleDiv.children.add(consoleText);

    _contentClipboard = contentClipboard;

    document.documentElement.children.add(consoleDiv);
  }

  double _fontSize = 100.0;

  void _changeFontSize(DivElement consoleText, double change) {
    var fontSizeProp = consoleText.style.fontSize;

    var fontSize = fontSizeProp == null || fontSizeProp.isEmpty
        ? 100
        : double.parse(fontSizeProp.replaceFirst('%', ''));
    var size = fontSize * change;

    size = size.toInt().toDouble();

    if (size >= 96 && size <= 104) size = 100.0;

    if (fontSize == size) {
      if (change > 1) {
        size++;
      } else {
        size--;
      }
    }

    if (size < 50) {
      size = 30.0;
    } else if (size > 300) {
      size = 300.0;
    }

    consoleText.style.fontSize = '$size%';

    _fontSize = size;
  }

  static void copy() {
    get()._copy();
  }

  void _copy() {
    var allLogs = _allLogs();

    if (_contentClipboard != null) {
      _contentClipboard.innerHtml = '<pre>${allLogs}</pre>';
      _copyElementToClipboard(_contentClipboard);
      _contentClipboard.text = '';
    }
  }

  void _copyElementToClipboard(Element elem) {
    var selection = window.getSelection();
    var range = document.createRange();

    range.selectNodeContents(elem);
    selection.removeAllRanges();
    selection.addRange(range);

    var selectedText = selection.toString();

    document.execCommand('copy');

    if (selectedText != null) {
      window.getSelection().removeAllRanges();
    }
  }

  static final String BUTTON_ID = 'UIConsole_button';

  static DivElement button([double opacity = 0.20]) {
    enable();

    var elem = createDivInline('[>_]');

    elem.id = BUTTON_ID;

    elem.style
      ..backgroundColor = 'rgba(0,0,0, 0.5)'
      ..color = 'rgba(0,255,0, 0.5)'
      ..fontSize = '14px'
      ..opacity = '$opacity';

    elem.onClick.listen((m) => isShowing() ? hide() : show());

    return elem;
  }

  static void displayButton() {
    var prevElem = querySelector('#$BUTTON_ID');
    if (prevElem != null) return;

    var elem = button(1.0);

    loggerIgnoreBonesUI.i('Button: ${elem.clientHeight}');

    elem.style
      ..position = 'fixed'
      ..left = '0px'
      ..top = '100%'
      ..transform = 'translateY(-15px)'
      ..zIndex = '999999';

    document.body.children.add(elem);
  }
}

/// Tracks and fires events of device orientation changes.
class UIDeviceOrientation extends EventHandlerPrivate {
  static final EVENT_CHANGE_ORIENTATION = 'CHANGE_ORIENTATION';

  static UIDeviceOrientation _instance;

  static UIDeviceOrientation get() {
    _instance ??= UIDeviceOrientation._internal();
    return _instance;
  }

  UIDeviceOrientation._internal() {
    window.onDeviceOrientation.listen(_onChangeOrientation);
  }

  /// Registers [listen] for device orientation changes.
  static void listen(UIEventListener listener) {
    get()._listen(listener);
  }

  void _listen(UIEventListener listener) {
    _registerEventListener(EVENT_CHANGE_ORIENTATION, listener);
  }

  var _lastOrientation;

  void _onChangeOrientation(DeviceOrientationEvent event) {
    var orientation = window.orientation;

    if (_lastOrientation != orientation) {
      _fireEvent(EVENT_CHANGE_ORIENTATION, event, [orientation]);
    }

    _lastOrientation = orientation;
  }

  /// Returns [true] if device is in landscape orientation.
  static bool isLandscape() {
    var orientation = window.orientation;
    if (orientation == null) return false;
    return orientation == -90 || orientation == 90;
  }
}

/// Returns [true] if a `Bones_UI` component is in DOM.
bool isComponentInDOM(dynamic element) {
  if (element == null) return false;

  if (element is Node) {
    return document.body.contains(element);
  } else if (element is UIComponent) {
    return isComponentInDOM(element.renderedElements);
  } else if (element is UIAsyncContent) {
    return isComponentInDOM(element.content);
  } else if (element is List) {
    for (var elem in element) {
      var inDom = isComponentInDOM(elem);
      if (inDom) return true;
    }
    return false;
  }

  return false;
}

/// Returns [true] if [element] type is able to be in DOM.
bool canBeInDOM(dynamic element) {
  if (element == null) return false;

  if (element is Node) {
    return true;
  } else if (element is UIComponent) {
    return true;
  } else if (element is UIAsyncContent) {
    return true;
  } else if (element is List) {
    return true;
  }

  return false;
}

typedef FilterRendered = bool Function(dynamic elem);
typedef FilterElement = bool Function(Element elem);
typedef ForEachElement = void Function(Element elem);
typedef ParametersProvider = Map<String, String> Function();

abstract class UIField<V> {
  V getFieldValue();
}

abstract class UIFieldMap<V> {
  Map<String, V> getFieldMap();
}

typedef UIComponentInstantiator<C extends UIComponent> = C Function(
    Element parent,
    Map<String, DOMAttribute> attributes,
    Node contentHolder,
    List<DOMNode> contentNodes);

typedef UIComponentAttributeParser<T> = T Function(dynamic value);

typedef UIComponentAttributeGetter<C extends UIComponent, T> = T Function(
    C uiComponent);

typedef UIComponentAttributeSetter<C extends UIComponent, T> = void Function(
    C uiComponent, T value);

typedef UIComponentAttributeAppender<C extends UIComponent, T> = void Function(
    C uiComponent, T value);

typedef UIComponentAttributeCleaner<C extends UIComponent, T> = void Function(
    C uiComponent);

class UIComponentAttributeHandler<C extends UIComponent, T> {
  static String normalizeComponentAttributeName(String name) {
    if (name == null) return null;
    name = name.toLowerCase().trim();
    if (name.isEmpty) return null;
    return name;
  }

  final String name;
  final UIComponentAttributeParser<T> parser;

  final UIComponentAttributeGetter<C, T> getter;

  final UIComponentAttributeSetter<C, T> setter;

  final UIComponentAttributeAppender<C, T> appender;

  final UIComponentAttributeCleaner<C, T> cleaner;

  UIComponentAttributeHandler(String name,
      {this.parser,
      this.getter,
      this.setter,
      UIComponentAttributeAppender<C, T> appender,
      UIComponentAttributeCleaner<C, T> cleaner})
      : name = normalizeComponentAttributeName(name),
        appender = appender ?? setter,
        cleaner = cleaner ?? ((c) => setter(c, null)) {
    if (getter == null) throw ArgumentError.notNull('getter');
    if (setter == null) throw ArgumentError.notNull('setter');
  }

  T parse(dynamic value) => parser != null ? parser(value) : value;

  T get(C uiComponent) => getter(uiComponent);

  void set(C uiComponent, dynamic value) {
    var v = parse(value);
    setter(uiComponent, v);
  }

  void append(C uiComponent, dynamic value) {
    var v = parse(value);
    appender(uiComponent, v);
  }

  void clear(C uiComponent) => cleaner(uiComponent);
}

class UIComponentGenerator<C extends UIComponent>
    extends ElementGenerator<Element> {
  @override
  final String tag;
  @override
  final bool hasChildrenElements;

  @override
  final bool usesContentHolder;

  final String generatedTag;

  final DOMAttributeValueSet componentClass;

  final DOMAttributeValueCSS componentStyle;

  final UIComponentInstantiator<C> instantiator;
  final Map<String, UIComponentAttributeHandler> attributes;

  UIComponentGenerator(
      this.tag,
      this.generatedTag,
      String componentClass,
      String componentStyle,
      this.instantiator,
      Iterable<UIComponentAttributeHandler> attributes,
      {bool hasChildrenElements = true,
      bool usesContentHolder = true,
      bool contentAsText = false})
      : componentClass = DOMAttributeValueSet(
            componentClass,
            DOMAttribute.getAttributeDelimiter('class'),
            DOMAttribute.getAttributeDelimiterPattern('class')),
        componentStyle = DOMAttributeValueCSS(componentStyle),
        attributes = Map.fromEntries(
            attributes.map((attr) => MapEntry(attr.name, attr))),
        hasChildrenElements = hasChildrenElements ?? true,
        usesContentHolder = usesContentHolder ?? true {
    if (instantiator == null) throw ArgumentError.notNull('instantiator');
  }

  @override
  Element generate(
      DOMGenerator<Node> domGenerator,
      tag,
      Node parent,
      Map<String, DOMAttribute> attributes,
      Node contentHolder,
      List<DOMNode> contentNodes) {
    var component =
        instantiator(parent, attributes, contentHolder, contentNodes);
    var anySet = component.appendAttributes(attributes.values);

    if (anySet) {
      component.ensureRendered(true);
    } else {
      component.ensureRendered();
    }

    return component.content;
  }

  @override
  bool isGeneratedElement(Node element) {
    if (element is Element) {
      var tag = element.tagName.toLowerCase();
      if (tag != generatedTag) return false;
      var classes = element.classes;
      var match = classes.containsAll(componentClass.asAttributeValues);
      print(classes);
      print('$componentClass -> $match');
      return match;
    } else {
      return false;
    }
  }

  UIComponentAttributeHandler getAttributeHandler(String name) {
    name = UIComponentAttributeHandler.normalizeComponentAttributeName(name);
    if (name == null || name.isEmpty) return null;
    return attributes[name];
  }

  T getAttribute<T>(C uiComponent, String name) {
    var attribute = getAttributeHandler(name);
    return attribute != null ? attribute.get(uiComponent) : null;
  }

  void setAttribute<T>(C uiComponent, String name, dynamic value) {
    var attribute = getAttributeHandler(name);
    if (attribute != null) {
      attribute.set(uiComponent, value);
    }
  }

  void appendAttribute<T>(C uiComponent, String name, dynamic value) {
    var attribute = getAttributeHandler(name);
    if (attribute != null) {
      attribute.append(uiComponent, value);
    }
  }

  void clearAttribute<T>(C uiComponent, String name) {
    var attribute = getAttributeHandler(name);
    if (attribute != null) {
      attribute.set(uiComponent, null);
    }
  }

  @override
  DOMElement revert(DOMGenerator<Node> domGenerator, DOMTreeMap<Node> treeMap,
      DOMElement domParent, Element parent, Element node) {
    if (node == null) return null;
    var attributes = Map.fromEntries(node.attributes.entries);

    var classes = _parseNodeClass(attributes);
    var style = _parseNodeStyle(attributes);

    var domElement =
        DOMElement(tag, attributes: attributes, classes: classes, style: style);

    if (!hasChildrenElements) {
      if (treeMap != null) {
        var mappedDOMNode = treeMap.getMappedDOMNode(node);
        if (mappedDOMNode != null) {
          domElement.add(mappedDOMNode.content);
        }
      } else {
        domElement.add(node.text);
      }
    }

    return domElement;
  }

  String _parseNodeStyle(Map<String, String> attributes) {
    var style = (attributes.remove('style') ?? '').trim();

    var attrComponentCSS = componentStyle.css;

    if (attrComponentCSS.isNoEmpty && style.isNotEmpty) {
      var attrCSS = DOMAttributeValueCSS(style).css;

      for (var cssEntry in attrComponentCSS.entries) {
        var name = cssEntry.name;
        var entry = attrCSS.getEntry(name);

        if (entry == cssEntry) {
          attrCSS.removeEntry(name);
        }
      }

      style = attrCSS.toString();
    }

    if (style != null && style.isEmpty) {
      style == null;
    }

    return style;
  }

  String _parseNodeClass(Map<String, String> attributes) {
    var classes = (attributes.remove('class') ?? '').trim();

    if (componentClass.hasAttributeValue && classes.isNotEmpty) {
      var attributeDelimiter = DOMAttribute.getAttributeDelimiter('class');
      var attrClass = DOMAttributeValueList(classes, attributeDelimiter,
          DOMAttribute.getAttributeDelimiterPattern('class'));

      attrClass.removeAttributeValueEntry('ui-component');
      attrClass
          .removeAttributeValueAllEntries(componentClass.asAttributeValues);

      classes = attrClass.asAttributeValue;
    }

    if (classes != null && classes.isEmpty) {
      classes == null;
    }

    return classes;
  }
}

/// Base class do create `Bones_UI` components.
abstract class UIComponent extends UIEventHandler {
  final UIComponentGenerator _generator;

  static int _globalIDCount = 0;

  final globalID;

  dynamic id;

  UIComponent _parentUIComponent;

  Element _parent;

  Element _content;

  bool _constructing;

  bool get constructing => _constructing;

  UIComponent(Element parent,
      {dynamic componentClass,
      dynamic componentStyle,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic style2,
      bool inline = true,
      bool renderOnConstruction,
      this.id,
      UIComponentGenerator generator})
      : globalID = ++_globalIDCount,
        _parent = parent ?? createDivInline(),
        _generator = generator {
    _constructing = true;
    try {
      _setParentUIComponent(_getUIComponentRenderingByContent(_parent));
      _content = createContentElement(inline);

      configureID();

      configureClasses(classes, classes2, componentClass);
      configureStyle(style, style2, componentStyle);

      configure();

      _parent.children.add(_content);

      renderOnConstruction ??= false;

      if (renderOnConstruction) {
        callRender();
      }
    } finally {
      _constructing = false;
    }
  }

  UIComponent clone() => null;

  Element setParent(Element parent) {
    return _setParentImpl(parent, true);
  }

  Element _setParentImpl(Element parent, bool addToParent) {
    if (parent == null) throw StateError('Null parent');

    if (_content != null) {
      if (identical(_parent, parent)) return _parent;

      _content.remove();

      if (_parent != null) {
        _parent.children.remove(_content);
      }
    }

    _parent = parent;

    if (_content != null && addToParent) {
      _parent.children.add(_content);

      clear();
    }

    if (_parent != null) {
      var parentUI = _getUIComponentRenderingByContent(_parent);

      if (parentUI == null) {
        if (isAnyComponentRendering) {
          _setUIComponentRenderingExtra(this);
        }
      }

      _setParentUIComponent(parentUI);
    }

    return parent;
  }

  final Set<UIComponent> _subUIComponents = {};

  void _setParentUIComponent(UIComponent uiParent) {
    _parentUIComponent = uiParent;

    if (_parentUIComponent != null) {
      _parentUIComponent._subUIComponents.add(this);
    }
  }

  UIComponent get parentUIComponent {
    if (_parentUIComponent != null) return _parentUIComponent;

    var myParentElem = parent;

    var foundParent = _getUIComponentRenderingByContent(myParentElem);

    if (foundParent != null) {
      _setParentUIComponent(foundParent);
    } else {
      var uiRoot = UIRoot.getInstance();
      if (uiRoot == null) return null;

      foundParent = uiRoot.getRenderedElement(
          (e) => e is UIComponent && identical(e._content, myParentElem), true);

      if (foundParent != null && foundParent is UIComponent) {
        _setParentUIComponent(foundParent);
      }
    }

    if (_parentUIComponent != null) {
      _resolve_componentsRenderingExtra();
    }

    return _parentUIComponent;
  }

  bool _showing = true;

  bool get isShowing => _showing;

  String _displayOnHidden;

  void hide() {
    _content.hidden = true;

    if (_showing) {
      _displayOnHidden = _content.style.display;
    }
    _content.style.display = 'none';

    _showing = false;
  }

  void show() {
    _content.hidden = false;

    if (!_showing) {
      _content.style.display = _displayOnHidden;
      _displayOnHidden = null;
    }

    _showing = true;
  }

  bool get isInDOM {
    return isNodeInDOM(_content);
  }

  void configureID() {
    setID(id);
  }

  void setID(dynamic id) {
    if (id != null) {
      var idStr = parseString(id, '').trim();
      if (id is String) {
        id = idStr;
      }

      if (idStr.isNotEmpty) {
        this.id = id;
        _content.id = idStr;
        return;
      }
    }

    this.id = null;

    if (_content.id != null) {
      _content.removeAttribute('id');
    }
  }

  static final RegExp _CLASSES_ENTRY_DELIMITER = RegExp(r'[\s,;]+');

  static List<String> parseClasses(dynamic classes1) =>
      toFlatListOfStrings(classes1,
          delimiter: _CLASSES_ENTRY_DELIMITER, trim: true, ignoreEmpty: true);

  void configureClasses(dynamic classes1,
      [dynamic classes2, dynamic componentClasses]) {
    content.classes.add('ui-component');

    var classesNamesComponent = parseClasses(componentClasses);
    if (classesNamesComponent != null && classesNamesComponent.isNotEmpty) {
      for (var c in classesNamesComponent) {
        if (!content.classes.contains(c)) {
          content.classes.add(c);
        }
      }
    }

    appendClasses(classes1, classes2);
  }

  void appendClasses(dynamic classes1, [dynamic classes2]) {
    var classesNames1 = parseClasses(classes1);
    var classesNames2 = parseClasses(classes2);

    classesNames1.addAll(classesNames2);

    // ignore: omit_local_variable_types
    List<String> classesNamesRemove = List.from(classesNames1);
    classesNamesRemove.retainWhere((s) => s.startsWith('!'));

    classesNames1.removeWhere((s) => s.startsWith('!'));
    if (classesNames1.isNotEmpty) content.classes.addAll(classesNames1);

    if (classesNamesRemove.isNotEmpty) {
      classesNamesRemove =
          classesNamesRemove.map((s) => s.replaceFirst('!', '')).toList();
      content.classes.removeAll(classesNamesRemove);
    }
  }

  static final RegExp _CSS_ENTRY_DELIMITER = RegExp(r'\s*;\s*');

  static List<String> parseStyle(style1) => toFlatListOfStrings(style1,
      delimiter: _CSS_ENTRY_DELIMITER, trim: true, ignoreEmpty: true);

  void configureStyle(dynamic style1,
      [dynamic style2, dynamic componentStyle]) {
    appendStyle(componentStyle, style1, style2);
  }

  void appendStyle(dynamic style1, [dynamic style2, dynamic style3]) {
    var styles1 = parseStyle(style1);
    var styles2 = parseStyle(style2);
    var styles3 = parseStyle(style3);

    styles1.addAll(styles2);
    styles1.addAll(styles3);

    if (styles1.isNotEmpty) {
      var allStyles = styles1.join('; ');

      if (content.style.cssText == '') {
        content.style.cssText = allStyles;
      } else {
        content.style.cssText += allStyles;
      }
    }
  }

  void configure() {}

  Element createContentElement(bool inline) {
    return createDiv(inline);
  }

  Element get parent => _parent;

  Element get content => _content;

  List<Element> getContentChildrenDeep([FilterElement filter]) {
    return _contentChildrenDeepImpl(_content.children, [], filter);
  }

  List<Element> _contentChildrenDeepImpl(List<Element> list, List<Element> deep,
      [FilterElement filter]) {
    if (list == null || list.isEmpty) return deep;

    if (filter != null) {
      for (var elem in list) {
        if (filter(elem)) {
          deep.add(elem);
        }
      }

      for (var elem in list) {
        _contentChildrenDeepImpl(elem.children, deep, filter);
      }
    } else {
      for (var elem in list) {
        deep.add(elem);
      }

      for (var elem in list) {
        _contentChildrenDeepImpl(elem.children, deep);
      }
    }

    return deep;
  }

  Element findInContentChildrenDeep(FilterElement filter) =>
      _findInContentChildrenDeepImpl(_content.children, filter);

  Element _findInContentChildrenDeepImpl(
      List<Element> list, FilterElement filter) {
    if (list == null || list.isEmpty) return null;

    for (var elem in list) {
      if (filter(elem)) return elem;
    }

    for (var elem in list) {
      var found = _findInContentChildrenDeepImpl(elem.children, filter);
      if (found != null) return found;
    }

    return null;
  }

  List _renderedElements;

  List get renderedElements => _renderedElements;

  dynamic getRenderedElement(FilterRendered filter, [bool deep]) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements) {
      if (filter(elem)) return elem;
    }

    deep ??= false;

    if (deep) {
      for (var elem in _renderedElements) {
        if (elem is UIComponent) {
          var found = elem.getRenderedElement(filter, deep);
          if (found != null) {
            return found;
          }
        }
      }
    }

    return null;
  }

  dynamic getRenderedElementById(dynamic id) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        if (elem.id == id) {
          return elem;
        }
      } else if (elem is Element) {
        if (elem.id == id) {
          return elem;
        }
      }
    }

    return null;
  }

  UIComponent getRenderedUIComponentById(dynamic id) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        if (elem.id == id) {
          return elem;
        }
      }
    }

    return null;
  }

  List<UIComponent> getRenderedUIComponentsByIds(List ids) {
    // ignore: omit_local_variable_types
    List<UIComponent> elems = [];

    for (var id in ids) {
      var comp = getRenderedUIComponentById(id);
      if (comp != null) elems.add(comp);
    }

    return elems;
  }

  UIComponent getRenderedUIComponentByType(Type type) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        if (elem.runtimeType == type) {
          return elem;
        }
      }
    }

    return null;
  }

  List<UIComponent> getRenderedUIComponents() {
    if (_renderedElements == null) return [];

    // ignore: omit_local_variable_types
    List<UIComponent> list = [];

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        list.add(elem);
      }
    }

    return list;
  }

  bool _rendered = false;

  bool get isRendered => _rendered;

  void clear() {
    if (!isRendered) return;

    if (_renderedElements != null) {
      for (var e in _renderedElements) {
        if (e is UIComponent) {
          e.delete();
        } else if (e is Element) {
          e.remove();
        }
      }
    }

    var elems = List.from(_content.children);
    elems.forEach((e) => e.remove());

    _content.children.clear();

    _subUIComponents.clear();

    _rendered = false;
  }

  bool __refreshFromExternalCall = false;

  bool get isRefreshFromExternalCall => __refreshFromExternalCall;

  void _refreshInternal() {
    _refreshImpl();
  }

  void refreshInternal() {
    _refreshImpl();
  }

  void refresh() {
    try {
      __refreshFromExternalCall = true;

      _refreshImpl();
    } finally {
      __refreshFromExternalCall = false;
    }
  }

  void _refreshImpl() {
    if (!isRendered) return;
    callRender(true);
  }

  void refreshIfLocaleChanged() {
    try {
      __refreshFromExternalCall = true;

      _refreshIfLocaleChangedImpl();
    } finally {
      __refreshFromExternalCall = false;
    }
  }

  void _refreshIfLocaleChangedImpl() {
    if (!isRendered) return;
    if (localeChangeFromLastRender) {
      UIConsole.log(
          'Locale changed: $_renderLocale -> ${UIRoot.getCurrentLocale()} ; Refreshing...');
      clear();
      callRender();
    }
  }

  void delete() {
    clear();
    content.remove();
  }

  void ensureRendered([bool force]) {
    if (!isRendered) {
      callRender();
    } else if (localeChangeFromLastRender) {
      callRender(true);
    } else if (force ?? false) {
      callRender(true);
    }
  }

  bool isAccessible() {
    return true;
  }

  String deniedAccessRoute() {
    return null;
  }

  void callRenderAsync() {
    Future.microtask(callRender);
  }

  bool get localeChangeFromLastRender {
    var currentLocale = UIRoot.getCurrentLocale();
    return _renderLocale != currentLocale;
  }

  static final Map<Element, UIComponent> _componentsRendering = {};

  static final Map<Element, UIComponent> _componentsRenderingExtra = {};

  static bool get isAnyComponentRendering => _componentsRendering.isNotEmpty;

  static void _setUIComponentRendering(UIComponent component) {
    if (component == null) return;
    _componentsRendering[component.content] = component;
  }

  static void _setUIComponentRenderingExtra(UIComponent component) {
    if (component == null) return;
    _componentsRenderingExtra[component.content] = component;
  }

  static void _clearUIComponentRendering(UIComponent component) {
    if (component == null) return;
    _componentsRendering.remove(component.content);
    if (_componentsRendering.isEmpty) {
      _componentsRenderingExtra.clear();
    }
  }

  static bool _resolve_componentsRenderingExtra_call = false;

  static void _resolve_componentsRenderingExtra() {
    if (_componentsRenderingExtra.isEmpty) return;

    if (_resolve_componentsRenderingExtra_call) return;
    _resolve_componentsRenderingExtra_call = true;

    try {
      for (var uiComp in _componentsRenderingExtra.values) {
        try {
          uiComp.parentUIComponent;
        } catch (e, s) {
          logger.e('Error resolving parent UIComponent', e, s);
        }
      }
    } finally {
      _resolve_componentsRenderingExtra_call = false;
    }
  }

  static UIComponent _getUIComponentRenderingByContent(Element content,
      [bool findUIRootTree = true]) {
    if (content == null) return null;

    var parent = _componentsRendering[content];
    parent ??= _componentsRenderingExtra[content];

    if (parent == null && findUIRootTree) {
      var uiRoot = UIRoot.getInstance();
      if (uiRoot != null) {
        parent = uiRoot.findUIComponentByContent(content);
        //parent ??= uiRoot.findUIComponentByChild(content);
      }
    }

    return parent;
  }

  UIComponent findUIComponentByContent(Element content) {
    if (content == null) return null;
    if (identical(content, _content)) return this;

    if (_renderedElements == null || _renderedElements.isEmpty) return null;

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        var uiComp = elem.findUIComponentByContent(content);
        if (uiComp != null) return uiComp;
      }
    }

    for (var elem in _subUIComponents) {
      var uiComp = elem.findUIComponentByChild(content);
      if (uiComp != null) return uiComp;
    }

    for (var elem in _content.children) {
      if (identical(content, elem)) {
        return this;
      }
    }

    return null;
  }

  UIComponent findUIComponentByChild(Element child) {
    if (child == null) return null;
    if (identical(child, _content)) return this;

    for (var elem in _content.children) {
      if (identical(child, elem)) {
        return this;
      }
    }

    if (_renderedElements != null && _renderedElements.isNotEmpty) {
      for (var elem in _renderedElements) {
        if (elem is UIComponent) {
          var uiComp = elem.findUIComponentByChild(child);
          if (uiComp != null) return uiComp;
        }
      }
    }

    for (var elem in _subUIComponents) {
      var uiComp = elem.findUIComponentByChild(child);
      if (uiComp != null) return uiComp;
    }

    var deepChild = findInContentChildrenDeep((elem) => identical(child, elem));
    if (deepChild != null) return this;

    return null;
  }

  bool _rendering = false;

  bool get isRendering => _rendering;

  bool _callingRender = false;

  void callRender([bool clear]) {
    if (_callingRender) return;

    _callingRender = true;
    try {
      _callRenderImpl(clear);
    } catch (e, s) {
      UIConsole.error('Error calling _callRenderImpl()', e, s);
    } finally {
      _callingRender = false;
    }
  }

  void _callRenderImpl(bool clear) {
    _setUIComponentRendering(this);

    if (clear ?? false) {
      this.clear();
    }

    _rendering = true;
    try {
      _doRender();
    } finally {
      _rendering = false;

      _resolve_componentsRenderingExtra();

      try {
        _notifyRendered();
      } catch (e, s) {
        UIConsole.error('$this _notifyRendered error', e, s);
      }

      try {
        _notifyRenderToParent();
      } catch (e, s) {
        UIConsole.error('$this _notifyRefreshToParent error', e, s);
      }

      _clearUIComponentRendering(this);
    }
  }

  String _renderLocale;

  void _doRender() {
    var currentLocale = UIRoot.getCurrentLocale();

    _renderLocale = currentLocale;

    try {
      if (!isAccessible()) {
        UIConsole.log('Not accessible: $this');

        _rendered = true;

        var redirectToRoute = deniedAccessRoute();

        if (redirectToRoute != null) {
          if (!isInDOM) {
            UIConsole.log(
                '[NOT IN DOM] Denied access to route: $redirectToRoute');
          } else {
            UIConsole.log('Denied access to route: $redirectToRoute');
            UINavigator.navigateTo(redirectToRoute);
          }
        }

        return;
      }
    } catch (e, s) {
      UIConsole.error('$this isAccessible error', e, s);
      return;
    }

    try {
      _rendered = true;

      var rendered = render();

      var renderedElements = toContentElements(content, rendered);

      _renderedElements = renderedElements;

      _ensureAllRendered(renderedElements);
    } catch (e, s) {
      UIConsole.error('$this render error', e, s);
    }

    try {
      _parseAttributesPosRender(content.children);
    } catch (e, s) {
      UIConsole.error('$this _parseAttributesPosRender(...) error', e, s);
    }

    _callPosRender();

    _markRenderTime();
  }

  void _ensureAllRendered(List elements) {
    if (elements == null || elements.isEmpty) return;

    for (var e in elements) {
      if (e is UIComponent) {
        e.ensureRendered();
      } else if (e is Element) {
        var subElements = [];

        for (var child in e.children) {
          var uiComponent = _getUIComponentRenderingByContent(child, false);

          if (uiComponent != null) {
            uiComponent.ensureRendered();
          } else if (child.children.isNotEmpty) {
            subElements.add(child);
          }
        }

        _ensureAllRendered(subElements);
      }
    }
  }

  final EventStream<UIComponent> onRender = EventStream();

  void _notifyRendered() {
    Future.delayed(Duration(milliseconds: 1), () => onRender.add(this));
  }

  void _notifyRenderToParent() {
    var parentUIComponent = this.parentUIComponent;

    if (parentUIComponent == null) {
      return;
    }

    parentUIComponent._call_onChildRendered(this);
  }

  void _call_onChildRendered(UIComponent child) {
    try {
      onChildRendered(this);
    } catch (e, s) {
      loggerIgnoreBonesUI.e(
          'Error calling onChildRendered() for instance: $this', e, s);
    }
  }

  void onChildRendered(UIComponent child) {}

  EventStream<dynamic> onChange = EventStream();

  static int _lastRenderTime;

  static bool _renderFinished = true;

  static void _markRenderTime() {
    _lastRenderTime = DateTime.now().millisecondsSinceEpoch;
    _renderFinished = false;
    _scheduleCheckFinishedRendered();
  }

  static void _scheduleCheckFinishedRendered() {
    Future.delayed(Duration(milliseconds: 300), _checkFinishedRendered);
  }

  static void _checkFinishedRendered() {
    if (_renderFinished) return;

    var now = DateTime.now().millisecondsSinceEpoch;
    var delay = now - _lastRenderTime;

    if (delay > 100) {
      _notifyFinishRendered();
    } else {
      _scheduleCheckFinishedRendered();
    }
  }

  static void _notifyFinishRendered() {
    if (_renderFinished) return;
    _renderFinished = true;

    if (UILayout.someInstanceNeedsRefresh()) {
      UILayout.refreshAll();
    } else {
      UILayout.checkInstances();
    }

    var uiRoot = UIRoot.getInstance();

    uiRoot.onFinishRender.add(uiRoot);
  }

  dynamic render();

  void _callPosRender() {
    try {
      posRender();
    } catch (e, s) {
      UIConsole.error('$this posRender error', e, s);
    }

    connectDataSource();
  }

  void posRender() {}

  List toContentElements(Element content, dynamic rendered,
      [bool append = false, bool parseAttributes = true]) {
    try {
      var list = _toContentElementsImpl(content, rendered, append);

      if (parseAttributes) {
        _parseAttributes(content.children);
      }

      return list;
    } catch (e, s) {
      logger.e(
          'Error converting rendered to content elements: $rendered', e, s);
      return [];
    }
  }

  static bool isRenderable(dynamic element) {
    if (element == null) return false;
    return element is Element ||
        element is UIContent ||
        element is UIAsyncContent;
  }

  static dynamic copyRenderable(dynamic element, [dynamic def]) {
    if (element is String) return element;

    if (element is UIComponent) {
      var clone = element.clone();
      return clone ?? (isRenderable(def) ? def : null);
    } else if (isRenderable(element)) {
      return element;
    } else {
      return null;
    }
  }

  List toRenderableList(dynamic list) {
    List renderableList;

    if (list != null) {
      if (list is List) {
        renderableList = list;
      } else if (list is Iterable) {
        renderableList = List.from(list);
      } else if (list is Map) {
        renderableList = [];

        for (var entry in list.entries) {
          var key = entry.key;
          var val = entry.value;
          if (isRenderable(key)) {
            renderableList.add(key);
          }
          if (isRenderable(val) || isHTMLElement(val)) {
            renderableList.add(val);
          }
        }
      } else {
        renderableList = [list];
      }
    }

    return renderableList;
  }

  List _toContentElementsImpl(Element content, dynamic rendered, bool append) {
    var renderableList = toRenderableList(rendered);

    if (renderableList != null) {
      if (isListOfStrings(renderableList)) {
        var html = renderableList.join('\n');

        if (append) {
          appendElementInnerHTML(content, html);
        } else {
          setElementInnerHTML(content, html);
        }

        var list = List.from(content.childNodes);
        return list;
      } else {
        for (var value in renderableList) {
          _removeFromContent(value);
        }

        var renderedList2 = [];

        var prevElemIndex = -1;

        for (var value in renderableList) {
          prevElemIndex =
              _buildRenderList(content, value, renderedList2, prevElemIndex);
        }

        return renderedList2;
      }
    } else {
      return List.from(content.childNodes);
    }
  }

  static final UIDOMGenerator _domGenerator = UIDOMGenerator();

  static UIDOMGenerator get domGenerator => _domGenerator;

  static bool registerGenerator(UIComponentGenerator generator) {
    if (generator == null) throw ArgumentError.notNull('generator');
    return _domGenerator.registerElementGenerator(generator);
  }

  int _buildRenderList(
      Element content, dynamic value, List renderedList, int prevElemIndex) {
    if (value == null) return prevElemIndex;

    if (value is DOMNode) {
      var domNode = value as DOMNode;
      value = domNode.buildDOM(generator: _domGenerator, parent: content);
    }

    if (value is Node) {
      var idx = content.nodes.indexOf(value);

      if (idx < 0) {
        content.nodes.add(value);
        idx = content.nodes.indexOf(value);
      }

      prevElemIndex = idx;
      renderedList.add(value);
    } else if (value is UIComponent) {
      if (value.parent != content) {
        value._setParentImpl(content, false);
      }

      var idx = content.nodes.indexOf(value.content);

      if (idx < 0) {
        content.children.add(value.content);
        idx = content.nodes.indexOf(value.content);
      } else if (idx < prevElemIndex) {
        value.content.remove();
        content.children.add(value.content);
        idx = content.nodes.indexOf(value.content);
      }

      prevElemIndex = idx;
      renderedList.add(value);
    } else if (value is UIAsyncContent) {
      if (!value.isLoaded || value.hasAutoRefresh) {
        value.onLoadContent.listen((c) => refresh(), singletonIdentifier: this);
      }

      if (value.isExpired) {
        value.refreshAsync();
      } else if (value.isWithError) {
        if (value.hasAutoRefresh) {
          value.reset();
        }
      }

      prevElemIndex =
          _buildRenderList(content, value.content, renderedList, prevElemIndex);
    } else if (value is List) {
      for (var elem in value) {
        prevElemIndex =
            _buildRenderList(content, elem, renderedList, prevElemIndex);
      }
    } else if (value is String) {
      if (prevElemIndex < 0) {
        setElementInnerHTML(content, value);
        prevElemIndex = content.nodes.length - 1;

        renderedList.addAll(content.nodes);
      } else {
        var preAppendSize = content.nodes.length;

        appendElementInnerHTML(content, value);

        var appendedElements =
            content.nodes.sublist(preAppendSize, content.nodes.length);

        if (prevElemIndex == preAppendSize - 1) {
          prevElemIndex = content.nodes.length - 1;
        } else {
          if (appendedElements.isNotEmpty) {
            for (var elem in appendedElements) {
              elem.remove();
            }

            var restDyn = copyList(content.nodes.length >= prevElemIndex
                ? content.nodes.sublist(prevElemIndex + 1)
                : null);

            // ignore: omit_local_variable_types
            List<Node> rest = restDyn.cast();

            for (var elem in rest) {
              elem.remove();
            }

            appendedElements.forEach((n) => content.append(n));
            rest.forEach((n) => content.append(n));

            prevElemIndex = content.nodes.indexOf(appendedElements[0]);
          }
        }

        renderedList.addAll(appendedElements);
      }
    } else if (value is Function) {
      try {
        var result = value();
        prevElemIndex =
            _buildRenderList(content, result, renderedList, prevElemIndex);
      } catch (e, s) {
        UIConsole.error('Error calling function: $value', e, s);
      }
    } else {
      UIConsole.log("Bones_UI: Can't render element of type");
      UIConsole.log(value);

      throw UnsupportedError(
          "Bones_UI: Can't render element of type: ${value.runtimeType}");
    }

    return prevElemIndex;
  }

  void _removeFromContent(dynamic value) {
    if (value == null) return;

    if (value is Element) {
      value.remove();
    } else if (value is UIComponent) {
      if (value.isRendered) {
        value.content.remove();
      }
    } else if (value is UIAsyncContent) {
      _removeFromContent(value.loadingContent);
      _removeFromContent(value.content);
    } else if (value is List) {
      for (var val in value) {
        _removeFromContent(val);
      }
    }
  }

  void _parseAttributes(List list) {
    if (list == null || list.isEmpty) return;

    for (var elem in list) {
      if (elem is Element) {
        _parseNavigate(elem);
        _parseAction(elem);
        _parseEvents(elem);
        _parseDataSource(elem);

        try {
          _parseAttributes(elem.children);
        } catch (e) {
          UIConsole.error('Error parsing attributes for element: $elem', e);
        }
      }
    }
  }

  void _parseAttributesPosRender(List list) {
    if (list == null || list.isEmpty) return;

    for (var elem in list) {
      if (elem is Element) {
        try {
          _parseUiLayout(elem);
        } catch (e) {
          UIConsole.error('Error parsing attributes for element: $elem', e);
        }

        try {
          _parseAttributesPosRender(elem.children);
        } catch (e) {
          UIConsole.error('Error parsing attributes for element: $elem', e);
        }
      }
    }
  }

  void _parseNavigate(Element elem) {
    var navigateRoute = getElementAttribute(elem, 'navigate');

    if (navigateRoute != null && navigateRoute.isNotEmpty) {
      UINavigator.navigateOnClick(elem, navigateRoute);
    }
  }

  void _parseDataSource(Element content) {
    var dataSourceCall = getElementAttribute(content, 'data-source');

    if (dataSourceCall != null && dataSourceCall.isNotEmpty) {
      this.dataSourceCall = dataSourceCall;
    }
  }

  DataSourceCall _dataSourceCall;

  bool get hasDataSource => _dataSourceCall != null;

  DataSource get dataSource =>
      _dataSourceCall != null ? _dataSourceCall.dataSource : null;

  DataSourceCall get dataSourceCall => _dataSourceCall;

  set dataSourceCall(dynamic daraSourceCall) {
    _dataSourceCall = DataSourceCall.from(daraSourceCall);
  }

  String get dataSourceCallString =>
      _dataSourceCall != null ? _dataSourceCall.toString() : '';

  void connectDataSource() {
    refreshDataSource();
  }

  void refreshDataSource() {
    if (!hasDataSource) return;

    var cachedResponse = _dataSourceCall.cachedCall();

    if (cachedResponse != null) {
      applyData(cachedResponse);
    } else {
      _dataSourceCall.call().then((result) {
        applyData(result);
      });
    }
  }

  bool applyData(dynamic data) {
    var changed = setData(data);

    if (changed) {
      ensureRendered(true);
    }

    return changed;
  }

  bool setData(dynamic data) {
    print('SET DATA: $data');
    return false;
  }

  String _normalizeComponentAttributeName(String name) {
    if (name == null) return null;
    name = name.toLowerCase().trim();
    if (name.isEmpty) return null;
    return name;
  }

  static final RegExp _VALUE_DELIMITER_GENERIC = RegExp(r'[\s,;]+');

  static List<String> parseAttributeValueAsStringList(dynamic value,
          [Pattern delimiter]) =>
      parseStringFromInlineList(value, delimiter ?? _VALUE_DELIMITER_GENERIC);

  static String parseAttributeValueAsString(dynamic value,
      [String delimiter, Pattern delimiterPattern]) {
    var list = parseAttributeValueAsStringList(value, delimiterPattern);
    if (list.isEmpty) return '';
    delimiter ??= ' ';
    return list.length == 1 ? list.single : list.join(delimiter);
  }

  bool setAttributes(Iterable<DOMAttribute> attributes) {
    if (attributes == null || attributes.isEmpty) return true;

    var anySet = false;
    for (var attr in attributes) {
      var wasSet =
          setAttribute(attr.name, attr.isList ? attr.values : attr.value);
      if (wasSet) {
        anySet = true;
      }
    }
    return anySet;
  }

  bool appendAttributes(Iterable<DOMAttribute> attributes) {
    if (attributes == null || attributes.isEmpty) return false;

    var anySet = false;
    for (var attr in attributes) {
      var wasSet =
          appendAttribute(attr.name, attr.isList ? attr.values : attr.value);
      if (wasSet) {
        anySet = true;
      }
    }
    return anySet;
  }

  dynamic getAttribute(String name) {
    name = _normalizeComponentAttributeName(name);
    if (name == null) return null;

    switch (name) {
      case 'style':
        return content.style.cssText;
      case 'class':
        return content.classes.join(' ');
      case 'navigate':
        return UINavigator.getNavigateOnClick(content);
      case 'data-source':
        return dataSourceCallString;
      default:
        return _generator != null ? _generator.getAttribute(this, name) : null;
    }
  }

  static final RegExp _PATTERN_STYLE_DELIMITER = RegExp(r'\s*;\s*');

  bool setAttribute(String name, dynamic value) {
    if (value == null) {
      return clearAttribute(name);
    }

    name = _normalizeComponentAttributeName(name);
    if (name == null) return false;

    switch (name) {
      case 'style':
        {
          var valueCSS = parseAttributeValueAsString(
              value, '; ', _PATTERN_STYLE_DELIMITER);
          content.style.cssText = valueCSS;
          return true;
        }
      case 'class':
        {
          content.classes.clear();
          content.classes.addAll(parseAttributeValueAsStringList(value));
          return true;
        }
      case 'navigate':
        {
          UINavigator.navigateOnClick(content, value);
          return true;
        }
      case 'data-source':
        {
          dataSourceCall = parseString(value);
          return true;
        }
      default:
        {
          if (_generator != null) {
            _generator.setAttribute(this, name, value);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  bool appendAttribute(String name, dynamic value) {
    name = _normalizeComponentAttributeName(name);
    if (name == null) return false;

    switch (name) {
      case 'style':
        {
          appendStyle(value);
          return true;
        }
      case 'class':
        {
          appendClasses(value);
          return true;
        }
      case 'id':
        {
          setID(value);
          return true;
        }
      case 'navigate':
        {
          UINavigator.navigateOnClick(content, value);
          return true;
        }
      case 'data-source':
        {
          dataSourceCall = parseString(value);
          return true;
        }
      default:
        {
          if (_generator != null) {
            _generator.appendAttribute(this, name, value);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  bool clearAttribute(String name) {
    name = _normalizeComponentAttributeName(name);
    if (name == null) return false;

    switch (name) {
      case 'style':
        {
          content.style.cssText = '';
          return true;
        }
      case 'class':
        {
          content.classes.clear();
          return true;
        }
      case 'navigate':
        {
          UINavigator.clearNavigateOnClick(content);
          return true;
        }
      case 'data-source':
        {
          dataSourceCall = null;
          return true;
        }
      default:
        {
          if (_generator != null) {
            _generator.clearAttribute(this, name);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  Element getFieldElement(String fieldName) => findInContentChildrenDeep((e) {
        if (e is Element) {
          var fieldValue = getElementAttribute(e, 'field');
          return fieldValue == fieldName;
        }
        return false;
      });

  Map<String, Element> getFieldsElementsMap({List<String> ignore}) {
    ignore ??= [];

    var fieldsElements = getFieldsElements();

    var map = <String, Element>{};

    for (var elem in fieldsElements) {
      var fieldName = getElementAttribute(elem, 'field');
      if (!ignore.contains(fieldName)) {
        if (map.containsKey(fieldName)) {
          var elemValue = parseElementValue(map[fieldName], null, false);

          if (isEmptyObject(elemValue)) {
            var value = parseElementValue(elem, null, false);
            if (isNotEmptyObject(value)) {
              map[fieldName] = elem;
            }
          }
        } else {
          map[fieldName] = elem;
        }
      }
    }

    return map;
  }

  bool clearContent() {
    content.nodes.clear();
    return true;
  }

  bool setContentNodes(List<Node> nodes) {
    content.nodes.clear();
    content.nodes.addAll(nodes);
    return true;
  }

  bool appendToContent(List<Node> nodes) {
    content.nodes.addAll(nodes);
    return true;
  }

  List<Element> getFieldsElements() =>
      _contentChildrenDeepImpl(content.children, [], (e) {
        if (e is Element) {
          var fieldValue = getElementAttribute(e, 'field');
          return fieldValue != null && fieldValue.isNotEmpty;
        }
        return false;
      });

  static String parseElementValue(Element element,
      [UIComponent parentComponent, bool allowTextAsValue = true]) {
    UIComponent uiComponent;

    if (parentComponent != null) {
      uiComponent = parentComponent.findUIComponentByChild(element);
    } else {
      uiComponent = UIRoot.getInstance().findUIComponentByChild(element);
    }

    if (uiComponent is UIField) {
      var uiField = uiComponent as UIField;
      return MapProperties.toStringValue(uiField.getFieldValue());
    } else if (element is TextAreaElement) {
      return element.value;
    } else if (element is SelectElement) {
      var selected = element.selectedOptions;
      if (selected == null || selected.isEmpty) return '';
      return MapProperties.toStringValue(selected.map((opt) => opt.value));
    } else if (element is FileUploadInputElement) {
      var files = element.files;
      if (files != null && files.isNotEmpty) {
        return MapProperties.toStringValue(files.map((f) => f.name));
      }
    }

    if (element is InputElement) {
      return element.value;
    } else {
      var value = element.getAttribute('field_value');
      if (isEmptyObject(value) && allowTextAsValue) {
        value = element.text;
      }
      return value;
    }
  }

  Map<String, String> getFields({List<String> ignore}) =>
      getFieldsElementsMap(ignore: ignore)
          .map((k, v) => MapEntry(k, parseElementValue(v, this)));

  String getField(String fieldName) {
    var fieldElem = getFieldElement(fieldName);
    if (fieldElem == null) return null;
    return parseElementValue(fieldElem, this);
  }

  Map<String, dynamic> _renderedFieldsValues;

  dynamic getPreviousRenderedFieldValue(String fieldName) =>
      _renderedFieldsValues != null ? _renderedFieldsValues[fieldName] : null;

  void setField(String fieldName, dynamic value) {
    var fieldElem = getFieldElement(fieldName);
    if (fieldElem == null) return;

    var valueStr = value != null ? '$value' : null;

    _renderedFieldsValues ??= {};
    _renderedFieldsValues[fieldName] = valueStr;

    if (fieldElem is InputElement) {
      fieldElem.value = valueStr;
    } else {
      fieldElem.text = valueStr;
    }
  }

  void updateRenderedFieldValue(String fieldName) {
    var fieldElem = getFieldElement(fieldName);
    if (fieldElem == null) return;

    var value = parseElementValue(fieldElem, this);

    _renderedFieldsValues ??= {};
    _renderedFieldsValues[fieldName] = value;
  }

  void updateRenderedFieldElementValue(Element fieldElem) {
    if (fieldElem == null) return;

    var fieldName = fieldElem.getAttribute('field');
    if (fieldName == null || fieldName.isEmpty) return;

    var value = parseElementValue(fieldElem, this);

    _renderedFieldsValues ??= {};
    _renderedFieldsValues[fieldName] = value;
  }

  bool hasEmptyField() => getFieldsElementsMap().isEmpty;

  List<String> getFieldsNames() => List.from(getFieldsElementsMap().keys);

  bool isEmptyField(String fieldName) {
    var fieldElement = getFieldElement(fieldName);
    var val = parseElementValue(fieldElement, this);
    return val == null || val.toString().isEmpty;
  }

  List<String> getEmptyFields() {
    var fields = getFields();
    fields.removeWhere((k, v) => (v != null && v.isNotEmpty));
    return List.from(fields.keys);
  }

  int forEachFieldElement(ForEachElement f) {
    var count = 0;

    for (var elem in getFieldsElements()) {
      f(elem);
      count++;
    }

    return count;
  }

  int forEachEmptyFieldElement(ForEachElement f) {
    var count = 0;

    var list = getEmptyFields();
    for (var fieldName in list) {
      var elem = getFieldElement(fieldName);
      if (elem != null) {
        f(elem);
        count++;
      }
    }

    return count;
  }

  void _parseAction(Element elem) {
    var actionValue = getElementAttribute(elem, 'action');

    if (actionValue != null && actionValue.isNotEmpty) {
      elem.onClick.listen((e) => action(actionValue));
    }
  }

  void action(String action) {
    UIConsole.log('action: $action');
  }

  void _parseUiLayout(Element elem) {
    var uiLayout = getElementAttribute(elem, 'uiLayout');

    if (uiLayout != null) {
      UILayout(this, elem, uiLayout);
    }
  }

  void _parseEvents(Element elem) {
    _parseOnEventKeyPress(elem);
    _parseOnEventClick(elem);
  }

  void _parseOnEventKeyPress(Element elem) {
    var keypress = getElementAttribute(elem, 'onEventKeyPress');

    if (keypress != null && keypress.isNotEmpty) {
      var parts = keypress.split(':');
      var key = parts[0].trim();
      var actionType = parts[1];

      if (key == '*') {
        elem.onKeyPress.listen((e) {
          action(actionType);
        });
      } else {
        elem.onKeyPress.listen((e) {
          if (e.key == key || e.keyCode.toString() == key) {
            action(actionType);
          }
        });
      }
    }
  }

  void _parseOnEventClick(Element elem) {
    var click = getElementAttribute(elem, 'onEventClick');

    if (click != null && click.isNotEmpty) {
      elem.onClick.listen((e) {
        action(click);
      });
    }
  }
}

abstract class _ElementGenerator extends ElementGenerator<Node> {
  void setElementAttributes(
      Element element, Map<String, DOMAttribute> attributes) {
    element.classes.add(tag);

    var attrClass = attributes['class'];

    if (attrClass != null && attrClass.valueLength > 0) {
      element.classes.addAll(attrClass.values);
    }

    var attrStyle = attributes['style'];

    if (attrStyle != null && attrStyle.valueLength > 0) {
      var prevCssText = element.style.cssText;
      if (prevCssText == '') {
        element.style.cssText = attrStyle.value;
      } else {
        var cssText2 = '$prevCssText; ${attrStyle.value} ;';
        element.style.cssText = cssText2;
      }
    }
  }
}

class _BUIElementGenerator extends _ElementGenerator {
  @override
  final String tag = 'bui';

  @override
  DivElement generate(
      DOMGenerator domGenerator,
      String tag,
      Node parent,
      Map<String, DOMAttribute> attributes,
      Node contentHolder,
      List<DOMNode> contentNodes) {
    var buiElement = DivElement();

    setElementAttributes(buiElement, attributes);

    buiElement.nodes.addAll(contentHolder.nodes);

    return buiElement;
  }

  @override
  bool isGeneratedElement(Node element) {
    return element is DivElement && element.classes.contains(tag);
  }

  @override
  DOMElement revert(DOMGenerator domGenerator, DOMTreeMap treeMap,
      DOMElement domParent, Node parent, Node node) {
    if (node is DivElement) {
      var bui =
          $tag(tag, classes: node.classes.join(' '), style: node.style.cssText);

      if (treeMap != null) {
        var mappedDOMNode = treeMap.getMappedDOMNode(node);
        if (mappedDOMNode != null) {
          bui.add(mappedDOMNode.content);
        }
      } else {
        bui.add(node.text);
      }

      return bui;
    } else {
      return null;
    }
  }
}

class _UITemplateElementGenerator extends _ElementGenerator {
  final DOMGenerator<Node> domGenerator;

  _UITemplateElementGenerator(this.domGenerator);

  @override
  final String tag = 'ui-template';

  @override
  bool get hasChildrenElements => false;

  @override
  bool get usesContentHolder => false;

  @override
  Element generate(
      DOMGenerator domGenerator,
      String tag,
      Node parent,
      Map<String, DOMAttribute> attributes,
      Node contentHolder,
      List<DOMNode> contentNodes) {
    var element = DivElement();

    setElementAttributes(element, attributes);

    var html = contentNodes.map((e) => e.buildHTML(withIndent: true)).join('');

    if (html.contains('{{')) {
      var t = Template(html, lenient: true);
      var context = getTemplateVariables();
      html = t.renderString(context);
    }

    var domElement = $htmlRoot(element.outerHtml);

    domGenerator.addChildToElement(parent, element);
    domGenerator.generateFromHTML(html,
        domParent: domElement, parent: element, finalizeTree: false);

    return element;
  }

  Map<String, dynamic> getTemplateVariables() {
    if (domGenerator.domContext == null) return {};

    var vars = domGenerator.domContext.variables;

    deepReplaceValues(vars, (c, k, v) {
      if (v is Function) {
        return true;
      } else {
        return false;
      }
    }, (c, k, v) {
      return v();
    });

    return vars;
  }

  @override
  bool isGeneratedElement(Node element) {
    return element is DivElement && element.classes.contains(tag);
  }

  @override
  DOMElement revert(DOMGenerator domGenerator, DOMTreeMap treeMap,
      DOMElement domParent, Node parent, Node node) {
    if (node is DivElement) {
      var domElement =
          $tag(tag, classes: node.classes.join(' '), style: node.style.cssText);

      if (treeMap != null) {
        var mappedDOMNode = treeMap.getMappedDOMNode(node);
        if (mappedDOMNode != null) {
          domElement.add(mappedDOMNode.content);
        }
      } else {
        domElement.add(node.text);
      }

      return domElement;
    } else {
      return null;
    }
  }
}

/// A [DOMGenerator] (from package `dom_builder`)
/// able to generate [Element] (from `dart:html`).
class UIDOMGenerator extends DOMGeneratorDartHTMLImpl {
  UIDOMGenerator() {
    registerElementGenerator(_BUIElementGenerator());
    registerElementGenerator(_UITemplateElementGenerator(this));

    domContext = DOMContext();
    _setupContextVariables();
  }

  void _setupContextVariables() {
    domContext.variables = {
      'routes': () {
        return UINavigator.navigableRoutes;
      }
    };
  }

  @override
  DOMTreeMap<Node> createGenericDOMTreeMap() => createDOMTreeMap();

  @override
  bool canHandleExternalElement(externalElement) {
    if (externalElement is List) {
      return listMatchesAll(externalElement, canHandleExternalElement);
    } else if (externalElement is UIComponent) {
      return true;
    }

    return super.canHandleExternalElement(externalElement);
  }

  @override
  List<Node> addExternalElementToElement(Node element, externalElement) {
    if (externalElement is List) {
      if (externalElement.isEmpty) return null;
      var children = <Node>[];
      for (var elem in externalElement) {
        var child = addExternalElementToElement(element, elem);
        children.addAll(child);
      }
      return children;
    } else if (externalElement is UIComponent) {
      var component = externalElement;
      var componentContent = component.content;

      if (element is Element) {
        element.children.add(componentContent);
        component.setParent(element);
        component.ensureRendered();
        return [componentContent];
      }

      return null;
    }

    return super.addExternalElementToElement(element, externalElement);
  }
}

/// A `Bones_UI` component for navigable contents by routes.
abstract class UINavigableContent extends UINavigableComponent {
  /// Optional top margin (in px) for the content.
  int topMargin;

  UINavigableContent(Element parent, List<String> routes,
      {this.topMargin,
      dynamic classes,
      dynamic classes2,
      bool inline = true,
      bool renderOnConstruction = false})
      : super(parent, routes,
            classes: classes,
            classes2: classes2,
            inline: inline,
            renderOnConstruction: renderOnConstruction);

  @override
  dynamic render() {
    // ignore: omit_local_variable_types
    List allRendered = [];

    if (topMargin != null && topMargin > 0) {
      var divTopMargin = Element.div();
      divTopMargin.style.width = '100%';
      divTopMargin.style.height = '${topMargin}px';

      allRendered.add(divTopMargin);
    }

    var headRendered = renderRouteHead(currentRoute, _currentRouteParameters);
    var contentRendered = renderRoute(currentRoute, _currentRouteParameters);
    var footRendered = renderRouteFoot(currentRoute, _currentRouteParameters);

    addAllToList(allRendered, headRendered);
    addAllToList(allRendered, contentRendered);
    addAllToList(allRendered, footRendered);

    if (_findRoutes != null && _findRoutes) {
      _updateRoutes();
    }

    return allRendered;
  }

  /// Called to render the head of the content.
  dynamic renderRouteHead(String route, Map<String, String> parameters) {
    return null;
  }

  /// Called to render the footer of the content.
  dynamic renderRouteFoot(String route, Map<String, String> parameters) {
    return null;
  }
}

/// Base class for content components.
abstract class UIContent extends UIComponent {
  /// Optional top margin (in px) for the content.
  int topMargin;

  UIContent(Element parent,
      {this.topMargin,
      dynamic classes,
      dynamic classes2,
      bool inline = true,
      bool renderOnConstruction})
      : super(parent,
            classes: classes,
            classes2: classes2,
            inline: inline,
            renderOnConstruction: renderOnConstruction);

  @override
  List render() {
    // ignore: omit_local_variable_types
    List allRendered = [];

    if (topMargin != null && topMargin > 0) {
      var divTopMargin = Element.div();
      divTopMargin.style.width = '100%';
      divTopMargin.style.height = '${topMargin}px';

      allRendered.add(divTopMargin);
    }

    var headRendered = renderHead();
    var contentRendered = renderContent();
    var footRendered = renderFoot();

    addAllToList(allRendered, headRendered);
    addAllToList(allRendered, contentRendered);
    addAllToList(allRendered, footRendered);

    return allRendered;
  }

  /// Called to render the head of the content.
  dynamic renderHead() {
    return null;
  }

  /// Called to render the content.
  dynamic renderContent();

  /// Called to render the footer of the content.
  dynamic renderFoot() {
    return null;
  }
}

class _Content {
  final dynamic content;

  int status;

  _Content(this.content, [this.status = 0]);

  dynamic _contentForDOM;

  dynamic get contentForDOM {
    _contentForDOM ??= _ensureElementForDOM(content);
    return _contentForDOM;
  }
}

dynamic _ensureElementForDOM(dynamic element) {
  if (_isElementForDOM(element)) {
    return element;
  }

  if (element is String) {
    if (element.contains('<') && element.contains('>')) {
      var div = createDivInline(element);
      if (div.childNodes.isEmpty) return div;

      if (div.childNodes.length == 1) {
        return div.childNodes.first;
      } else {
        div;
      }
    } else {
      var span = SpanElement();
      setElementInnerHTML(span, element);
      return span;
    }
  }

  return element;
}

bool _isElementForDOM(dynamic element) {
  if (element is Element) {
    return true;
  } else if (element is Node) {
    return true;
  } else if (element is UIComponent) {
    return true;
  } else if (element is UIAsyncContent) {
    return true;
  } else if (element is List) {
    for (var elem in element) {
      if (_isElementForDOM(elem)) return true;
    }
    return false;
  }

  return false;
}

typedef AsyncContentProvider = Future<dynamic> Function();

/// An asynchronous content.
class UIAsyncContent {
  AsyncContentProvider _asyncContentProvider;

  Future<dynamic> _asyncContentFuture;

  dynamic _loadingContent;

  dynamic _errorContent;

  Duration _refreshInterval;

  _Content _loadedContent;

  final String _locale;

  String get locale => _locale;

  final Map<String, dynamic> _properties;

  static bool isNotValid(UIAsyncContent asyncContent,
      [Map<String, dynamic> properties]) {
    return !isValid(asyncContent, properties);
  }

  static bool isValid(UIAsyncContent asyncContent,
      [Map<String, dynamic> properties]) {
    if (asyncContent == null) return false;

    if (asyncContent.equalsProperties(properties)) {
      return isValidLocale(asyncContent);
    } else {
      asyncContent.stop();
      return false;
    }
  }

  static bool isNotValidLocale(UIAsyncContent asyncContent) {
    return !isValidLocale(asyncContent);
  }

  static bool isValidLocale(UIAsyncContent asyncContent) {
    if (asyncContent == null) return false;

    if (asyncContent.equalsCurrentLocale()) {
      return true;
    } else {
      asyncContent.stop();
      return false;
    }
  }

  bool equalsCurrentLocale() => _locale == IntlLocale.getDefaultLocale();

  bool equalsLocale(String locale) => _locale == locale;

  bool equalsProperties(Map<String, dynamic> properties) {
    properties ??= {};
    return isEqualsDeep(_properties, properties);
  }

  final EventStream<dynamic> onLoadContent = EventStream();

  /// Constructs an [UIAsyncContent] using [_asyncContentProvider] ([Function]), that returns the content.
  ///
  /// [loadingContent] Content to show while loading.
  /// [errorContent] Content to show on error.
  /// [_refreshInterval] Interval to refresh the content.
  /// [properties] Properties of this content.
  UIAsyncContent.provider(this._asyncContentProvider, dynamic loadingContent,
      [dynamic errorContent,
      this._refreshInterval,
      Map<String, dynamic> properties])
      : _locale = IntlLocale.getDefaultLocale(),
        _properties = properties ?? {} {
    _loadingContent = _ensureElementForDOM(loadingContent);
    _errorContent = _ensureElementForDOM(errorContent);

    _callContentProvider(false);
  }

  /// Constructs an [UIAsyncContent] using [contentFuture] ([Future<dynamic>]), that returns the content.
  ///
  /// [loadingContent] Content to show while loading.
  /// [errorContent] Content to show on error.
  /// [_refreshInterval] Interval to refresh the content.
  /// [properties] Properties of this content.
  UIAsyncContent.future(Future<dynamic> contentFuture, dynamic loadingContent,
      [dynamic errorContent, Map<String, dynamic> properties])
      : _locale = IntlLocale.getDefaultLocale(),
        _properties = properties ?? {} {
    _loadingContent = _ensureElementForDOM(loadingContent);
    _errorContent = _ensureElementForDOM(errorContent);

    _setAsyncContentFuture(contentFuture);
  }

  Map<String, dynamic> get properties => Map<String, dynamic>.from(_properties);

  dynamic get loadingContent => _loadingContent;

  dynamic get errorContent => _errorContent;

  bool _stopped = false;

  bool get stopped => _stopped;

  /// Stops any attempt to load this content.
  void stop() {
    _stopped = true;
  }

  Duration get refreshInterval => _refreshInterval;

  int _maxIgnoredRefreshCount = 10;

  int get maxIgnoredRefreshCount => _maxIgnoredRefreshCount;

  set maxIgnoredRefreshCount(int value) {
    if (value == null || value < 1) value = 1;
    _maxIgnoredRefreshCount = value;
  }

  int _ignoredRefreshCount = 0;

  void _callContentProvider(bool fromRefresh) {
    if (fromRefresh) {
      if (!isLoaded) {
        _ignoreRefresh();
        return;
      }

      var content = this.content;

      if (!isComponentInDOM(content) && canBeInDOM(content)) {
        _ignoreRefresh(false);
        return;
      }
    }

    _ignoredRefreshCount = 0;

    var contentFuture = _asyncContentProvider();
    _setAsyncContentFuture(contentFuture);
  }

  void _ignoreRefresh([bool inDOM]) {
    _ignoredRefreshCount++;
    if (_ignoredRefreshCount < _maxIgnoredRefreshCount) {
      if (inDOM == null || inDOM) {
        _scheduleRefresh();
      }
    }
  }

  void _scheduleRefresh() {
    if (_refreshInterval != null && !_stopped) {
      Future.delayed(_refreshInterval, refresh);
    }
  }

  void _setAsyncContentFuture(Future<dynamic> contentFuture) {
    _asyncContentFuture = contentFuture;

    if (_asyncContentFuture != null) {
      _asyncContentFuture.then(_onLoadedContent).catchError(_onLoadError);
    } else {
      _onLoadedContent(null);
    }
  }

  /// Calls [refresh] asynchronously.
  void refreshAsync() {
    Future.microtask(refresh);
  }

  /// Refresh this content.
  ///
  /// If [_asyncContentProvider] is null calls to this method are ignored.
  void refresh() {
    _refreshImpl(true);
  }

  void _refreshImpl(bool fromRefresh) {
    if (_asyncContentProvider == null) return;
    _callContentProvider(fromRefresh);
  }

  int _loadCount = 0;

  /// Returns the number of loads performed for this asynchronous content.
  int get loadCount => _loadCount;

  DateTime _loadTime;

  /// Returns the [DateTime] of last load.
  DateTime get loadTime => _loadTime;

  /// Returns in milliseconds the amount of elpased time since last load.
  int get elapsedLoadTime => _loadTime != null
      ? DateTime.now().millisecondsSinceEpoch - _loadTime.millisecondsSinceEpoch
      : -1;

  /// Returns true if this content is expired ([elapsedLoadTime] > [_refreshInterval]).
  bool get isExpired =>
      _refreshInterval != null &&
      elapsedLoadTime > _refreshInterval.inMilliseconds;

  /// Returns [true] if has a [_refreshInterval].
  bool get hasAutoRefresh => _refreshInterval != null;

  void _onLoadedContent(dynamic content) {
    _loadedContent = _Content(content, 200);
    _loadCount++;
    _loadTime = DateTime.now();

    _inspectContent(content);

    _scheduleRefresh();

    onLoadContent.add(content);
  }

  void _onLoadError(dynamic error, StackTrace stackTrace) {
    loggerIgnoreBonesUI.e(
        'Error loading async content for instance: $this', error, stackTrace);

    _loadedContent = _Content(error, 500);
    _loadCount++;
    _loadTime = DateTime.now();
    _scheduleRefresh();

    onLoadContent.add(null);
  }

  void _inspectContent(dynamic content) {
    if (content == null) return;

    if (content is Map) {
      _inspectContent(content.keys);
      _inspectContent(content.values);
    } else if (content is Iterable) {
      for (var e in content) {
        _inspectContent(e);
      }
    } else if (content is UIAsyncContent) {
      throw StateError(
          "Can't have as content another UIAsyncContent: $content");
    }
  }

  /// Returns [true] if the content is loaded.
  bool get isLoaded => _loadedContent != null;

  /// Returns [true] if the content is loaded and OK.
  bool get isOK => _loadedContent != null && _loadedContent.status == 200;

  /// Returns [true] if the content is loaded and with error.
  bool get isWithError =>
      _loadedContent != null && _loadedContent.status == 500;

  /// Returns the already loaded content.
  dynamic get content {
    if (_loadedContent == null) {
      return loadingContent;
    } else if (_loadedContent.status == 200) {
      return _loadedContent.contentForDOM;
    } else {
      return errorContent ?? loadingContent;
    }
  }

  /// Resets the component.
  ///
  /// [refresh] If [true] (default), will call [refresh] after reset.
  void reset([bool refresh = true]) {
    loggerIgnoreBonesUI.i('Resetting async content for instance: $this');

    _loadedContent = null;
    _ignoredRefreshCount = 0;
    onLoadContent.add(null);

    if (refresh ?? true) {
      Future.microtask(() => _refreshImpl(false));
    }
  }

  @override
  String toString() {
    return 'UIAsyncContent{isLoaded: $isLoaded, loadingContent: <<$loadingContent>>, loadedContent: <<$_loadedContent>>}';
  }
}

class Dimension {
  final int width;

  final int height;

  Dimension(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dimension && width == other.width && height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;

  @override
  String toString() {
    return '${width}X${height}';
  }
}

/// The root for `Bones_UI` component tree.
abstract class UIRoot extends UIComponent {
  static UIRoot _rootInstance;

  /// Returns the current [UIRoot] instance.
  static UIRoot getInstance() {
    return _rootInstance;
  }

  LocalesManager _localesManager;

  Future<bool> _futureInitializeLocale;

  UIRoot(Element rootContainer, {dynamic classes})
      : super(rootContainer, classes: classes) {
    _registerAllComponents();

    _rootInstance = this;

    _localesManager = createLocalesManager(initializeLocale, _onDefineLocale);
    _localesManager.onPreDefineLocale.add(onPrefDefineLocale);

    _futureInitializeLocale = _localesManager.initialize(getPreferredLocale);

    window.onResize.listen(_onResize);

    UINavigator.get().refreshNavigationAsync();

    UIConsole.checkAutoEnable();
  }

  void _onResize(Event e) {
    try {
      onResize(e);
    } catch (e, s) {
      loggerIgnoreBonesUI.e(
          'Error calling onResize() for instance: $this', e, s);
    }
  }

  void onResize(Event e) {}

  LocalesManager getLocalesManager() {
    return _localesManager;
  }

  // ignore: use_function_type_syntax_for_parameters
  SelectElement buildLanguageSelector(refreshOnChange()) {
    return _localesManager.buildLanguageSelector(refreshOnChange)
        as SelectElement;
  }

  Future<bool> initializeLocale(String locale) {
    return null;
  }

  String getPreferredLocale() {
    return null;
  }

  static String getCurrentLocale() {
    return Intl.defaultLocale;
  }

  Future<bool> setPreferredLocale(String locale) {
    return _localesManager.setPreferredLocale(locale);
  }

  Future<bool> initializeAllLocales() {
    return _localesManager.initializeAllLocales();
  }

  List<String> getInitializedLocales() {
    return _localesManager.getInitializedLocales();
  }

  Future<bool> onPrefDefineLocale(String locale) {
    return Future.value(null);
  }

  void _onDefineLocale(String locale) {
    UIConsole.log('UIRoot> Locale defined: $locale');
    refreshIfLocaleChanged();
  }

  @override
  List render() {
    var menu = renderMenu();
    var content = renderContent();

    return [menu, content];
  }

  Future<bool> isReady() {
    return null;
  }

  void initialize() {
    var ready = isReady();

    if (_futureInitializeLocale != null) {
      if (ready == null) {
        ready = _futureInitializeLocale;
      } else {
        ready = ready.then((ok) {
          return _futureInitializeLocale;
        });
      }
    }

    _initializeImpl(ready);
  }

  void _initializeImpl([Future<bool> ready]) {
    if (ready == null) {
      _onReadyToInitialize();
    } else {
      ready.then((_) {
        _onReadyToInitialize();
      }, onError: (e) {
        _onReadyToInitialize();
      }).timeout(Duration(seconds: 10), onTimeout: () {
        _onReadyToInitialize();
      });
    }
  }

  /// [EventStream] for when this [UIRoot] is initialized.
  final EventStream<UIRoot> onInitialize = EventStream();

  /// [EventStream] for when this [UIRoot] finishes to render UI.
  final EventStream<UIRoot> onFinishRender = EventStream();

  void _onReadyToInitialize() {
    UIConsole.log('UIRoot> ready to initialize!');

    onInitialized();

    _initialRender();
    callRender();

    try {
      onInitialize.add(this);
    } catch (e) {
      UIConsole.error('Error calling UIRoot.onInitialize()', e);
    }
    ;
  }

  @override
  void callRender([bool clear]) {
    UIConsole.log('UIRoot> rendering...');
    super.callRender(clear);
  }

  void onInitialized() {}

  void _initialRender() {
    buildAppStatusBar();
  }

  /// Called to render App status bar.
  void buildAppStatusBar() {
    return null;
  }

  /// Called to render UI menu.
  UIComponent renderMenu() {
    return null;
  }

  /// Called to render UI content.
  UIComponent renderContent();
}

/// A `Bones_UI` component for navigable components by routes.
abstract class UINavigableComponent extends UIComponent {
  static final String COMPONENT_CLASS = 'ui-navigable-component';

  List<String> _routes;

  bool _findRoutes;

  String _currentRoute;

  Map<String, String> _currentRouteParameters;

  UINavigableComponent(Element parent, this._routes,
      {dynamic classes,
      dynamic classes2,
      bool inline = true,
      bool renderOnConstruction = false})
      : super(parent,
            componentClass: COMPONENT_CLASS,
            classes: classes,
            classes2: classes2,
            inline: inline,
            renderOnConstruction: renderOnConstruction) {
    _normalizeRoutes();

    if (routes.isEmpty) throw ArgumentError('Empty routes');

    var currentRoute = UINavigator.currentRoute;
    var currentRouteParameters = UINavigator.currentRouteParameters;

    if (currentRoute != null && currentRoute.isNotEmpty) {
      if (_routes.contains(currentRoute)) {
        _currentRoute = currentRoute;
        _currentRouteParameters = currentRouteParameters;
      }
    }

    _currentRoute ??= _routes[0];

    UINavigator.get().registerNavigable(this);

    if (renderOnConstruction) {
      callRender();
    }
  }

  String _currentTitle = '';

  String get currentTitle => _currentTitle;

  set currentTitle(String value) {
    _currentTitle = value ?? '';
  }

  bool get findRoutes => _findRoutes;

  set findRoutes(bool value) {
    _findRoutes = value;
  }

  void _normalizeRoutes() {
    // ignore: omit_local_variable_types
    List<String> routesOk = [];

    if (_routes == null || _routes.isEmpty) _routes = ['*'];

    var findRoutes = false;

    for (var r in _routes) {
      if (r == null || r.isEmpty) continue;

      if (r == '*') {
        findRoutes = true;

        var foundRoutes = UINavigator.get().findElementNavigableRoutes(content);

        for (var r2 in foundRoutes) {
          if (!routesOk.contains(r2)) routesOk.add(r2);
        }
      } else if (!routesOk.contains(r)) {
        routesOk.add(r);
      }
    }

    _findRoutes = findRoutes;

    UIConsole.log('_normalizeRoutes: $_routes -> $routesOk');

    _routes = routesOk;
  }

  void _updateRoutes([List<String> foundRoutes]) {
    foundRoutes ??= UINavigator.get().findElementNavigableRoutes(content);

    UIConsole.log('foundRoutes: $foundRoutes');

    for (var r in foundRoutes) {
      if (!_routes.contains(r)) {
        UIConsole.log('_updateRoutes: $_routes + $r');
        _routes.add(r);
      }
    }
  }

  List<String> get routes => copyListString(_routes);

  String get currentRoute => _currentRoute;

  Map<String, String> get currentRouteParameters =>
      copyMapString(_currentRouteParameters);

  /// Returns [true] if this instance can navigate to [route].
  bool canNavigateTo(String route) {
    for (var r in routes) {
      if (route == r || route.startsWith('$r/')) {
        return true;
      }
    }

    if (_findRoutes != null && _findRoutes) {
      return _findNewRoutes(route);
    }

    return false;
  }

  bool _findNewRoutes(String route) {
    var canHandleNewRoute = _canHandleNewRoute(route);
    if (!canHandleNewRoute) return false;
    _updateRoutes([route]);
    return true;
  }

  bool _canHandleNewRoute(String route) {
    var rendered = renderRoute(route, {});

    if (rendered == null) {
      return false;
    } else if (rendered is List) {
      return rendered.isNotEmpty;
    } else {
      return true;
    }
  }

  @override
  dynamic render() {
    var rendered = renderRoute(currentRoute, _currentRouteParameters);

    if (_findRoutes != null && _findRoutes) {
      _updateRoutes();
    }

    return rendered;
  }

  /// Called to render the [route] with [parameters].
  dynamic renderRoute(String route, Map<String, String> parameters);

  /// Changes the current selected [route], with [parameters],
  /// of this [UINavigableComponent].
  bool navigateTo(String route, [Map<String, String> parameters]) {
    if (!canNavigateTo(route)) return false;

    _currentRoute = route;
    _currentRouteParameters = parameters ?? {};

    _refreshInternal();
    return true;
  }
}

/// Represents a navigation ([route] + [parameters]).
class Navigation {
  /// The route ID/name.
  final String route;

  /// The route parameters.
  final Map<String, String> parameters;

  Navigation(this.route, [this.parameters]);

  /// Returns [true] if this route ID/name is valid.
  bool get isValid => route != null && route.isNotEmpty;

  String parameter(String key, [String def]) =>
      parameters != null ? parameters[key] ?? def : def;

  int parameterAsInt(String key, [int def]) =>
      parameters != null ? parseInt(parameters[key], def) : def;

  num parameterAsNum(String key, [num def]) =>
      parameters != null ? parseNum(parameters[key], def) : def;

  bool parameterAsBool(String key, [bool def]) =>
      parameters != null ? parseBool(parameters[key], def) : def;

  List<String> parameterAsStringList(String key, [List<String> def]) =>
      parameters != null
          ? parseStringFromInlineList(parameters[key], RegExp(r'\s*,\s*'), def)
          : def;

  List<int> parameterAsIntList(String key, [List<int> def]) =>
      parameters != null
          ? parseIntsFromInlineList(parameters[key], RegExp(r'\s*,\s*'), def)
          : def;

  List<num> parameterAsNumList(String key, [List<num> def]) =>
      parameters != null
          ? parseNumsFromInlineList(parameters[key], RegExp(r'\s*,\s*'), def)
          : def;

  List<bool> parameterAsBoolList(String key, [List<bool> def]) =>
      parameters != null
          ? parseBoolsFromInlineList(parameters[key], RegExp(r'\s*,\s*'), def)
          : def;

  @override
  String toString() {
    return 'Navigation{route: $route, parameters: $parameters}';
  }
}

/// Handles navigation and routes.
class UINavigator {
  static UINavigator _instance;

  static UINavigator get() {
    _instance ??= UINavigator._internal();
    return _instance;
  }

  UINavigator._internal() {
    window.onHashChange.listen((e) => _onChangeRoute(e));

    var href = window.location.href;
    var url = Uri.parse(href);

    var routeFragment = _parseRouteFragment(url);

    String route = routeFragment[0];
    var parameters = routeFragment[1];

    _currentRoute = route;
    _currentRouteParameters = parameters;

    UIConsole.log(
        'Init UINavigator[$href]> route: $_currentRoute ; parameters:  $_currentRouteParameters ; secureContext: $isSecureContext');
  }

  /// Returns [true] if this device is online.
  static bool get isOnline => window.navigator.onLine;

  /// Returns [true] if this device is off-line.
  static bool get isOffline => !isOnline;

  /// Returns [true] if this device is in secure contexts (HTTPS).
  ///
  /// See: [https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts]
  static bool get isSecureContext {
    try {
      return window.isSecureContext;
    } catch (e, s) {
      logger.e('Error calling `window.isSecureContext`', e, s);
      return false;
    }
  }

  void _onChangeRoute(HashChangeEvent event) {
    var uri = Uri.parse(event.newUrl);
    UIConsole.log(
        'UINavigator._onChangeRoute: new: $uri > previous: ${event.oldUrl}');
    _navigateToFromURL(uri);
  }

  /// Refreshed the current route asynchronously.
  void refreshNavigationAsync([bool force = false]) {
    Future.microtask(() => refreshNavigation(force));
  }

  /// Refreshed the current route.
  void refreshNavigation([bool force = false]) {
    _navigateTo(currentRoute,
        parameters: _currentRouteParameters, force: force);
  }

  String _currentRoute;

  Map<String, String> _currentRouteParameters;

  /// Returns the current [Navigation].
  static Navigation get currentNavigation {
    var route = currentRoute;
    if (route == null || route.isEmpty) return null;
    return Navigation(route, currentRouteParameters);
  }

  /// Returns the current route.
  static String get currentRoute => get()._currentRoute;

  /// Returns the current route parameters.
  static Map<String, String> get currentRouteParameters =>
      copyMapString(get()._currentRouteParameters);

  /// Returns [true] if current location has a route entry.
  static bool get hasRoute => get()._hasRoute();

  bool _hasRoute() {
    return _currentRoute != null && _currentRoute.isNotEmpty;
  }

  String _lastNavigateRoute;

  Map<String, String> _lastNavigateRouteParameters;

  List _parseRouteFragment(Uri url) {
    var fragment = url != null ? url.fragment : '';
    fragment ??= '';

    var parts = fragment.split('?');

    var route = parts[0];
    var routeQueryString = parts.length > 1 ? parts[1] : null;

    var parameters = decodeQueryString(routeQueryString);

    return [route, parameters];
  }

  void _navigateToFromURL(Uri url, [bool force = false]) {
    var routeFragment = _parseRouteFragment(url);

    String route = routeFragment[0];
    var parameters = routeFragment[1];

    if (route.toLowerCase() == 'uiconsole') {
      String enableStr = parameters['enable'];
      var enable = enableStr == null ||
          enableStr.toLowerCase() == 'true' ||
          enableStr == '1';

      if (enable) {
        UIConsole.displayButton();
      } else {
        UIConsole.disable();
      }
    }

    UIConsole.log(
        'UINavigator._navigateToFromURL[$url] route: $route ; parameters: $parameters');

    _navigateTo(route, parameters: parameters, force: force, fromURL: true);
  }

  /// Navigate using [navigation] do determine route and parameters.
  static void navigate(Navigation navigation, [bool force = false]) {
    if (navigation == null || !navigation.isValid) return;
    get()._callNavigateTo(navigation.route,
        parameters: navigation.parameters, force: force);
  }

  /// Navigate asynchronously using [navigation] do determine route and parameters.
  static void navigateAsync(Navigation navigation, {bool force = false}) {
    if (navigation == null || !navigation.isValid) return;
    get()._callNavigateToAsync(
        navigation.route, navigation.parameters, null, force);
  }

  /// Navigate to a [route] with [parameters] or [parametersProvider].
  ///
  /// [force] If [true] changes the route even if the current route is the same.
  static void navigateTo(String route,
      {Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false}) {
    get()._callNavigateTo(route,
        parameters: parameters,
        parametersProvider: parametersProvider,
        force: force);
  }

  /// Navigate asynchronously to a [route] with [parameters] or [parametersProvider].
  ///
  /// [force] If [true] changes the route even if the current route is the same.
  static void navigateToAsync(String route,
      {Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false}) {
    get()._callNavigateToAsync(route, parameters, parametersProvider, force);
  }

  void _callNavigateTo(String route,
      {Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false}) {
    if (_navigables.isEmpty || findNavigable(route) == null) {
      Future.microtask(() => _navigateTo(route,
          parameters: parameters,
          parametersProvider: parametersProvider,
          force: force));
    } else {
      _navigateTo(route,
          parameters: parameters,
          parametersProvider: parametersProvider,
          force: force);
    }
  }

  void _callNavigateToAsync(String route,
      [Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false]) {
    Future.microtask(() => _navigateTo(route,
        parameters: parameters,
        parametersProvider: parametersProvider,
        force: force));
  }

  int _navigateCount = 0;

  final List<Navigation> _navigationHistory = [];

  /// Returns a history list of [Navigation].
  static List<Navigation> get navigationHistory =>
      List.from(get()._navigationHistory);

  /// Returns the initial route when browser window was open.
  static String get initialRoute => get()._initialRoute;

  String get _initialRoute {
    var nav = _initialNavigation;
    return nav != null && nav.isValid ? nav.route : null;
  }

  /// Returns the initial [Navigation] when browser window was open.
  static Navigation get initialNavigation => get()._initialNavigation;

  Navigation get _initialNavigation {
    if (_navigationHistory.isNotEmpty) {
      var navigation = _navigationHistory[0];

      if (navigation.isValid) {
        var navigable = UINavigator.get().findNavigable(navigation.route);
        if (navigable != null) {
          return navigation;
        }
      }
    }

    return null;
  }

  final EventStream<String> _onNavigate = EventStream();

  /// [EventStream] for when navigation changes.
  static EventStream<String> get onNavigate => get()._onNavigate;

  void _navigateTo(String route,
      {Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false,
      bool fromURL = false}) {
    if (route == '<') {
      var navigation = _navigationHistory.last;

      if (navigation != null) {
        route = navigation.route;
        parameters = navigation.parameters;
      } else {
        return;
      }
    }

    route ??= '';
    parameters ??= {};

    if (parametersProvider != null && parameters.isEmpty) {
      parameters = parametersProvider();
    }

    if (!force &&
        _lastNavigateRoute == route &&
        isEquivalentMap(parameters, _lastNavigateRouteParameters)) return;

    _navigateCount++;

    if (route.contains('?')) {
      var parts = route.split('?');
      route = parts[0];
      var params = decodeQueryString(parts[1]);
      var parametersOrig = parameters;
      parameters = params;
      parameters.addAll(parametersOrig);
    }

    UIConsole.log(
        'UINavigator.navigateTo[force: $force ; count: $_navigateCount] from: $_lastNavigateRoute $_lastNavigateRouteParameters > to: $route $parameters');

    _currentRoute = route;
    _currentRouteParameters = copyMapString(parameters);

    if (_lastNavigateRoute != null) {
      var navigation =
          Navigation(_lastNavigateRoute, _lastNavigateRouteParameters);
      _navigationHistory.add(navigation);

      if (_navigationHistory.length > 12) {
        while (_navigationHistory.length > 10) {
          _navigationHistory.removeAt(0);
        }
      }
    }

    _lastNavigateRoute = route;
    _lastNavigateRouteParameters = copyMapString(parameters);

    var routeQueryString = _encodeRouteParameters(parameters);

    var fragment = '#$route';

    if (routeQueryString.isNotEmpty) fragment += '?$routeQueryString';

    var locationUrl = window.location.href;
    var locationUrl2 = locationUrl.contains('#')
        ? locationUrl.replaceFirst(RegExp(r'#.*'), fragment)
        : '$locationUrl$fragment';

    var routeNavigable = findNavigable(route);

    var routeTitle = route;
    if (routeNavigable != null) {
      routeTitle = routeNavigable.currentTitle;
    }

    if (!fromURL) {
      window.history.pushState({}, routeTitle, locationUrl2);
    }

    clearDetachedNavigables();

    for (var container in _navigables) {
      if (container.canNavigateTo(route)) {
        container.navigateTo(route, parameters);
      }
    }

    UIConsole.log('Navigated to $route $parameters');

    _onNavigate.add(route);
  }

  String _encodeRouteParameters(Map<String, String> parameters) {
    var urlEncoded = encodeQueryString(parameters);
    var routeEncoded = urlEncoded.replaceAll('%2C', ',');
    return routeEncoded;
  }

  /// Returns all the known routes of registered navigables.
  static List<String> get navigableRoutes {
    var routes = <String>{};
    for (var nav in navigables) {
      routes.addAll(nav.routes);
    }
    routes.remove('*');
    return List.from(routes);
  }

  final List<UINavigableComponent> _navigables = [];

  static List<UINavigableComponent> get navigables =>
      List.from(get()._navigables);

  /// Finds a [UINavigableComponent] that responds for [route].
  UINavigableComponent findNavigable(String route) {
    for (var nav in _navigables) {
      if (nav.canNavigateTo(route)) return nav;
    }
    return null;
  }

  /// Registers a [UINavigableComponent].
  ///
  /// Called internally by [UINavigableComponent].
  void registerNavigable(UINavigableComponent navigable) {
    if (!_navigables.contains(navigable)) {
      _navigables.add(navigable);
    }

    clearDetachedNavigables();
  }

  static final String _navigableComponentSelector =
      '.${UINavigableComponent.COMPONENT_CLASS}';

  /// Returns [List<Element>] that are from navigable components.
  ///
  /// [element] If null uses [document] to select sub elements.
  List<Element> selectNavigables([Element element]) {
    return element != null
        ? element.querySelectorAll(_navigableComponentSelector)
        : document.querySelectorAll(_navigableComponentSelector);
  }

  /// Find in [element] tree nodes with attribute `navigate`.
  List<String> findElementNavigableRoutes(Element element) {
    // ignore: omit_local_variable_types
    List<String> routes = [];

    _findElementNavigableRoutes([element], routes);

    return routes;
  }

  void _findElementNavigableRoutes(
      List<Element> elements, List<String> routes) {
    for (var elem in elements) {
      var navigateRoute = elem.getAttribute('navigate');
      if (navigateRoute != null &&
          navigateRoute.isNotEmpty &&
          !routes.contains(navigateRoute)) {
        routes.add(navigateRoute);
      }
      _findElementNavigableRoutes(elem.children, routes);
    }
  }

  /// Removes from navigables cache detached elements.
  void clearDetachedNavigables() {
    // ignore: omit_local_variable_types
    List<Element> list = selectNavigables();

    // ignore: omit_local_variable_types
    List<UINavigableComponent> navigables = List.from(_navigables);

    var uiRoot = UIRoot.getInstance();

    for (var container in navigables) {
      var navigableContent = container.content;
      if (!list.contains(navigableContent) &&
          (uiRoot != null &&
              uiRoot.findUIComponentByContent(navigableContent) == null)) {
        _navigables.remove(container);
      }
    }
  }

  /// Register a `onClick` listener in [element] to navigate to [route]
  /// with [parameters].
  static StreamSubscription navigateOnClick(Element element, String route,
      [Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false]) {
    var paramsStr = encodeQueryString(parameters);

    var attrRoute = element.getAttribute('__navigate__route');
    var attrParams = element.getAttribute('__navigate__parameters');

    if (route != attrRoute || paramsStr != attrParams) {
      element.setAttribute('__navigate__route', route);
      element.setAttribute('__navigate__parameters', paramsStr);

      var subscriptionHolder = <StreamSubscription>[];

      var subscription = element.onClick.listen((e) {
        var elemRoute = element.getAttribute('__navigate__route');
        var elemRouteParams = element.getAttribute('__navigate__parameters');

        if (elemRoute == route && elemRouteParams == paramsStr) {
          navigateTo(route,
              parameters: parameters,
              parametersProvider: parametersProvider,
              force: force);
        } else if (subscriptionHolder.isNotEmpty) {
          var subscription = subscriptionHolder[0];
          subscription.cancel();
        }
      });

      subscriptionHolder.add(subscription);

      if (element.style.cursor == null || element.style.cursor.isEmpty) {
        element.style.cursor = 'pointer';
      }

      return subscription;
    }

    return null;
  }

  static bool clearNavigateOnClick(Element element) {
    var attrRoute = element.getAttribute('__navigate__route');
    element.removeAttribute('__navigate__route');
    element.removeAttribute('__navigate__parameters');

    if (attrRoute != null) {
      if (element.style.cursor == 'pointer') {
        element.style.cursor = '';
      }
      return true;
    }

    return null;
  }

  /// Returns the current `navigate` property of [element].
  static String getNavigateOnClick(Element element) {
    var attrRoute = element.getAttribute('__navigate__route');

    if (isNotEmptyObject(attrRoute)) {
      var attrParams = element.getAttribute('__navigate__parameters');
      return isNotEmptyObject(attrParams)
          ? '$attrRoute?$attrParams'
          : attrRoute;
    }

    return null;
  }
}

class TextProvider {
  String _text;

  String Function() _function;

  IntlKey _intlKey;

  ElementProvider _elementProvider;

  TextProvider.fromText(this._text);

  TextProvider.fromFunction(this._function);

  TextProvider.fromElementProvider(this._elementProvider);

  TextProvider.fromIntlKey(this._intlKey);

  TextProvider.fromMessages(IntlMessages intlMessages, String key,
      {Map<String, dynamic> variables, IntlVariablesProvider variablesProvider})
      : this.fromIntlKey(IntlKey(intlMessages, key,
            variables: variables, variablesProvider: variablesProvider));

  factory TextProvider.from(dynamic text) {
    if (text == null) return null;
    if (text is TextProvider) return text;

    if (text is String) return TextProvider.fromText(text);
    if (text is Function) return TextProvider.fromFunction(text);
    if (text is IntlKey) return TextProvider.fromIntlKey(text);

    if (text is ElementProvider) return TextProvider.fromElementProvider(text);
    if (ElementProvider.accepts(text)) {
      return TextProvider.fromElementProvider(ElementProvider.from(text));
    }

    return null;
  }

  static bool accepts(dynamic text) {
    if (text == null) return false;
    if (text is TextProvider) return true;

    if (text is String) return true;
    if (text is Function) return true;
    if (ElementProvider.accepts(text)) return true;

    return null;
  }

  bool _singleCall = false;

  bool get singleCall => _singleCall;

  set singleCall(bool value) {
    _singleCall = value ?? false;
  }

  String get text {
    if (_text != null) {
      return _text;
    }

    String text;

    if (_function != null) {
      text = _function();
    } else if (_elementProvider != null) {
      text = _elementProvider.element.text;
    } else if (_intlKey != null) {
      text = _intlKey.message;
    } else {
      throw StateError("Can't provide a text: $this");
    }

    if (_singleCall) {
      _text = text;
    }

    return text;
  }

  @override
  String toString() {
    return 'TextProvider{_text: $_text, _function: $_function, _intlKey: $_intlKey, _elementProvider: $_elementProvider, _singleCall: $_singleCall}';
  }
}

class ElementProvider {
  Element _element;

  String _html;

  UIComponent _uiComponent;

  DOMNode _domNode;

  ElementProvider.fromElement(this._element);

  ElementProvider.fromHTML(this._html);

  ElementProvider.fromUIComponent(this._uiComponent);

  ElementProvider.fromDOMNode(this._domNode);

  factory ElementProvider.from(dynamic element) {
    if (element == null) return null;
    if (element is ElementProvider) return element;
    if (element is String) return ElementProvider.fromHTML(element);
    if (element is Element) return ElementProvider.fromElement(element);
    if (element is UIComponent) return ElementProvider.fromUIComponent(element);
    if (element is DOMNode) return ElementProvider.fromDOMNode(element);
    return null;
  }

  static bool accepts(dynamic element) {
    if (element == null) return false;
    if (element is ElementProvider) return true;
    if (element is String) return true;
    if (element is Element) return true;
    if (element is UIComponent) return true;
    if (element is DOMNode) return true;
    return false;
  }

  String get elementAsHTML {
    var elem = element;
    return elem != null ? element.outerHtml : null;
  }

  Element get element {
    if (_element != null) {
      return _element;
    }

    if (_html != null) {
      _element = createHTML(_html);
      return _element;
    }

    if (_uiComponent != null) {
      _uiComponent.ensureRendered();
      _element = _uiComponent.content;
      return _element;
    }

    if (_domNode != null) {
      var runtime = _domNode.runtime;
      if (runtime != null && runtime.exists) {
        return runtime.node as Element;
      } else {
        return _domNode.buildDOM(generator: UIComponent.domGenerator)
            as Element;
      }
    }

    throw StateError("Can't provide an Element: $this");
  }

  @override
  String toString() {
    return 'ElementProvider{_element: $_element, _html: $_html, _uiComponent: $_uiComponent, _domNode: $_domNode}';
  }
}

bool _registeredAllComponents = false;

void _registerAllComponents() {
  if (_registeredAllComponents) return;
  _registeredAllComponents = true;
  UIButton.register();
  UIMultiSelection.register();
  UIDataSource.register();
}
