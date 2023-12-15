import 'dart:async';

import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_async_content.dart';
import '../bones_ui_component.dart';

typedef RenderPropertiesProvider = Map<String, dynamic> Function();
typedef RenderAsync = Future<dynamic>? Function(
    Map<String, dynamic> properties);

/// A component that renders a content asynchronously.
///
/// Useful to render a content that is loading.
class UIComponentAsync extends UIComponent {
  static bool isValidComponentAsync(UIComponentAsync? asyncContent,
      [Map<String, dynamic>? properties]) {
    if (asyncContent == null || asyncContent._asyncContent == null) {
      return false;
    }
    return UIAsyncContent.isValid(asyncContent._asyncContent, properties);
  }

  static bool isValidLocaleComponentAsync(UIComponentAsync? asyncContent,
      [Map<String, dynamic>? properties]) {
    if (asyncContent == null || asyncContent._asyncContent == null) {
      return false;
    }
    return UIAsyncContent.isValidLocale(asyncContent._asyncContent);
  }

  RenderPropertiesProvider? _renderPropertiesProvider;

  RenderAsync? _renderAsync;

  final dynamic loadingContent;

  final dynamic errorContent;

  final Duration? refreshInterval;

  final bool cacheRenderAsync;

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
  UIComponentAsync(super.parent, this._renderPropertiesProvider,
      this._renderAsync, this.loadingContent, this.errorContent,
      {this.refreshInterval,
      this.cacheRenderAsync = true,
      super.componentClass,
      super.componentStyle,
      super.classes,
      super.classes2,
      super.style,
      super.style2,
      super.id,
      super.generator,
      bool renderOnConstruction = false})
      : super(renderOnConstruction: false) {
    _renderPropertiesProvider ??= renderPropertiesProvider;
    _renderAsync ??= renderAsync;

    if (renderOnConstruction) {
      callRender();
    }
  }

  Map<String, dynamic> renderPropertiesProvider() => {};

  Future<dynamic>? renderAsync(Map<String, dynamic> properties) => null;

  final EventStream<dynamic> onLoadAsyncContent = EventStream();

  UIAsyncContent? _asyncContent;
  int _asyncContentRenderCount = 0;

  @override
  dynamic render() {
    _asyncContentRenderCount++;

    var properties = renderProperties();

    if ((!cacheRenderAsync && _asyncContentRenderCount > 1) ||
        !UIAsyncContent.isValid(_asyncContent, properties)) {
      _asyncContent = UIAsyncContent.provider(
          () => _renderAsync!(renderProperties()), loadingContent,
          errorContent: errorContent,
          refreshInterval: refreshInterval,
          properties: properties);
      _asyncContent!.onLoadContent.listen((content) {
        onLoadAsyncContent.add(content);
        onChange.add(content);
      });
      _asyncContentRenderCount = 0;
    }

    return _asyncContent;
  }

  bool isValid() {
    return UIAsyncContent.isValid(_asyncContent, renderProperties());
  }

  bool isNotValid() => !isValid();

  /// Stops
  void stop() {
    if (_asyncContent != null) _asyncContent!.stop();
  }

  void refreshAsyncContent() {
    if (_asyncContent != null && !_asyncContent!.stopped) {
      _asyncContent!.refresh();
    }
  }

  void reset([bool refresh = true]) {
    if (_asyncContent != null) _asyncContent!.reset(refresh);
  }

  bool get hasAutoRefresh => refreshInterval != null;

  bool get stopped => _asyncContent != null ? _asyncContent!.stopped : false;

  bool get isLoaded => _asyncContent != null ? _asyncContent!.isLoaded : false;

  bool get isOK => _asyncContent != null ? _asyncContent!.isOK : false;

  bool get isWithError =>
      _asyncContent != null ? _asyncContent!.isWithError : false;

  DateTime? get loadTime => _asyncContent?.loadTime;

  int get loadCount => _asyncContent != null ? _asyncContent!.loadCount : 0;

  Map<String, dynamic>? get asyncContentProperties => _asyncContent?.properties;

  bool asyncContentEqualsProperties(Map<String, dynamic> properties) =>
      _asyncContent != null
          ? _asyncContent!.equalsProperties(properties)
          : false;

  Map<String, dynamic> renderProperties() {
    var properties =
        _renderPropertiesProvider != null ? _renderPropertiesProvider!() : null;
    properties ??= {};
    return properties;
  }
}
