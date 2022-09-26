import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_utils.dart';
import 'package:collection/collection.dart'
    show IterableExtension, IterableNullableExtension;
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:json_render/json_render.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_async_content.dart';
import 'bones_ui_base.dart';
import 'bones_ui_content.dart';
import 'bones_ui_extension.dart';
import 'bones_ui_generator.dart';
import 'bones_ui_internal.dart';
import 'bones_ui_layout.dart';
import 'bones_ui_log.dart';
import 'bones_ui_navigator.dart';
import 'bones_ui_root.dart';

/// [UIComponent] behavior to clear the component.
enum UIComponentClearParent { onConstruct, onInitialRender, onRender }

/// Base class to create `Bones_UI` components.
abstract class UIComponent extends UIEventHandler {
  static final UIDOMGenerator domGenerator = UIDOMGenerator();

  /// Register a [generator] for a type of [UIComponent].
  static bool registerGenerator(UIComponentGenerator generator) {
    return domGenerator.registerElementGenerator(generator);
  }

  final UIComponentGenerator? _generator;

  static int _globalIDCount = 0;

  final int globalID;

  dynamic id;

  UIComponent? _parentUIComponent;

  Element? _parent;
  final UIComponentClearParent? clearParent;

  Element? _content;

  bool? _constructing;

  bool? get constructing => _constructing;

  UIComponent(Element? parent,
      {dynamic componentClass,
      dynamic componentStyle,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic style2,
      this.clearParent,
      bool inline = true,
      bool construct = true,
      bool renderOnConstruction = false,
      bool preserveRender = false,
      this.id,
      UIComponentGenerator? generator})
      : globalID = ++_globalIDCount,
        _parent = parent ?? createDivInline(),
        _generator = generator {
    _resolveParentUIComponent();
    if (construct) {
      _construct(preserveRender, inline, classes, classes2, componentClass,
          style, style2, componentStyle, renderOnConstruction);
    }
  }

  void _construct(
    bool preserveRender,
    bool inline,
    classes,
    classes2,
    componentClass,
    style,
    style2,
    componentStyle,
    bool renderOnConstruction,
  ) {
    _constructing = true;
    try {
      this.preserveRender = preserveRender;

      onPreConstruct();

      if (_content == null) {
        _setContent(createContentElement(inline));
      }

      _setParentUIComponent(_getUIComponentByContent(_parent));

      registerInUIRoot();

      configureID();

      configureClasses(classes, classes2, componentClass);
      configureStyle(style, style2, componentStyle);

      if (clearParent == UIComponentClearParent.onConstruct) {
        _parent!.nodes.clear();
      }
      _parent!.append(_content!);

      configure();

      if (renderOnConstruction) {
        callRender();
      }
    } finally {
      _constructing = false;
    }
  }

  UIComponentInternals get componentInternals => UIComponentInternals(
        this,
        _getContent,
        _setContent,
        _construct,
        _parseAttributes,
        _ensureAllRendered,
        _refreshInternal,
      );

  Element? _getContent() => _content;

  static final Expando<UIComponent> _contentsUIComponents =
      Expando<UIComponent>('_content:UIComponent');

  static _getContentUIComponent(Element content) =>
      _contentsUIComponents[content];

  void _setContent(Element content) {
    var prev = _content;
    if (prev != null && !identical(prev, content)) {
      _contentsUIComponents[prev] = null;
    }

    _content = content;
    _contentsUIComponents[content] = this;
  }

  void addTo(Element parent) {
    _setParentImpl(parent, true);
  }

  void insertTo(int index, Element parent) {
    _setParentImpl(parent, true);
    parent.nodes.insert(index, content!);
  }

  /// Called by constructor to register this component in the [UIRoot] tree.
  void registerInUIRoot() {
    UIRoot.getInstance()!.registerUIComponentInTree(this);
  }

  /// Called in the beginning of constructor.
  void onPreConstruct() {}

  UIComponent? clone() => null;

  /// Sets the [parent] [Element].
  Element? setParent(Element parent) {
    return _setParentImpl(parent, true);
  }

  Element? _setParentImpl(Element? parent, bool addToParent) {
    if (parent == null) throw StateError('Null parent');

    if (_content != null) {
      if (identical(_parent, parent)) {
        if (!identical(_content!.parent, _parent)) {
          _parent!.append(_content!);
        }
        _resolveParentUIComponent();
        return _parent;
      } else if (identical(_content!.parent, parent)) {
        _parentUIComponent = null;
        _parent = parent;
        _resolveParentUIComponent();
        return _parent;
      } else {
        _content!.remove();
      }
    }

    _parentUIComponent = null;
    _parent = parent;

    if (_content != null && addToParent) {
      _parent!.append(_content!);
      clear();
    }

    _resolveParentUIComponent();

    return _parent;
  }

