import 'package:dom_builder/dom_builder_web.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:statistics/statistics.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import 'bones_ui_async_content.dart';
import 'bones_ui_component.dart';
import 'bones_ui_navigator.dart';
import 'bones_ui_root.dart';
import 'bones_ui_web.dart';
import 'component/bui.dart';
import 'component/template.dart';

typedef UIComponentInstantiator<C extends UIComponent> = C Function(
    UIElement? parent,
    Map<String, DOMAttribute> attributes,
    UINode? contentHolder,
    List<DOMNode>? contentNodes);

typedef UIComponentAttributeParser<T> = T? Function(dynamic value);

typedef UIComponentAttributeGetter<C extends UIComponent, T> = T? Function(
    C uiComponent);

typedef UIComponentAttributeSetter<C extends UIComponent, T> = void Function(
    C uiComponent, T? value);

typedef UIComponentAttributeAppender<C extends UIComponent, T> = void Function(
    C uiComponent, T? value);

typedef UIComponentAttributeCleaner<C extends UIComponent, T> = void Function(
    C uiComponent);

/// Handler of a [UIComponent] attribute.
class UIComponentAttributeHandler<C extends UIComponent, T> {
  static String? normalizeComponentAttributeName(String? name) {
    if (name == null) return null;
    name = name.toLowerCase().trim();
    if (name.isEmpty) return null;
    return name;
  }

  final String? name;
  final UIComponentAttributeParser<T>? parser;

  final UIComponentAttributeGetter<C, T>? getter;

  final UIComponentAttributeSetter<C, T>? setter;

  final UIComponentAttributeAppender<C, T>? appender;

  final UIComponentAttributeCleaner<C, T> cleaner;

  UIComponentAttributeHandler(String name,
      {this.parser,
      this.getter,
      this.setter,
      UIComponentAttributeAppender<C, T>? appender,
      UIComponentAttributeCleaner<C, T>? cleaner})
      : name = normalizeComponentAttributeName(name),
        appender = appender ?? setter,
        cleaner = cleaner ?? ((c) => setter!(c, null)) {
    if (getter == null) throw ArgumentError.notNull('getter');
    if (setter == null) throw ArgumentError.notNull('setter');
  }

  T? parse(dynamic value) => parser != null ? parser!(value) : value;

  T? get(C uiComponent) => getter!(uiComponent);

  void set(C uiComponent, dynamic value) {
    var v = parse(value);
    setter!(uiComponent, v);
  }

  void append(C uiComponent, dynamic value) {
    var v = parse(value);
    appender!(uiComponent, v);
  }

  void clear(C uiComponent) => cleaner(uiComponent);
}

