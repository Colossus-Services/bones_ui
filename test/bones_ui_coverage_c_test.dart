@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:swiss_knife/swiss_knife.dart' show ResourceContent;
import 'package:test/test.dart';

/// Matches the same JS object as [expected] (JS `===`). With `dart2wasm`,
/// the same JS object can be wrapped by distinct Dart objects.
Matcher _sameJS(JSAny expected) => predicate<Object?>(
  (actual) => (actual as JSAny?).strictEquals(expected).toDart,
  'the same JS object as $expected',
);

/// Integration tests (real DOM) for less exercised paths of
/// `bones_ui_component.dart`, `bones_ui_navigator.dart`,
/// `bones_ui_explorer.dart`, `input_config.dart`, `bones_ui_root.dart` and
/// `bones_ui_base.dart`: render error handling, rendered elements lookup,
/// rendering stacks, data sources, route discovery and explorer documents.
void main() {
  late final _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  /// A container attached to the root, removed after the test.
  HTMLDivElement newHolder() {
    var holder = HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    return holder;
  }

  /// Enables the [UIConsole] logs (restored after the test).
  void captureConsole() {
    var wasEnabled = UIConsole.get()!.enabled;
    UIConsole.clear();
    UIConsole.enable();
    addTearDown(() {
      if (!wasEnabled) UIConsole.disable();
      UIConsole.clear();
    });
  }

  String consoleLogs() => UIConsole.logs().join('\n');

  group('UIComponent render errors', () {
    for (var step in ['preRender', 'render', 'posRender', 'isAccessible']) {
      test('an error in `$step` is logged, not thrown', () async {
        captureConsole();

        var c = _FailingComponent(newHolder(), step);
        await c.callRenderAndWait();

        // An `isAccessible` error aborts the render before marking it as
        // rendered:
        expect(c.isRendered, step != 'isAccessible');
        expect(consoleLogs(), contains('$step error'));
        expect(consoleLogs(), contains('fail at $step'));

        if (step == 'preRender' || step == 'posRender') {
          expect(c.content!.text, equals('rendered'));
        } else {
          expect(c.content!.text, isEmpty);
        }
      });
    }

    test('an error in `posAsyncRender` is logged', () async {
      captureConsole();

      var c = _FailingComponent(newHolder(), 'posAsyncRender');
      await c.callRenderAndWait();
      await testUISleepUntil(() => consoleLogs().contains('posAsyncRender'));

      expect(c.content!.text, equals('async rendered'));
      expect(consoleLogs(), contains('posAsyncRender error'));
    });

    test('a rendered function that throws is logged', () async {
      captureConsole();

      var c = _FuncComponent(newHolder(), () => throw StateError('func fail'));
      await c.callRenderAndWait();

      expect(c.content!.text, equals('before'));
      expect(consoleLogs(), contains('Error calling function'));
      expect(consoleLogs(), contains('func fail'));
    });

    test('a rendered function returns renderable content', () async {
      var c = _FuncComponent(newHolder(), () => '<b>from function</b>');
      await c.callRenderAndWait();

      expect(c.content!.querySelector('b')!.textContent, 'from function');
    });

    test(
      'an `InputConfig` is not renderable outside of `UIInputTable`',
      () async {
        captureConsole();

        var c = _FuncComponent(newHolder(), InputConfig('f', 'F'));
        await c.callRenderAndWait();

        expect(consoleLogs(), contains("Can't render element of type"));
        expect(consoleLogs(), contains('InputConfig'));
        expect(c.content!.querySelector('input'), isNull);
      },
    );

    test('an error in `onChildRendered` is caught', () async {
      var parent = _ParentFailingOnChild(newHolder());
      await parent.callRenderAndWait();

      var child = parent.child;
      await child.callRenderAndWait();

      expect(parent.childRenderedCalls, greaterThanOrEqualTo(1));
      expect(child.content!.text, equals('child'));
      expect(parent.content!.text, contains('child'));
    });

    test('not accessible with a denied route not in DOM', () async {
      captureConsole();

      var c = _NotAccessible(null);
      c.callRender();

      expect(c.isRendered, isTrue);
      expect(c.content!.text, isEmpty);
      expect(consoleLogs(), contains('Not accessible'));
      expect(consoleLogs(), contains('[NOT IN DOM] Denied access to route'));
    });

    test('default `deniedAccessRoute` and `isAccessible`', () {
      var c = _HTMLComponent(null, 'x');
      expect(c.isAccessible(), isTrue);
      expect(c.deniedAccessRoute(), isNull);
    });
  });

  group('UIComponent rendered elements', () {
    test('findUIComponentByContent / ByID / ByChild', () async {
      var c = _TreeComponent(newHolder());
      await c.callRenderAndWait();
      await c.child.callRenderAndWait();

      var plain = c.content!.querySelector('#plain-div')!;

      expect(c.findUIComponentByContent(c.content), same(c));
      expect(c.findUIComponentByContent(plain), same(c));
      expect(c.findUIComponentByContent(HTMLDivElement()), isNull);
      expect(c.findUIComponentByContent(null), isNull);

      expect(c.findUIComponentByChild(plain), same(c));
      expect(c.findUIComponentByChild(c.child.content), same(c));

      expect(c.findUIComponentByID('#tree-comp'), same(c));
      expect(c.findUIComponentByID('tree-child'), same(c.child));
      expect(c.findUIComponentByID('#'), isNull);
      expect(c.findUIComponentByID('nope'), isNull);
    });

    test('getRenderedElement / getAllRenderedElements deeply', () async {
      var c = _TreeComponent(newHolder());
      await c.callRenderAndWait();
      await c.child.callRenderAndWait();

      bool isDeep(Object? e) => e.isElement && (e as Element).id == 'deep';

      expect(c.getRenderedElement(isDeep), isNull, reason: 'Not deep');

      var deep = c.getRenderedElement(isDeep, true) as Element;
      expect(deep.textContent, equals('deep'));

      expect(c.getRenderedElementById('deep'), isNull);
      expect(
        (c.getRenderedElementById('deep', true) as Element).textContent,
        equals('deep'),
      );

      var all = c.getAllRenderedElements(isDeep, true)!;
      expect(all.length, equals(1));
      expect((all.single as Element).textContent, equals('deep'));

      expect(c.getAllRenderedElements(isDeep), isEmpty);

      var allDivs = c.getAllRenderedElements(
        (e) => e.isElement && (e as Element).tagName.toLowerCase() == 'div',
      )!;
      expect(allDivs.length, equals(1), reason: '#plain-div');
    });

    test(
      'getRenderedElement in sub components not rendered directly',
      () async {
        // In the `uiRoot` content (resolving its `uiRootComponent`):
        var c = _WrappedChildComponent(uiRoot.content);
        addTearDown(() => c.content!.remove());

        await c.callRenderAndWait();
        await c.child.callRenderAndWait();

        expect(c.uiRootComponent, same(uiRoot));
        expect(c.renderedElements, equals([c.wrapper]));
        expect(c.subUIComponents, equals([c.child]));

        bool isWrappedDeep(Object? e) =>
            e.isElement && (e as Element).id == 'wrapped-deep';

        var found = c.getRenderedElement(isWrappedDeep, true) as Element;
        expect(found.textContent, equals('wrapped'));

        var all = c.getAllRenderedElements(isWrappedDeep, true)!;
        expect(all.map((e) => (e as Element).textContent), equals(['wrapped']));

        var allChild = c.getAllRenderedElements((e) => e == c.child, true)!;
        expect(allChild, equals([c.child]));
      },
    );

    test('ensureRendered: forced and not forced', () async {
      var c = _CountingComponent(newHolder());
      expect(c.isRendered, isFalse);

      c.ensureRendered();
      expect(c.renders, equals(1));

      c.ensureRendered();
      expect(c.renders, equals(1), reason: 'Already rendered');

      c.ensureRendered(true);
      expect(c.renders, equals(2));
      expect(c.content!.text, equals('render 2'));
    });

    test('refreshOnNavigate', () {
      var c = _CountingComponent(newHolder());
      expect(c.refreshOnNavigate, isFalse);

      c.refreshOnNavigate = true;
      expect(c.refreshOnNavigate, isTrue);
      c.refreshOnNavigate = true;
      expect(c.refreshOnNavigate, isTrue);

      c.refreshOnNavigate = false;
      expect(c.refreshOnNavigate, isFalse);
    });
  });

  group('UIComponent.parentRenderingUIComponent', () {
    test('in the synchronous rendering stack', () async {
      var parent = _StackParent(newHolder());
      await parent.callRenderAndWait();

      var child = parent.child;
      expect(child.parentWhileRendering, same(parent));
      // `parent` isn't the last in the stack, so the last (`child`) is
      // returned:
      expect(child.selfWhileRendering, same(child));
    });

    test('alone in the rendering stack', () async {
      var c = _StackAlone(newHolder());
      c.callRender();
      expect(c.rendered, isTrue);
      expect(c.parentWhileRendering, isNull);
    });

    test('in an asynchronous rendering zone', () async {
      var other = _HTMLComponent(null, 'other');
      var c = _AsyncZoneComponent(newHolder(), other);
      await c.callRenderAndWait();
      await testUISleepUntil(() => c.asyncDone);

      expect(c.content!.text, equals('zone'));
      expect(c.otherParent, same(c));
      expect(c.selfParent, isNull);
    });
  });

  group('UIComponent data source', () {
    test('`data-source` attributes and `refreshDataSource`', () async {
      var source = _MemDataSource();

      var c = _DataComponent(newHolder());
      await c.callRenderAndWait();
      expect(c.hasDataSource, isFalse);
      expect(c.dataSourceCallString, isEmpty);

      // Without a data source:
      c.refreshDataSource();
      expect(c.dataSets, isEmpty);

      expect(c.setAttribute('data-source', 'test:mem.get(a=1)'), isTrue);
      expect(c.hasDataSource, isTrue);
      expect(c.dataSource, same(source));
      // The call is described by the data source name (without its domain):
      expect(c.getAttribute('data-source'), equals('mem.get(a=1)'));

      expect(c.appendAttribute('data-source', 'test:mem.get(a=2)'), isTrue);
      expect(c.dataSourceCallString, equals('mem.get(a=2)'));

      c.connectDataSource();
      await testUISleepUntil(() => c.changes > 0);

      expect(source.calls, equals(1));
      expect(c.changes, equals(1));
      expect(
        c.dataSets.first,
        equals([
          {'a': '2'},
        ]),
      );
      expect(c.content!.text, equals('a=2'));

      // The render after the change (`posRender`) connects the data source
      // again, applying its cached response (without changes):
      expect(c.dataSets.length, equals(2));
      expect(c.dataSets.last, equals(c.dataSets.first));

      // The cached response (no new call):
      c.refreshDataSource();
      expect(c.dataSets.length, equals(3));
      expect(c.changes, equals(1));
      expect(source.calls, equals(1));
    });

    test('`applyData` without changes does not render', () async {
      var c = _PrintDataComponent(newHolder());
      await c.callRenderAndWait();
      var count = c.renderCount;

      expect(c.applyData({'x': 1}), isFalse);
      expect(c.renderCount, equals(count));
    });
  });

  group('UINavigableComponent routes', () {
    test('finds new routes with `*`', () async {
      var nav = _WildcardNavigable(newHolder(), ['', '*', 'home', 'home']);

      expect(nav.findRoutes, isTrue);
      expect(nav.routes, equals(['home']));

      expect(nav.canNavigateTo('empty'), isFalse, reason: 'Renders `[]`');
      expect(nav.canNavigateTo('null'), isFalse, reason: 'Renders `null`');
      expect(nav.canNavigateTo('list'), isTrue, reason: 'Renders a list');
      expect(nav.routes, contains('list'));
      expect(nav.canNavigateTo('other'), isTrue);
      expect(nav.routes, containsAll(['home', 'list', 'other']));

      await nav.callRenderAndWait();
      expect(nav.content!.text, contains('route: home'));
    });

    test('default route hooks', () {
      var nav = _WildcardNavigable(newHolder(), ['a']);
      expect(nav.findRoutes, isFalse);
      expect(nav.getRouteName('a'), isNull);
      expect(nav.isRouteHiddenFromMenu('a'), isFalse);
      expect(nav.isAccessibleRoute('a'), isTrue);
      expect(nav.deniedAccessRouteOfRoute('a'), isNull);
      expect(nav.routesAndNames, equals({'a': 'a'}));
      expect(nav.menuRoutesAndNames, equals({'a': 'a'}));

      nav.setRoutes(null);
      expect(nav.routes, isEmpty);
      nav.setRoutes(['x', 'y']);
      expect(nav.routes, equals(['x', 'y']));
    });

    test('UINavigableContent with `*` updates its routes on render', () async {
      var content = _WildcardContent(newHolder());
      expect(content.findRoutes, isTrue);

      await content.callRenderAndWait();

      expect(content.content!.querySelector('.head'), isNotNull);
      expect(content.content!.querySelector('.foot'), isNotNull);
      // The routes are searched in the current content, before the rendered
      // elements are added: found by the next render.
      content.callRender();
      expect(content.routes, contains('found-route'));
    });

    test('Navigation.toString and getCurrentRoute', () {
      var nav = Navigation('r1', {'a': '1'});
      expect(
        nav.toString(),
        equals('Navigation{route: r1, parameters: {a: 1}}'),
      );

      expect(
        UINavigator.getCurrentRoute(defaultRoute: 'def'),
        equals(
          UINavigator.currentRoute?.isNotEmpty ?? false
              ? UINavigator.currentRoute
              : 'def',
        ),
      );
    });
  });

  group('UIExplorer documents', () {
    test('a `document` model with `content`', () async {
      var explorer = UIExplorer(newHolder(), {
        'model': 'document',
        'content': '<p class="doc-content">The content</p>',
      });
      await explorer.callRenderAndWait();
      await testUISleepUntil(
        () => explorer.content!.querySelector('.doc-content') != null,
      );

      expect(
        explorer.content!.querySelector('.doc-content')!.textContent,
        equals('The content'),
      );
      expect(
        explorer.content!.classList.contains('ui-explorer-document'),
        isTrue,
      );
    });

    test('a `document` model with `markdown`', () async {
      var explorer = UIExplorer(newHolder(), {
        'model': 'document',
        'markdown': '# Title\n\nSome *text*.',
      });
      await explorer.callRenderAndWait();
      await testUISleepUntil(
        () => explorer.content!.querySelector('h1') != null,
      );

      expect(explorer.content!.querySelector('h1')!.textContent, 'Title');
      expect(explorer.content!.querySelector('em')!.textContent, 'text');
    });

    // The package files, served locally by the test runner:
    test('a `document` model with a markdown `url`', () async {
      var explorer = UIExplorer(newHolder(), {
        'model': 'document',
        'url': '../doc/benchmarks.md',
      });
      await explorer.callRenderAndWait();
      await testUISleepUntil(
        () => explorer.content!.querySelector('h1') != null,
        timeoutMs: 5000,
      );

      expect(
        explorer.content!.querySelector('h1')!.textContent,
        equals('Bones_UI benchmarks'),
      );
    });

    test('a `document` model with an `url` of other language', () async {
      var explorer = UIExplorer(newHolder(), {
        'model': 'document',
        'url': '../dart_test.yaml',
      });
      await explorer.callRenderAndWait();
      await testUISleepUntil(
        () => explorer.content!.text!.contains('timeout'),
        timeoutMs: 5000,
      );

      expect(explorer.content!.text, contains('timeout'));
    });

    test('a `document` model without content renders nothing', () async {
      var explorer = UIExplorer(newHolder(), {'model': 'document'});
      await explorer.callRenderAndWait();
      await testUISleep(ms: 50);
      expect(explorer.content!.text, isEmpty);
    });

    test('an unknown model renders nothing', () async {
      var explorer = UIExplorer(newHolder(), {'model': 'unknown'});
      await explorer.callRenderAndWait();
      await testUISleep(ms: 50);
      expect(explorer.content!.text, isEmpty);
      expect(
        explorer.content!.classList.contains('ui-explorer-unknown'),
        isTrue,
      );
    });

    test('a `document` model with a `locale_url_pattern`', () async {
      var explorer = UIExplorer(newHolder(), {
        'model': 'document',
        'url': '../doc/benchmarks.md',
        // Without a match, the `url` is the same for all the locales:
        'locale_url_pattern': r'\{\{locale\}\}',
      });
      await explorer.callRenderAndWait();
      await testUISleepUntil(
        () => explorer.content!.querySelector('h1') != null,
        timeoutMs: 5000,
      );

      expect(
        explorer.content!.querySelector('h1')!.textContent,
        equals('Bones_UI benchmarks'),
      );
    });

    test('ResourceConfig from a resource', () async {
      var config = _MemJSONConfig('{"model": "document", "content": "x"}');

      expect(config.isLoaded, isFalse);
      expect(config.getDocumentIfLoaded(), isNull);

      var doc = (await config.getDocument())!;
      expect(doc.getAsString('model'), equals('document'));
      expect(config.isLoaded, isTrue);
      expect(await config.load(), same(doc));
      expect(config.getDocumentIfLoaded(), same(doc));
      expect(config.resourceContent, isNotNull);

      var yaml = _MemYAMLConfig('model: query\nx: 1');
      var yamlDoc = (await yaml.getDocument())!;
      expect(yamlDoc.getAsString('model'), equals('query'));
      expect(yamlDoc.getAsInt('x'), equals(1));
    });
  });

  group('ElementProvider / CSSProvider', () {
    test('without a source throws a StateError', () {
      expect(() => ElementProvider.fromElement(null).element, throwsStateError);
      expect(() => CSSProvider.fromElement(null).css, throwsStateError);
    });

    test('from a DOMNode', () async {
      var node = $div(style: 'color: rgb(1, 2, 3)', content: 'css');

      var css = CSSProvider.fromDOMNode(node).css;
      expect(css.color.toString(), contains('1'));

      var element = ElementProvider.fromDOMNode(node).element!;
      expect(element.textContent, equals('css'));
    });
  });

  group('UIComponent fields and actions', () {
    test('typed fields groups', () async {
      var c = _HTMLComponent(
        newHolder(),
        '<div>'
        '<input name="p_1" value="1.5">'
        '<input name="p_2" value="2">'
        '<input name="flag" value="true">'
        '</div>',
      );
      await c.callRenderAndWait();

      expect(
        c.getFieldsGroupByPrefix<int, double>('p_'),
        equals({1: 1.5, 2: 2.0}),
      );
      expect(c.getFieldsGroupByPrefix<num, num>('p_'), equals({1: 1.5, 2: 2}));
      expect(
        c.getFieldsGroupByPrefix<String, bool>('fl', keyPart: (k) => k),
        equals({'flag': true}),
      );
      expect(c.getFieldAs<bool>('flag'), isTrue);
    });

    test('an `UIComponent` (not an `UIField`) as field', () async {
      var c = _FieldHostComponent(uiRoot.content);
      addTearDown(() => c.content!.remove());
      await c.callRenderAndWait();
      await c.child.callRenderAndWait();

      // Only an `UIField` is resolved as a field component: for other
      // components, the field is their `content` element:
      expect(c.getFieldComponent('comp'), _sameJS(c.child.content!));
      expect(c.getFieldExtended('comp'), equals('comp text'));

      expect(c.focusField('comp'), isTrue);
      expect(c.focusField(null), isFalse);
    });

    test('`action` and `onEventKeyPress` attributes', () async {
      captureConsole();

      var c = _HTMLComponent(
        newHolder(),
        '<div>'
        '<button action="save">Save</button>'
        '<input onEventKeyPress=":typed">'
        '<input onEventKeyPress="Enter:entered">'
        '</div>',
      );
      await c.callRenderAndWait();

      c.content!.querySelector('button')!.dispatchEvent(MouseEvent('click'));
      expect(consoleLogs(), contains('action: save'));

      var inputs = c.content!.querySelectorAll('input').toElements();

      inputs[0].dispatchEvent(
        KeyboardEvent('keypress', KeyboardEventInit(key: 'x')),
      );
      expect(consoleLogs(), contains('action: typed'));

      inputs[1].dispatchEvent(
        KeyboardEvent('keypress', KeyboardEventInit(key: 'a')),
      );
      expect(consoleLogs(), isNot(contains('action: entered')));

      inputs[1].dispatchEvent(
        KeyboardEvent('keypress', KeyboardEventInit(key: 'Enter')),
      );
      expect(consoleLogs(), contains('action: entered'));
    });

    test('UIInputTable `complete` events', () async {
      var changes = <Object?>[];

      var table = UIInputTable(newHolder(), [
        InputConfig('name', 'Name', onChangeListener: changes.add),
      ]);
      await table.callRenderAndWait();

      var tableChanges = <Object?>[];
      table.onChange.listen(tableChanges.add);

      var name = table.getFieldElementNonTyped('name') as HTMLInputElement;
      name.value = 'Completed';
      name.dispatchEvent(Event('complete'));
      expect(changes.length, equals(1));

      // `onChange` is notified asynchronously:
      await testUISleepUntil(() => tableChanges.isNotEmpty);

      expect(changes.length, equals(1));
      expect(tableChanges.length, equals(1));
      expect(table.getPreviousRenderedFieldValue('name'), equals('Completed'));
    });
  });

  group('UINavigator', () {
    test('a stale `navigateOnClick` listener cancels itself', () async {
      var routeBefore = UINavigator.currentRoute;

      var elem = HTMLDivElement();
      newHolder().append(elem);

      expect(UINavigator.navigateOnClick(elem, 'stale-route'), isNotNull);
      expect(UINavigator.getNavigateOnClick(elem), equals('stale-route'));

      // Changed without `navigateOnClick` (the listener is now stale):
      elem.setAttribute('__navigate__route', 'other-route');

      elem.dispatchEvent(MouseEvent('click'));
      elem.dispatchEvent(MouseEvent('click'));
      await testUISleep(ms: 10);

      expect(UINavigator.currentRoute, equals(routeBefore));
    });

    test('clearDetachedNavigables', () {
      var detached = _WildcardNavigable(null, ['detached-route']);
      expect(UINavigator.navigables, contains(detached));

      var attached = _WildcardNavigable(uiRoot.content, ['attached-route']);
      addTearDown(() => attached.content!.remove());

      UINavigator.get().clearDetachedNavigables(ignore: attached);

      expect(UINavigator.navigables, isNot(contains(detached)));
      expect(UINavigator.navigables, contains(attached));
    });
  });

  group('UIRoot', () {
    test('an error in `onResize` is caught', () async {
      uiRoot.failOnResize = true;
      addTearDown(() => uiRoot.failOnResize = false);

      window.dispatchEvent(Event('resize'));
      await testUISleep(ms: 10);

      expect(uiRoot.resizeCalls, greaterThanOrEqualTo(1));
    });

    test('purgeRoot with an initialized DOMTreeMap', () async {
      var treeMap = uiRoot.domTreeMap;
      expect(uiRoot.domTreeMapIfInitialized, same(treeMap));

      var c = _HTMLComponent(newHolder(), '<i>purge</i>');
      await c.callRenderAndWait();

      await uiRoot.purgeRoot();

      expect(c.content!.querySelector('i')!.textContent, 'purge');
    });

    test('renderLoading is null by default', () {
      expect(uiRoot.renderLoading(), isNull);
    });
  });

  group('UIInputTable', () {
    test('intl labels and values', () async {
      var prev = uiRoot.intlMessageResolver;
      addTearDown(() => uiRoot.intlMessageResolver = prev);
      uiRoot.intlMessageResolver = (String key, [Map? params]) => 'T-$key';

      var table = UIInputTable(newHolder(), [
        InputConfig('name', '{{intl:nameLabel}}', value: '{{intl:nameValue}}'),
      ]);
      await table.callRenderAndWait();

      var label = table.content!.querySelector('label')!;
      expect(label.textContent, contains('nameLabel'));

      var input = table.getFieldElementNonTyped('name') as HTMLInputElement;
      expect(input.value, contains('nameValue'));
    });

    test('action listeners of passwords, dates and textareas', () async {
      var actions = <String>[];

      var table = UIInputTable(newHolder(), [
        InputConfig(
          'pass',
          'Pass',
          type: 'password',
          onActionListener: (_) => actions.add('pass'),
        ),
        InputConfig(
          'when',
          'When',
          type: 'date',
          onActionListener: (_) => actions.add('when'),
        ),
        InputConfig(
          'text',
          'Text',
          type: 'textarea',
          onActionListener: (_) => actions.add('text'),
        ),
      ]);
      await table.callRenderAndWait();

      var pass = table.getFieldElementNonTyped('pass') as HTMLInputElement;
      expect(pass.type, equals('password'));

      pass.dispatchEvent(KeyboardEvent('keyup', KeyboardEventInit(key: 'a')));
      expect(actions, isEmpty);

      pass.dispatchEvent(
        KeyboardEvent('keyup', KeyboardEventInit(key: 'Enter')),
      );
      expect(actions, equals(['pass']));

      var when = table.getFieldElementNonTyped('when') as HTMLInputElement;
      expect(when.type, equals('date'));

      var text = table.getFieldElementNonTyped('text');
      expect(text.isA<HTMLTextAreaElement>(), isTrue);
    });
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'coverage-c-root');

  bool failOnResize = false;
  int resizeCalls = 0;

  @override
  void onResize(Event e) {
    resizeCalls++;
    if (failOnResize) throw StateError('resize fail');
  }

  @override
  UIComponent? renderContent() => null;
}

class _HTMLComponent extends UIComponent {
  final String html;

  _HTMLComponent(super.parent, this.html);

  @override
  dynamic render() => html;
}

class _FieldHostComponent extends UIComponent {
  _FieldHostComponent(super.parent);

  late final _FieldChild child = _FieldChild(content);

  @override
  dynamic render() => [child];
}

/// An [UIComponent] (not an [UIField]) with a `field` attribute.
class _FieldChild extends UIComponent {
  _FieldChild(super.parent);

  @override
  void configure() {
    content!.setAttribute('field', 'comp');
  }

  @override
  dynamic render() => 'comp text';
}

class _FailingComponent extends UIComponent {
  final String step;

  _FailingComponent(super.parent, this.step);

  Never _fail() => throw StateError('fail at $step');

  @override
  bool isAccessible() {
    if (step == 'isAccessible') _fail();
    return true;
  }

  @override
  void preRender() {
    if (step == 'preRender') _fail();
  }

  @override
  dynamic render() {
    if (step == 'render') _fail();
    if (step == 'posAsyncRender') {
      return Future.value('async rendered');
    }
    return 'rendered';
  }

  @override
  void posRender() {
    if (step == 'posRender') _fail();
  }

  @override
  void posAsyncRender() {
    if (step == 'posAsyncRender') _fail();
  }
}

class _FuncComponent extends UIComponent {
  final Object value;

  _FuncComponent(super.parent, this.value);

  @override
  dynamic render() => ['before', value];
}

class _ParentFailingOnChild extends UIComponent {
  _ParentFailingOnChild(super.parent);

  late final _HTMLComponent child = _HTMLComponent(content, 'child');

  int childRenderedCalls = 0;

  @override
  dynamic render() => [child];

  @override
  void onChildRendered(UIComponent child) {
    childRenderedCalls++;
    throw StateError('onChildRendered fail');
  }
}

class _NotAccessible extends UIComponent {
  _NotAccessible(super.parent);

  @override
  bool isAccessible() => false;

  @override
  String? deniedAccessRoute() => 'login';

  @override
  dynamic render() => 'secret';
}

class _TreeComponent extends UIComponent {
  _TreeComponent(super.parent) : super(id: 'tree-comp');

  late final _ChildWithDeep child = _ChildWithDeep(content);

  @override
  dynamic render() => ['<div id="plain-div">plain</div>', child];
}

class _ChildWithDeep extends UIComponent {
  _ChildWithDeep(super.parent) : super(id: 'tree-child');

  @override
  dynamic render() => '<span id="deep">deep</span>';
}

class _WrappedChildComponent extends UIComponent {
  _WrappedChildComponent(super.parent);

  final HTMLDivElement wrapper = HTMLDivElement()..className = 'wrapper';

  _WrappedChild? _child;

  _WrappedChild get child => _child!;

  @override
  dynamic render() => wrapper;

  @override
  void posRender() {
    // The child is inside of the rendered `wrapper` (it's not a rendered
    // element of this component):
    _child ??= _WrappedChild(wrapper)..callRender();
  }
}

class _WrappedChild extends UIComponent {
  _WrappedChild(super.parent);

  @override
  dynamic render() => '<b id="wrapped-deep">wrapped</b>';
}

class _CountingComponent extends UIComponent {
  int renders = 0;

  _CountingComponent(super.parent);

  @override
  dynamic render() => 'render ${++renders}';
}

class _StackParent extends UIComponent {
  _StackParent(super.parent);

  late final _StackChild child = _StackChild(content, this);

  @override
  dynamic render() {
    child.callRender();
    return [child];
  }
}

class _StackChild extends UIComponent {
  final UIComponent parentComponent;

  _StackChild(super.parent, this.parentComponent);

  UIComponent? parentWhileRendering;
  UIComponent? selfWhileRendering;

  @override
  dynamic render() {
    parentWhileRendering = UIComponent.parentRenderingUIComponent(this);
    selfWhileRendering = UIComponent.parentRenderingUIComponent(
      parentComponent,
    );
    return 'child';
  }
}

class _StackAlone extends UIComponent {
  _StackAlone(super.parent);

  bool rendered = false;
  UIComponent? parentWhileRendering = _HTMLComponent(null, 'x');

  @override
  dynamic render() {
    rendered = true;
    parentWhileRendering = UIComponent.parentRenderingUIComponent(this);
    return 'alone';
  }
}

class _AsyncZoneComponent extends UIComponent {
  final UIComponent other;

  _AsyncZoneComponent(super.parent, this.other);

  bool asyncDone = false;
  UIComponent? otherParent;
  UIComponent? selfParent = _HTMLComponent(null, 'x');

  @override
  dynamic render() async {
    await Future<void>.delayed(Duration.zero);
    otherParent = UIComponent.parentRenderingUIComponent(other);
    selfParent = UIComponent.parentRenderingUIComponent(this);
    asyncDone = true;
    return 'zone';
  }
}

/// An in-memory [DataSource] (`test:mem`), returning its call parameters.
class _MemDataSource extends DataSource<Map> {
  int calls = 0;

  _MemDataSource() : super('test', 'mem');

  @override
  Future getImpl(Map<String, dynamic>? parameters) async {
    calls++;
    return [Map.from(parameters ?? {})];
  }
}

class _DataComponent extends UIComponent {
  _DataComponent(super.parent);

  /// Every applied data.
  final List<Object?> dataSets = [];

  /// The number of applied data that changed the previous one.
  int changes = 0;

  @override
  bool setData(dynamic data) {
    var changed = dataSets.isEmpty || '${dataSets.last}' != '$data';
    dataSets.add(data);
    if (changed) changes++;
    return changed;
  }

  @override
  dynamic render() {
    if (dataSets.isEmpty) return 'no data';
    var data = dataSets.last as List;
    return data
        .map((e) => (e as Map).entries.map((e) => '${e.key}=${e.value}'))
        .expand((e) => e)
        .join(', ');
  }
}

class _PrintDataComponent extends UIComponent {
  _PrintDataComponent(super.parent);

  @override
  dynamic render() => 'data';
}

class _WildcardNavigable extends UINavigableComponent {
  _WildcardNavigable(super.parent, super.routes);

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    switch (route) {
      case 'empty':
        return [];
      case 'null':
        return null;
      case 'list':
        return ['list'];
      default:
        return 'route: $route';
    }
  }
}

class _WildcardContent extends UINavigableContent {
  _WildcardContent(Object? parent) : super(parent, ['*'], topMargin: 10);

  @override
  dynamic renderRouteHead(String? route, Map<String, String>? parameters) =>
      '<div class="head">head</div>';

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      '<a navigate="found-route">go</a>';

  @override
  dynamic renderRouteFoot(String? route, Map<String, String>? parameters) =>
      '<div class="foot">foot</div>';
}

class _MemJSONConfig extends JSONConfig {
  _MemJSONConfig(String json) : super(ResourceContent(null, json));
}

class _MemYAMLConfig extends YAMLConfig {
  _MemYAMLConfig(String yaml) : super(ResourceContent(null, yaml));
}