  /// Returns a [List] of sub [UIComponent].
  List<UIComponent> get subUIComponents =>
      UIRoot.getInstance()?.getSubUIComponentsByElement(content) ?? [];

  /// Returns a [List] of sub [UIComponent] deeply in the tree.
  List<UIComponent> get subUIComponentsDeeply =>
      subUIComponents.expand((e) => [e, ...e.subUIComponents]).toList();

  void _setParentUIComponent(UIComponent? uiParent) {
    _parentUIComponent = uiParent;
    _uiRoot = null;
  }

  /// The parent [UIComponent].
  UIComponent? get parentUIComponent =>
      _parentUIComponent ??= _resolveParentUIComponent();

  UIComponent? _resolveParentUIComponent() {
    UIComponent? foundUIParent;

    var myParent = parent;
    if (myParent != null) {
      foundUIParent = _getContentUIComponent(myParent);
    }

    foundUIParent ??=
        _getUIComponentByContent(myParent) ?? _getUIComponentByChild(myParent);

    if (foundUIParent != null) {
      _setParentUIComponent(foundUIParent);
    }

    return foundUIParent;
  }

  UIRoot? _uiRoot;

  /// Returns the [UIRoot] that is parent of this [UIComponent] instance,
  /// or `null` if it's not in an [UIRoot] components tree.
  UIRoot? get uiRoot => _uiRoot ??= _resolveUIRoot();

  UIRoot? _resolveUIRoot() {
    var parent = parentUIComponent;
    if (parent == null) return null;
    return _uiRoot = parent.uiRoot;
  }

  bool _showing = true;

  bool get isShowing => _showing;

  String? _displayOnHidden;

  /// Hide component.
  void hide() {
    _content!.hidden = true;

    if (_showing) {
      _displayOnHidden = _content!.style.display;
    }
    _content!.style.display = 'none';

    _showing = false;
  }

  /// Show component.
  void show() {
    _content!.hidden = false;

    if (!_showing) {
      _content!.style.display = _displayOnHidden;
      _displayOnHidden = null;
    }

    _showing = true;
  }

  bool get isInDOM {
    return isNodeInDOM(_content!);
  }

  void configureID() {
    setID(id);
  }

  void setID(dynamic id) {
    if (id != null) {
      var idStr = parseString(id, '')!.trim();
      if (id is String) {
        id = idStr;
      }

      if (idStr.isNotEmpty) {
        this.id = id;
        _content!.id = idStr;
        return;
      }
    }

    this.id = null;
    _content!.removeAttribute('id');
  }

  static final RegExp _classesEntryDelimiter = RegExp(r'[\s,;]+');

  static List<String> parseClasses(dynamic classes1, [dynamic classes2]) {
    var c1 = _parseClasses(classes1);
    if (classes2 == null) return c1;

    var c2 = _parseClasses(classes2);

    var set = c1.toSet();
    set.addAll(c2);

    return set.toList();
  }

  static List<String> _parseClasses(classes) => toFlatListOfStrings(classes,
      delimiter: _classesEntryDelimiter, trim: true, ignoreEmpty: true);

