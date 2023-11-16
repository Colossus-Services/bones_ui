import 'dart:async';
import 'dart:html';

import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_log.dart';
import 'bones_ui_utils.dart';

typedef AsyncContentProvider = Future<dynamic>? Function();

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

/// An asynchronous content.
class UIAsyncContent {
  AsyncContentProvider? _asyncContentProvider;

  Future<dynamic>? _asyncContentFuture;

  final dynamic _loadingContent;

  final dynamic _errorContent;

  final Duration? _refreshInterval;

  _Content? _loadedContent;

  final String? _locale;

  String? get locale => _locale;

  final Map<String, dynamic> _properties;

  static bool isNotValid(UIAsyncContent asyncContent,
      [Map<String, dynamic>? properties]) {
    return !isValid(asyncContent, properties);
  }

  static bool isValid(UIAsyncContent? asyncContent,
      [Map<String, dynamic>? properties]) {
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

  static bool isValidLocale(UIAsyncContent? asyncContent) {
    if (asyncContent == null) return false;

    if (asyncContent.equalsCurrentLocale()) {
      return true;
    } else {
      asyncContent.stop();
      return false;
    }
  }

  final StackTrace _constructionStackTrace;

  /// Constructs an [UIAsyncContent] using [_asyncContentProvider] ([Function]), that returns the content.
  ///
  /// [loadingContent] Content to show while loading.
  /// [errorContent] Content to show on error.
  /// [_refreshInterval] Interval to refresh the content.
  /// [properties] Properties of this content.
  UIAsyncContent.provider(this._asyncContentProvider, dynamic loadingContent,
      {dynamic errorContent,
      Duration? refreshInterval,
      Map<String, dynamic>? properties})
      : _locale = IntlLocale.getDefaultLocale(),
        _refreshInterval = refreshInterval,
        _properties = properties ?? {},
        _loadingContent = _normalizeContent(loadingContent),
        _errorContent = _normalizeContent(errorContent),
        _constructionStackTrace = stackTraceSafe() {
    _callContentProvider(false);
  }

  /// Constructs an [UIAsyncContent] using [contentFuture] ([Future<dynamic>]), that returns the content.
  ///
  /// [loadingContent] Content to show while loading.
  /// [errorContent] Content to show on error.
  /// [_refreshInterval] Interval to refresh the content.
  /// [properties] Properties of this content.
  UIAsyncContent.future(Future<dynamic> contentFuture, dynamic loadingContent,
      {dynamic errorContent,
      Duration? refreshInterval,
      Map<String, dynamic>? properties})
      : _locale = IntlLocale.getDefaultLocale(),
        _refreshInterval = refreshInterval,
        _properties = properties ?? {},
        _loadingContent = _normalizeContent(loadingContent),
        _errorContent = _normalizeContent(errorContent),
        _constructionStackTrace = stackTraceSafe() {
    _setAsyncContentFuture(contentFuture);
  }

  UIComponent? parentUIComponent;

  bool equalsCurrentLocale() => _locale == IntlLocale.getDefaultLocale();

  bool equalsLocale(String locale) => _locale == locale;

  bool equalsProperties(Map<String, dynamic>? properties) {
    properties ??= {};
    return isEqualsDeep(_properties, properties);
  }

  final EventStream<dynamic> onLoadContent = EventStream();

  Map<String, dynamic> get properties => Map<String, dynamic>.from(_properties);

  dynamic get loadingContent => _loadingContent;

  dynamic get errorContent {
    if (_errorContent is Function) {
      final errorContent = _errorContent;
      Object? content;
      if (errorContent is Function(dynamic e)) {
        content = errorContent(error);
      } else if (errorContent is Function()) {
        content = errorContent();
      } else {
        content = null;
      }
      return _normalizeContent(content);
    } else {
      return _errorContent;
    }
  }

  static dynamic _normalizeContent(dynamic content) {
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

  Duration? get refreshInterval => _refreshInterval;

  int _maxIgnoredRefreshCount = 10;

  int get maxIgnoredRefreshCount => _maxIgnoredRefreshCount;

  set maxIgnoredRefreshCount(int value) {
    if (value < 1) value = 1;
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

    var contentFuture = _asyncContentProvider!();
    _setAsyncContentFuture(contentFuture);
  }

  void _ignoreRefresh([bool? inDOM]) {
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

  void _setAsyncContentFuture(Future<dynamic>? contentFuture) {
    _asyncContentFuture = contentFuture;

    if (_asyncContentFuture != null) {
      var parentStackTrace = stackTraceSafe();
      _asyncContentFuture!
          .then(_onLoadedContent)
          .catchError((e, r) => _onLoadError(e, r, parentStackTrace));
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

  DateTime? _loadTime;

  /// Returns the [DateTime] of last load.
  DateTime? get loadTime => _loadTime;

  /// Returns in milliseconds the amount of elapsed time since last load.
  int get elapsedLoadTime => _loadTime != null
      ? DateTime.now().millisecondsSinceEpoch -
          _loadTime!.millisecondsSinceEpoch
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

  void _onLoadError(
      dynamic error, StackTrace stackTrace, StackTrace parentStackTrace) {
    logger.error(
        'Error loading async content! parentUIComponent: $parentUIComponent ; _asyncContentFuture: <<<$_asyncContentFuture>>> ; this: <<<$this>>>',
        error,
        stackTrace);

    logger.error('Parent StackTrace:', error, parentStackTrace);

    logger.error('Construction StackTrace:', error, _constructionStackTrace);

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
  bool get isOK => _loadedContent != null && _loadedContent!.status == 200;

  /// Returns [true] if the content is loaded and with error.
  bool get isWithError =>
      _loadedContent != null && _loadedContent!.status == 500;

  /// The error instance when loaded with error.
  dynamic get error => isWithError ? _loadedContent!.content : null;

  /// Returns the already loaded content.
  dynamic get content {
    if (_loadedContent == null) {
      return loadingContent;
    } else if (_loadedContent!.status == 200) {
      return _loadedContent!.contentForDOM;
    } else {
      return errorContent ?? loadingContent;
    }
  }

  /// Resets the component.
  ///
  /// [refresh] If [true] (default), will call [refresh] after reset.
  void reset([bool refresh = true]) {
    logger.log('Resetting async content for instance: $this');

    _loadedContent = null;
    _ignoredRefreshCount = 0;
    onLoadContent.add(null);

    if (refresh) {
      Future.microtask(() => _refreshImpl(false));
    }
  }

  @override
  String toString() {
    return 'UIAsyncContent{isLoaded: $isLoaded, loadingContent: <<$loadingContent>>, loadedContent: <<$_loadedContent>>}';
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
