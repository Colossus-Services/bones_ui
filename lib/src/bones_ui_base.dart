import 'dart:async';
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:dom_builder/dom_builder_dart_html.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:json_render/json_render.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_layout.dart';
import 'component/bui.dart';
import 'component/template.dart';

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

/// For a [UIComponent] that is a field (has a value).
abstract class UIField<V> {
  V getFieldValue();
}

/// For a [UIComponent] that is a field with a Map value.
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

/// Handler of a [UIComponent] attribute.
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

/// A generator of [UIComponent] based in a HTML tag,
/// for `dom_builder` (extends [ElementGenerator]).
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
      DOMTreeMap<Node> treeMap,
      tag,
      DOMElement domParent,
      Node parent,
      DOMNode domNode,
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

/// [UIComponent] behavior to clear the component.
enum UIComponentClearParent { onConstruct, onInitialRender, onRender }

/// Base class to create `Bones_UI` components.
abstract class UIComponent extends UIEventHandler {
  static final UIDOMGenerator domGenerator = UIDOMGenerator();

  /// Register a [generator] for a type of [UIComponent].
  static bool registerGenerator(UIComponentGenerator generator) {
    if (generator == null) throw ArgumentError.notNull('generator');
    return domGenerator.registerElementGenerator(generator);
  }

  final UIComponentGenerator _generator;

  static int _globalIDCount = 0;

  final globalID;

  dynamic id;

  UIComponent _parentUIComponent;

