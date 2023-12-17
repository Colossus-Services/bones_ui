import 'dart:html';

import 'package:dom_builder/dom_builder.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_generator.dart';
import '../bones_ui_navigator.dart';
import '../bones_ui_web.dart';
import 'loading.dart';

class UITemplateElementGenerator extends ElementGeneratorBase {
  UITemplateElementGenerator();

  @override
  final String tag = 'ui-template';

  @override
  bool get hasChildrenElements => false;

  @override
  bool get usesContentHolder => false;

  @override
  Element generate(
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode> treeMap,
      String? tag,
      DOMElement? domParent,
      UINode? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      UINode? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<UINode>? context) {
    context ??= domGenerator.domContext;

    var domElement = domNode as DOMElement;

    var element = DivElement();

    setElementAttributes(element, attributes);

    domGenerator.addChildToElement(parent, element);

    var hasUnresolvedTemplate =
        contentNodes!.where((e) => e.hasUnresolvedTemplate).isNotEmpty;

    if (hasUnresolvedTemplate) {
      var htmlUnresolved = _nodesToHTMLUnresolved(contentNodes);
      _generateFromTemplateHTML(htmlUnresolved, domGenerator, treeMap,
          domElement, element, attributes, context);
    } else {
      domGenerator.generateWithRoot(domElement, element, contentNodes);
    }

    return element;
  }

  String _nodesToHTMLUnresolved(List<DOMNode> contentNodes) {
    return contentNodes
        .map((e) => e.buildHTML(
            withIndent: true, buildTemplates: false, resolveDSX: false))
        .join('');
  }

  void _generateFromTemplateHTML(
      String html,
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode> treeMap,
      DOMElement domElement,
      DivElement element,
      Map<String, DOMAttribute> attributes,
      DOMContext<UINode>? domContext) {
    try {
      var template = DOMTemplate.tryParse(html);

      if (template == null) {
        _generateElementContentFromHTML(
            domGenerator, treeMap, html, domElement, element);
      } else {
        var variables =
            getTemplateVariables(domGenerator, attributes, domContext);

        var asyncValues = deepCatchesMapValues(variables, (c, k, v) {
          return v is AsyncValue;
        });

        if (asyncValues.isNotEmpty) {
          var futures =
              asyncValues.whereType<AsyncValue>().map((e) => e.future).toList();

          var loadingConfig = UILoadingConfig.fromMap(attributes, 'loading-');

          DivElement? uiLoading;
          if (loadingConfig != null) {
            uiLoading = loadingConfig.asDivElement();
            element.append(uiLoading);
          }

          Future.wait(futures).then((_) {
            _normalizeVariables(variables, domContext);

            uiLoading?.remove();

            _generateElementContentFromTemplate(domGenerator, treeMap,
                domContext, template, variables, domElement, element);
          });
        } else {
          _generateElementContentFromTemplate(domGenerator, treeMap, domContext,
              template, variables, domElement, element);
        }
      }
    } catch (e, s) {
      print(e);
      print(s);

      _generateElementContentFromHTML(
          domGenerator, treeMap, html, domElement, element);
    }
  }

  void _generateElementContentFromTemplate(
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode> treeMap,
      DOMContext<UINode>? domContext,
      DOMTemplateNode template,
      Map<String, dynamic> variables,
      DOMElement domElement,
      DivElement element) {
    var templateBuiltHTML = template.buildAsString(variables,
        resolveDSX: false,
        elementProvider: (q) => treeMap.queryElement(q,
            domContext: domContext, buildTemplates: true),
        intlMessageResolver: domContext?.intlMessageResolver);

    var nodes = DOMNode.parseNodes(templateBuiltHTML);

    _setElementAttributes(domElement, element);

    domElement.clearNodes();

    domGenerator.generateWithRoot(domElement, element, nodes,
        treeMap: treeMap, finalizeTree: false, setTreeMapRoot: false);

    return;
  }

  void _generateElementContentFromHTML(
      DOMGenerator<UINode> domGenerator,
      DOMTreeMap<UINode> treeMap,
      String html,
      DOMElement domElement,
      DivElement element) {
    _setElementAttributes(domElement, element);

    domElement.clearNodes();

    domGenerator.generateFromHTML(html,
        treeMap: treeMap,
        domParent: domElement,
        parent: element,
        finalizeTree: false,
        setTreeMapRoot: false);
  }

