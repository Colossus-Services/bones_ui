import 'dart:async';

import 'package:collection/collection.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_log.dart';
import 'bones_ui_root.dart';
import 'bones_ui_web.dart';

/// Handles navigation and routes.
class UINavigator {
  static UINavigator? _instance;

  static UINavigator get() {
    _instance ??= UINavigator._();
    return _instance!;
  }

  UINavigator._() {
    navigationOnChangeRoute(_onChangeRoute);

    var href = navigationURL();
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
  static bool get isOnline => navigationIsOnline();

  /// Returns [true] if this device is off-line.
  static bool get isOffline => !isOnline;

  /// Returns [true] if this device is in secure contexts (HTTPS).
  ///
  /// See: [https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts]
  static bool get isSecureContext {
    try {
      return navigationIsSecureContext();
    } catch (e, s) {
      logger.error('Error calling `window.isSecureContext`', e, s);
      return false;
    }
  }

  void _onChangeRoute(String? oldURL, String? newUrl) {
    if (newUrl == null) return;

    var uri = Uri.parse(newUrl);
    UIConsole.log('UINavigator._onChangeRoute: new: $uri > previous: $oldURL');

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
      bool Function(String? route) isLoggedRoute,
      [bool Function(String route)? isNotLoggedRoute]) {
    isNotLoggedRoute ??= (r) => !isLoggedRoute(r);

    var currentRoute = UINavigator.currentRoute;
    var emptyRoute = isEmptyString(currentRoute, trim: true);

    if (isLogged()) {
      if (emptyRoute || !isLoggedRoute(currentRoute)) {
        UINavigator.navigateToAsync(mainRouteLogged);
        return true;
      }
    } else {
      if (emptyRoute || !isNotLoggedRoute(currentRoute!)) {
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

    _navigateTo(++_navigateIDCount, currentRoute,
        parameters: _currentRouteParameters, force: force);
  }

  String? _currentRoute;

  Map<String, String>? _currentRouteParameters;

  /// Returns the current [Navigation].
  static Navigation? get currentNavigation {
    var route = currentRoute;
    if (route == null || route.isEmpty) return null;
    return Navigation(route, currentRouteParameters);
  }

  /// Returns the current route.
  static String? get currentRoute => get()._currentRoute;

  /// Returns the [currentRoute] or [defaultRoute].
  static String getCurrentRoute({String defaultRoute = ''}) {
    var route = currentRoute ?? '';
    return route.isNotEmpty ? route : defaultRoute;
  }

  /// Returns the current route parameters.
  static Map<String, String>? get currentRouteParameters =>
      copyMapString(get()._currentRouteParameters);

  /// Returns `true` if [route] equals to [currentRoute].
  ///
  /// - If [parameters] is provided it checks if [parameters] is equals to [currentRouteParameters].
  static bool equalsToCurrentRoute(String route,
          {Map<String, String>? parameters}) =>
      currentRoute == route &&
      (parameters == null || equalsToCurrentRouteParameters(parameters));

  /// Returns `true` if [parameters] are equals to [currentRouteParameters].
  static bool equalsToCurrentRouteParameters(Map<String, String>? parameters) =>
      MapEquality().equals(currentRouteParameters, parameters);

  /// Returns [true] if current location has a route entry.
  static bool get hasRoute => get()._hasRoute();

  bool _hasRoute() {
    return _currentRoute != null && _currentRoute!.isNotEmpty;
  }

  String? _lastNavigateRoute;

  Map<String, String>? _lastNavigateRouteParameters;

  List _parseRouteFragment(Uri uri) {
    if (urlFilter != null) {
      var url = uri.toString();
      var url2 = urlFilter!(url);
      if (isNotEmptyString(url2) && url2 != url) {
        UIConsole.log('Filtered URL: $url -> $url2');
        uri = Uri.parse(url2);
      }
    }

    var fragment = uri.fragment;

    var parts = fragment.split('?');

    var route = parts[0];
    var routeQueryString = parts.length > 1 ? parts[1] : null;

    var parameters = decodeQueryString(routeQueryString);

    return [route, parameters];
  }

  static String Function(String a)? urlFilter;

  void _navigateToFromURL(Uri url, [bool force = false]) {
    var routeFragment = _parseRouteFragment(url);

    var route = routeFragment[0] as String;
    var parameters = routeFragment[1] as Map<String, String>;

    if (route.toLowerCase() == 'uiconsole') {
      String? enableStr = parameters['enable'];
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

    _navigateTo(++_navigateIDCount, route,
        parameters: parameters, force: force, fromURL: true);
  }

  /// Navigate using [navigation] do determine route and parameters.
  static void navigate(Navigation navigation, [bool force = false]) {
    if (!navigation.isValid) return;
    get()._callNavigateTo(navigation.route,
        parameters: navigation.parameters, force: force);
  }

  /// Navigate asynchronously using [navigation] do determine route and parameters.
  static void navigateAsync(Navigation navigation, {bool force = false}) {
    if (!navigation.isValid) return;
    get()._callNavigateToAsync(
        navigation.route, navigation.parameters, null, force);
  }

  /// Navigate to a [route] with [parameters] or [parametersProvider].
  ///
  /// [force] If [true] changes the route even if the current route is the same.
  static void navigateTo(String? route,
      {Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false}) {
    get()._callNavigateTo(route,
        parameters: parameters,
        parametersProvider: parametersProvider,
        force: force);
  }

  /// Navigate asynchronously to a [route] with [parameters] or [parametersProvider].
  ///
  /// [force] If [true] changes the route even if the current route is the same.
  static void navigateToAsync(String? route,
      {Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false}) {
    get()._callNavigateToAsync(route, parameters, parametersProvider, force);
  }

  void _callNavigateTo(String? route,
      {Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false}) {
    if (_navigables.isEmpty || findNavigable(route!) == null) {
      Future.delayed(
          Duration(milliseconds: 50),
          () => _navigateTo(++_navigateIDCount, route,
              parameters: parameters,
              parametersProvider: parametersProvider,
              force: force));
    } else {
      _navigateTo(++_navigateIDCount, route,
          parameters: parameters,
          parametersProvider: parametersProvider,
          force: force);
    }
  }

  void _callNavigateToAsync(String? route,
      [Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false]) {
    Future.microtask(() => _navigateTo(++_navigateIDCount, route,
        parameters: parameters,
        parametersProvider: parametersProvider,
        force: force));
  }

  int _navigateCount = 0;

  final List<Navigation> _navigationHistory = [];

  /// Returns a history list of [Navigation].
  static List<Navigation> get navigationHistory =>
      get()._navigationHistory.toList();

  /// Returns the initial route when browser window was open.
  static String? get initialRoute => get()._initialRoute;

  String? get _initialRoute {
    var nav = _initialNavigation;
    return nav != null && nav.isValid ? nav.route : null;
  }

  /// Returns the initial [Navigation] when browser window was open.
  static Navigation? get initialNavigation => get()._initialNavigation;

  Navigation? get _initialNavigation {
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

  int _navigateIDCount = 0;
  int _lastNavigateID = 0;

  void _navigateTo(int navigateID, String? route,
      {Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false,
      bool fromURL = false,
      int cantFindNavigableRetry = 0}) {
    if (navigateID <= _lastNavigateID) return;

    if (route == '<') {
      var navigation =
          _navigationHistory.isNotEmpty ? _navigationHistory.last : null;

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
          () => _navigateTo(navigateID, route,
              parameters: parameters,
              force: force,
              cantFindNavigableRetry: cantFindNavigableRetry + 1));
      return;
    }

    if (routeNavigable != null) {
      String? deniedAccessRoute;

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

    _lastNavigateID = navigateID;

    UIConsole.log(
        'UINavigator.navigateTo[force: $force ; count: $_navigateCount] from: $_lastNavigateRoute $_lastNavigateRouteParameters > to: $route $parameters');

    _currentRoute = route;
    _currentRouteParameters = copyMapString(parameters);

    if (_lastNavigateRoute != null) {
      var navigation =
          Navigation(_lastNavigateRoute!, _lastNavigateRouteParameters);
      _navigationHistory.add(navigation);

      if (_navigationHistory.length > 12) {
        while (_navigationHistory.length > 10) {
          _navigationHistory.removeAt(0);
        }
      }
    }

    _lastNavigateRoute = route;
    _lastNavigateRouteParameters = copyMapString(parameters);

    var routeQueryString = Navigation.encodeParameters(parameters);

    var fragment = '#$route';

    if (routeQueryString.isNotEmpty) fragment += '?$routeQueryString';

    var locationUrl = navigationURL();
    var locationUrl2 = locationUrl.contains('#')
        ? locationUrl.replaceFirst(RegExp(r'#.*'), fragment)
        : '$locationUrl$fragment';

    var routeTitle = route;
    if (routeNavigable != null) {
      routeTitle = routeNavigable.currentTitle;
    }

    if (!fromURL) {
      navigationHistoryPush(routeTitle, locationUrl2);
    }

    clearDetachedNavigables();

    for (var container in _navigables) {
      if (container.canNavigateTo(route)) {
        container.navigateTo(route, parameters);
      }
    }

    UIConsole.log('Navigated to route: `$route` $parameters');

    _onNavigate.add(route);
  }

  /// Returns all the known routes of registered navigables.
  static List<String> get navigableRoutes {
    var routes = <String>{};
    for (var nav in navigables) {
      routes.addAll(nav.routes);
    }
    routes.remove('*');
    return routes.toList();
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
      get()._navigables.toList();

  /// Finds a [UINavigableComponent] that responds for [route].
  UINavigableComponent? findNavigable(String route) {
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

    clearDetachedNavigables(ignore: navigable);
  }

  static final String _navigableComponentSelector =
      '.${UINavigableComponent.componentClass}';

  /// Returns [List<UIElement>] that are from navigable components.
  ///
  /// [element] If null uses [document] to select sub elements.
  List<UIElement> selectNavigables([UIElement? element]) {
    return element != null
        ? element.querySelectorAll(_navigableComponentSelector)
        : documentQuerySelectorAll(_navigableComponentSelector);
  }

  /// Find in [element] tree nodes with attribute `navigate`.
  List<String> findElementNavigableRoutes(UIElement? element) {
    // ignore: omit_local_variable_types
    List<String> routes = [];

    _findElementNavigableRoutes([element!], routes);

    return routes;
  }

  void _findElementNavigableRoutes(
      List<UIElement> elements, List<String> routes) {
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
  void clearDetachedNavigables({UINavigableComponent? ignore}) {
    var list = selectNavigables();
    var navigables = _navigables.toList();

    var uiRoot = UIRoot.getInstance();

    for (var container in navigables) {
      if (identical(ignore, container)) continue;

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
  static StreamSubscription? navigateOnClick(UIElement element, String? route,
      [Map<String, String>? parameters,
      ParametersProvider? parametersProvider,
      bool force = false]) {
    var paramsStr = encodeQueryString(parameters);

    var attrRoute = element.getAttribute('__navigate__route');
    var attrParams = element.getAttribute('__navigate__parameters');

    if (route != attrRoute || paramsStr != attrParams) {
      element.setAttribute('__navigate__route', route!);
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

      if (element.style.cursor.isEmpty) {
        element.style.cursor = 'pointer';
      }

      return subscription;
    }

    return null;
  }

  static bool clearNavigateOnClick(UIElement element) {
    var attrRoute = element.getAttribute('__navigate__route');
    element.removeAttribute('__navigate__route');
    element.removeAttribute('__navigate__parameters');

    if (attrRoute != null) {
      if (element.style.cursor == 'pointer') {
        element.style.cursor = '';
      }
      return true;
    }

    return false;
  }

  /// Returns the current `navigate` property of [element].
  static String? getNavigateOnClick(UIElement element) {
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

/// Represents a navigation ([route] + [parameters]).
class Navigation {
  /// Encodes [parameters] in a Query String.
  static String encodeParameters(Map<String, String> parameters) {
    var urlEncoded = encodeQueryString(parameters);
    var routeEncoded = urlEncoded.replaceAll('%2C', ',');
    return routeEncoded;
  }

  /// Returns the [route] followed by `?` and the [parameters] encoded.
  /// - It's the same format used in an URL fragment route.
  /// - See [encodeParameters].
  static String encodeRouteAndParameters(
      String route, Map<String, String>? parameters) {
    route = route.trim();

    return parameters != null && parameters.isNotEmpty
        ? '$route?${encodeParameters(parameters)}'
        : route;
  }

  /// The route ID/name.
  final String route;

  /// The route parameters.
  final Map<String, String>? parameters;

  Navigation(this.route, [this.parameters]);

  /// Returns the [route] followed by `?` and the [parameters] encoded.
  /// See [encodeRouteAndParameters].
  String get routeAndParameters => encodeRouteAndParameters(route, parameters);

  bool get isValid => route.isNotEmpty;

  String? parameter(String key, [String? def]) =>
      parameters != null ? parameters![key] ?? def : def;

  int? parameterAsInt(String key, [int? def]) =>
      parameters != null ? parseInt(parameters![key], def) : def;

  num? parameterAsNum(String key, [num? def]) =>
      parameters != null ? parseNum(parameters![key], def) : def;

  bool? parameterAsBool(String key, [bool? def]) =>
      parameters != null ? parseBool(parameters![key], def) : def;

  List<String>? parameterAsStringList(String key, [List<String>? def]) =>
      parameters != null
          ? parseStringFromInlineList(parameters![key], RegExp(r'\s*,\s*'), def)
          : def;

  List<int>? parameterAsIntList(String key, [List<int>? def]) =>
      parameters != null
          ? parseIntsFromInlineList(parameters![key], RegExp(r'\s*,\s*'), def)
          : def;

  List<num>? parameterAsNumList(String key, [List<num>? def]) =>
      parameters != null
          ? parseNumsFromInlineList(parameters![key], RegExp(r'\s*,\s*'), def)
          : def;

  List<bool>? parameterAsBoolList(String key, [List<bool>? def]) =>
      parameters != null
          ? parseBoolsFromInlineList(parameters![key], RegExp(r'\s*,\s*'), def)
          : def;

  @override
  String toString() {
    return 'Navigation{route: $route, parameters: $parameters}';
  }
}

/// `Bones_UI` base class for navigable components using routes.
abstract class UINavigableComponent extends UIComponent {
  static final String componentClass = 'ui-navigable-component';

  List<String> _routes;

  bool? findRoutes;

  String? _currentRoute;

  Map<String, String>? _currentRouteParameters;

  UINavigableComponent(super.parent, Iterable<String> routes,
      {dynamic componentClass,
      dynamic componentStyle,
      super.classes,
      super.classes2,
      super.style,
      super.style2,
      super.id,
      super.inline,
      bool renderOnConstruction = false})
      : _routes = routes.toList(),
        super(componentClass: [
          UINavigableComponent.componentClass,
          componentClass
        ], renderOnConstruction: renderOnConstruction) {
    _normalizeRoutes();

    if (findRoutes!) updateRoutes();
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

  String currentTitle = '';

  void _normalizeRoutes() {
    // ignore: omit_local_variable_types
    List<String> routesOk = [];

    if (_routes.isEmpty) _routes = ['*'];

    var findRoutes = false;

    for (var r in _routes) {
      if (r.isEmpty) continue;

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

    this.findRoutes = findRoutes;

    // UIConsole.log('_normalizeRoutes: $_routes -> $routesOk');

    _routes = routesOk;
  }

  bool updateRoutes([List<String>? foundRoutes]) {
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

  void setRoutes(List<String>? routes) {
    _routes = List<String>.from(routes ?? <String>[]);
  }

  /// Returns a [route] name.
  String? getRouteName(String route) => null;

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
      _routes.where((r) => !isRouteHiddenFromMenu(r)).toList();

  /// The current route rendered by this component.
  String? get currentRoute => _currentRoute;

  /// The current route parameters used to rendered this component.
  Map<String, String>? get currentRouteParameters =>
      copyMapString(_currentRouteParameters);

  /// Returns [true] if this instance can navigate to [route].
  bool canNavigateTo(String route) {
    for (var r in routes) {
      if (route == r || route.startsWith('$r/')) {
        return true;
      }
    }

    if (findRoutes != null && findRoutes!) {
      return _findNewRoute(route);
    }

    return false;
  }

  bool _findNewRoute(String route) {
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

    if (findRoutes != null && findRoutes!) {
      updateRoutes();
    }

    notifyChangeRoute();

    return rendered;
  }

  /// Called to render the [route] with [parameters].
  dynamic renderRoute(String? route, Map<String, String>? parameters);

  /// Should return [true] if [route] [isAccessible].
  bool isAccessibleRoute(String route) => true;

  /// Should return the route to redirect if [route] is not accessible.
  ///
  /// Same behavior of [deniedAccessRoute].
  String? deniedAccessRouteOfRoute(String route) => null;

  /// Changes the current selected [route], with [parameters],
  /// of this [UINavigableComponent].
  bool navigateTo(String route, [Map<String, String>? parameters]) {
    if (!canNavigateTo(route)) return false;

    parameters ??= {};

    if (_currentRoute == route &&
        isEquivalentMap(_currentRouteParameters, parameters)) {
      return true;
    }

    _currentRoute = route;
    _currentRouteParameters = copyMapString(parameters);

    componentInternals.refreshInternal();
    return true;
  }

  final EventStream<String> onChangeRoute = EventStream();

  String? _notifiedChangeRoute;

  Map<String, String>? _notifiedChangeRouteParameters;

  void notifyChangeRoute() {
    var route = currentRoute;
    var parameters = currentRouteParameters;

    if (_notifiedChangeRoute == route &&
        isEquivalentMap(_notifiedChangeRouteParameters, parameters)) {
      return;
    }

    _notifiedChangeRoute = route;
    _notifiedChangeRouteParameters = parameters;

    onChangeRoute.add(route!);
  }
}

/// A `Bones_UI` component for navigable contents by routes.
abstract class UINavigableContent extends UINavigableComponent {
  /// Optional top margin (in px) for the content.
  int topMargin;

  UINavigableContent(super.parent, List<String> super.routes,
      {this.topMargin = 0,
      super.classes,
      super.classes2,
      super.style,
      super.style2,
      super.inline,
      super.renderOnConstruction});

  @override
  dynamic render() {
    // ignore: omit_local_variable_types
    List allRendered = [];

    if (topMargin > 0) {
      var divTopMargin = UIElement.div();
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

    if (findRoutes != null && findRoutes!) {
      updateRoutes();
    }

    return allRendered;
  }

  /// Called to render the head of the content.
  dynamic renderRouteHead(String? route, Map<String, String>? parameters) {
    return null;
  }

  /// Called to render the footer of the content.
  dynamic renderRouteFoot(String? route, Map<String, String>? parameters) {
    return null;
  }
}