/// A generator of [UIComponent] based in a HTML tag,
/// for `dom_builder` (extends [ElementGenerator]).
class UIComponentGenerator<C extends UIComponent>
    extends ElementGenerator<UIElement> {
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
      {this.hasChildrenElements = true,
      this.usesContentHolder = true,
      bool contentAsText = false})
      : componentClass = DOMAttributeValueSet(
            componentClass,
            DOMAttribute.getAttributeDelimiter('class')!,
            DOMAttribute.getAttributeDelimiterPattern('class')!),
        componentStyle = DOMAttributeValueCSS(componentStyle),
        attributes = Map<String, UIComponentAttributeHandler>.fromEntries(
            attributes.map(((attr) => MapEntry(attr.name!, attr))));

  @override
  UIElement generate(
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode> treeMap,
      tag,
      DOMElement? domParent,
      UINode? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      UINode? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<UINode>? context) {
    var component = instantiator(
        parent as UIElement?, attributes, contentHolder, contentNodes);
    var anySet = component.appendAttributes(attributes.values);

    if (anySet) {
      component.ensureRendered(true);
    } else {
      component.ensureRendered();
    }

    return component.content!;
  }

  @override
  bool isGeneratedElement(UINode element) {
    final element2 = element.asElementChecked;
    if (element2 != null) {
      var tag = element2.tagName.toLowerCase();
      if (tag != generatedTag) return false;
      var classes = element2.classList.toList();
      var match = classes.containsAll(componentClass.asAttributeValues!);
      print(classes);
      print('$componentClass -> $match');
      return match;
    } else {
      return false;
    }
  }

  UIComponentAttributeHandler? getAttributeHandler(String? name) {
    name = UIComponentAttributeHandler.normalizeComponentAttributeName(name);
    if (name == null || name.isEmpty) return null;
    return attributes[name];
  }

  T? getAttribute<T>(C uiComponent, String name) {
    var attribute = getAttributeHandler(name);
    return attribute?.get(uiComponent);
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
  DOMElement? revert(
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode>? treeMap,
      DOMElement? domParent,
      UIElement? parent,
      UIElement? node) {
    var attributes =
        node != null ? node.attributes.toMap() : <String, String>{};

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
      } else if (node != null) {
        domElement.add(node.text);
      }
    }

    return domElement;
  }

  String? _parseNodeStyle(Map<String, String> attributes) {
    String? style = (attributes.remove('style') ?? '').trim();

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

    if (style.isEmpty) {
      style = null;
    }

    return style;
  }

  String? _parseNodeClass(Map<String, String> attributes) {
    String? classes = (attributes.remove('class') ?? '').trim();

    if (componentClass.hasAttributeValue && classes.isNotEmpty) {
      var attributeDelimiter = DOMAttribute.getAttributeDelimiter('class')!;
      var attrClass = DOMAttributeValueList(classes, attributeDelimiter,
          DOMAttribute.getAttributeDelimiterPattern('class')!);

      attrClass.removeAttributeValueEntry('ui-component');
      attrClass
          .removeAttributeValueAllEntries(componentClass.asAttributeValues!);

      classes = attrClass.asAttributeValue;
    }

    if (classes != null && classes.isEmpty) {
      classes = null;
    }

    return classes;
  }
}

abstract class ElementGeneratorBase extends ElementGenerator<UINode> {
  void setElementAttributes(
      UIElement element, Map<String, DOMAttribute> attributes) {
    element.classList.add(tag);

    var attrClass = attributes['class'];

    if (attrClass != null && attrClass.valueLength > 0) {
      element.classList.addAll(attrClass.values!);
    }

    var attrStyle = attributes['style'];

    if (attrStyle != null && attrStyle.valueLength > 0) {
      var prevCssText = element.style?.cssText;
      if (prevCssText == '') {
        element.style?.cssText = attrStyle.value ?? '';
      } else {
        var cssText2 = '$prevCssText; ${attrStyle.value} ;';
        element.style?.cssText = cssText2;
      }
    }
  }
}

class UIComponentDOMContext extends DOMContext<UINode> {
  final UIComponent uiComponent;

  UIComponentDOMContext(this.uiComponent, DOMContext<UINode>? parent)
      : super(parent: parent, intlMessageResolver: parent?.intlMessageResolver);

  @override
  String toString() {
    return 'UIComponentDOMContext{viewport: $viewport, resolveCSSViewportUnit: $resolveCSSViewportUnit resolveCSSURL: $resolveCSSURL}@$uiComponent';
  }
}

/// A [DOMGenerator] (from package `dom_builder`)
/// able to generate [UIElement] (from `web`).
class UIDOMGenerator extends DOMGeneratorWebImpl {
  UIDOMGenerator() {
    registerElementGenerator(BUIElementGenerator());
    registerElementGenerator(UITemplateElementGenerator());

    domActionExecutor = UIDOMActionExecutor();

    domContext = DOMContext<UINode>(intlMessageResolver: resolveIntlMessage);

    setupContextVariables();
  }

  @override
  bool isMappable(DOMNode domNode, {DOMContext<Node>? context}) =>
      _isMappableImpl(domNode);

