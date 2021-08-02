import 'dart:async';
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'component_async.dart';

enum ControllerPropertiesType {
  controllerValue,
  routeParameters,
  implementation
}

abstract class UIControlledComponent extends UIComponent {
  final dynamic loadingContent;

  final dynamic errorContent;

  final dynamic resultLoadingContent;

  final dynamic resultErrorContent;

  final ControllerPropertiesType controllersPropertiesType;

  UIControlledComponent(Element? parent, this.loadingContent, this.errorContent,
      {this.resultLoadingContent,
      this.resultErrorContent,
      ControllerPropertiesType? controllersPropertiesType,
      dynamic classes,
      dynamic classes2})
      : controllersPropertiesType = controllersPropertiesType ??
            ControllerPropertiesType.controllerValue,
        super(parent,
            classes: classes, classes2: classes2, renderOnConstruction: false);

  UIComponentAsync? _componentAsync;

  @override
  dynamic render() {
    if (!UIComponentAsync.isValidLocaleComponentAsync(
        _componentAsync, getControllersProperties())) {
      reset();
      _componentAsync = UIComponentAsync(
          content,
          getControllersProperties,
          (props) => renderAsync(props as MapProperties),
          loadingContent,
          errorContent,
          id: '$id/_componentAsync');
    }
    return _componentAsync;
  }

  void refreshComponentAsync() {
    if (_componentAsync != null) {
      _componentAsync!.refreshAsyncContent();
    }
  }

  MapProperties getControllersProperties() {
    switch (controllersPropertiesType) {
      case ControllerPropertiesType.controllerValue:
        return getControllersPropertiesByControllersValues();
      case ControllerPropertiesType.routeParameters:
        return getControllersPropertiesByRouteParameters();
      default:
        return getControllersPropertiesByControllersValues();
    }
  }

  MapProperties getControllersPropertiesByControllersValues() {
    var mapProperties = MapProperties();
    if (_controllers == null || _controllers!.isEmpty) return mapProperties;

    for (var entry in _controllers!.entries) {
      var key = entry.key;
      var value = entry.value;

      if (value is UIField) {
        value = value.getFieldValue();
      } else if (value is UIComponent) {
        dynamic fields = value.getFields();
        value = asMapOfString(fields);
      } else if (value is Element) {
        value = parseChildElementValue(value);
      }

      mapProperties.put(key, value);
    }

    return mapProperties;
  }

  MapProperties getControllersPropertiesByRouteParameters() {
    return MapProperties.fromStringProperties(
        UINavigator.currentNavigation!.parameters!);
  }

  Map<String, dynamic>? _controllers;

  Map<String, dynamic>? get controllers =>
      _controllers != null ? Map.from(_controllers!).cast() : null;

  dynamic getController(String key) {
    return _controllers != null ? _controllers![key] : null;
  }

  void reset() {
    _componentAsync = null;
    _componentAsyncResult = null;
    _controllers = null;
  }

  UIComponentAsync? _componentAsyncResult;

  Future<dynamic> renderAsync(MapProperties properties) async {
    if (_controllers == null) {
      var controllers = await renderControllers(properties);
      _controllers = _resolveControllers(controllers);
      await listenControllers(_controllers!);
    }

    await setupControllers(properties, _controllers);

    var validSetup = isValidControllersSetup(properties, _controllers);

    if (!validSetup) {
      return renderOnlyControllers(properties, _controllers);
    }

    var resultLoadingContent =
        this.resultLoadingContent ?? UIComponent.copyRenderable(loadingContent);
    var resultErrorContent =
        this.resultErrorContent ?? UIComponent.copyRenderable(errorContent);

    if (!UIComponentAsync.isValidComponentAsync(
        _componentAsyncResult, properties)) {
      _componentAsyncResult = UIComponentAsync(
          content,
          getControllersProperties,
          (props) => renderResult(props as MapProperties),
          resultLoadingContent,
          resultErrorContent,
          id: '$id/_componentAsyncResult');
    }

    return renderControllersAndResult(
        properties, _controllers, _componentAsyncResult);
  }

