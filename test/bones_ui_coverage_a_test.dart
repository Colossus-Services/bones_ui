@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_layout.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:swiss_knife/swiss_knife.dart' show MapProperties, MimeType;
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// Integration tests (real DOM) for `bui.dart`, `template.dart`,
/// `bones_ui_layout.dart`, `controlled_component.dart` and `data_source.dart`.
void main() {
  late final _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();

    UIButton.register();
    UIDataSource.register();
  });

  /// A container attached to the root, removed after the test.
  web.HTMLDivElement newHolder() {
    var holder = web.HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    return holder;
  }

  group('UILayoutEvaluator', () {
    UILayoutEvaluator newEvaluator({Object? thisElement}) => UILayoutEvaluator(
      (id, all) => id == '_' ? thisElement : null,
      (element, property) => null,
    );

    test('ValueUnitExpression arithmetic keeps the unit', () {
      var v = ValueUnitExpression(10, 'px');

      expect('${v + 5}', equals('15px'));
      expect('${v - 3}', equals('7px'));
      expect('${v * 2}', equals('20px'));
      expect('${v / 4}', equals('2.5px'));
      expect('${v ~/ 3}', equals('3px'));
      expect(v.valueAsLiteral.value, equals(10));
    });

    test('a unit value with a nested binary expression', () {
      var evaluator = newEvaluator();

      expect(evaluator.processLayout('1px + (2 + 3)', {}), equals('6px'));
      expect(evaluator.processLayout('(2 + 3) + 1px', {}), equals('6px'));
      expect(evaluator.processLayout('(2 * 3) - 1', {}, 'px'), equals('5px'));
    });

    test('index of a non-List value', () {
      var evaluator = newEvaluator();

      var map = {1: 'one'};
      expect(evaluator.processLayout('m[1]', {'m': map}), equals('one'));
      // Index `0` of a non-`List` is the value itself:
      expect(evaluator.processLayout('m[0]', {'m': map}), same(map));
      // An out of range `List` index:
      expect(
        evaluator.processLayout(
          'l[5]',
          {
            'l': [1, 2],
          },
          'px',
          'none',
        ),
        equals('none'),
      );
    });

    test('`this` without an element gives the default value', () {
      var evaluator = newEvaluator();
      expect(evaluator.processLayout('this', {}, 'px', 'def'), equals('def'));

      var element = web.HTMLDivElement();
      var withThis = newEvaluator(thisElement: element);
      expect(withThis.processLayout('this', {}), same(element));
      expect(withThis.isProvidedElement(element), isTrue);
      expect(withThis.isProvidedElement(null), isFalse);
    });

    test('evalValue of a Map, a List and other values', () {
      var evaluator = newEvaluator();

      expect(evaluator.evalValue([10, 20], '1'), equals(20));
      expect(evaluator.evalValue({'a': 1}, 'a'), equals(1));
      expect(evaluator.evalValue('x', 'a'), equals('x'));
      expect(evaluator.evalValue('x', null), equals('x'));
    });
  });

  group('UILayout', () {
    /// A `relative` container (in the DOM) holding [children].
    web.HTMLDivElement newContainer(
      List<web.HTMLElement> children, {
      int width = 200,
      int height = 100,
    }) {
      var container = web.HTMLDivElement()
        ..style.position = 'relative'
        ..style.width = '${width}px'
        ..style.height = '${height}px';

      for (var e in children) {
        container.append(e);
      }

      newHolder().append(container);
      return container;
    }

    test('`*` and `%` with a zero sized parent need a refresh', () {
      var element = web.HTMLDivElement();
      var container = newContainer([element], width: 0, height: 0);

      var layout = UILayout(uiRoot, element, 'x(*); width(*); height(50%)');

      expect(element.style.left, equals('0px'));
      expect(element.style.width, equals('0px'));
      expect(element.style.height, equals('0px'));
      expect(layout.needsRefresh, isTrue);
      expect(layout.isRegistered, isTrue);
      expect(UILayout.someInstanceNeedsRefresh(), isTrue);

      container.style
        ..width = '200px'
        ..height = '100px';

      layout.refresh();

      expect(layout.needsRefresh, isFalse);
      expect(element.style.left, equals('100px'));
      expect(element.style.width, equals('200px'));
      expect(element.style.height, equals('50px'));
    });

    test('a window resize refreshes the layouts', () async {
      var element = web.HTMLDivElement();
      var container = newContainer([element]);

      UILayout(uiRoot, element, 'width(50%)');
      expect(element.style.width, equals('100px'));

      container.style.width = '400px';
      web.window.dispatchEvent(web.Event('resize'));
      await testUISleep(ms: 10);

      expect(element.style.width, equals('200px'));
    });

    test('`index` and `indexbyid` element properties', () {
      var first = web.HTMLDivElement()..id = 'covfirst';
      var second = web.HTMLDivElement()..id = 'covsecond';
      var element = web.HTMLDivElement();
      newContainer([first, second, element]);

      UILayout(
        uiRoot,
        element,
        'x(#covsecond.index * 10); y(#covsecond.indexbyid + 4)',
      );

      expect(element.style.left, equals('10px'));
      expect(element.style.top, equals('4px'));
    });

    test('a removed element is unregistered', () {
      var element = web.HTMLDivElement();
      var container = newContainer([element]);

      var layout = UILayout(uiRoot, element, 'x(5px)');
      expect(layout.isRegistered, isTrue);

      container.remove();
      UILayout.checkInstances();

      expect(layout.isRegistered, isFalse);
    });
  });

  group('ui-template', () {
    test('variables from a data source', () async {
      var dataSource = _MemDataSource();
      expect(DataSource.byID('covtpl:items'), same(dataSource));

      var component = _HTMLComponent(
        newHolder(),
        '<ui-template data-source="covtpl:items">'
        '{{*:data}}<i class="ds">{{name}}</i>{{/data}}'
        '</ui-template>',
      );
      await component.callRenderAndWait();

      var content = component.content!;
      var ready = await testUISleepUntil(
        () => content.querySelectorAll('i.ds').length == 2,
        timeoutMs: 5000,
      );
      expect(ready, isTrue);

      var names = content
          .querySelectorAll('i.ds')
          .toElements()
          .map((e) => e.textContent)
          .toList();
      expect(names, equals(['A', 'B']));
    });

    test('a variable that is a template', () async {
      var component = _HTMLComponent(
        newHolder(),
        // `%7B%7Bwho%7D%7D` is `{{who}}` (not parsed as a template in the
        // attribute):
        '<ui-template variables="who=Ana&greet=Hi%20%7B%7Bwho%7D%7D">'
        '<b class="greet">{{greet}}</b>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      expect(
        component.content!.querySelector('b.greet')!.textContent,
        equals('Hi Ana'),
      );
    });

    test('a failing template falls back to the plain content', () async {
      // Fails only once: while resolving the template variables.
      var calls = 0;
      var context = UIComponent.domGenerator.domContext!;
      context.putVariable('covOnce', () {
        if (calls++ == 0) throw StateError('boom');
        return 'recovered';
      });
      addTearDown(() => context.putVariable('covOnce', null));

      var component = _HTMLComponent(
        newHolder(),
        '<ui-template class="covfail" title="T">'
        '<b class="raw">{{covOnce}}</b><i class="ok">ok</i>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var div = component.content!.querySelector('div.covfail')!;
      expect(div.getAttribute('title'), equals('T'));
      expect(div.querySelector('b.raw')!.textContent, equals('recovered'));
      expect(div.querySelector('i.ok')!.textContent, equals('ok'));
      expect(calls, greaterThan(1));
    });

    test('a valueless boolean attribute is kept', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-template class="covbool" hidden variables="v=1">'
        '<b>{{v}}</b>'
        '</ui-template>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var div = component.content!.querySelector('div.covbool')!;
      expect(div.hasAttribute('hidden'), isTrue);
      expect(div.querySelector('b')!.textContent, equals('1'));
    });
  });

  group('BUI', () {
    test('assets are resolved in sources and CSS URLs', () async {
      var dataAssets = DataAssets()
        ..putContent('a.txt', 'asset', MimeType.parse('text/plain')!);
      var assetURL = dataAssets.getURL('a.txt')!;

      var render = BUIRender(
        newHolder(),
        dataAssets: dataAssets,
        source:
            '<bui><img id="cov-img" src="assets/a.txt">'
            '<div id="cov-bg" style="background-image: url(assets/a.txt)">'
            '</div></bui>',
      );
      await testUISleep(ms: 50);

      var root = render.renderedRoot!;
      var img = root.querySelector('#cov-img')!;
      expect(img.getAttribute('src'), equals(assetURL));

      var bg = root.querySelector('#cov-bg') as web.HTMLElement;
      expect(bg.style.backgroundImage, contains(assetURL));
    });

    test('without intl messages', () async {
      var render = BUIRender(newHolder(), source: '<bui><p>no intl</p></bui>');
      await testUISleep(ms: 50);

      expect(render.hasIntlMessages, isFalse);
      expect(render.isIntlLoaded, isTrue);
      expect(await render.ensureIntlMessagesLoaded(), isTrue);
      expect(render.content!.textContent, contains('no intl'));
    });

    test('routes without a view provider', () async {
      var render = BUIRender(newHolder(), source: '<bui>x</bui>');
      await testUISleep(ms: 50);

      expect(render.viewProvider, isNull);
      expect(render.updateRoutes(), isFalse);
      expect(render.getRouteName('any'), isNull);
      expect(render.isRouteHiddenFromMenu('any'), isFalse);
      // `UINavigableComponent`'s default (`*` routes):
      expect(render.canHandleNewRoute('any'), isTrue);
      expect(render.dataAssets, isNull);

      // No view provider to set a route into:
      render.setCurrentRoute('any');
      expect(render.viewProvider, isNull);
    });

    test('a child component notifies onRenderChildComponent', () async {
      var render = BUIRender(
        newHolder(),
        source: '<bui><ui-button>Child</ui-button></bui>',
        renderOnConstruction: false,
      );

      var children = <UIComponent>[];
      render.onRenderChildComponent.listen(children.add);

      await render.callRenderAndWait();
      var ready = await testUISleepUntil(
        () => children.isNotEmpty,
        timeoutMs: 5000,
      );
      expect(ready, isTrue);

      expect(children.first, isA<UIButton>());
      expect(render.content!.querySelector('button')!.textContent, 'Child');
    });

    // Inline contents (not URLs, which would be fetched):
    test('a manifest with views and headers as lists', () async {
      var provider = (await BUIViewProvider.fromManifestTree({
        'name': 'list',
        'views': ['<bui route="lv">\n<p>LIST VIEW</p></bui>'],
        'headers': ['<bui route="lh">\nLIST HEADER</bui>'],
        'footers': ['<bui route="lf">\nLIST FOOTER</bui>'],
      }))!;

      expect(provider.name, equals('list'));
      expect(provider.routes, equals(['lv']));
      expect(provider.getView('lv')!.buiCode, contains('LIST VIEW'));
      expect(provider.getHeader('lh')!.buiCode, contains('LIST HEADER'));
      expect(provider.getFooter('lf')!.buiCode, contains('LIST FOOTER'));
    });

    test('a ZIP with a latin1 view', () {
      var latin1Bytes = latin1.encode('<bui>café</bui>');

      var archive = Archive()
        ..addFile(ArchiveFile.bytes('app/views/lat.bui', latin1Bytes));
      var bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      var provider = BUIViewProvider.fromZipBytes('zip', bytes);
      expect(provider.getView('lat')!.buiCode, equals('<bui>café</bui>'));
    });

    test('a manifest loaded from a URI registers its data sources', () async {
      String dataURL(String content) =>
          Uri.dataFromString(content, base64: true).toString();

      Map ds(String id) => {
        'id': id,
        'baseURL': 'http://localhost/api',
        'get': {'path': 'items', 'parameters': {}},
      };

      var manifests = [
        // A list, with a nested list:
        {
          'name': 'm1',
          'data-sources': [
            ds('covm:a'),
            [ds('covm:b')],
          ],
        },
        // A map:
        {
          'name': 'm2',
          'data-sources': {'c': ds('covm:c')},
        },
      ];

      var expectedIDs = [
        ['covm:a', 'covm:b'],
        ['covm:c'],
      ];

      for (var i = 0; i < manifests.length; ++i) {
        var m = manifests[i];
        var manifest = BUIManifest.from(Uri.parse(dataURL(jsonEncode(m))))!;
        expect((await manifest.getManifestTree())!['name'], equals(m['name']));

        // Regression: the loaded data sources were never stored
        // (`_dataSources = _dataSources`).
        var loaded = await testUISleepUntil(
          () => manifest.dataSources != null,
          timeoutMs: 5000,
        );
        expect(loaded, isTrue, reason: 'Manifest `${m['name']}`');
        expect(manifest.dataSources!.keys, unorderedEquals(expectedIDs[i]));

        for (var id in expectedIDs[i]) {
          expect(manifest.dataSources![id], isA<DataSourceHttp>());
          expect(DataSource.byID(id), isNotNull, reason: 'Registered `$id`');
        }
      }

      // An URL `String`:
      var fromString = BUIManifest.from(
        dataURL(jsonEncode({'name': 'm4', 'data-sources': []})),
      )!;
      expect((await fromString.getManifestTree())!['name'], equals('m4'));
      expect(
        await testUISleepUntil(
          () => fromString.dataSources != null,
          timeoutMs: 5000,
        ),
        isTrue,
      );
      expect(fromString.dataSources, isEmpty);
    });
  });

  group('UIControlledComponent', () {
    test('renders only the labeled controllers until valid', () async {
      var component = _Controlled(newHolder());
      await component.callRenderAndWait();

      var content = component.content!;
      var ready = await testUISleepUntil(
        () => content.querySelector('input.cov-a') != null,
        timeoutMs: 5000,
      );
      expect(ready, isTrue);

      expect(content.querySelector('input.cov-b'), isNotNull);
      expect(content.querySelector('.cov-result'), isNull);

      // The `a_label` controller is resolved to a content node (not a
      // `String`), rendered before its controller:
      var a = content.querySelector('input.cov-a')!;
      var b = content.querySelector('input.cov-b')!;
      expect(content.textContent, contains('A'));
      expect(
        a.compareDocumentPosition(b) & web.Node.DOCUMENT_POSITION_FOLLOWING,
        isNonZero,
      );

      // The separators between the controllers:
      expect(content.querySelector('div.w-100.d-md-none'), isNotNull);
    });

    test('an error in onChangeController still notifies onChange', () async {
      var component = _Controlled(newHolder(), failOnChange: true);
      await component.callRenderAndWait();

      var content = component.content!;
      await testUISleepUntil(
        () => content.querySelector('input.cov-a') != null,
        timeoutMs: 5000,
      );

      var changes = 0;
      component.onChange.listen((_) => changes++);

      var input = content.querySelector('input.cov-a') as web.HTMLInputElement;
      input.value = 'x';
      input.dispatchEvent(web.Event('change'));
      await testUISleep(ms: 10);

      expect(component.onChangeCalls, equals(1));
      expect(changes, equals(1));
    });
  });

  group('ui-data-source', () {
    test('generated from a tag with a JSON content', () async {
      var component = _HTMLComponent(
        newHolder(),
        '<ui-data-source>'
        '{"id": "covtag:items", "baseURL": "http://localhost/api", '
        '"get": {"path": "items", "parameters": {}}}'
        '</ui-data-source>',
      );
      await component.callRenderAndWait();
      await testUISleep(ms: 50);

      var div = component.content!.querySelector(
        '.ui-data-source',
      ) as web.HTMLElement;
      expect(div.style.display, equals('none'));

      var dataSource = DataSource.byID('covtag:items');
      expect(dataSource, isA<DataSourceHttp>());
      expect(div.textContent, contains('covtag'));
    });
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'coverage-a-root');

  @override
  UIComponent? renderContent() => null;
}