  static bool _isNoEventDOMElement(DOMElement domElement) {
    switch (domElement.tag) {
      // No event elements:
      case 'br':
      case 'wbr':
      case 'hr':
        return true;

      default:
        return false;
    }
  }

  static final _handledElementAttributes = UIComponent.handledElementAttributes
      .map(DOMAttribute.normalizeName)
      .nonNulls
      .toList();

  static bool _domElementContainsHandledAttribute(DOMElement domElement) {
    for (var a in _handledElementAttributes) {
      if (domElement.containsAttribute(a)) return true;
    }
    return false;
  }

  final _stack = <DOMNode>[];

  bool _isMappableImpl(DOMNode node) {
    final stack = _stack..clear();

    stack.add(node);

    do {
      final domNode = stack.removeLast();

      if (domNode is TextNode) {
        continue;
      } else if (domNode is! DOMElement) {
        stack.clear();
        return true;
      }

      if (_isNoEventDOMElement(domNode)) {
        continue;
      }

      if (domNode.hasAnyEventListener) {
        stack.clear();
        return true;
      }

      if (_domElementContainsHandledAttribute(domNode)) {
        stack.clear();
        return true;
      }

      final content = domNode.content;
      if (content == null || content.isEmpty) continue;

      for (var i = content.length - 1; i >= 0; --i) {
        stack.add(content[i]);
      }
    } while (stack.isNotEmpty);

    stack.clear();
    return false;
  }

  void setupContextVariables() {
    domContext!.variables = {
      'routes': () => _routesEntries(false),
      'menuRoutes': () => _routesEntries(true),
      'currentRoute': () => _currentRouteEntry(),
      'locale': () => UIRoot.getCurrentLocale(),
    };
  }

  String? resolveIntlMessage(String key, [Map<String, dynamic>? parameters]) {
    var uiRoot = UIRoot.getInstance();
    var msgResolver = uiRoot?.intlMessageResolver;
    var msg = msgResolver != null ? msgResolver(key, parameters) : null;
    if (isEmptyString(msg)) {
      msg = IntlBasicDictionary.msg(key, IntlLocale.getDefaultIntlLocale());
    }
    return msg;
  }

