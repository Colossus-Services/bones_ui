import 'dart:html';

import 'package:dom_builder/dom_builder_dart_html.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_async_content.dart';
import 'bones_ui_component.dart';
import 'bones_ui_navigator.dart';
import 'bones_ui_root.dart';
import 'component/bui.dart';
import 'component/template.dart';

typedef UIComponentInstantiator<C extends UIComponent> = C Function(
    Element? parent,
    Map<String, DOMAttribute> attributes,
    Node? contentHolder,
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
  Element generate(
      DOMGenerator<Node> domGenerator,
      DOMTreeMap<Node> treeMap,
      tag,
      DOMElement? domParent,
      Node? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      Node? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<Node>? context) {
    var component = instantiator(
        parent as Element?, attributes, contentHolder, contentNodes);
    var anySet = component.appendAttributes(attributes.values);

    if (anySet) {
      component.ensureRendered(true);
    } else {
      component.ensureRendered();
    }

    return component.content!;
  }

  @override
  bool isGeneratedElement(Node element) {
    if (element is Element) {
      var tag = element.tagName.toLowerCase();
      if (tag != generatedTag) return false;
      var classes = element.classes;
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
  DOMElement? revert(DOMGenerator<Node> domGenerator, DOMTreeMap<Node>? treeMap,
      DOMElement? domParent, Element? parent, Element? node) {
    var attributes = node != null
        ? Map<String, String>.fromEntries(node.attributes.entries)
        : <String, String>{};

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

abstract class ElementGeneratorBase extends ElementGenerator<Node> {
  void setElementAttributes(
      Element element, Map<String, DOMAttribute> attributes) {
    element.classes.add(tag);

    var attrClass = attributes['class'];

    if (attrClass != null && attrClass.valueLength > 0) {
      element.classes.addAll(attrClass.values!);
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

/// A [DOMGenerator] (from package `dom_builder`)
/// able to generate [Element] (from `dart:html`).
class UIDOMGenerator extends DOMGeneratorDartHTMLImpl {
  UIDOMGenerator() {
    registerElementGenerator(BUIElementGenerator());
    registerElementGenerator(UITemplateElementGenerator());

    domActionExecutor = UIDOMActionExecutor();

    domContext = DOMContext<Node>(intlMessageResolver: resolveIntlMessage);

    setupContextVariables();
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

  static void setElementsBGBlur(Element element) {
    setTreeElementsBackgroundBlur(element, 'bg-blur');
  }

  static void setElementsDivCentered(Element element) {
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
  List<Node>? addExternalElementToElement(Node element, externalElement) {
    if (externalElement is List) {
      if (externalElement.isEmpty) return null;
      var children = <Node>[];
      for (var elem in externalElement) {
        var child = addExternalElementToElement(element, elem)!;
        children.addAll(child);
      }
      return children;
    } else if (externalElement is UIComponent) {
      var component = externalElement;
      var componentContent = component.content;

      if (element is Element) {
        element.append(componentContent!);
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
      DOMElement? domParent,
      Node? parent,
      DOMNode domElement,
      Node? templateElement,
      futureElementResolved,
      DOMTreeMap<Node> treeMap,
      DOMContext<Node>? context) {
    super.attachFutureElement(domParent, parent, domElement, templateElement,
        futureElementResolved, treeMap, context);

    if (futureElementResolved is Element) {
      var parentComponent =
          UIRoot.getInstance()!.findUIComponentByChild(futureElementResolved);
      if (parentComponent != null) {
        parentComponent.componentInternals
            .parseAttributes([futureElementResolved]);
        parentComponent.componentInternals
            .ensureAllRendered([futureElementResolved]);
      }
    }
  }

  @override
  List<Node>? toElements(elements) {
    if (elements is UIComponent) {
      var content = elements.content;
      return content != null ? [content] : null;
    } else if (elements is UIAsyncContent) {
      var content = elements.content;
      return content != null ? [content] : null;
    } else {
      return super.toElements(elements);
    }
  }

  @override
  bool replaceChildElement(Node parent, Node? child1, List<Node>? child2) {
    var ok = super.replaceChildElement(parent, child1, child2);

    if (ok && child2 != null && child2.isNotEmpty) {
      var uiRoot = UIRoot.getInstance();

      for (var e in child2.whereType<Element>()) {
        var uiComponent =
            uiRoot!.getUIComponentByContent(e, includePurgedEntries: true);
        if (uiComponent != null) {
          uiComponent.setParent(parent as Element);
          uiComponent.ensureRendered();
        }
      }
    }

    return ok;
  }

  @override
  void finalizeGeneratedTree(DOMTreeMap<Node> treeMap) {
    var rootElement = treeMap.rootElement;
    if (rootElement is Element) {
      setElementsBGBlur(rootElement);
      setElementsDivCentered(rootElement);
    }
  }
}

class UIDOMActionExecutor extends DOMActionExecutorDartHTML {
  @override
  Node? callLocale(Node? target, List<String> parameters, DOMContext? context) {
    var variables = context?.variables ?? {};
    var event = (variables['event'] as Map?) ?? {};
    var locale = event['value'] ?? '';

    if (locale != null) {
      var localeStr = '$locale'.trim().toLowerCase();

      if (localeStr.isNotEmpty) {
        var uiRoot = UIRoot.getInstance();

        var currentLocale = UIRoot.getCurrentLocale();

        if (currentLocale != localeStr) {
          uiRoot!.setPreferredLocale(localeStr);
          uiRoot.refresh();
        }
      }
    }

    return target;
  }
}
