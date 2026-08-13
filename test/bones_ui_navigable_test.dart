@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

void main() {
  group('UINavigableComponent', () {
    late final _NavigableRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _NavigableRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('exposes its routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact', 'admin']);

      expect(nav.routes, equals(['home', 'contact', 'admin']));
      expect(nav.currentRoute, equals('home'), reason: 'The first route');
    });

    test('canNavigateTo only its own routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact']);

      expect(nav.canNavigateTo('home'), isTrue);
      expect(nav.canNavigateTo('contact'), isTrue);
      expect(nav.canNavigateTo('nope'), isFalse);
    });

    test('canNavigateTo sub-routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['docs']);

      expect(nav.canNavigateTo('docs/page-1'), isTrue);
      expect(nav.canNavigateTo('docs2'), isFalse);
    });

    test('navigateTo changes the current route and renders it', () async {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact']);
      await nav.callRenderAndWait();

      expect(nav.content!.text, contains('route: home'));

      var navigated = nav.navigateTo('contact', {'id': '10'});
      expect(navigated, isTrue);

      await testUISleep(ms: 100);

      expect(nav.currentRoute, equals('contact'));
      expect(nav.currentRouteParameters, equals({'id': '10'}));
      expect(nav.content!.text, contains('route: contact'));
      expect(nav.content!.text, contains('id=10'));
    });

    test('navigateTo an unknown route is ignored', () async {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact']);
      await nav.callRenderAndWait();

      expect(nav.navigateTo('nope'), isFalse);
      expect(nav.currentRoute, equals('home'));
    });

    test('onChangeRoute is notified once per route change', () async {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact']);

      var notified = <String>[];
      nav.onChangeRoute.listen(notified.add);

      await nav.callRenderAndWait();
      await testUISleep(ms: 100);

      nav.navigateTo('contact');
      await testUISleep(ms: 150);

      expect(notified, contains('contact'));

      var countBefore = notified.length;

      // Navigating to the same route should not notify again:
      nav.navigateTo('contact');
      await testUISleep(ms: 150);

      expect(notified.length, equals(countBefore));
    });

    test('routesAndNames and menuRoutes hide the marked routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['home', 'contact', 'admin']);

      expect(
        nav.routesAndNames,
        equals({'home': 'Home', 'contact': 'Contact', 'admin': 'admin'}),
      );

      expect(nav.isRouteHiddenFromMenu('admin'), isTrue);
      expect(nav.menuRoutes, equals(['home', 'contact']));
      expect(
        nav.menuRoutesAndNames,
        equals({'home': 'Home', 'contact': 'Contact'}),
      );
    });

    test('setRoutes replaces the routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['home']);

      nav.setRoutes(['a', 'b']);

      expect(nav.routes, equals(['a', 'b']));
      expect(nav.canNavigateTo('home'), isFalse);
      expect(nav.canNavigateTo('a'), isTrue);

      nav.setRoutes(null);
      expect(nav.routes, isEmpty);
    });

    test('updateRoutes adds new routes', () {
      var nav = _RoutesComponent(uiRoot.content, ['home']);

      expect(nav.updateRoutes(['home']), isFalse, reason: 'Already present');
      expect(nav.updateRoutes(['extra']), isTrue);
      expect(nav.routes, equals(['home', 'extra']));
    });

    test('an empty routes list becomes a `*` wildcard', () {
      var nav = _WildcardComponent(uiRoot.content);

      expect(nav.findRoutes, isTrue);

      // `*` accepts any route that `renderRoute` can handle:
      expect(nav.canNavigateTo('known-a'), isTrue);
      expect(nav.canNavigateTo('known-b'), isTrue);
      expect(nav.canNavigateTo('unknown'), isFalse);

      // The accepted routes are memorized:
      expect(nav.routes, containsAll(['known-a', 'known-b']));
    });

    test('is registered in UINavigator', () {
      var nav = _RoutesComponent(uiRoot.content, ['unique-route']);

      expect(UINavigator.navigables, contains(nav));
      expect(UINavigator.navigableRoutes, contains('unique-route'));
      expect(UINavigator.get().findNavigable('unique-route'), same(nav));
      expect(UINavigator.get().findNavigable('no-such-route'), isNull);
    });

    test('an inaccessible route redirects', () async {
      var nav = _RestrictedComponent(uiRoot.content);
      await nav.callRenderAndWait();

      expect(nav.isAccessibleRoute('public'), isTrue);
      expect(nav.isAccessibleRoute('private'), isFalse);
      expect(nav.deniedAccessRouteOfRoute('private'), equals('public'));
    });
  });

  group('UINavigableContent', () {
    late final _NavigableRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _NavigableRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('renders head, content and foot of the route', () async {
      var content = _ContentComponent(uiRoot.content);
      await content.callRenderAndWait();
      await testUISleep(ms: 100);

      var text = content.content!.text!;

      expect(text, contains('HEAD:home'));
      expect(text, contains('BODY:home'));
      expect(text, contains('FOOT:home'));

      expect(
        text.indexOf('HEAD:home'),
        lessThan(text.indexOf('BODY:home')),
        reason: 'The head should be rendered before the body',
      );
      expect(
        text.indexOf('BODY:home'),
        lessThan(text.indexOf('FOOT:home')),
        reason: 'The body should be rendered before the foot',
      );
    });

    test('a `topMargin` adds a spacer div', () async {
      var content = _ContentComponent(uiRoot.content, topMargin: 30);
      await content.callRenderAndWait();
      await testUISleep(ms: 100);

      var firstChild = content.content!.children.toIterable().first;
      expect(firstChild.style?.height, equals('30px'));
    });
  });
}

class _NavigableRoot extends UIRoot {
  _NavigableRoot(super.rootContainer) : super(id: 'navigable-root');

  @override
  UIComponent? renderContent() => null;
}

class _RoutesComponent extends UINavigableComponent {
  _RoutesComponent(super.parent, List<String> super.routes);

  @override
  String? getRouteName(String route) => switch (route) {
    'home' => 'Home',
    'contact' => 'Contact',
    _ => null,
  };

  @override
  bool isRouteHiddenFromMenu(String route) => route == 'admin';

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    var params = (parameters ?? {}).entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '<div>route: $route [$params]</div>';
  }
}

/// Declares no routes, so it becomes a `*` (wildcard) navigable.
class _WildcardComponent extends UINavigableComponent {
  _WildcardComponent(Object? parent) : super(parent, []);

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    if (route == 'known-a' || route == 'known-b') {
      return '<div>$route</div>';
    }
    return null;
  }
}

class _RestrictedComponent extends UINavigableComponent {
  _RestrictedComponent(Object? parent) : super(parent, ['public', 'private']);

  @override
  bool isAccessibleRoute(String route) => route != 'private';

  @override
  String? deniedAccessRouteOfRoute(String route) =>
      route == 'private' ? 'public' : null;

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      '<div>$route</div>';
}

class _ContentComponent extends UINavigableContent {
  _ContentComponent(Object? parent, {super.topMargin})
    : super(parent, ['home', 'about']);

  @override
  dynamic renderRouteHead(String? route, Map<String, String>? parameters) =>
      '<div>HEAD:$route</div>';

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      '<div>BODY:$route</div>';

  @override
  dynamic renderRouteFoot(String? route, Map<String, String>? parameters) =>
      '<div>FOOT:$route</div>';
}