  Map<String, dynamic>? _currentRouteEntry() {
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

  static void setElementsBGBlur(UIElement element) {
    setTreeElementsBackgroundBlur(element, 'bg-blur');
  }

  static void setElementsDivCentered(UIElement element) {
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
  DOMTreeMap<UINode> createGenericDOMTreeMap() => createDOMTreeMap();

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
  List<UINode>? addExternalElementToElement(
      UINode element, Object? externalElement,
      {DOMTreeMap<Node>? treeMap, DOMContext<Node>? context}) {
    if (externalElement == null) return null;

    if (externalElement is List) {
      if (externalElement.isEmpty) return null;

      if (externalElement.length == 1) {
        return addExternalElementToElement(element, externalElement.first,
            treeMap: treeMap, context: context);
      }

      var children = <UINode>[];
      for (var elem in externalElement) {
        var child = addExternalElementToElement(element, elem,
            treeMap: treeMap, context: context);
        if (child != null) {
          children.addAll(child);
        }
      }
      return children;
    } else if (externalElement is UIComponent) {
      var component = externalElement;
      var componentContent = component.content;

      if (componentContent != null) {
        final element2 = element.asElementChecked;
        if (element2 != null) {
          element2.appendChild(componentContent);
          component.setParent(element2);
          _resolveParentUIComponent(element2, component.content,
              childUIComponent: component);
          component.ensureRendered();
          return [componentContent];
        } else {
          _resolveParentUIComponent(element2, component.content,
              childUIComponent: component);
          return null;
        }
      }
    } else if (externalElement is MessageBuilder) {
      var text = externalElement.build();
      var span = HTMLSpanElement();
      setElementInnerHTML(span, text);
      element.appendChild(span);
      return [span];
    }

    return super.addExternalElementToElement(element, externalElement,
        treeMap: treeMap, context: context);
  }

  @override
  bool addChildToElement(UINode? parent, UINode? child) {
    var ok = super.addChildToElement(parent, child);
    _resolveParentUIComponent(parent, child);
    return ok;
  }

  @override
  void attachFutureElement(
      DOMElement? domParent,
      UINode? parent,
      DOMNode domElement,
      UINode? templateElement,
      Object? futureElementResolved,
      DOMTreeMap<UINode> treeMap,
      DOMContext<UINode>? context) {
    futureElementResolved = resolveElements(futureElementResolved);
    if (futureElementResolved == null) return;

    super.attachFutureElement(domParent, parent, domElement, templateElement,
        futureElementResolved, treeMap, context);

    if (futureElementResolved.isElement) {
      UIComponent? parentComponent;

      if (context is UIComponentDOMContext) {
        parentComponent = context.uiComponent;
      } else {
        parentComponent = UIRoot.getInstance()!
            .findUIComponentByChild(futureElementResolved as UIElement);
      }

      if (parentComponent != null) {
        parentComponent.componentInternals
            .parseAttributes([futureElementResolved]);
        parentComponent.componentInternals
            .ensureAllRendered([futureElementResolved]);

        _resolveParentUIComponent(
            parentComponent.content, futureElementResolved as UIElement,
            parentUIComponent: parentComponent);
      }
    }
  }

  @override
  List<UINode>? toElements(Object? elements,
      {DOMTreeMap<UINode>? treeMap,
      DOMContext<UINode>? context,
      bool setTreeMapRoot = true}) {
    if (elements is UIComponent) {
      elements.ensureRendered();
      var content = elements.content;
      return content != null ? [content] : null;
    } else if (elements is UIAsyncContent) {
      var content = elements.content;
      return content != null ? [content] : null;
    } else {
      return super.toElements(elements,
          treeMap: treeMap, context: context, setTreeMapRoot: setTreeMapRoot);
    }
  }

  @override
  bool replaceChildElement(
      UINode parent, UINode? child1, List<UINode>? child2) {
    var ok = super.replaceChildElement(parent, child1, child2);

    if (ok && child2 != null && child2.isNotEmpty) {
      var uiRoot = UIRoot.getInstance();

      for (var element in child2.whereElement()) {
        var uiComponent = uiRoot!
            .getUIComponentByContent(element, includePurgedEntries: true);
        if (uiComponent != null) {
          uiComponent.setParent(parent as UIElement);
          _resolveParentUIComponent(parent, element,
              childUIComponent: uiComponent);
          uiComponent.ensureRendered();
        }
      }
    }

    return ok;
  }

  @override
  void finalizeGeneratedTree(DOMTreeMap<UINode> treeMap) {
    var rootElement = treeMap.rootElement;
    if (rootElement.isElement) {
      setElementsBGBlur(rootElement as Element);
      setElementsDivCentered(rootElement);
    }
  }

  void _resolveParentUIComponent(UINode? parent, UINode? child,
      {UIComponent? parentUIComponent, UIComponent? childUIComponent}) {
    UIComponent.resolveParentUIComponent(
        parent: parent,
        parentUIComponent: parentUIComponent,
        element: child,
        elementUIComponent: childUIComponent);
  }
}

class UIDOMActionExecutor extends DOMActionExecutorWebHTML {
  @override
  UINode? callLocale(
      UINode? target, List<String> parameters, DOMContext? context) {
    var variables = context?.variables ?? {};
    var event = (variables['event'] as Map?) ?? {};
    var locale = event['value'] ?? '';

    if (locale != null) {
      var localeStr = '$locale'.trim().toLowerCase();

      if (localeStr.isNotEmpty) {
        var uiRoot = UIRoot.getInstance();

        if (uiRoot != null) {
          var currentLocale = UIRoot.getCurrentLocale();

          if (currentLocale != localeStr) {
            uiRoot.setPreferredLocale(localeStr).then((ok) {
              uiRoot.refresh();
            });
          }
        }
      }
    }

    return target;
  }
}