  void _setElementAttributes(DOMElement domElement, DivElement element) {
    for (var attr in domElement.domAttributes.entries) {
      var attrValue = attr.value;
      if (attrValue.isBoolean && !attrValue.hasValue) {
        continue;
      } else {
        var value = attrValue.value;
        var valueStr = value?.toString() ?? '';

        if (valueStr.isNotEmpty) {
          element.setAttribute(attr.key, valueStr);
        }
      }
    }
  }

  Map<String, dynamic> getTemplateVariables(DOMGenerator domGenerator,
      Map<String, DOMAttribute> attributes, DOMContext<UINode>? domContext) {
    domContext ??= domGenerator.domContext as DOMContext<UINode>?;
    if (domContext == null) return {};

    var variables = domContext.variables;

    var routeParameters = UINavigator.currentNavigation?.parameters;

    if (isNotEmptyObject(routeParameters)) {
      variables['parameters'] = routeParameters;
    }

    resolveAttributeVariables(attributes, variables);

    variables['attributes'] =
        attributes.map((key, value) => MapEntry(key, '$value'));

    _normalizeVariables(variables, domContext);

    var attributesResolved = variables['attributes'] as Map<String, String>;

    var dataSourceResponse = getDataSourceResponse(attributesResolved);

    if (dataSourceResponse != null) {
      variables['data'] = AsyncValue.from(dataSourceResponse);
    }

    _normalizeVariables(variables, domContext);

    return variables;
  }

  void resolveAttributeVariables(
      Map<String, DOMAttribute> attributes, Map<String, dynamic> variables) {
    var map = parseAttributeVariables(attributes) ?? {};

    for (var entry in map.entries) {
      var k = '${entry.key}';
      var v = entry.value;
      if (isNotEmptyString(k)) {
        variables[k] = v;
      }
    }
  }

  Map? parseAttributeVariables(Map<String, DOMAttribute> attributes) {
    var value = attributes['variables']?.toString();

    if (isNotEmptyString(value, trim: true)) {
      if (isJSONMap(value)) {
        return parseJSON(value) as Map?;
      } else {
        return decodeQueryString(value);
      }
    }
    return null;
  }

  void _normalizeVariables(
      Map<String, dynamic> variables, DOMContext? domContext) {
    deepReplaceValues(variables, (c, k, v) {
      return v is Function;
    }, (c, k, v) {
      var f = v as Function;
      // ignore: avoid_dynamic_calls
      return f();
    });

    deepReplaceValues(variables, (c, k, v) {
      return v is Future;
    }, (c, k, v) {
      return AsyncValue.from(v);
    });

    deepReplaceValues(variables, (c, k, v) {
      return v is AsyncValue && v.isLoaded;
    }, (c, k, v) {
      var v2 = (v as AsyncValue).get();
      return v2;
    });

    deepReplaceValues(variables, (c, k, v) {
      return v is String && DOMTemplate.possiblyATemplate(v);
    }, (c, k, v) {
      var template = DOMTemplate.parse(v as String);
      var v2 = template.build(variables,
          resolveDSX: false,
          intlMessageResolver: domContext?.intlMessageResolver);
      return v2;
    });
  }

  Future<dynamic>? getDataSourceResponse(Map<String, String> attributes) {
    var daraSourceCallAttr = attributes['data-source'];
    if (daraSourceCallAttr == null) return null;
    var dataSourceCall = DataSourceCall.from(daraSourceCallAttr);

    if (dataSourceCall != null) {
      try {
        var response = dataSourceCall.call();
        return response;
      } catch (e, s) {
        print(e);
        print(s);
      }
    }

    return null;
  }

  @override
  bool isGeneratedElement(UINode element) {
    return element is DivElement && element.classes.contains(tag);
  }

  @override
  DOMElement? revert(DOMGenerator domGenerator, DOMTreeMap? treeMap,
      DOMElement? domParent, UINode? parent, UINode? node) {
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