  void configureClasses(dynamic classes1,
      [dynamic classes2, dynamic componentClasses]) {
    content!.classes.add('ui-component');

    var classesNamesComponent = parseClasses(componentClasses);
    if (classesNamesComponent.isNotEmpty) {
      for (var c in classesNamesComponent) {
        if (!content!.classes.contains(c)) {
          content!.classes.add(c);
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
    if (classesNames1.isNotEmpty) content!.classes.addAll(classesNames1);

    if (classesNamesRemove.isNotEmpty) {
      classesNamesRemove =
          classesNamesRemove.map((s) => s.replaceFirst('!', '')).toList();
      content!.classes.removeAll(classesNamesRemove);
    }
  }

  static final RegExp _cssEntryDelimiter = RegExp(r'\s*;\s*');

  static List<String> parseStyle(style1) => toFlatListOfStrings(style1,
      delimiter: _cssEntryDelimiter, trim: true, ignoreEmpty: true);

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

      var cssText = content!.style.cssText ?? '';
      if (cssText == '') {
        cssText = allStyles;
      } else {
        cssText += allStyles;
      }

      content!.style.cssText = cssText;
    }
  }

  static final RegExp _regexpIntlMessage = RegExp(r'\{\{intl?:(\w+)\}\}');

  /// Resolves [text] `{{intl:key}}` messages.
  String resolveTextIntl(String text) {
    if (text.contains('{{')) {
      var intlMessageResolver = uiRoot?.intlMessageResolver;
      intlMessageResolver ??=
          (String key, [Map<String, dynamic>? parameters]) => key;

      return text.replaceAllMapped(_regexpIntlMessage, (m) {
        var key = m[1]!;
        return intlMessageResolver!(key) ?? key;
      });
    } else {
      return text;
    }
  }

  /// Called by constructor, to configure this component.
  void configure() {}

  StreamSubscription<String>? _refreshOnNavigateListener;

  bool get refreshOnNavigate => _refreshOnNavigateListener != null;

  set refreshOnNavigate(bool refresh) {
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

  Element? get parent => _parent;

  Element? get content => _content;

  List<Element> getContentChildren({FilterElement? filter, bool deep = true}) {
    return _getContentChildrenImpl(
        _content!.children, <Element>[], deep, filter);
  }

  List<Element> _getContentChildrenImpl(
      List<Element> list, List<Element> dst, bool deep, FilterElement? filter) {
    if (list.isEmpty) return dst;

    filter ??= (_) => true;

    for (var elem in list) {
      if (filter(elem)) {
        dst.add(elem);
      }
    }

    if (deep) {
      for (var elem in list) {
        _getContentChildrenImpl(elem.children, dst, true, filter);
      }
    }

    return dst;
  }

  Element? findInContentChildDeep(FilterElement filter) =>
      _findInContentChildDeepImpl(_content?.children ?? <Element>[], filter);

  Element? _findInContentChildDeepImpl(
      List<Element> list, FilterElement filter) {
    if (list.isEmpty) return null;

    for (var elem in list) {
      if (filter(elem)) return elem;
    }

    for (var elem in list) {
      var found = _findInContentChildDeepImpl(elem.children, filter);
      if (found != null) return found;
    }

    return null;
  }

  List<Element> findChildDeep(FilterElement filter) {
    var list = <Element>[];
    _findChildDeepImpl(_content!.children, filter, list);
    return list;
  }

  void _findChildDeepImpl(
      List<Element> list, FilterElement filter, List<Element> dst) {
    if (list.isEmpty) return;

    for (var elem in list) {
      if (filter(elem)) {
        dst.add(elem);
      }
    }

    for (var elem in list) {
      _findChildDeepImpl(elem.children, filter, dst);
    }
  }

  MapEntry<String, Object>? findChildrenDeep(String fieldName) =>
      _findChildrenDeepImpl(_content!.children, fieldName);

  MapEntry<String, Object>? _findChildrenDeepImpl(
      List<Element> list, String fieldName) {
    if (list.isEmpty) return null;

    for (var elem in list) {
      var ret = _resolveElementField(elem);
      if (ret != null && ret.key == fieldName) return ret;
    }

    for (var elem in list) {
      var found = _findChildrenDeepImpl(elem.children, fieldName);
      if (found != null) return found;
    }

    return null;
  }

  List<Object> getFieldsComponents() =>
      getFieldsComponentsMap().values.toList();

  Map<String, Object> getFieldsComponentsMap(
      {List<String>? fields, List<String>? ignoreFields}) {
    var map = Map<String, Object>.fromEntries(
        _listFieldsEntriesInContentDeepImpl(_content!.children));

    if (fields != null) {
      map.removeWhere((key, value) => !fields.contains(key));
    }

    if (ignoreFields != null) {
      map.removeWhere((key, value) => ignoreFields.contains(key));
    }

    return map;
  }

  List<MapEntry<String, Object>> _listFieldsEntriesInContentDeepImpl(
      List<Element> list) {
    if (list.isEmpty) return <MapEntry<String, Object>>[];

    var fieldsEntries = list
        .expand((e) {
          var ret = _resolveElementField(e);
          if (ret != null) return [ret];
          return _listFieldsEntriesInContentDeepImpl([e]);
        })
        .whereNotNull()
        .toList();

    return fieldsEntries;
  }

  String? _renderedElementsLocale;

  List? _renderedElements;

  List? get renderedElements =>
      _renderedElements != null ? List.unmodifiable(_renderedElements!) : null;

  dynamic getRenderedElement(FilterRendered filter, [bool? deep]) {
    if (_renderedElements == null) return null;

    for (var elem in _renderedElements!) {
      if (filter(elem)) return elem;
    }

    if (deep ?? false) {
      for (var elem in _renderedElements!) {
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

  List? getAllRenderedElements(FilterRendered filter, [bool deep = false]) {
    if (_renderedElements == null) return null;

    var elements = <dynamic>{};

    for (var elem in _renderedElements!) {
      if (filter(elem)) {
        elements.add(elem);
      }
    }

    if (deep) {
      for (var elem in _renderedElements!) {
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

  dynamic getRenderedElementValueById(dynamic id, [bool deep = false]) {
    var element = getRenderedElementById(id, deep);
    if (element == null) return null;
    var value = getElementValue(element);
    return value;
  }

  dynamic getRenderedElementById(dynamic id, [bool deep = false]) =>
      getRenderedElement(
          (elem) =>
              (elem is UIComponent && elem.id == id) ||
              (elem is Element && elem.id == id),
          deep);

  dynamic getRenderedUIComponentById(dynamic id, [bool? deep]) {
    if (id == null) return null;
    var components = getRenderedUIComponents(deep);
    return components.firstWhereOrNull((e) => e.id == id);
  }

  List<UIComponent> getRenderedUIComponentsByIds(List ids, [bool? deep]) {
    if (ids.isEmpty) return <UIComponent>[];
    return getRenderedUIComponents(deep)
        .where((e) => e.id != null && ids.contains(e.id))
        .toList();
  }

  List<T> getRenderedUIComponentByType<T>([bool? deep]) =>
      getRenderedUIComponents(deep).whereType<T>().toList();

  List<UIComponent> getRenderedUIComponents([bool? deep]) =>
      (deep ?? false) ? subUIComponentsDeeply : subUIComponents;

  bool _rendered = false;

  bool get isRendered => _rendered;

  /// Clear component, removing last rendered content.
  void clear() {
    if (!isRendered) return;

    if (_renderedElements != null) {
      for (var e in _renderedElements!) {
        if (e is UIComponent) {
          e.delete();
        } else if (e is Element) {
          e.remove();
        }
      }
    }

    _renderedAsyncContents.clear();

    var elements = List.from(_content!.children);

    for (var e in elements) {
      e.remove();
    }

    _content!.children.clear();

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
    content!.remove();
  }

  void ensureRendered([bool force = false]) {
    if (!isRendered) {
      callRender();
    } else if (localeChangedFromLastRender) {
      callRender(true);
    } else if (force) {
      callRender(true);
    }
  }

  bool isAccessible() {
    return true;
  }

  String? deniedAccessRoute() {
    return null;
  }

  void callRenderAsync() {
    Future.microtask(callRender);
  }

  bool get localeChangedFromLastRender {
    var currentLocale = UIRoot.getCurrentLocale();
    return _renderLocale != currentLocale;
  }

  bool deviceSizeChangedFromLastRender(
      {double tolerance = 0.10,
      bool onlyWidth = false,
      bool onlyHeight = false}) {
    if (_renderDeviceWidth == null || _renderDeviceHeight == null) {
      return false;
    }

    var w = deviceWidth!;
    var h = deviceHeight!;

    var rw = Math.max(_renderDeviceWidth! / w, w / _renderDeviceWidth!) - 1;
    var rh = Math.max(_renderDeviceHeight! / h, h / _renderDeviceHeight!) - 1;

    //print('deviceSizeChangedFromLastRender>> $_renderDeviceWidth / $w ; $_renderDeviceHeight / $h > $rw ; $rh > $tolerance');

    if (onlyWidth) {
      return rw > tolerance;
    } else if (onlyHeight) {
      return rh > tolerance;
    } else {
      return rw > tolerance || rh > tolerance;
    }
  }

  static bool get isAnyComponentRendering =>
      UIRoot.getInstance()?.isAnyComponentRendering ?? false;

  static UIComponent? _getUIComponentByContent(Element? content) {
    return UIRoot.getInstance()?.getUIComponentByContent(content);
  }

  static UIComponent? _getUIComponentByChild(Element? content) {
    return UIRoot.getInstance()?.getUIComponentByChild(content);
  }

  UIComponent? findUIComponentByID(String id) {
    if (id.startsWith('#')) id = id.substring(1);
    if (isEmptyString(id)) return null;
    return _findUIComponentByIDImpl(id);
  }

  UIComponent? _findUIComponentByIDImpl(String id) {
    if (_content == null) return null;
    if (_content!.id == id) return this;
    if (_renderedElements == null || _renderedElements!.isEmpty) return null;

    for (var elem in _renderedElements!) {
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

  UIComponent? findUIComponentByContent(Element? content) {
    if (content == null) return null;
    if (identical(content, _content)) return this;

    if (_renderedElements == null || _renderedElements!.isEmpty) return null;

    for (var elem in _renderedElements!) {
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

    for (var elem in _content!.children) {
      if (identical(content, elem)) {
        return this;
      }
    }

    return null;
  }

  UIComponent? findUIComponentByChild(Element? child) {
    if (child == null) return null;
    if (identical(child, _content)) return this;

    for (var elem in _content!.children) {
      if (identical(child, elem)) {
        return this;
      }
    }

    if (_renderedElements != null && _renderedElements!.isNotEmpty) {
      for (var elem in _renderedElements!) {
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

    var deepChild = findInContentChildDeep((elem) => identical(child, elem));
    if (deepChild != null) return this;

    return null;
  }

  bool _rendering = false;

  bool get isRendering => _rendering;

  bool _callingRender = false;

  void callRender([bool clear = false]) {
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
        var nodes = List<Node>.from(_parent!.nodes);

        var containsContent = false;
        for (var node in nodes) {
          if (identical(node, content)) {
            containsContent = true;
          } else {
            node.remove();
          }
        }

        if (!containsContent) {
          _parent!.append(content!);
        }
      } else if (!_parent!.nodes.contains(content)) {
        _parent!.append(content!);
      }
    }

    if (clear) {
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

  String? _renderLocale;
  int? _renderDeviceWidth;
  int? _renderDeviceHeight;

  void _doRender() {
    var currentLocale = UIRoot.getCurrentLocale();

    _renderLocale = currentLocale;
    _renderDeviceWidth = deviceWidth;
    _renderDeviceHeight = deviceHeight;

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
      if (preserveRender &&
          !_renderedWithError &&
          _renderedElements != null &&
          _renderedElements!.isNotEmpty &&
          _renderedElementsLocale == _renderLocale) {
        _preserveRenderCount++;
        rendered = List.from(_renderedElements!);
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
      _parseAttributesPosRender(content!.children);
    } catch (e, s) {
      UIConsole.error('$this _parseAttributesPosRender(...) error', e, s);
    }

    _callPosRender();

    _markRenderTime();
  }

  void _finalizeRender() {
    setTreeElementsBackgroundBlur(content!, 'bg-blur');
  }

  void _ensureAllRendered(List elements) {
    if (elements.isEmpty) return;

    for (var e in elements) {
      if (e is UIComponent) {
        e.ensureRendered();
      } else if (e is Element) {
        var subElements = [];

        for (var child in e.children) {
          var uiComponent = _getUIComponentByContent(child);

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
    if (parentUIComponent == null) return;

    parentUIComponent._callOnChildRendered(this);
  }

  void _callOnChildRendered(UIComponent child) {
    try {
      onChildRendered(this);
    } catch (e, s) {
      loggerIgnoreBonesUI.e(
          'Error calling onChildRendered() for instance: $this', e, s);
    }
  }

  void onChildRendered(UIComponent child) {}

  EventStream<dynamic> onChange = EventStream();

  static int _lastRenderTime = DateTime.now().millisecondsSinceEpoch;

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

  /// If [true] will preserve last render in next calls to [render].
  bool preserveRender = false;

  /// Clears previous rendered elements. Only relevant if [preserveRender] is true.
  void clearPreservedRender() {
    if (preserveRender) {
      _renderedElements = [];
    }
  }

  /// Called when [render] returns a [Future] value, to render the content
  /// while loading `Future`.
  dynamic renderLoading() => uiRoot?.renderLoading();

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
        _parseAttributes(content!.children);
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

  List? toRenderableList(dynamic list) {
    List? renderableList;

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

    var content = this.content!;

    if (renderableList != null) {
      if (isListOfStrings(renderableList)) {
        var html = renderableList.join('\n');

        var values = _normalizeRenderListValue(content, html);

        var nodes = (values is List
                ? values
                : (values is Iterable ? values.toList() : [values]))
            .expand((e) => e is List ? e : [e])
            .map((e) {
              return _normalizeRenderListValue(content, e);
            })
            .cast<Node>()
            .toList();

        if (append) {
          content.nodes.addAll(nodes);
        } else {
          content.nodes.clear();
          content.nodes.addAll(nodes);
        }

        var renderedList = List.from(content.childNodes);
        return renderedList;
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

  dynamic _normalizeRenderListValue(Element? content, value) {
    if (value is DOMNode) {
      return value.buildDOM(generator: domGenerator, parent: content);
    } else if (value is AsDOMElement) {
      var element = value.asDOMElement;
      return element.buildDOM(generator: domGenerator, parent: content);
    } else if (value is AsDOMNode) {
      var node = value.asDOMNode;
      return node.buildDOM(generator: domGenerator, parent: content);
    } else if (value is String) {
      var nodes = $html(value);
      return nodes;
    } else if (value is Map ||
        (value is List && listMatchesAll(value, (dynamic e) => e is Map))) {
      var jsonRender = JSONRender.fromJSON(value)
        ..renderMode = JSONRenderMode.view
        ..addAllKnownTypeRenders();
      return jsonRender.render();
    } else if (value is Iterable && value is! List) {
      return value.toList();
    } else if (value is Future) {
      var asyncContent = UIAsyncContent.future(
        value,
        () {
          return renderLoading() ?? '...';
        },
        errorContent: (error) {
          markRenderedWithError();
          return renderError(error) ?? '[error: $error]';
        },
        properties: {'__Future__': value},
      )..parentUIComponent = this;
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
          value, value.content!, renderedList, prevElemIndex);
    } else if (value is UIAsyncContent) {
      prevElemIndex =
          _addUIAsyncContentToRenderList(value, renderedList, prevElemIndex);
    } else if (value is List) {
      for (var elem in value) {
        prevElemIndex = _buildRenderList(elem, renderedList, prevElemIndex);
      }
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

  void _callPosAsyncRender() {
    try {
      posAsyncRender();
    } catch (e, s) {
      UIConsole.error('$this posAsyncRender error', e, s);
    }
  }

  void posAsyncRender() {}

  Map<UIAsyncContent, List> _renderedAsyncContents = {};
  final Set<UIAsyncContent> _loadingAsyncContents = {};

  bool get isLoadingUIAsyncContent => _loadingAsyncContents.isNotEmpty;

  void _resolveUIAsyncContentLoaded(UIAsyncContent asyncContent) {
    if (!asyncContent.isLoaded) return;

    if (asyncContent.isLoaded && !asyncContent.hasAutoRefresh) {
      _loadingAsyncContents.remove(asyncContent);
    }

    var prevRendered = _renderedAsyncContents[asyncContent];
    if (prevRendered == null) return;

    if (_renderedElements == null) {
      return;
    }

    int? minRenderedElementsIdx;

    for (var e in prevRendered) {
      if (e == null) continue;
      var idx = _renderedElements!.indexOf(e);
      if (idx >= 0) {
        _renderedElements!.removeAt(idx);
        if (minRenderedElementsIdx == null || idx < minRenderedElementsIdx) {
          minRenderedElementsIdx = idx;
        }
      }
    }

    var prevElements = prevRendered
        .where((e) => e != null)
        .map((e) => e is UIComponent ? e.content : e)
        .toSet();

    int? maxContentIdx;

    for (var node in content!.nodes.toList()) {
      if (prevElements.contains(node)) {
        var idx = content!.nodes.indexOf(node);
        if (idx >= 0) {
          content!.nodes.removeAt(idx);
          if (maxContentIdx == null || idx > maxContentIdx) {
            maxContentIdx = idx;
          }
        }
      }
    }

    var loadedContent = asyncContent.content;

    var renderedList = [];
    if (maxContentIdx == null || maxContentIdx >= content!.nodes.length) {
      _buildRenderList(loadedContent, renderedList, content!.nodes.length - 1);

      _renderedElements!.addAll(renderedList);
    } else {
      var tail = content!.nodes.sublist(maxContentIdx).toList();
      for (var e in tail) {
        content!.nodes.remove(e);
      }

      _buildRenderList(loadedContent, renderedList, content!.nodes.length - 1);

      content!.nodes.addAll(tail);

      minRenderedElementsIdx ??= 0;
      _renderedElements!.insertAll(minRenderedElementsIdx, renderedList);
    }

    _ensureAllRendered(renderedList);

    try {
      _parseAttributes(content!.children);
      _parseAttributesPosRender(content!.children);
    } catch (e, s) {
      UIConsole.error('$this _parseAttributesPosRender(...) error', e, s);
    }

    _renderedAsyncContents[asyncContent] = renderedList;

    _callPosAsyncRender();
  }

  int _addUIAsyncContentToRenderList(
      UIAsyncContent asyncContent, List renderedList, int prevElemIndex) {
    if (!asyncContent.isLoaded ||
        asyncContent.isExpired ||
        asyncContent.hasAutoRefresh) {
      _loadingAsyncContents.add(asyncContent);
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
    var content = this.content!;

    var idx = content.nodes.indexOf(element);

    if (idx < 0) {
      content.append(element);
      idx = content.nodes.indexOf(element);
    } else if (idx < prevElemIndex) {
      element.remove();
      content.append(element);
      idx = content.nodes.indexOf(element);
    }

    prevElemIndex = idx;
    renderedList.add(value);

    return prevElemIndex;
  }

  void _removeFromContent(dynamic value) {
    if (value == null) return;

    if (value is Element) {
      value.remove();
    } else if (value is UIComponent) {
      if (value.isRendered) {
        value.content!.remove();
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
    if (list.isEmpty) return;

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
    if (list.isEmpty) return;

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

  DataSourceCall? _dataSourceCall;

  bool get hasDataSource => _dataSourceCall != null;

  DataSource? get dataSource =>
      _dataSourceCall != null ? _dataSourceCall!.dataSource : null;

  DataSourceCall? get dataSourceCall => _dataSourceCall;

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

    var cachedResponse = _dataSourceCall!.cachedCall();

    if (cachedResponse != null) {
      applyData(cachedResponse);
    } else {
      _dataSourceCall!.call().then((result) {
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

  String? _normalizeComponentAttributeName(String? name) {
    if (name == null) return null;
    name = name.toLowerCase().trim();
    if (name.isEmpty) return null;
    return name;
  }

  static final RegExp _valueDelimiterGeneric = RegExp(r'[\s,;]+');

  static List<String>? parseAttributeValueAsStringList(dynamic value,
          [Pattern? delimiter]) =>
      parseStringFromInlineList(value, delimiter ?? _valueDelimiterGeneric);

  static String parseAttributeValueAsString(dynamic value,
      [String? delimiter, Pattern? delimiterPattern]) {
    var list = parseAttributeValueAsStringList(value, delimiterPattern)!;
    if (list.isEmpty) return '';
    delimiter ??= ' ';
    return list.length == 1 ? list.single : list.join(delimiter);
  }

  bool setAttributes(Iterable<DOMAttribute> attributes) {
    if (attributes.isEmpty) return true;

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
    if (attributes.isEmpty) return false;

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

  dynamic getAttribute(String? name) {
    name = _normalizeComponentAttributeName(name);
    if (name == null) return null;

    switch (name) {
      case 'style':
        return content!.style.cssText;
      case 'class':
        return content!.classes.join(' ');
      case 'navigate':
        return UINavigator.getNavigateOnClick(content!);
      case 'data-source':
        return dataSourceCallString;
      default:
        return _generator != null ? _generator!.getAttribute(this, name) : null;
    }
  }

  static final RegExp _patternStyleDelimiter = RegExp(r'\s*;\s*');

  bool setAttribute(String? name, dynamic value) {
    if (value == null) {
      return clearAttribute(name);
    }

    name = _normalizeComponentAttributeName(name);
    if (name == null) return false;

    switch (name) {
      case 'style':
        {
          var valueCSS =
              parseAttributeValueAsString(value, '; ', _patternStyleDelimiter);
          content!.style.cssText = valueCSS;
          return true;
        }
      case 'class':
        {
          content!.classes.clear();
          content!.classes.addAll(parseAttributeValueAsStringList(value)!);
          return true;
        }
      case 'navigate':
        {
          UINavigator.navigateOnClick(content!, value);
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
            _generator!.setAttribute(this, name, value);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  bool appendAttribute(String? name, dynamic value) {
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
          UINavigator.navigateOnClick(content!, value);
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
            _generator!.appendAttribute(this, name, value);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  bool clearAttribute(String? name) {
    name = _normalizeComponentAttributeName(name);
    if (name == null) return false;

    switch (name) {
      case 'style':
        {
          content!.style.cssText = '';
          return true;
        }
      case 'class':
        {
          content!.classes.clear();
          return true;
        }
      case 'navigate':
        {
          UINavigator.clearNavigateOnClick(content!);
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
            _generator!.clearAttribute(this, name);
            return true;
          } else {
            return false;
          }
        }
    }
  }

  Element? getFieldElement(String? fieldName) =>
      findInContentChildDeep((e) => getElementFieldName(e) == fieldName);

  Object? getFieldComponent(String? fieldName) {
    if (fieldName == null) return null;
    return findChildrenDeep(fieldName)?.value;
  }

  List<Element> getFieldElements(String? fieldName) =>
      findChildDeep((e) => getElementFieldName(e) == fieldName);

  Element? getFieldElementByValue(String? fieldName, String value) =>
      getFieldElements(fieldName)
          .firstWhereOrNull((e) => e.resolveElementValue() == value);

  String? getComponentFieldName(Object obj) {
    if (obj is UIField) {
      return obj.fieldName;
    } else if (obj is Element) {
      return getElementFieldName(obj);
    } else {
      return null;
    }
  }

  String? getElementFieldName(Element element) {
    var ret = _resolveElementField(element);
    return ret?.key;
  }

  MapEntry<String, Object>? _resolveElementField<V>(Element element) {
    var fieldName = getElementAttributeStr(element, 'field');
    if (fieldName != null) {
      fieldName = fieldName.trim();
      if (fieldName.isNotEmpty) {
        return MapEntry<String, Object>(fieldName, element);
      }
    }

    if (element is InputElement ||
        element is TextAreaElement ||
        element is ButtonElement ||
        element is SelectElement) {
      fieldName = getElementAttributeStr(element, 'name');

      if (fieldName != null) {
        fieldName = fieldName.trim();
        if (fieldName.isNotEmpty) {
          return MapEntry<String, Object>(fieldName, element);
        }
      }
    }

    var component = _getUIComponentByContent(element);

    if (component != null) {
      if (component is UIField) {
        var field = component as UIField;
        var fieldName = field.fieldName;
        return MapEntry<String, Object>(fieldName, component);
      }
    }

    return null;
  }

  Map<String, Element> getFieldsElementsMap(
      {List<String>? fields, List<String>? ignoreFields}) {
    ignoreFields ??= [];

    var specificFields = isNotEmptyObject(fields);

    var fieldsElements = getFieldsElements();

    var map = <String, Element>{};

    for (var elem in fieldsElements) {
      var fieldName = getElementFieldName(elem)!;

      var include = specificFields ? fields!.contains(fieldName) : true;

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
    content!.nodes.clear();
    return true;
  }

  bool setContentNodes(List<Node> nodes) {
    content!.nodes.clear();
    content!.nodes.addAll(nodes);
    return true;
  }

  bool appendToContent(List<Node> nodes) {
    content!.nodes.addAll(nodes);
    return true;
  }

  List<Element> getFieldsElements() => _getContentChildrenImpl(
      content!.children, [], true, (e) => getElementFieldName(e) != null);

  String? parseChildElementValue(Element? childElement,
          {bool allowTextAsValue = true}) =>
      childElement?.resolveElementValue(
          parentUIComponent: this, allowTextAsValue: allowTextAsValue);

  Map<String, String?> getFields(
      {List<String>? fields, List<String>? ignoreFields}) {
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

    var fieldsValues = <String, String?>{};

    for (var entry in entries) {
      var key = entry.key;
      if (fieldsValues.containsKey(key)) continue;
      var value = parseChildElementValue(entry.value);
      fieldsValues[key] = value;
    }

    return fieldsValues;
  }

  Map<String, Object?> getFieldsExtended(
      {List<String>? fields, List<String>? ignoreFields}) {
    var fieldsElementsMap =
        getFieldsComponentsMap(fields: fields, ignoreFields: ignoreFields);

    var entries = fieldsElementsMap.entries.toList();
    entries.sort((a, b) {
      var aIsUIComponent = a is UIComponent;
      var bIsUIComponent = b is UIComponent;

      if (aIsUIComponent && !bIsUIComponent) {
        return -1;
      } else if (bIsUIComponent && !aIsUIComponent) {
        return 1;
      } else {
        return 0;
      }
    });

    var fieldsValues = <String, Object?>{};

    for (var entry in entries) {
      var key = entry.key;
      if (fieldsValues.containsKey(key)) continue;
      fieldsValues[key] = entry.value;
    }

    return fieldsValues;
  }

  Map<String, dynamic>? _renderedFieldsValues;

  dynamic getPreviousRenderedFieldValue(String? fieldName) =>
      _renderedFieldsValues != null ? _renderedFieldsValues![fieldName!] : null;

  void setField(String fieldName, dynamic value) {
    var fieldElem = getFieldElement(fieldName);
    if (fieldElem == null) return;

    var valueStr = value != null ? '$value' : null;

    _renderedFieldsValues ??= {};
    _renderedFieldsValues![fieldName] = valueStr;

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
    _renderedFieldsValues![fieldName] = value;
  }

  void updateRenderedFieldElementValue(Element fieldElem) {
    var fieldName = getElementFieldName(fieldElem);
    if (fieldName == null) return;

    var value = parseChildElementValue(fieldElem);

    _renderedFieldsValues ??= {};
    _renderedFieldsValues![fieldName] = value;
  }

  bool hasEmptyField() => getFieldsElementsMap().isEmpty;

  List<String> getFieldsNames() => List.from(getFieldsElementsMap().keys);

  String? getField(String? fieldName) {
    if (fieldName == null) return null;
    var field = getFieldExtended(fieldName);
    return field?.toString();
  }

  V? getFieldExtended<V>(String? fieldName) {
    if (fieldName == null) return null;
    var fieldComponent = getFieldComponent(fieldName);
    if (fieldComponent == null) return null;

    if (fieldComponent is UIField) {
      return fieldComponent.getFieldValue() as V?;
    } else if (fieldComponent is UIComponent) {
      var val = parseChildElementValue(fieldComponent.content);
      return val as V?;
    } else if (fieldComponent is Element) {
      var val = parseChildElementValue(fieldComponent);
      return val as V?;
    } else {
      return fieldComponent.toString() as V?;
    }
  }

  bool isEmptyField(String? fieldName) {
    if (fieldName == null) return false;
    var val = getFieldExtended(fieldName);
    return isEmptyValue(val);
  }

  List<String> getEmptyFields() {
    var fields = getFields();
    fields.removeWhere((k, v) => !isEmptyValue(v));
    return fields.keys.toList();
  }

  bool focusField(String? fieldName) {
    if (fieldName == null) return false;

    var component = getFieldComponent(fieldName);

    if (component is Element) {
      component.focus();
      return true;
    } else if (component is UIComponent) {
      var input = findInContentChildDeep(
          (e) => e is InputElement || e is TextAreaElement);
      if (input != null) {
        input.focus();
        return true;
      }

      component.content?.focus();
      return true;
    }

    return false;
  }

  int forEachFieldElement(ForEachElement f) {
    var count = 0;

    for (var elem in getFieldsElements()) {
      f(elem);
      count++;
    }

    return count;
  }

  int forEachFieldComponent(ForEachComponent f) {
    var count = 0;

    for (var e in getFieldsComponents()) {
      f(e);
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

  int forEachEmptyFieldComponent(ForEachComponent f) {
    var count = 0;

    var list = getEmptyFields();

    for (var fieldName in list) {
      var elem = getFieldComponent(fieldName);
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