  Future<Map<String, dynamic>> renderControllers(MapProperties properties);

  Future<bool> setupControllers(
      MapProperties properties, Map<String, dynamic>? controllers);

  Future<bool> setupControllersOnChange(
      MapProperties properties, Map<String, dynamic>? controllers) async {
    return false;
  }

  Future<bool> listenControllers(Map<String, dynamic> controllers) async {
    for (var control in controllers.values) {
      if (control is Element) {
        control.onChange.listen((e) => callOnChangeControllers(control));
      } else if (control is UIComponent) {
        control.onChange.listen((e) => callOnChangeControllers(control));
      } else if (control is UIAsyncContent) {
        control.onLoadContent.listen((e) => callOnChangeControllers(control));
      }
    }

    return true;
  }

  void callOnChangeControllers(dynamic control) {
    var propertiesNow = getControllersProperties();

    try {
      var valid = isValidControllersSetup(propertiesNow, _controllers);
      onChangeController(_controllers, valid, control);
    } catch (e, s) {
      print(e);
      print(s);
    }

    onChange.add(this);
  }

  void onChangeController(Map<String, dynamic>? controllers,
      bool validControllersSetup, dynamic changedController) {
    if (validControllersSetup) {
      switch (controllersPropertiesType) {
        case ControllerPropertiesType.controllerValue:
          {
            _refreshContentOnPropertiesChange();
            break;
          }
        case ControllerPropertiesType.routeParameters:
          {
            var route = UINavigator.currentRoute;
            var parameters = getControllersProperties().toStringProperties();
            UINavigator.navigateTo(route, parameters: parameters);
            break;
          }
        default:
          {
            _refreshContentOnPropertiesChange();
            break;
          }
      }
    } else {
      var propertiesNow = getControllersProperties();
      setupControllersOnChange(propertiesNow, controllers);
    }
  }

  void _refreshContentOnPropertiesChange() {
    var controllersProperties = getControllersProperties().toStringProperties();

    if (!_componentAsync!.asyncContentEqualsProperties(controllersProperties)) {
      refreshComponentAsync();
    }
  }

  bool isValidControllersSetup(
      MapProperties properties, Map<String, dynamic>? controllers);

  Future<dynamic> renderOnlyControllers(
      MapProperties properties, Map<String, dynamic>? controllers) async {
    return _renderControllers(controllers);
  }

  List? _renderControllers(Map<String, dynamic>? controllers) {
    if (controllers == null) return null;

    var list = [];

    for (var entry in controllers.entries) {
      if (entry.key.endsWith('_label')) continue;

      if (list.isNotEmpty) {
        var separatorH = createSpan('&nbsp<wbr>');
        var separatorV = DivElement()
              ..classes.add('w-100')
              ..classes.add('d-md-none')
            //..classes.add('d-lg-block')
            ;
        list.add(separatorH);
        list.add(separatorV);
      }

      var label = controllers['${entry.key}_label'];
      var controller = entry.value;

      if (label is String) {
        var span = createLabel('$label: &nbsp ');
        list.add(span);
      } else {
        list.add(label);
      }

      list.add(controller);
    }

    return list;
  }

  Map<String, dynamic> _resolveControllers(Map<String, dynamic> controllers) {
    var resolvedControllers = controllers.map((key, value) {
      var elements = _componentAsync!.toContentElements(value);
      var element = elements.isEmpty
          ? null
          : (elements.length == 1 ? elements.single : elements);
      return MapEntry(key, element);
    });

    return resolvedControllers;
  }

  Future<dynamic> renderResult(MapProperties properties);

  Future<dynamic> renderControllersAndResult(MapProperties properties,
      Map<String, dynamic>? controllers, dynamic result) async {
    return [_renderControllers(controllers), '<p>', result];
  }
}