class _HTMLComponent extends UIComponent {
  final String html;

  _HTMLComponent(super.parent, this.html);

  @override
  dynamic render() => html;
}

class _MemDataSource extends DataSource<Map<String, dynamic>> {
  _MemDataSource() : super('covtpl', 'items');

  @override
  Future getImpl(Map<String, dynamic>? parameters) async => [
    {'name': 'A'},
    {'name': 'B'},
  ];
}

class _Controlled extends UIControlledComponent {
  final bool failOnChange;

  int onChangeCalls = 0;

  _Controlled(Object? parent, {this.failOnChange = false})
    : super(parent, 'Loading...', 'Error!');

  @override
  Future<Map<String, dynamic>> renderControllers(
    MapProperties properties,
  ) async {
    return {
      'a': web.HTMLInputElement()..className = 'cov-a',
      'a_label': 'A',
      'b': web.HTMLInputElement()..className = 'cov-b',
    };
  }

  @override
  Future<bool> setupControllers(
    MapProperties properties,
    Map<String, dynamic>? controllers,
  ) async => true;

  // Never valid: only the controllers are rendered.
  @override
  bool isValidControllersSetup(
    MapProperties properties,
    Map<String, dynamic>? controllers,
  ) => false;

  @override
  void onChangeController(
    Map<String, dynamic>? controllers,
    bool validControllersSetup,
    dynamic changedController,
  ) {
    onChangeCalls++;
    if (failOnChange) throw StateError('onChangeController failed');
    super.onChangeController(
      controllers,
      validControllersSetup,
      changedController,
    );
  }

  @override
  Future<dynamic> renderResult(MapProperties properties) async =>
      '<div class="cov-result">RESULT</div>';
}
