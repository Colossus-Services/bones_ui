import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:swiss_knife/swiss_knife.dart';

typedef RenderPropertiesProvider = Map<String, dynamic> Function();
typedef RenderAsync = Future<dynamic> Function(Map<String, dynamic> properties);

/// A component that renders a content asynchronously.
///
/// Useful to render a content that is loading.
class UIComponentAsync extends UIComponent {
  static bool isValidComponentAsync(UIComponentAsync asyncContent,
      [Map<String, dynamic> properties]) {
    if (asyncContent == null || asyncContent._asyncContent == null) {
      return false;
    }
    return UIAsyncContent.isValid(asyncContent._asyncContent, properties);
  }

  static bool isValidLocaleComponentAsync(UIComponentAsync asyncContent,
      [Map<String, dynamic> properties]) {
    if (asyncContent == null || asyncContent._asyncContent == null) {
      return false;
    }
    return UIAsyncContent.isValidLocale(asyncContent._asyncContent);
  }

  RenderPropertiesProvider _renderPropertiesProvider;

  RenderAsync _renderAsync;

  final dynamic loadingContent;

  final dynamic errorContent;

  final Duration refreshInterval;

  /// Constructs a [UIComponentAsync].
  ///
  /// Note: if an attempt to render happens with the same properties of
  /// previously rendered content it will be ignored.
  ///
  /// [_renderPropertiesProvider] Provider of the properties of rendered content.
  /// [_renderAsync] Function that renders the component.
  /// [loadingContent] Content to show while loading.
  /// [errorContent] Content to show on error.
  /// [refreshInterval] Refresh interval [Duration].
  UIComponentAsync(Element parent, this._renderPropertiesProvider,
      this._renderAsync, this.loadingContent, this.errorContent,
      {this.refreshInterval,
      dynamic componentClass,
      dynamic componentStyle,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic style2,
      dynamic id,
      UIComponentGenerator generator,
      bool renderOnConstruction})
      : super(parent,
            componentClass: componentClass,
            componentStyle: componentStyle,
            classes: classes,
            classes2: classes2,
            style: style,
            style2: style2,
            id: id,
            generator: generator,
            renderOnConstruction: false) {
    _renderPropertiesProvider ??= renderPropertiesProvider;
    _renderAsync ??= renderAsync;

    if (renderOnConstruction != null && renderOnConstruction) {
      callRender();
    }
  }

  Map<String, dynamic> renderPropertiesProvider() => {};

  Future<dynamic> renderAsync(Map<String, dynamic> properties) => null;

  final EventStream<dynamic> onLoadAsyncContent = EventStream();

  UIAsyncContent _asyncContent;

  @override
  dynamic render() {
    var properties = renderProperties();

    if (!UIAsyncContent.isValid(_asyncContent, properties)) {
      _asyncContent = UIAsyncContent.provider(
          () => _renderAsync(renderProperties()),
          loadingContent,
          errorContent,
          refreshInterval,
          properties);
      _asyncContent.onLoadContent.listen((content) {
        onLoadAsyncContent.add(content);
        onChange.add(content);
      });
    }

    return _asyncContent;
  }

  bool isValid() {
    return UIAsyncContent.isValid(_asyncContent, renderProperties());
  }

  bool isNotValid() => !isValid();

  /// Stops
  void stop() {
    if (_asyncContent != null) _asyncContent.stop();
  }

  void refreshAsyncContent() {
    if (_asyncContent != null && !_asyncContent.stopped) {
      _asyncContent.refresh();
    }
  }

  void reset([bool refresh = true]) {
    if (_asyncContent != null) _asyncContent.reset(refresh);
  }

  bool get hasAutoRefresh => refreshInterval != null;

  bool get stopped => _asyncContent != null ? _asyncContent.stopped : false;

  bool get isLoaded => _asyncContent != null ? _asyncContent.isLoaded : false;

  bool get isOK => _asyncContent != null ? _asyncContent.isOK : false;

  bool get isWithError =>
      _asyncContent != null ? _asyncContent.isWithError : false;

  DateTime get loadTime =>
      _asyncContent != null ? _asyncContent.loadTime : null;

  int get loadCount => _asyncContent != null ? _asyncContent.loadCount : 0;

  Map<String, dynamic> get asyncContentProperties =>
      _asyncContent != null ? _asyncContent.properties : null;

  bool asyncContentEqualsProperties(Map<String, dynamic> properties) =>
      _asyncContent != null
          ? _asyncContent.equalsProperties(properties)
          : false;

  Map<String, dynamic> renderProperties() {
    var properties =
        _renderPropertiesProvider != null ? _renderPropertiesProvider() : null;
    properties ??= {};
    return properties;
  }
}