  Element _parent;
  final UIComponentClearParent clearParent;

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
      UIComponentClearParent clearParent,
      bool inline = true,
      bool renderOnConstruction,
      bool preserveRender,
      this.id,
      UIComponentGenerator generator})
      : globalID = ++_globalIDCount,
        _parent = parent ?? createDivInline(),
        clearParent = clearParent,
        _generator = generator {
    _constructing = true;
    try {
      if (preserveRender != null) {
        this.preserveRender = preserveRender;
      }

      onPreConstruct();

      _content = createContentElement(inline);

      _setParentUIComponent(_getUIComponentByContent(_parent));

      registerInUIRoot();

      configureID();

      configureClasses(classes, classes2, componentClass);
      configureStyle(style, style2, componentStyle);

      configure();

      if (this.clearParent == UIComponentClearParent.onConstruct) {
        _parent.nodes.clear();
      }
      _parent.append(_content);

      renderOnConstruction ??= false;

      if (renderOnConstruction) {
        callRender();
      }
    } finally {
      _constructing = false;
    }
  }

  /// Called by constructor to register this component in the [UIRoot] tree.
  void registerInUIRoot() {
    UIRoot.getInstance().registerUIComponentInTree(this);
  }

  /// Called in the beginning of constructor.
  void onPreConstruct() {}

  UIComponent clone() => null;

  /// Sets the [parent] [Element].
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
      var parentUI = _getUIComponentByContent(_parent);
      _setParentUIComponent(parentUI);
    }

    return parent;
  }

  /// Returns a [List] of sub [UIComponent].
  List<UIComponent> get subUIComponents =>
      UIRoot.getInstance()?.getSubUIComponentsByElement(content) ?? [];

  /// Returns a [List] of sub [UIComponent] deeply in the tree.
  List<UIComponent> get subUIComponentsDeeply =>
      subUIComponents?.expand((e) => [e, ...?e.subUIComponents])?.toList() ??
      [];

  void _setParentUIComponent(UIComponent uiParent) {
    _parentUIComponent = uiParent;
  }

  /// The parent [UIComponent].
  UIComponent get parentUIComponent {
    if (_parentUIComponent != null) return _parentUIComponent;

    var myParentElem = parent;

    var foundParent = _getUIComponentByContent(myParentElem);

    if (foundParent != null) {
      _setParentUIComponent(foundParent);
    }

    return _parentUIComponent;
  }

  bool _showing = true;

  bool get isShowing => _showing;

  String _displayOnHidden;

  /// Hide component.
  void hide() {
    _content.hidden = true;

    if (_showing) {
      _displayOnHidden = _content.style.display;
    }
    _content.style.display = 'none';

    _showing = false;
  }

  /// Show component.
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

  static List<String> parseClasses(dynamic classes1, [dynamic classes2]) {
    var c1 = _parseClasses(classes1);
    if (classes2 == null) return c1;

    var c2 = _parseClasses(classes2);

    var set = c1.toSet();
    set.addAll(c2);

    return set.toList();
  }

  static List<String> _parseClasses(classes) => toFlatListOfStrings(classes,
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

  /// Called by constructor, to configure this component.
  void configure() {}

  StreamSubscription<String> _refreshOnNavigateListener;

  bool get refreshOnNavigate => _refreshOnNavigateListener != null;

  set refreshOnNavigate(bool refresh) {
    refresh ??= false;
    if (refreshOnNavigate != refresh) {
      if (refresh) {
        _refreshOnNavigateListener =
            UINavigator.onNavigate.listen((_) => this.refresh());
      } else {
        _refreshOnNavigateListener?.cancel();
        _refreshOnNavigateListener = null;
      }
    }
  }

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

  String _renderedElementsLocale;

  List _renderedElements;

  List get renderedElements =>
      _renderedElements != null ? List.unmodifiable(_renderedElements) : null;

  dynamic getRenderedElement(FilterRendered filter, [bool deep]) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements) {
      if (filter(elem)) return elem;
    }

    if (deep ?? false) {
      for (var elem in _renderedElements) {
        if (elem is UIComponent) {
          var found = elem.getRenderedElement(filter, true);
          if (found != null) {
            return found;
          }
        }
      }

      var subUIComponents = this.subUIComponents;

      for (var elem in subUIComponents) {
        if (filter(elem)) return elem;

        var found = elem.getRenderedElement(filter, true);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  List getAllRenderedElements(FilterRendered filter, [bool deep]) {
    if (_renderedElements == null) return null;

    var elements = <dynamic>{};

    for (var elem in _renderedElements) {
      if (filter(elem)) {
        elements.add(elem);
      }
    }

    if (deep ?? false) {
      for (var elem in _renderedElements) {
        if (elem is UIComponent) {
          var found = elem.getRenderedElement(filter, true);
          if (found != null) {
            elements.add(found);
          }
        }
      }

      var subUIComponents = this.subUIComponents;

      for (var elem in subUIComponents) {
        if (filter(elem)) {
          elements.add(elem);
        }

        var found = elem.getRenderedElement(filter, true);
        if (found != null) {
          elements.add(found);
        }
      }
    }

    return elements.toList();
  }

  dynamic getRenderedElementById(dynamic id, [bool deep]) => getRenderedElement(
      (elem) =>
          (elem is UIComponent && elem.id == id) ||
          (elem is Element && elem.id == id),
      deep);

  dynamic getRenderedUIComponentById(dynamic id, [bool deep]) {
    if (id == null) return null;
    return getRenderedUIComponents(deep)
        .firstWhere((e) => e.id == id, orElse: () => null);
  }

  List<UIComponent> getRenderedUIComponentsByIds(List ids, [bool deep]) {
    if (ids == null || ids.isEmpty) return <UIComponent>[];
    return getRenderedUIComponents(deep)
        .where((e) => e.id != null && ids.contains(e.id))
        .toList();
  }

  dynamic getRenderedUIComponentByType(Type type, [bool deep]) {
    if (type == null) return null;
    return getRenderedUIComponents(deep)
        .where((e) => e.runtimeType == type)
        .toList();
  }

  List<UIComponent> getRenderedUIComponents([bool deep]) =>
      (deep ?? false) ? subUIComponentsDeeply : subUIComponents;

  bool _rendered = false;

  bool get isRendered => _rendered;

  /// Clear component, removing last rendered content.
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

    var elements = List.from(_content.children);
    elements.forEach((e) => e.remove());

    _content.children.clear();

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

  /// Refresh component, calling [render].
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
    if (localeChangedFromLastRender) {
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
    } else if (localeChangedFromLastRender) {
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

  bool get localeChangedFromLastRender {
    var currentLocale = UIRoot.getCurrentLocale();
    return _renderLocale != currentLocale;
  }

  static bool get isAnyComponentRendering =>
      UIRoot.getInstance()?.isAnyComponentRendering ?? false;

  static UIComponent _getUIComponentByContent(Element content,
      [bool findUIRootTree = true]) {
    return UIRoot.getInstance()?.getUIComponentByContent(content);
  }

  UIComponent findUIComponentByID(String id) {
    if (id.startsWith('#')) id = id.substring(1);
    if (isEmptyString(id)) return null;
    return _findUIComponentByIDImpl(id);
  }

  UIComponent _findUIComponentByIDImpl(String id) {
    if (_content == null) return null;
    if (_content.id == id) return this;
    if (_renderedElements == null || _renderedElements.isEmpty) return null;

    for (var elem in _renderedElements) {
      if (elem is UIComponent) {
        if (elem.id == id) return elem;
        var uiComp = elem._findUIComponentByIDImpl(id);
        if (uiComp != null) return uiComp;
      }
    }

    var subUIComponents = this.subUIComponents;

    for (var elem in subUIComponents) {
      if (elem.id == id) return elem;
      var uiComp = elem._findUIComponentByIDImpl(id);
      if (uiComp != null) return uiComp;
    }

    return null;
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

    var subUIComponents = this.subUIComponents;

    for (var elem in subUIComponents) {
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

    var subUIComponents = this.subUIComponents;

    for (var elem in subUIComponents) {
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

  void preRenderClear() {
    clear();
  }

  int _renderCount = 0;

  int get renderCount => _renderCount;

  void _callRenderImpl(bool clear) {
    _renderCount++;

    var content = this.content;

    if (_parent != null) {
      if (clearParent == UIComponentClearParent.onRender ||
          (clearParent == UIComponentClearParent.onInitialRender &&
              _renderCount == 1)) {
        var nodes = List<Node>.from(_parent.nodes);

        var containsContent = false;
        for (var node in nodes) {
          if (identical(node, content)) {
            containsContent = true;
          } else {
            node.remove();
          }
        }

        if (!containsContent) {
          _parent.append(content);
        }
      } else if (!_parent.nodes.contains(content)) {
        _parent.append(content);
      }
    }

    if (clear ?? false) {
      preRenderClear();
    }

    _rendering = true;
    try {
      _doRender();
    } finally {
      _rendering = false;

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
    }
  }

  int _preserveRenderCount = 0;

  int get preserveRenderCount => _preserveRenderCount;

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
            UINavigator.navigateToAsync(redirectToRoute);
          }
        }

        return;
      }
    } catch (e, s) {
      UIConsole.error('$this isAccessible error', e, s);
      return;
    }

    try {
      _callPreRender();

      _rendered = true;

      dynamic rendered;
      if (_preserveRender &&
          !_renderedWithError &&
          _renderedElements != null &&
          _renderedElements.isNotEmpty &&
          _renderedElementsLocale == _renderLocale) {
        _preserveRenderCount++;
        rendered = List.from(_renderedElements);
      } else {
        _renderedWithError = false;
        _preserveRenderCount = 0;
        rendered = render();
      }

      _renderedAsyncContents = {};

      var renderedElements = toContentElements(rendered);

      _renderedElements = renderedElements;

      _renderedElementsLocale = _renderLocale;

      _ensureAllRendered(renderedElements);
    } catch (e, s) {
      UIConsole.error('$this render error', e, s);
    }

    _finalizeRender();

    try {
      _parseAttributesPosRender(content.children);
    } catch (e, s) {
      UIConsole.error('$this _parseAttributesPosRender(...) error', e, s);
    }

    _callPosRender();

    _markRenderTime();
  }

  void _finalizeRender() {
    setTreeElementsBackgroundBlur(content, 'bg-blur');
  }

  void _ensureAllRendered(List elements) {
    if (elements == null || elements.isEmpty) return;

    for (var e in elements) {
      if (e is UIComponent) {
        e.ensureRendered();
      } else if (e is Element) {
        var subElements = [];

        for (var child in e.children) {
          var uiComponent = _getUIComponentByContent(child, false);

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

    UIRoot.getInstance()?.notifyFinishRender();
  }

  bool _preserveRender = false;

  /// If [true] will preserve last render in next calls to [render].
  bool get preserveRender => _preserveRender;

  set preserveRender(bool value) {
    _preserveRender = value ?? false;
  }

  /// Clears previous rendered elements. Only relevant if [preserveRender] is true.
  void clearPreservedRender() {
    if (_preserveRender) {
      _renderedElements = [];
    }
  }

  /// Called when [render] returns a [Future] value, to render the content
  /// while loading `Future`.
  dynamic renderLoading() => null;

  bool _renderedWithError = false;

  /// Returns [true] if current/last render had errors.
  bool get isRenderedWithError => _renderedWithError;

  /// Marks current/last render with error.
  void markRenderedWithError() => _renderedWithError = true;

  /// Called when [render] returns a `Future` value, to render the content
  /// when [Future] has an error.
  dynamic renderError(dynamic error) => null;

  /// Called before [render].
  void preRender() {}

  /// Renders the elements of this component.
  ///
  /// Accepted return types:
  /// - `dart:html` [Node] and [Element].
  /// - [DIVElement], [DOMNode], [AsDOMElement] and [AsDOMNode].
  /// - [Future].
  /// - [UIAsyncContent].
  /// - [String], parsed as `HTML`.
  /// - [Map] (rendered as JSON).
  /// - [List] with previous types (recursively).
  /// - [Function] that returns any previous type. Including [Function]<Future>, allowing `async` functions.
  dynamic render();

  /// Called after [render].
  void posRender() {}

  void _callPreRender() {
    try {
      preRender();
    } catch (e, s) {
      UIConsole.error('$this preRender error', e, s);
    }
  }

  void _callPosRender() {
    try {
      posRender();
    } catch (e, s) {
      UIConsole.error('$this posRender error', e, s);
    }

    connectDataSource();
  }

  List toContentElements(dynamic rendered,
      [bool append = false, bool parseAttributes = true]) {
    try {
      var list = _toContentElementsImpl(rendered, append);

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

  List _toContentElementsImpl(dynamic rendered, bool append) {
    var renderableList = toRenderableList(rendered);

    var content = this.content;

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
        if (isListValuesIdentical(renderableList, content.nodes.toList())) {
          return List.from(renderableList);
        }

        for (var value in renderableList) {
          _removeFromContent(value);
        }

        var renderedList2 = [];

        var prevElemIndex = -1;

        for (var value in renderableList) {
          prevElemIndex = _buildRenderList(value, renderedList2, prevElemIndex);
        }

        return renderedList2;
      }
    } else {
      return List.from(content.childNodes);
    }
  }

  dynamic _normalizeRenderListValue(Element content, value) {
    if (value is DOMNode) {
      return value.buildDOM(generator: domGenerator, parent: content);
    } else if (value is AsDOMElement) {
      var element = value.asDOMElement;
      return element.buildDOM(generator: domGenerator, parent: content);
    } else if (value is AsDOMNode) {
      var node = value.asDOMNode;
      return node.buildDOM(generator: domGenerator, parent: content);
    } else if (value is Map ||
        (value is List &&
            listMatchesAll(value, (e) => e != null && e is Map))) {
      var jsonRender = JSONRender.fromJSON(value)
        ..renderMode = JSONRenderMode.VIEW
        ..addAllKnownTypeRenders();
      return jsonRender.render();
    } else if (value is Iterable && !(value is List)) {
      return value.toList();
    } else if (value is Future) {
      var asyncContent = UIAsyncContent.future(
        value,
        () => renderLoading() ?? '...',
        (error) {
          markRenderedWithError();
          return renderError(error) ?? '[error: $error]';
        },
        {'__Future__': value},
      );
      return asyncContent;
    } else {
      return value;
    }
  }

  int _buildRenderList(dynamic value, List renderedList, int prevElemIndex) {
    if (value == null) return prevElemIndex;
    var content = this.content;

    value = _normalizeRenderListValue(content, value);

    if (value is Node) {
      prevElemIndex =
          _addElementToRenderList(value, value, renderedList, prevElemIndex);
    } else if (value is UIComponent) {
      if (value.parent != content) {
        value._setParentImpl(content, false);
      }
      prevElemIndex = _addElementToRenderList(
          value, value.content, renderedList, prevElemIndex);
    } else if (value is UIAsyncContent) {
      prevElemIndex =
          _addUIAsyncContentToRenderList(value, renderedList, prevElemIndex);
    } else if (value is List) {
      for (var elem in value) {
        prevElemIndex = _buildRenderList(elem, renderedList, prevElemIndex);
      }
    } else if (value is String) {
      prevElemIndex =
          _addStringToRenderList(value, renderedList, prevElemIndex);
    } else if (value is Function) {
      try {
        var result = value();
        prevElemIndex = _buildRenderList(result, renderedList, prevElemIndex);
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

  Map<UIAsyncContent, List> _renderedAsyncContents = {};

  void _resolveUIAsyncContentLoaded(UIAsyncContent asyncContent) {
    if (!asyncContent.isLoaded) return;

    var prevRendered = _renderedAsyncContents[asyncContent];
    if (prevRendered == null) return;

    if (_renderedElements == null) {
      return;
    }

    var minRenderedIdx;

    for (var e in prevRendered) {
      if (e == null) continue;
      var idx = _renderedElements.indexOf(e);
      if (idx >= 0) {
        _renderedElements.removeAt(idx);
        if (minRenderedIdx == null || idx < minRenderedIdx) {
          minRenderedIdx = idx;
        }
      }
    }

    var prevElements = prevRendered.where((e) => e != null).toSet();

    int minElementIdx;

    for (var node in content.nodes.toList()) {
      if (prevElements.contains(node)) {
        var idx = content.nodes.indexOf(node);
        if (idx >= 0) {
          content.nodes.removeAt(idx);
          if (minElementIdx == null || minElementIdx < idx) {
            minElementIdx = idx;
          }
        }
      }
    }

    var loadedContent = asyncContent.content;

    var renderedList = [];
    if (minElementIdx == null || minElementIdx >= content.nodes.length) {
      _buildRenderList(loadedContent, renderedList, content.nodes.length - 1);

      _renderedElements.addAll(renderedList);
    } else {
      var tail = content.nodes.sublist(minElementIdx).toList();
      tail.forEach((e) => content.nodes.remove(e));

      _buildRenderList(loadedContent, renderedList, content.nodes.length - 1);

      content.nodes.addAll(tail);

      _renderedElements.insertAll(minRenderedIdx, renderedList);
    }

    _renderedAsyncContents[asyncContent] = renderedList;
  }

  int _addUIAsyncContentToRenderList(
      UIAsyncContent asyncContent, List renderedList, int prevElemIndex) {
    if ((!asyncContent.isLoaded || asyncContent.hasAutoRefresh)) {
      asyncContent.onLoadContent.listen((c) {
        _resolveUIAsyncContentLoaded(asyncContent);
      }, singletonIdentifier: this);
    }

    if (asyncContent.isExpired) {
      asyncContent.refreshAsync();
    } else if (asyncContent.isWithError) {
      if (asyncContent.hasAutoRefresh) {
        asyncContent.reset();
      }
    }

    var renderIdx = renderedList.length;

    prevElemIndex =
        _buildRenderList(asyncContent.content, renderedList, prevElemIndex);

    var rendered = renderedList.sublist(renderIdx).toList();

    _renderedAsyncContents[asyncContent] = rendered;

    return prevElemIndex;
  }

  int _addElementToRenderList(
      dynamic value, Node element, List renderedList, int prevElemIndex) {
    var content = this.content;

    var idx = content.nodes.indexOf(element);

    if (idx < 0) {
      content.children.add(element);
      idx = content.nodes.indexOf(element);
    } else if (idx < prevElemIndex) {
      element.remove();
      content.children.add(element);
      idx = content.nodes.indexOf(element);
    }

    prevElemIndex = idx;
    renderedList.add(value);

    return prevElemIndex;
  }

  int _addStringToRenderList(String s, List renderedList, int prevElemIndex) {
    var content = this.content;

    if (prevElemIndex < 0) {
      setElementInnerHTML(content, s);
      prevElemIndex = content.nodes.length - 1;
      renderedList.addAll(content.nodes);
    } else {
      var preAppendSize = content.nodes.length;
      appendElementInnerHTML(content, s);

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

          var rest = restDyn.cast<Node>();
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

  Map<String, Element> getFieldsElementsMap(
      {List<String> fields, List<String> ignoreFields}) {
    ignoreFields ??= [];

    var specificFields = isNotEmptyObject(fields);

    var fieldsElements = getFieldsElements();

    var map = <String, Element>{};

    for (var elem in fieldsElements) {
      var fieldName = getElementAttribute(elem, 'field');

      var include = specificFields ? fields.contains(fieldName) : true;

      if (include && !ignoreFields.contains(fieldName)) {
        if (map.containsKey(fieldName)) {
          var elemValue =
              parseChildElementValue(map[fieldName], allowTextAsValue: false);

          if (isEmptyObject(elemValue)) {
            var value = parseChildElementValue(elem, allowTextAsValue: false);
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

  String parseChildElementValue(Element element,
          {bool allowTextAsValue = true}) =>
      parseElementValue(element,
          parentUIComponent: this, allowTextAsValue: allowTextAsValue);

  static String parseElementValue(Element element,
      {UIComponent parentUIComponent, bool allowTextAsValue = true}) {
    UIComponent uiComponent;

    if (parentUIComponent != null) {
      uiComponent = parentUIComponent.findUIComponentByChild(element);
    } else {
      uiComponent = UIRoot.getInstance().findUIComponentByChild(element);
    }

    if (uiComponent is UIField) {
      var uiField = uiComponent as UIField;
      var fieldValue = uiField.getFieldValue();
      return fieldValue != null
          ? MapProperties.toStringValue(fieldValue)
          : null;
    } else if (uiComponent is UIFieldMap) {
      var uiFieldMap = uiComponent as UIFieldMap;
      var fieldValue = uiFieldMap.getFieldMap();
      return fieldValue != null
          ? MapProperties.toStringValue(fieldValue)
          : null;
    } else if (element is TextAreaElement) {
      return element.value;
    } else if (element is SelectElement) {
      var selected = element.selectedOptions;
      if (selected == null || selected.isEmpty) return '';
      return MapProperties.toStringValue(selected.map((opt) => opt.value));
    } else if (element is InputElement) {
      var type = element.type;
      switch (type) {
        case 'file':
          return MapProperties.toStringValue(element.files.map((f) => f.name));
        default:
          return element.value;
      }
    } else {
      var value = element.getAttribute('field_value');
      if (isEmptyObject(value) && allowTextAsValue) {
        value = element.text;
      }
      return value;
    }
  }

  Map<String, String> getFields(
      {List<String> fields, List<String> ignoreFields}) {
    var fieldsElementsMap =
        getFieldsElementsMap(fields: fields, ignoreFields: ignoreFields);

    var entries = fieldsElementsMap.entries.toList();
    entries.sort((a, b) {
      var aUiComponent = findUIComponentByChild(a.value);
      var bUiComponent = findUIComponentByChild(b.value);
      var aIsUIComponent = aUiComponent != null;
      var bIsUIComponent = bUiComponent != null;

      if (aIsUIComponent && !bIsUIComponent) {
        return -1;
      } else if (bIsUIComponent && !aIsUIComponent) {
        return 1;
      } else {
        return 0;
      }
    });

    var fieldsValues = <String, String>{};

    for (var entry in entries) {
      var key = entry.key;
      if (fieldsValues.containsKey(key)) continue;
      var value = parseChildElementValue(entry.value);
      fieldsValues[key] = value;
    }

    return fieldsValues;
  }

  String getField(String fieldName) {
    var fieldElem = getFieldElement(fieldName);
    if (fieldElem == null) return null;
    return parseChildElementValue(fieldElem);
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

    var value = parseChildElementValue(fieldElem);

    _renderedFieldsValues ??= {};
    _renderedFieldsValues[fieldName] = value;
  }

  void updateRenderedFieldElementValue(Element fieldElem) {
    if (fieldElem == null) return;

    var fieldName = fieldElem.getAttribute('field');
    if (fieldName == null || fieldName.isEmpty) return;

    var value = parseChildElementValue(fieldElem);

    _renderedFieldsValues ??= {};
    _renderedFieldsValues[fieldName] = value;
  }

  bool hasEmptyField() => getFieldsElementsMap().isEmpty;

  List<String> getFieldsNames() => List.from(getFieldsElementsMap().keys);

  bool isEmptyField(String fieldName) {
    var fieldElement = getFieldElement(fieldName);
    var val = parseChildElementValue(fieldElement);
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

abstract class ElementGeneratorBase extends ElementGenerator<Node> {
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

class UIDOMActionExecutor extends DOMActionExecutorDartHTML {
  @override
  Node callLocale(Node target, List<String> parameters, DOMContext context) {
    var variables = context?.variables ?? {};
    var event = variables['event'] ?? {};
    var locale = event['value'] ?? '';

    if (locale != null) {
      var localeStr = '$locale'.trim().toLowerCase();

      if (localeStr.isNotEmpty) {
        var uiRoot = UIRoot.getInstance();

        var currentLocale = UIRoot.getCurrentLocale();

        if (currentLocale != localeStr) {
          uiRoot.setPreferredLocale(localeStr);
          uiRoot.refresh();
        }
      }
    }

    return target;
  }
}

/// A [DOMGenerator] (from package `dom_builder`)
/// able to generate [Element] (from `dart:html`).
class UIDOMGenerator extends DOMGeneratorDartHTMLImpl {
  UIDOMGenerator() {
    registerElementGenerator(BUIElementGenerator());
    registerElementGenerator(UITemplateElementGenerator());

    domActionExecutor = UIDOMActionExecutor();

    domContext = DOMContext<Node>();
    setupContextVariables();
  }

  void setupContextVariables() {
    domContext.variables = {
      'routes': () => _routesEntries(false),
      'menuRoutes': () => _routesEntries(true),
      'currentRoute': () => _currentRouteEntry(),
      'locale': () => UIRoot.getCurrentLocale(),
    };
  }

  Map<String, dynamic> _currentRouteEntry() {
    var current = UINavigator.currentNavigation;
    if (current == null) return null;
    return {'route': current.route, 'parameters': current.parameters};
  }

  List<Map<String, String>> _routesEntries(bool menuRoutes) {
    return UINavigator.navigables
        .map((e) =>
            (menuRoutes ? e.menuRoutesAndNames : e.routesAndNames).entries)
        .expand((e) => e)
        .map((e) => {'route': e.key, 'name': e.value})
        .toList();
  }

  static void setElementsBGBlur(Element element) {
    setTreeElementsBackgroundBlur(element, 'bg-blur');
  }

  static void setElementsDivCentered(Element element) {
    if (element == null) return;

    setTreeElementsDivCentered(element, 'div-centered-vh',
        centerVertically: true, centerHorizontally: true);

    setTreeElementsDivCentered(element, 'div-centered-hv',
        centerVertically: true, centerHorizontally: true);

    setTreeElementsDivCentered(element, 'div-centered-v',
        centerVertically: true, centerHorizontally: false);
    setTreeElementsDivCentered(element, 'div-centered-h',
        centerVertically: false, centerHorizontally: true);
  }

  @override
  DOMTreeMap<Node> createGenericDOMTreeMap() => createDOMTreeMap();

  @override
  bool canHandleExternalElement(externalElement) {
    if (externalElement is List) {
      return listMatchesAll(externalElement, canHandleExternalElement);
    } else if (externalElement is UIComponent) {
      return true;
    } else if (externalElement is MessageBuilder) {
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
        element.append(componentContent);
        component.setParent(element);
        component.ensureRendered();
        return [componentContent];
      }

      return null;
    } else if (externalElement is MessageBuilder) {
      var text = externalElement.build();
      var span = SpanElement();
      setElementInnerHTML(span, text);
      element.append(span);
      return [span];
    }

    return super.addExternalElementToElement(element, externalElement);
  }

  @override
  void attachFutureElement(
      DOMElement domParent,
      Node parent,
      DOMNode domElement,
      Node templateElement,
      futureElementResolved,
      DOMTreeMap<Node> treeMap,
      DOMContext<Node> context) {
    super.attachFutureElement(domParent, parent, domElement, templateElement,
        futureElementResolved, treeMap, context);

    if (futureElementResolved is Element) {
      var parentComponent =
          UIRoot.getInstance().findUIComponentByChild(futureElementResolved);
      if (parentComponent != null) {
        parentComponent._parseAttributes([futureElementResolved]);
      }
    }
  }

  @override
  void finalizeGeneratedTree(DOMTreeMap<Node> treeMap) {
    var rootElement = treeMap.rootElement;
    setElementsBGBlur(rootElement);
    setElementsDivCentered(rootElement);
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
      updateRoutes();
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
    _loadingContent = _normalizeContent(loadingContent);
    _errorContent = _normalizeContent(errorContent);

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
    _loadingContent = _normalizeContent(loadingContent);
    _errorContent = _normalizeContent(errorContent);

    _setAsyncContentFuture(contentFuture);
  }

  Map<String, dynamic> get properties => Map<String, dynamic>.from(_properties);

  dynamic get loadingContent => _loadingContent;

  dynamic get errorContent {
    if (_errorContent is Function) {
      var content = _errorContent is Function(dynamic e)
          ? _errorContent(error)
          : _errorContent();
      return _normalizeContent(content);
    } else {
      return _errorContent;
    }
  }

  dynamic _normalizeContent(dynamic content) {
    if (content is Function) {
      return content;
    } else {
      return _ensureElementForDOM(content);
    }
  }

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

  /// The error instance when loaded with error.
  dynamic get error => isWithError ? _loadedContent.content : null;

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

/// The root for `Bones_UI` component tree.
abstract class UIRoot extends UIComponent {
  static UIRoot _rootInstance;

  /// Returns the current [UIRoot] instance.
  static UIRoot getInstance() {
    return _rootInstance;
  }

  DOMTreeReferenceMap<UIComponent> _uiComponentsTree;

  LocalesManager _localesManager;

  Future<bool> _futureInitializeLocale;

  UIRoot(Element rootContainer, {dynamic classes})
      : super(rootContainer,
            classes: classes,
            componentClass: 'ui-root',
            clearParent: UIComponentClearParent.onInitialRender) {
    _initializeAll();

    _uiComponentsTree = DOMTreeReferenceMap(content,
        keepPurgedKeys: true,
        maxPurgedEntries: 1000,
        purgedEntriesTimeout: Duration(minutes: 1));

    _rootInstance = this;

    _localesManager = createLocalesManager(initializeLocale, _onDefineLocale);
    _localesManager.onPreDefineLocale.add(onPrefDefineLocale);

    _futureInitializeLocale = _localesManager.initialize(getPreferredLocale);

    window.onResize.listen(_onResize);

    UIConsole.checkAutoEnable();
  }

  @override
  void registerInUIRoot() {}

  bool get isAnyComponentRendering => _uiComponentsTree.validEntries
      .where((e) => e.value.isRendering)
      .isNotEmpty;

  UIComponent getUIComponentByContent(Element uiComponentContent) {
    if (uiComponentContent == null) return null;
    return _uiComponentsTree.get(uiComponentContent);
  }

  UIComponent getUIComponentByChild(Element child) {
    return _uiComponentsTree.getParentValue(child);
  }

  List<UIComponent> getSubUIComponentsByElement(Element element) {
    if (element == null || !_uiComponentsTree.isInTree(element)) {
      return null;
    }
    return _uiComponentsTree.getSubValues(element);
  }

  void registerUIComponentInTree(UIComponent uiComponent) {
    if (uiComponent == null) return null;
    _uiComponentsTree.put(uiComponent.content, uiComponent);
    //print('_uiComponentsTree> $_uiComponentsTree');
  }

  void purgeUIComponentsTree() => _uiComponentsTree.purge();

  @override
  void onPreConstruct() {
    UILoading.resolveLoadingElements();
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
    return _localesManager.getPreferredLocale();
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

  void notifyFinishRender() {
    onFinishRender.add(this);

    _uiComponentsTree.purge();
    //print('FINISH RENDER> _uiComponentsTree: $_uiComponentsTree');
  }

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

    UINavigator.get().refreshNavigationAsync();
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

  static void alert(dynamic dialogContent) {
    getInstance().renderAlert(dialogContent);
  }

  void renderAlert(dynamic dialogContent) {
    var div = $div(
        classes: 'bg-blur',
        style:
            'color: #fff; background-color: rgba(255,255,255,0.20); margin: 12px 24px; padding: 14px; border-radius: 8px;',
        content: dialogContent);
    UIDialog($div(content: [$br(), div]), showCloseButton: true, show: true);
  }
}

/// `Bones_UI` base class for navigable components using routes.
abstract class UINavigableComponent extends UIComponent {
  static final String COMPONENT_CLASS = 'ui-navigable-component';

  List<String> _routes;

  bool _findRoutes;

  String _currentRoute;

  Map<String, String> _currentRouteParameters;

  UINavigableComponent(Element parent, List<String> routes,
      {dynamic componentClass,
      dynamic componentStyle,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic style2,
      bool inline = true,
      bool renderOnConstruction = false})
      : _routes = routes,
        super(parent,
            componentClass: [componentClass, COMPONENT_CLASS],
            classes: classes,
            classes2: classes2,
            style: style,
            style2: style2,
            inline: inline,
            renderOnConstruction: renderOnConstruction) {
    _normalizeRoutes();

    if (findRoutes) updateRoutes();
    //if (this.routes.isEmpty) throw ArgumentError('Empty routes');

    var currentRoute = UINavigator.currentRoute;
    var currentRouteParameters = UINavigator.currentRouteParameters;

    if (currentRoute != null && currentRoute.isNotEmpty) {
      if (_routes.contains(currentRoute)) {
        _currentRoute = currentRoute;
        _currentRouteParameters = currentRouteParameters;
      }
    }

    _currentRoute ??= _routes.isNotEmpty ? _routes[0] : '';

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

  bool updateRoutes([List<String> foundRoutes]) {
    foundRoutes ??= UINavigator.get().findElementNavigableRoutes(content);

    UIConsole.log('Found navigate routes: $foundRoutes');

    var changed = false;

    for (var r in foundRoutes) {
      if (!_routes.contains(r)) {
        UIConsole.log('updateRoutes: $_routes + $r');
        _routes.add(r);
        changed = true;
      }
    }

    return changed;
  }

  void setRoutes(List<String> routes) {
    _routes = List<String>.from(routes ?? []);
  }

  /// Returns a [route] name.
  String getRouteName(String route) => null;

  /// Returns [true] of [route] should be hidden from menu.
  bool isRouteHiddenFromMenu(String route) {
    return false;
  }

  /// Returns a [Map] of routes and respective names.
  Map<String, String> get routesAndNames =>
      Map.fromEntries(routes.map((r) => MapEntry(r, getRouteName(r) ?? r)));

  /// Returns a [Map] of routes (not hidden from menu) and respective names.
  Map<String, String> get menuRoutesAndNames =>
      Map.fromEntries(menuRoutes.map((r) => MapEntry(r, getRouteName(r) ?? r)));

  /// List of routes that this component can [navigateTo].
  List<String> get routes => copyListString(_routes) ?? [];

  /// List of routes (not hidden from menu) that this component can [navigateTo].
  List<String> get menuRoutes =>
      (_routes ?? []).where((r) => !isRouteHiddenFromMenu(r)).toList();

  /// The current route rendered by this component.
  String get currentRoute => _currentRoute;

  /// The current route parameters used to rendered this component.
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
    var canHandleNewRoute = this.canHandleNewRoute(route);
    if (!canHandleNewRoute) return false;
    updateRoutes([route]);
    return true;
  }

  bool canHandleNewRoute(String route) {
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
    var currentRoute = this.currentRoute;
    var currentRouteParameters = _currentRouteParameters;
    var rendered = renderRoute(currentRoute, currentRouteParameters);

    if (_findRoutes != null && _findRoutes) {
      updateRoutes();
    }

    notifyChangeRoute();

    return rendered;
  }

  /// Called to render the [route] with [parameters].
  dynamic renderRoute(String route, Map<String, String> parameters);

  /// Should return [true] if [route] [isAccessible].
  bool isAccessibleRoute(String route) => true;

  /// Should return the route to redirect if [route] is not accessible.
  ///
  /// Same behavior of [deniedAccessRoute].
  String deniedAccessRouteOfRoute(String route) => null;

  /// Changes the current selected [route], with [parameters],
  /// of this [UINavigableComponent].
  bool navigateTo(String route, [Map<String, String> parameters]) {
    if (!canNavigateTo(route)) return false;

    parameters ??= {};

    if (_currentRoute == route &&
        isEquivalentMap(_currentRouteParameters, parameters)) {
      return true;
    }

    _currentRoute = route;
    _currentRouteParameters = copyMapString(parameters);

    _refreshInternal();
    return true;
  }

  final EventStream<String> onChangeRoute = EventStream();

  String _notifiedChangeRoute;

  Map<String, String> _notifiedChangeRouteParameters;

  void notifyChangeRoute() {
    var route = currentRoute;
    var parameters = currentRouteParameters;

    if (_notifiedChangeRoute == route &&
        isEquivalentMap(_notifiedChangeRouteParameters, parameters)) {
      return;
    }

    _notifiedChangeRoute = route;
    _notifiedChangeRouteParameters = parameters;

    onChangeRoute.add(route);
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

  /// Navigates to a main route ([mainRouteLogged] or [mainRouteNotLogged]) based in [isLogged] status and [isLoggedRoute] and [isNotLoggedRoute] checkers.
  ///
  /// Keeps the [currentRoute] if is allowed by [isLoggedRoute] and [isNotLoggedRoute], depending on [isLogged] status.
  ///
  /// Returns true if called [navigateTo].
  static bool navigateToMainRoute(
      bool Function() isLogged,
      String mainRouteLogged,
      String mainRouteNotLogged,
      bool Function(String route) isLoggedRoute,
      [bool Function(String route) isNotLoggedRoute]) {
    isNotLoggedRoute ??= (r) => !isLoggedRoute(r);

    if (isLogged()) {
      if (!isLoggedRoute(UINavigator.currentRoute)) {
        UINavigator.navigateToAsync(mainRouteLogged);
        return true;
      }
    } else {
      if (!isNotLoggedRoute(UINavigator.currentRoute)) {
        UINavigator.navigateToAsync(mainRouteNotLogged);
        return true;
      }
    }

    return false;
  }

  /// Refreshed the current route asynchronously.
  void refreshNavigationAsync([bool force = false]) {
    Future.microtask(() => refreshNavigation(force));
  }

  /// Refreshed the current route.
  void refreshNavigation([bool force = false]) {
    if (isEmptyString(currentRoute)) {
      print('Empty route!');
      return;
    }

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

  List _parseRouteFragment(Uri uri) {
    if (urlFilter != null) {
      var url = uri.toString();
      var url2 = urlFilter(url);
      if (isNotEmptyString(url2) && url2 != url) {
        UIConsole.log('Filtered URL: $url -> $url2');
        uri = Uri.parse(url2);
      }
    }

    var fragment = uri != null ? uri.fragment : '';
    fragment ??= '';

    var parts = fragment.split('?');

    var route = parts[0];
    var routeQueryString = parts.length > 1 ? parts[1] : null;

    var parameters = decodeQueryString(routeQueryString);

    return [route, parameters];
  }

  static String Function(String a) urlFilter;

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
      Future.delayed(
          Duration(milliseconds: 50),
          () => _navigateTo(route,
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

  /// [EventStream] for when navigation changes. Passes route name.
  static EventStream<String> get onNavigate => get()._onNavigate;

  void _navigateTo(String route,
      {Map<String, String> parameters,
      ParametersProvider parametersProvider,
      bool force = false,
      bool fromURL = false,
      int cantFindNavigableRetry = 0}) {
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

    if (route.contains('?')) {
      var parts = route.split('?');
      route = parts[0];
      var params = decodeQueryString(parts[1]);
      var parametersOrig = parameters;
      parameters = params;
      parameters.addAll(parametersOrig);
    }

    if (!force &&
        _lastNavigateRoute == route &&
        isEquivalentMap(parameters, _lastNavigateRouteParameters)) return;

    var routeNavigable = findNavigable(route);

    if (routeNavigable == null && cantFindNavigableRetry < 3) {
      var delay = 100 + (cantFindNavigableRetry * 500);
      Future.delayed(
          Duration(milliseconds: delay),
          () => _navigateTo(route,
              parameters: parameters,
              force: force,
              cantFindNavigableRetry: cantFindNavigableRetry + 1));
      return;
    }

    if (routeNavigable != null) {
      String deniedAccessRoute;

      if (!routeNavigable.isAccessible()) {
        deniedAccessRoute = routeNavigable.deniedAccessRoute();
      }
      if (deniedAccessRoute == null &&
          !routeNavigable.isAccessibleRoute(route)) {
        deniedAccessRoute = routeNavigable.deniedAccessRouteOfRoute(route);
      }

      if (isNotEmptyObject(deniedAccessRoute)) {
        navigateToAsync(deniedAccessRoute);
        return;
      }
    }

    _navigateCount++;

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

  static Map<String, String> get navigableRoutesAndNames {
    var routes = <String, String>{};
    for (var nav in navigables) {
      for (var route in nav.routes) {
        var name = nav.getRouteName(route);
        routes[route] = name ?? route;
      }
    }
    routes.remove('*');
    return routes;
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
  dynamic _object;

  String _text;

  String Function() _function;

  IntlKey _intlKey;

  ElementProvider _elementProvider;

  TextProvider.fromText(this._text);

  TextProvider.fromObject(this._object);

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
    } else {
      return TextProvider.fromObject(text);
    }
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

    dynamic value;

    if (_object != null) {
      value = _object.toString();
    } else if (_function != null) {
      value = _function();
    } else if (_elementProvider != null) {
      value = _elementProvider.element.text;
    } else if (_intlKey != null) {
      value = _intlKey.message;
    } else {
      throw StateError("Can't provide a text: $this");
    }

    var text = value != null ? value.toString() : '';

    if (_singleCall) {
      _text = text;
    }

    return text;
  }

  @override
  String toString() {
    return text;
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

class CSSProvider {
  Element _element;

  String _html;

  UIComponent _uiComponent;

  DOMNode _domNode;

  CSSProvider.fromElement(this._element);

  CSSProvider.fromHTML(this._html);

  CSSProvider.fromUIComponent(this._uiComponent);

  CSSProvider.fromDOMNode(this._domNode);

  factory CSSProvider.from(dynamic provider) {
    if (provider == null) return null;
    if (provider is CSSProvider) return provider;
    if (provider is String) return CSSProvider.fromHTML(provider);
    if (provider is Element) return CSSProvider.fromElement(provider);
    if (provider is UIComponent) return CSSProvider.fromUIComponent(provider);
    if (provider is DOMNode) return CSSProvider.fromDOMNode(provider);
    return null;
  }

  static bool accepts(dynamic element) {
    if (element == null) return false;
    if (element is CSSProvider) return true;
    if (element is String) return true;
    if (element is Element) return true;
    if (element is UIComponent) return true;
    if (element is DOMNode) return true;
    return false;
  }

  String get cssAsString {
    var css = this.css;
    return css != null ? css.style : null;
  }

  CSS get css {
    if (_element != null) {
      return cssFromElement(_element);
    }

    if (_html != null) {
      _element = createHTML(_html);
      return cssFromElement(_element);
    }

    if (_uiComponent != null) {
      _uiComponent.ensureRendered();
      _element = _uiComponent.content;
      return cssFromElement(_element);
    }

    if (_domNode != null) {
      var runtime = _domNode.runtime;
      if (runtime != null && runtime.exists) {
        return cssFromElement(runtime.node as Element);
      } else {
        var element =
            _domNode.buildDOM(generator: UIComponent.domGenerator) as Element;
        return cssFromElement(element);
      }
    }

    throw StateError("Can't provide CSS from: $this");
  }

  static CSS cssFromElement(Element element) {
    if (isNodeInDOM(element)) {
      return CSS(element.getComputedStyle().cssText);
    } else {
      return CSS(element.style.cssText);
    }
  }

  @override
  String toString() {
    return 'CSSProvider{_element: $_element, _html: $_html, _uiComponent: $_uiComponent, _domNode: $_domNode}';
  }
}

bool _initializedAll = false;

void _initializeAll() {
  if (_initializedAll) return;
  _initializedAll = true;

  _configure();

  _registerAllComponents();
}

void _configure() {
  Dimension.parsers.add((v) {
    return v is Screen ? Dimension(v.width, v.height) : null;
  });
}

void _registerAllComponents() {
  UIButton.register();
  UIButtonLoader.register();
  UIMultiSelection.register();
  UIDataSource.register();
  UIDocument.register();
  UIDialog.register();
}
