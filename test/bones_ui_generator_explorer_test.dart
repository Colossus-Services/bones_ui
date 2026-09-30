@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart' show parseString;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' show YamlList, YamlMap, YamlScalar;

/// Runs [f] capturing the lines it prints.
List<String> _capturePrints(void Function() f) {
  var lines = <String>[];
  runZoned(
    f,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// Matches the same JS object as [expected] (JS `===`). With `dart2wasm`,
/// the same JS object can be wrapped by distinct Dart objects.
Matcher _sameJS(JSAny expected) => predicate<Object?>(
  (actual) => (actual as JSAny?).strictEquals(expected).toDart,
  'the same JS object as $expected',
);

/// A host `div` attached to the root, removed after the test.
HTMLDivElement _host(UIRoot uiRoot) {
  var host = HTMLDivElement();
  uiRoot.content!.appendChild(host);
  addTearDown(() => host.remove());
  return host;
}

void main() {
  testUI<_Root>('generator, explorer and test tools', (c) => _Root(c), (
    context,
  ) {
    group('UIComponentAttributeHandler', () {
      test('normalizeComponentAttributeName', () {
        expect(
          UIComponentAttributeHandler.normalizeComponentAttributeName(null),
          isNull,
        );
        expect(
          UIComponentAttributeHandler.normalizeComponentAttributeName('  '),
          isNull,
        );
        expect(
          UIComponentAttributeHandler.normalizeComponentAttributeName(' Foo '),
          equals('foo'),
        );
      });

      test('requires a getter and a setter', () {
        expect(
          () => UIComponentAttributeHandler<_GenComp, String>(
            'x',
            setter: (c, v) {},
          ),
          throwsArgumentError,
        );
        expect(
          () => UIComponentAttributeHandler<_GenComp, String>(
            'x',
            getter: (c) => null,
          ),
          throwsArgumentError,
        );
      });

      test('parse / set / append / clear with defaults', () {
        var comp = _GenComp(null);

        var handler = UIComponentAttributeHandler<_GenComp, String>(
          ' Tags ',
          getter: (c) => c.tags,
          setter: (c, v) => c.tags = v,
        );

        expect(handler.name, equals('tags'));
        expect(handler.parse('raw'), equals('raw'));

        handler.set(comp, 'a');
        expect(handler.get(comp), equals('a'));

        // The default appender is the setter:
        handler.append(comp, 'b');
        expect(comp.tags, equals('b'));

        // The default cleaner sets `null`:
        handler.clear(comp);
        expect(comp.tags, isNull);

        var parsed = UIComponentAttributeHandler<_GenComp, String>(
          'label',
          parser: (v) => '<$v>',
          getter: (c) => c.label,
          setter: (c, v) => c.label = v,
          appender: (c, v) => c.label = '${c.label ?? ''}$v',
          cleaner: (c) => c.label = 'CLEARED',
        );

        parsed.set(comp, 'x');
        expect(comp.label, equals('<x>'));
        parsed.append(comp, 'y');
        expect(comp.label, equals('<x><y>'));
        parsed.clear(comp);
        expect(comp.label, equals('CLEARED'));
      });
    });

    group('UIComponentGenerator', () {
      setUpAll(() => UIComponent.registerGenerator(_GenComp.generator));

      test('generates the component from DSX/DOM', () async {
        var host = _host(context.uiRoot);

        var element = UIComponent.domGenerator.generate(
          $tag('ui-test-gen', attributes: {'label': 'hello', 'class': 'extra'}),
          parent: host,
        );

        await testUISleep(ms: 50);

        expect(element, isNotNull);
        var div = element as Element;
        expect(div.tagName.toLowerCase(), equals('div'));
        expect(div.classList.contains('ui-test-gen'), isTrue);
        expect(div.classList.contains('extra'), isTrue);
        expect(div.textContent, contains('label: hello'));

        var comp = context.uiRoot.getUIComponentByContent(div) as _GenComp;
        expect(comp.label, equals('hello'));
      });

      test('generates the component from HTML', () async {
        var host = _host(context.uiRoot);

        UIComponent.domGenerator.generateFromHTML(
          '<div><ui-test-gen label="from-html"></ui-test-gen></div>',
          parent: host,
        );
        await testUISleep(ms: 50);

        var div = host.querySelector('div.ui-test-gen')!;
        expect(div.textContent, contains('label: from-html'));
      });

      test('get / set / append / clear attributes', () {
        var gen = _GenComp.generator;
        var comp = _GenComp(null, label: 'a');

        expect(gen.getAttributeHandler(null), isNull);
        expect(gen.getAttributeHandler(' '), isNull);
        expect(gen.getAttributeHandler('nope'), isNull);
        expect(gen.getAttributeHandler(' LABEL ')!.name, equals('label'));

        expect(gen.getAttribute<String>(comp, 'label'), equals('a'));
        expect(gen.getAttribute<String>(comp, 'nope'), isNull);

        gen.setAttribute(comp, 'label', 'b');
        expect(comp.label, equals('b'));

        gen.setAttribute(comp, 'tags', 't1');
        gen.appendAttribute(comp, 'tags', '+t2');
        expect(comp.tags, equals('t1+t2'));

        // Unknown attributes are ignored:
        gen.setAttribute(comp, 'nope', 'x');
        gen.appendAttribute(comp, 'nope', 'x');
        gen.clearAttribute(comp, 'nope');

        // Routed through the component:
        expect(comp.getAttribute('label'), equals('b'));
        expect(comp.setAttribute('label', 'c'), isTrue);
        expect(comp.label, equals('c'));
      });

      // Regression: `clearAttribute` called `set(c, null)`, ignoring the
      // handler's `cleaner`.
      test('clearAttribute uses the handler cleaner', () {
        var comp = _GenComp(null, label: 'a');
        _GenComp.generator.clearAttribute(comp, 'label');
        expect(comp.label, equals('CLEARED'));
      });

      test('isGeneratedElement', () {
        var gen = _GenComp.generator;
        var comp = _GenComp(context.uiRoot.content);
        comp.ensureRendered();

        // Regression: it printed debug lines on every call.
        late bool generated;
        var prints = _capturePrints(
          () => generated = gen.isGeneratedElement(comp.content!),
        );
        expect(generated, isTrue);
        expect(prints, isEmpty);

        expect(
          gen.isGeneratedElement(HTMLDivElement()..className = 'other'),
          isFalse,
        );
        expect(
          gen.isGeneratedElement(HTMLSpanElement()..className = 'ui-test-gen'),
          isFalse,
        );
        expect(gen.isGeneratedElement(Text('t')), isFalse);
      });

      test('revert', () {
        var gen = _GenComp.generator;

        var div = HTMLDivElement()
          ..className = 'ui-component ui-test-gen extra'
          ..setAttribute('style', 'font-weight: bold')
          ..setAttribute('label', 'x');

        var dom = gen.revert(UIComponent.domGenerator, null, null, null, div)!;
        expect(dom.tag, equals('ui-test-gen'));
        expect(dom.getAttributeValue('class'), equals('extra'));
        expect(dom.getAttributeValue('style'), contains('font-weight'));
        expect(dom.getAttributeValue('label'), equals('x'));

        var dom2 = gen.revert(
          UIComponent.domGenerator,
          null,
          null,
          null,
          HTMLDivElement()..className = 'ui-test-gen',
        )!;
        expect(dom2.getAttributeValue('class'), isNull);
        expect(dom2.getAttributeValue('style'), isNull);

        var empty = gen.revert(
          UIComponent.domGenerator,
          null,
          null,
          null,
          null,
        );
        expect(empty!.tag, equals('ui-test-gen'));
      });

      test('revert without children elements keeps the text', () {
        var gen = UIComponentGenerator<_GenComp>(
          'ui-text-gen',
          'div',
          'ui-text-gen',
          '',
          (parent, attributes, contentHolder, contentNodes) => _GenComp(parent),
          [],
          hasChildrenElements: false,
        );

        expect(gen.hasChildrenElements, isFalse);
        expect(gen.usesContentHolder, isTrue);

        var div = HTMLDivElement()..textContent = 'some text';
        var dom = gen.revert(UIComponent.domGenerator, null, null, null, div)!;
        expect(dom.text, equals('some text'));

        var treeMap = UIComponent.domGenerator.createDOMTreeMap();
        var dom2 = gen.revert(
          UIComponent.domGenerator,
          treeMap,
          null,
          null,
          div,
        )!;
        expect(dom2.text, isEmpty);
      });
    });

    group('ElementGeneratorBase', () {
      test('setElementAttributes', () {
        var gen = _ElemGen();
        var div = HTMLDivElement();

        gen.setElementAttributes(div, {
          'class': DOMAttribute.from('class', 'a b')!,
          'style': DOMAttribute.from('style', 'color: red')!,
        });

        expect(div.classList.toList(), equals(['x-elem', 'a', 'b']));
        expect(div.style.color, equals('red'));

        gen.setElementAttributes(div, {
          'style': DOMAttribute.from('style', 'font-weight: bold')!,
        });

        expect(div.style.color, equals('red'));
        expect(div.style.fontWeight, equals('bold'));

        var plain = HTMLDivElement();
        gen.setElementAttributes(plain, {});
        expect(plain.classList.toList(), equals(['x-elem']));
      });
    });

    group('UIDOMGenerator', () {
      UIDOMGenerator gen() => UIComponent.domGenerator;

      test('isMappable', () {
        expect(gen().isMappable(TextNode('x')), isFalse);
        expect(gen().isMappable($div(content: 'x')), isFalse);
        expect(gen().isMappable($br()), isFalse);
        expect(gen().isMappable($div(id: 'x')), isTrue);
        expect(
          gen().isMappable($div(attributes: {'navigate': 'home'})),
          isTrue,
        );

        var clickable = $b(content: 'b');
        clickable.onClick.listen((_) {});
        expect(
          gen().isMappable(
            $div(
              content: [
                $span(content: [clickable]),
              ],
            ),
          ),
          isTrue,
        );

        // Not a `DOMElement` nor a `TextNode`:
        expect(gen().isMappable($asyncContent(loading: 'x')), isTrue);
      });

      test('context variables and intl messages', () async {
        UINavigator.navigateTo('home', parameters: {'p': '1'});
        await testUISleepUntilRoute('home', timeoutMs: 1000, expected: true);

        var variables = gen().domContext!.variables;
        expect(
          variables.keys,
          containsAll(['routes', 'menuRoutes', 'currentRoute', 'locale']),
        );

        var routes = (variables['routes'] as Function)() as List;
        expect(
          routes.map((e) => (e as Map)['route']),
          containsAll(['home', 'second']),
        );

        var menuRoutes = (variables['menuRoutes'] as Function)() as List;
        expect(menuRoutes, isNotEmpty);

        var currentRoute =
            (variables['currentRoute'] as Function)() as Map<String, dynamic>?;
        expect(currentRoute?['route'], equals('home'));
        expect(currentRoute?['parameters'], equals({'p': '1'}));

        expect((variables['locale'] as Function)(), isA<String>());

        expect(gen().resolveIntlMessage('loading'), isNotEmpty);
      });

      test('canHandleExternalElement', () {
        var comp = _GenComp(null);
        var msg = IntlMessages.package('bones_ui_generator_test').msg('k');

        expect(gen().canHandleExternalElement(comp), isTrue);
        expect(gen().canHandleExternalElement([comp, comp]), isTrue);
        expect(gen().canHandleExternalElement(msg), isTrue);
        expect(gen().canHandleExternalElement(123), isFalse);
      });

      test('addExternalElementToElement', () async {
        var host = _host(context.uiRoot);

        expect(gen().addExternalElementToElement(host, null), isNull);
        expect(gen().addExternalElementToElement(host, []), isNull);

        var c1 = _GenComp(null, label: 'c1');
        var single = gen().addExternalElementToElement(host, [c1])!;
        expect(single, hasLength(1));
        expect(single.first, _sameJS(c1.content!));
        expect(c1.content!.parentNode, _sameJS(host));

        var c2 = _GenComp(null, label: 'c2');
        var c3 = _GenComp(null, label: 'c3');
        var many = gen().addExternalElementToElement(host, [c2, c3])!;
        expect(many, hasLength(2));

        var msg = IntlMessages.package('bones_ui_generator_test').msg('k');
        var spans = gen().addExternalElementToElement(host, msg)!;
        expect((spans.single as Element).tagName.toLowerCase(), 'span');

        // Not an element: can't attach the component content.
        var c4 = _GenComp(null, label: 'c4');
        expect(gen().addExternalElementToElement(Text('t'), c4), isNull);

        await testUISleep(ms: 50);
        expect(host.textContent, contains('label: c1'));
        expect(host.textContent, contains('label: c3'));
      });

      test('toElements', () async {
        var comp = _GenComp(null, label: 'te');
        var fromComp = gen().toElements(comp)!;
        expect(fromComp.single, _sameJS(comp.content!));

        var async = UIAsyncContent.future(Future.value('async!'), 'loading');
        var fromAsync = gen().toElements(async)!;
        expect(fromAsync, hasLength(1));

        var fromHTML = gen().toElements('<b>bold</b>')!;
        expect((fromHTML.single as Element).tagName.toLowerCase(), 'b');
      });

      test('replaceChildElement re-parents components', () {
        var host = _host(context.uiRoot);
        var old = HTMLSpanElement()..textContent = 'old';
        host.appendChild(old);

        var comp = _GenComp(null, label: 'replacement');
        comp.ensureRendered();

        var ok = gen().replaceChildElement(host, old, [comp.content!]);
        expect(ok, isTrue);
        expect(old.parentNode, isNull);
        expect(comp.content!.parentNode, _sameJS(host));
      });

      // Regression: `_setParentImpl` returned without setting `_parent` when
      // the content was already a child of `parent` (the generator appends
      // first), so `parent` stayed `null`.
      test('added/replacing components record their parent', () {
        var host = _host(context.uiRoot);

        var c1 = _GenComp(null, label: 'c1');
        gen().addExternalElementToElement(host, c1);
        expect(c1.parent, _sameJS(host));

        var old = HTMLSpanElement();
        host.appendChild(old);
        var c2 = _GenComp(null, label: 'c2')..ensureRendered();
        gen().replaceChildElement(host, old, [c2.content!]);
        expect(c2.parent, _sameJS(host));
      });

      test('future elements are attached when resolved', () async {
        var host = _host(context.uiRoot);

        var completer = Completer<Object>();
        UIComponent.domGenerator.generate(
          $div(id: 'future-host', content: completer.future),
          parent: host,
        );

        expect(host.querySelector('#late'), isNull);

        completer.complete($span(id: 'late', content: 'late'));
        await testUISleep(ms: 100);

        expect(host.querySelector('#late')?.textContent, equals('late'));
      });

      test('finalizeGeneratedTree / tree styles', () {
        var host = _host(context.uiRoot);

        UIComponent.domGenerator.generate(
          $div(
            content: [
              $div(
                classes: 'div-centered-vh',
                content: [$div(content: 'centered')],
              ),
              $div(classes: 'bg-blur', content: 'blur'),
            ],
          ),
          parent: host,
        );

        var centered = host.querySelector('.div-centered-vh') as HTMLElement;
        expect(centered.style.display, equals('table'));

        UIDOMGenerator.setElementsBGBlur(host);
        UIDOMGenerator.setElementsDivCentered(host);
        expect(centered.style.display, equals('table'));
      });
    });

    group('UIComponentDOMContext / UIDOMActionExecutor', () {
      test('UIComponentDOMContext', () {
        var comp = _GenComp(null, label: 'ctx');
        var parent = UIComponent.domContext;
        var ctx = UIComponentDOMContext(comp, parent);

        expect(ctx.uiComponent, same(comp));
        expect(ctx.intlMessageResolver, same(parent.intlMessageResolver));
        expect(ctx.toString(), startsWith('UIComponentDOMContext{'));

        var orphan = UIComponentDOMContext(comp, null);
        expect(orphan.intlMessageResolver, isNull);
      });

      test('callLocale keeps the current locale', () {
        var executor = UIDOMActionExecutor();
        var target = HTMLDivElement();

        expect(executor.callLocale(target, [], null), _sameJS(target));

        var locale = UIRoot.getCurrentLocale();
        var ctx = DOMContext<Node>()
          ..variables = {
            'event': {'value': locale},
          };

        expect(executor.callLocale(target, [], ctx), _sameJS(target));
        expect(UIRoot.getCurrentLocale(), equals(locale));

        var emptyCtx = DOMContext<Node>()
          ..variables = {
            'event': {'value': '  '},
          };
        expect(executor.callLocale(target, [], emptyCtx), _sameJS(target));
      });
    });

    group('Explorer config', () {
      test('YAMLConfigDocument', () {
        var doc = YAMLConfigDocument.load('''
model: document
count: 3
ratio: 1.5
flag: true
names: [a, b]
nums: [1, 2]
bools: [true, false]
nested:
  inner:
    deep: v
''');

        expect(doc.get('model'), equals('document'));
        expect(doc.get('missing', 'def'), equals('def'));
        expect(doc.getAsString('model'), equals('document'));
        expect(doc.getAsInt('count'), equals(3));
        expect(doc.getAsNum('ratio'), equals(1.5));
        expect(doc.getAsDouble('ratio'), equals(1.5));
        expect(doc.getAsBool('flag'), isTrue);
        expect(doc.getAsStringList('names'), equals(['a', 'b']));
        expect(doc.getAsIntList('nums'), equals([1, 2]));
        expect(doc.getAsNumList('nums'), equals([1, 2]));
        expect(doc.getAsBoolList('bools'), equals([true, false]));
        expect(doc.getAsMap('nested'), isA<Map>());
        expect(doc.getAsList('names'), hasLength(2));

        expect(doc.getPath(['nested', 'inner', 'deep']), equals('v'));
        expect(doc.getPath([], 'def'), equals('def'));
        expect(doc.getPath(['missing'], 'def'), equals('def'));
        expect(doc.getPath(['model', 'x'], 'def'), equals('def'));
        expect(doc.getPath(['nested', 'none'], 'def'), equals('def'));
        expect(doc.getPathAsString(['nested', 'inner', 'deep']), 'v');
        expect(doc.getPathAsString(['missing']), isEmpty);

        expect(doc.asYamlNode(), isA<YamlMap>());
        expect(doc.asString(), contains('document'));

        var list = YAMLConfigDocument.load('- a\n- b');
        expect(list.get('x', 'def'), equals('def'));
        expect(list.asYamlNode(), isA<YamlList>());

        var scalar = YAMLConfigDocument.load('hello');
        expect(scalar.asYamlNode(), isA<YamlScalar>());
      });

      test('JSONConfigDocument', () {
        var doc = JSONConfigDocument.loadFromJSONString(
          '{"model": "query", "n": 2}',
        );
        expect(doc.get('model'), equals('query'));
        expect(doc.getAsInt('n'), equals(2));
        expect(doc.asString(), contains('"model": "query"'));

        var fromJson = JSONConfigDocument.loadFromJSON({'a': 1});
        expect(fromJson.get('a'), equals(1));

        var notMap = JSONConfigDocument([1, 2]);
        expect(notMap.get('a', 'def'), equals('def'));
      });

      test('JSONConfig', () async {
        expect(JSONConfig.fromJSON(null), isNull);

        var config = JSONConfig.fromJSON('{"model": "document"}')!;
        expect(config.isLoaded, isTrue);
        expect(config.uri, isNull);
        expect(config.uriResolved, isNull);
        expect(config.resourceContent, isNull);
        expect(config.getDocumentIfLoaded()!.get('model'), 'document');
        expect((await config.load())!.get('model'), 'document');
        expect((await config.getDocument())!.get('model'), 'document');

        // Regression: the closing `}` was missing.
        expect(config.toString(), equals('JSONConfig{uri: null}'));

        var fromMap = JSONConfig.fromJSON({'model': 'query'})!;
        expect(fromMap.getDocumentIfLoaded()!.get('model'), 'query');

        expect(config.onLoad, isNotNull);
        expect(config.hashCode, equals(0));
        expect(config == config, isTrue);
      });

      test('YAMLConfig / JSONConfig from an URI', () {
        var yaml = YAMLConfig('config.yaml');
        expect(yaml.uri.toString(), endsWith('config.yaml'));
        expect(yaml.isLoaded, isFalse);
        // Regression: the closing `}` was missing.
        expect(yaml.toString(), endsWith('config.yaml}'));
        expect(yaml.loadDocument('model: x').get('model'), equals('x'));

        var json = JSONConfig('config.json');
        expect(json.uri.toString(), endsWith('config.json'));
        expect(json.toString(), endsWith('config.json}'));
        expect(json.loadDocument('{"model": "y"}').get('model'), 'y');
        expect(json.getDocumentIfLoaded(), isNull);
      });

      test('ExplorerModel', () async {
        expect(ExplorerModel.from(null), isNull);

        var model = ExplorerModel.fromJSON({'model': ' Document '})!;
        expect(ExplorerModel.from(model), same(model));
        expect(model.uri, isNull);
        expect(model.configDocument!.get('model'), ' Document ');
        expect(model.modelType, equals('document'));
        expect((await model.load())!.get('model'), ' Document ');
        expect(await model.getConfigDocument(), isNotNull);

        var fromConfig = ExplorerModel.from(model.resourceConfig)!;
        expect(fromConfig.resourceConfig, same(model.resourceConfig));

        var fromMap = ExplorerModel.from({'model': 'query'})!;
        expect(fromMap.modelType, equals('query'));

        expect(ExplorerModel.from('x.yaml')!.resourceConfig, isA<YAMLConfig>());
        expect(ExplorerModel.from('x.json')!.resourceConfig, isA<JSONConfig>());
        expect(
          ExplorerModel.from(Uri.parse('http://h/x.json'))!.resourceConfig,
          isA<JSONConfig>(),
        );
        expect(() => ExplorerModel.fromURI('x'), throwsArgumentError);
        expect(() => ExplorerModel.fromURI('x.txt'), throwsArgumentError);

        var empty = ExplorerModel.fromJSON({'other': 1})!;
        expect(empty.modelType, isEmpty);

        var notLoaded = ExplorerModel.fromURI('not-loaded.json');
        expect(notLoaded.modelType, isEmpty);
      });
    });

    group('UIExplorer', () {
      Future<UIExplorer> render(Object model) async {
        var host = _host(context.uiRoot);
        var explorer = UIExplorer(host, model);
        await explorer.callRenderAndWait();
        await testUISleep(ms: 200);
        await explorer.callRenderAndWait();
        await testUISleep(ms: 100);
        return explorer;
      }

      test('document with content', () async {
        var explorer = await render({
          'model': 'document',
          'content': '<b id="explorer-bold">Hello</b>',
        });

        expect(explorer.renderPropertiesProvider(), contains('model'));
        var content = explorer.content!;
        expect(content.classList.contains('ui-explorer'), isTrue);
        expect(content.classList.contains('ui-explorer-document'), isTrue);
        expect(content.textContent, contains('Hello'));
      });

      test('document with markdown', () async {
        var explorer = await render({
          'model': 'document',
          'markdown': '# Title\n\nSome *text*.',
        });

        var h1 = explorer.content!.querySelector('h1');
        expect(h1?.textContent, equals('Title'));
      });

      test('document without content', () async {
        var explorer = await render({'model': 'document'});
        expect(explorer.content!.textContent!.trim(), isEmpty);
      });

      test('without a model type', () async {
        var explorer = await render({'other': 1});
        expect(
          explorer.content!.classList.toList().where(
            (c) => c.startsWith('ui-explorer-'),
          ),
          isEmpty,
        );
      });

      // Regression: `_UIExplorerQuery.getControllersProperties` cast a
      // `Map<String, String?>` to `Map<String, String>`, which always threw.
      test('query renders its inputs', () async {
        var explorer = await render({
          'model': 'query',
          'inputs': {
            'q': {'type': 'text', 'label': 'Query', 'value': 'abc'},
            'n': {'type': 'text', 'label': 'N'},
          },
          'executor': {'type': 'none'},
          'viewer': {'type': 'html'},
        });

        var content = explorer.content!;
        expect(content.classList.contains('ui-explorer-query'), isTrue);
        expect(content.querySelector('input'), isNotNull);
        expect(content.textContent, contains('Query'));
      });

      // The requests go to the test server (localhost), to a missing path.
      const missingPath = '/__bones_ui_explorer_missing__';

      test('query with an HTTP executor and a JSON viewer', () async {
        var explorer = await render({
          'model': 'query',
          'inputs': {
            'q': {'type': 'text', 'label': 'Search', 'value': 'x'},
          },
          'executor': {'type': 'http', 'path': missingPath},
          'viewer': {'type': 'json'},
        });

        var content = explorer.content!;
        expect(content.classList.contains('ui-explorer-query'), isTrue);
        expect(content.textContent, contains('Search'));

        // Changing an input refreshes the result:
        var input = content.querySelector('input') as HTMLInputElement;
        input.value = 'y';
        input.dispatchEvent(Event('change'));
        await testUISleep(ms: 200);
        expect(content.textContent, contains('Search'));
      });

      test('catalog', () async {
        UINavigator.navigateTo('home');
        await testUISleepUntilRoute('home', timeoutMs: 1000, expected: true);

        var explorer = await render({
          'model': 'catalog',
          'document': {
            'title': {'type': 'text', 'label': 'Title'},
          },
          'document_viewer': {'type': 'html'},
          'document_preview': {'type': 'html'},
          'document_storage': {'path': missingPath, 'method': 'post'},
          'document_listing': {'path': missingPath},
        });

        var content = explorer.content!;
        expect(content.classList.contains('ui-explorer-catalog'), isTrue);
        expect(content.textContent, contains('New Document:'));
        expect(content.textContent, contains('Title'));

        var error = content.querySelector('[field="send-error"]')!;
        expect(error.hasAttribute('hidden'), isTrue);

        var button = content.querySelector('.ui-button') as HTMLElement;
        button.click();
        await testUISleepUntil(
          () => !error.hasAttribute('hidden'),
          timeoutMs: 2000,
          intervalMs: 50,
        );

        expect(
          error.hasAttribute('hidden'),
          isFalse,
          reason: 'The failed storage request shows the error',
        );
      });
    });

    group('test tools: sleep', () {
      tearDown(fastUI);

      test('testUISleep', () async {
        expect(await testUISleep(ms: 5), equals(5));
        expect(await testUISleep(frames: 2), equals(32));
        expect(await testUISleep(), equals(30));

        // Regression: the `clamp` result was discarded (no minimum/maximum).
        expect(await testUISleep(ms: 0), equals(1));
        expect(await testUISleep(ms: -5), equals(1));
      });

      test('slowUI / fastUI', () async {
        slowUI(slowFactor: 2);
        expect(await testUISleep(ms: 10), equals(20));

        slowUI(slowFactor: 1);
        expect(await testUISleep(ms: 10), equals(10));

        fastUI(fastFactor: 0.5);
        expect(await testUISleep(ms: 10), equals(5));

        fastUI();
        expect(await testUISleep(ms: 10), equals(10));
      });

      test('testUISleepUntil', () async {
        expect(await testUISleepUntil(() => true), isTrue);

        var count = 0;
        var ok = await testUISleepUntil(
          () => ++count >= 3,
          timeoutMs: 1000,
          intervalMs: 10,
        );
        expect(ok, isTrue);

        var sw = Stopwatch()..start();
        var notOk = await testUISleepUntil(
          () async => false,
          timeoutMs: 100,
          intervalMs: 20,
        );
        expect(notOk, isFalse);
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(100));
      });

      // Regression: `minMs` was ignored (computed from the timeout after it
      // had elapsed, and not at all when ready).
      test('testUISleepUntil honors minMs', () async {
        var sw = Stopwatch()..start();
        expect(
          await testUISleepUntil(() => true, timeoutMs: 1000, minMs: 200),
          isTrue,
        );
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(190));

        var count = 0;
        sw = Stopwatch()..start();
        expect(
          await testUISleepUntil(
            () => ++count >= 2,
            timeoutMs: 1000,
            intervalMs: 10,
            minMs: 200,
          ),
          isTrue,
        );
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(190));

        sw = Stopwatch()..start();
        expect(
          await testUISleepUntil(
            () => false,
            timeoutMs: 50,
            intervalMs: 10,
            minMs: 50,
          ),
          isFalse,
        );
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(45));
      });

      test('isHeadlessUI / printTestToolTitle', () {
        expect(isHeadlessUI(), isA<bool>());

        var lines = _capturePrints(printTestToolTitle);
        var text = lines.join('\n');
        expect(text, contains(bonesUiTestToolTitle));
        expect(text, contains('User Agent'));

        var noAgent = _capturePrints(
          () => printTestToolTitle(showUserAgent: false),
        ).join('\n');
        expect(noAgent, isNot(contains('User Agent')));
      });

      test('SpawnHybrid', () {
        var spawn = SpawnHybrid('test/x.dart', message: 'm');
        expect(spawn.uri, equals('test/x.dart'));
        expect(spawn.toString(), 'SpawnHybrid{uri: test/x.dart, message: m}');
      });

      test('testMultipleUI', () async {
        var calls = <String>[];
        await testMultipleUI({
          'a_test.dart': () => calls.add('a'),
          'b_test.dart': () async => calls.add('b'),
          'c_test.dart': () => calls.add('c'),
        });
        expect(calls, equals(['a', 'b', 'c']));

        calls.clear();
        await testMultipleUI(
          {
            'a_test.dart': () => calls.add('a'),
            'b_test.dart': () => calls.add('b'),
            'c_test.dart': () => calls.add('c'),
          },
          shuffle: true,
          shuffleSeed: 7,
        );
        expect(calls.toSet(), equals({'a', 'b', 'c'}));

        var calls2 = <String>[];
        await testMultipleUI(
          {
            'a_test.dart': () => calls2.add('a'),
            'b_test.dart': () => calls2.add('b'),
            'c_test.dart': () => calls2.add('c'),
          },
          shuffle: true,
          shuffleSeed: 7,
        );
        expect(calls2, equals(calls), reason: 'Same seed, same order');
      });

      test('clearTestUIOutputDiv', () {
        document.body!.appendChild(HTMLDivElement()..id = 'tmp-output');
        document.body!.appendChild(HTMLDivElement()..id = 'tmp-output');
        clearTestUIOutputDiv('tmp-output');
        expect(document.querySelectorAll('#tmp-output').length, equals(0));
      });
    });

    group('test tools: routes', () {
      test('expectUIRoute / expectUIRoutes', () async {
        UINavigator.navigateTo('home');
        await testUISleepUntilRoute('home', timeoutMs: 1000, expected: true);

        expectUIRoute('home');
        expectUIRoutes(['x', 'home']);
        expect(() => expectUIRoutes([]), throwsArgumentError);
        expect(() => expectUIRoute('nope'), throwsA(isA<TestFailure>()));
      });

      test('testUISleepUntilRoute with parameters', () async {
        UINavigator.navigateTo('second', parameters: {'a': '1', 'b': 'xyz'});

        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '1', 'b': RegExp(r'^x')},
            timeoutMs: 1000,
          ),
          isTrue,
        );

        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '1'},
            partialParameters: true,
            timeoutMs: 100,
          ),
          isTrue,
        );

        // Not a full match (extra `b`):
        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '1'},
            timeoutMs: 100,
            intervalMs: 20,
          ),
          isFalse,
        );

        // `null` is optional:
        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '1', 'b': 'xyz', 'c': null},
            timeoutMs: 100,
          ),
          isTrue,
        );

        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '2', 'b': 'xyz'},
            timeoutMs: 100,
            intervalMs: 20,
          ),
          isFalse,
        );

        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': '1', 'b': RegExp('^q')},
            timeoutMs: 100,
            intervalMs: 20,
          ),
          isFalse,
        );

        expect(
          await testUISleepUntilRoute(
            'second',
            parameters: {'a': null, 'b': 'xyz'},
            timeoutMs: 100,
            intervalMs: 20,
          ),
          isFalse,
        );

        await expectLater(
          testUISleepUntilRoute(
            'home',
            timeoutMs: 100,
            intervalMs: 20,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );
      });

      test('testUISleepUntilRoutes', () async {
        expect(
          await testUISleepUntilRoutes(['home', 'second'], timeoutMs: 500),
          isTrue,
        );
        expect(() => testUISleepUntilRoutes([]), throwsArgumentError);

        await expectLater(
          testUISleepUntilRoutes(
            ['nope'],
            timeoutMs: 100,
            intervalMs: 20,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );

        UINavigator.navigateTo('home');
        await testUISleepUntilRoute('home', timeoutMs: 1000, expected: true);
      });

      test('testUISleepUntilElement', () async {
        expect(() => testUISleepUntilElement(123, 'div'), throwsArgumentError);

        expect(await testUISleepUntilElement(null, '#btn'), isTrue);
        expect(
          await testUISleepUntilElement(context.uiRoot, '#btn', timeoutMs: 500),
          isTrue,
        );
        expect(
          await testUISleepUntilElement(
            null,
            '#list li',
            mapper: (l) => l.take(2),
            validator: (l) => l.length == 2,
          ),
          isTrue,
        );
        expect(
          await testUISleepUntilElement(
            null,
            '.never-here',
            timeoutMs: 100,
            intervalMs: 20,
          ),
          isFalse,
        );

        await expectLater(
          testUISleepUntilElement(
            null,
            '.never-here',
            timeoutMs: 100,
            intervalMs: 20,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    group('UITestContext', () {
      test('state', () {
        expect(context.isInitialized, isTrue);
        expect(context.uiRoot, isA<_Root>());
        expect(context.channel, isNull);
        expect(context.errors, isEmpty);
        expect(context.hasErrors, isFalse);
        expect(context.toString(), contains('UITestContext['));

        context.setTestWindowTitle('step "one" [x] -- y');
        context.setTestWindowTitle();

        var fresh = UITestContext<_Root>('fresh');
        expect(fresh.isInitialized, isFalse);
        expect(() => fresh.uiRoot, throwsStateError);
        expect(fresh.toString(), equals('UITestContext[fresh#0]'));
        fresh.setTestWindowTitle('x');
      });
    });

    group('UITestChain: select', () {
      test('root', () {
        var root = context.root;
        root.exists();
        expect(root.element, same(context.uiRoot));
        expect(root.uiRoot, same(context.uiRoot));
        expect(root.parent, isNull);
        expect(root.isNull, isFalse);
        expect(root.isNotNull, isTrue);
        expect(() => root.parentNotNull, throwsStateError);
        expect(root.testChainRoot, same(root));
        expect(root.document.element, _sameJS(document.documentElement!));
      });

      test('select / selectTyped from an Element node', () {
        // `document` is an `Element` node: exercises the
        // `(e.asJSAny as Element)` branches.
        var doc = context.document;

        var input = doc.select('#in-text', expected: true);
        expect(input.element, isNotNull);
        expect(input.parent, same(doc));
        expect(input.parentNotNull, same(doc));

        expect(doc.select(null).element, isNull);
        expect(doc.select('#none').isNull, isTrue);
        expect(
          () => doc.select('#none', expected: true),
          throwsA(isA<TestFailure>()),
        );

        var typed = doc.selectTyped('#in-text', Web.HTMLInputElement);
        expect(typed.element!.value, equals('a'));
        expect(doc.selectTyped(null, Web.HTMLInputElement).element, isNull);
        expect(
          doc.selectTyped('#plain-div', Web.HTMLInputElement).element,
          isNull,
        );
        expect(
          () => doc.selectTyped('#none', Web.HTMLInputElement, expected: true),
          throwsA(isA<TestFailure>()),
        );

        expect(doc.selectExpected('#btn').element.id, equals('btn'));
        expect(
          doc.selectTypedExpected('#in-area', Web.HTMLTextAreaElement).element,
          isA<HTMLTextAreaElement>(),
        );
      });

      test('selectAll / selectAllTyped', () {
        var doc = context.document;

        var items = doc.selectAll('#list li', expected: true);
        expect(items.elementsLength, equals(3));
        expect(doc.selectAll(null).element, isEmpty);
        expect(
          () => doc.selectAll('.none', expected: true),
          throwsA(isA<TestFailure>()),
        );

        var typed = doc.selectAllTyped('#list li', Web.HTMLLIElement);
        expect(typed.element, hasLength(3));
        expect(doc.selectAllTyped(null, Web.HTMLLIElement).element, isEmpty);
        expect(
          () => doc.selectAllTyped('.none', Web.HTMLLIElement, expected: true),
          throwsA(isA<TestFailure>()),
        );

        // From a list of elements:
        var lists = doc.selectAll('#list');
        expect(lists.selectAll('li').element, hasLength(3));
        expect(lists.selectAll(null).element, isEmpty);
        expect(
          lists.selectAllTyped('li', Web.HTMLLIElement).element,
          hasLength(3),
        );
        expect(lists.selectAllTyped(null, Web.HTMLLIElement).element, isEmpty);
      });

      test('select from the root / a component', () {
        var root = context.root;
        expect(root.select('#btn').element, isNotNull);
        expect(
          root.selectTyped('#btn', Web.HTMLButtonElement).element,
          isNotNull,
        );
        expect(root.selectAll('#list li').element, hasLength(3));
        expect(
          root.selectAllTyped('#list li', Web.HTMLLIElement).element,
          hasLength(3),
        );

        var page = root.map((r) => r.page);
        expect(page.select('#btn').element, isNotNull);
        expect(
          page.selectTyped('#btn', Web.HTMLButtonElement).element,
          isNotNull,
        );
        expect(page.selectAll('#list li').element, hasLength(3));
        expect(
          page.selectAllTyped('#list li', Web.HTMLLIElement).element,
          hasLength(3),
        );

        // Neither an element nor a component: falls back to the `UIRoot`.
        var other = root.map((r) => 'text');
        expect(other.select('#btn').element, isNotNull);
        expect(
          other.selectTyped('#btn', Web.HTMLButtonElement).element,
          isNotNull,
        );
        expect(other.selectAll('#list li').element, hasLength(3));
        expect(
          other.selectAllTyped('#list li', Web.HTMLLIElement).element,
          hasLength(3),
        );
      });

      test('selectWhere / selectFirstWhere', () {
        var doc = context.document;
        bool isB(Element e) => e.textContent!.contains('B');

        expect(doc.selectWhere('#list li', isB).element, hasLength(1));
        expect(
          () => doc.selectWhere('#list li', (e) => false, expected: true),
          throwsA(isA<TestFailure>()),
        );
        expect(
          doc.selectWhereTyped('#list li', Web.HTMLLIElement, isB).element,
          hasLength(1),
        );
        expect(
          () => doc.selectWhereTyped(
            '#list li',
            Web.HTMLLIElement,
            (e) => false,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );

        expect(doc.selectFirstWhere('#list li', isB).element, isNotNull);
        expect(
          () => doc.selectFirstWhere('#list li', (e) => false, expected: true),
          throwsA(isA<TestFailure>()),
        );
        expect(
          doc.selectFirstWhereTyped('#list li', Web.HTMLLIElement, isB).element,
          isNotNull,
        );
        expect(
          () => doc.selectFirstWhereTyped(
            '#list li',
            Web.HTMLLIElement,
            (e) => false,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );
      });

      test('async select variants', () async {
        var doc = context.document;
        bool isB(Element e) => e.textContent!.contains('B');

        expect((await doc.selectUntil('#btn')).element.id, equals('btn'));
        expect(
          (await doc.selectUntilTyped('#btn', Web.HTMLButtonElement)).element,
          isA<HTMLButtonElement>(),
        );
        // Regression: the type check used an `isA<O>()` matcher, which
        // always matches (JS interop types are erased at runtime), so a wrong
        // element type was silently returned.
        await expectLater(
          doc.selectUntilTyped('#btn', Web.HTMLInputElement, timeoutMs: 100),
          throwsA(isA<TestFailure>()),
        );

        expect(
          (await doc.selectWhereUntil('#list li', isB)).element,
          hasLength(1),
        );
        await expectLater(
          doc.selectWhereUntil(
            '#list li',
            (e) => false,
            timeoutMs: 100,
            intervalMs: 20,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );

        expect(
          (await doc.selectWhereUntilTyped(
            '#list li',
            Web.HTMLLIElement,
            isB,
          )).element,
          hasLength(1),
        );
        await expectLater(
          doc.selectWhereUntilTyped(
            '#list li',
            Web.HTMLLIElement,
            (e) => false,
            timeoutMs: 100,
            intervalMs: 20,
            expected: true,
          ),
          throwsA(isA<TestFailure>()),
        );

        expect(
          (await doc.selectFirstWhereUntil('#list li', isB)).element.text,
          contains('B'),
        );
        expect(
          (await doc.selectFirstWhereUntilTyped(
            '#list li',
            Web.HTMLLIElement,
            isB,
          )).element,
          isA<HTMLLIElement>(),
        );
        await expectLater(
          doc.selectFirstWhereUntilTyped(
            '#list li',
            Web.HTMLLIElement,
            (e) => false,
            timeoutMs: 100,
            intervalMs: 20,
          ),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    group('UITestChain: actions', () {
      test('click / setValue / selectIndex / checkbox', () async {
        var page = context.uiRoot.page;
        var doc = context.document;

        var clicksBefore = page.clicks;
        doc.click('#btn');
        doc.select('#btn').click();
        await testUISleep(ms: 20);
        expect(page.clicks, equals(clicksBefore + 2));

        doc.setValue('typed', '#in-text');
        expect(
          (document.querySelector('#in-text') as HTMLInputElement).value,
          equals('typed'),
        );

        doc.setValue('area', '#in-area');
        expect(
          (document.querySelector('#in-area') as HTMLTextAreaElement).value,
          equals('area'),
        );

        doc.setValue('text content', '#plain-div');
        expect(
          document.querySelector('#plain-div')!.textContent,
          equals('text content'),
        );

        doc.selectIndex(2, '#in-select');
        expect(
          (document.querySelector(
            '#in-select',
          ) as HTMLSelectElement).selectedIndex,
          equals(2),
        );

        doc.checkbox(true, '#in-check');
        expect(
          (document.querySelector('#in-check') as HTMLInputElement).checked,
          isTrue,
        );
        doc.select('#in-check').checkbox(false);
        expect(
          (document.querySelector('#in-check') as HTMLInputElement).checked,
          isFalse,
        );

        // An `UIField` component:
        context.root.map((r) => r.page.field).setValue('field-value');
        expect(page.field.getFieldValue(), equals('field-value'));

        // A component click:
        context.root.map((r) => r.page.field).click();

        expect(() => doc.click('#none'), throwsA(isA<TestFailure>()));
        expect(() => doc.setValue('x', '#none'), throwsA(isA<TestFailure>()));
        expect(
          () => doc.selectIndex(1, '#in-text'),
          throwsA(isA<TestFailure>()),
        );
        expect(
          () => doc.checkbox(true, '#in-text'),
          throwsA(isA<TestFailure>()),
        );
      });

      test('Future chain actions', () async {
        var page = context.uiRoot.page;
        var clicksBefore = page.clicks;

        await context.document
            .selectUntil('#chain-page')
            .click('#btn')
            .setValue('chained', '#in-text')
            .selectIndex(1, '#in-select')
            .checkbox(true, '#in-check');

        // The `onClick` stream delivers asynchronously:
        await testUISleep(ms: 20);
        expect(page.clicks, equals(clicksBefore + 1));
        expect(
          (document.querySelector('#in-text') as HTMLInputElement).value,
          equals('chained'),
        );
        expect(
          (document.querySelector(
            '#in-select',
          ) as HTMLSelectElement).selectedIndex,
          equals(1),
        );

        var select = await context.document.selectUntilTyped(
          '#in-select',
          Web.HTMLSelectElement,
        );
        select.selectIndex(0);
        expect(select.element.selectedIndex, equals(0));

        await Future.value(select).selectIndex(2);
        expect(select.element.selectedIndex, equals(2));
      });

      test('map / call / callAsync / elementAs', () async {
        var doc = context.document;

        expect(doc.map((e) => e.tagName.toLowerCase()).element, 'html');

        var called = <String>[];
        doc.call((e) => called.add('sync'));
        await doc.callAsync((e) async => called.add('async'));
        doc.callAsync((e) => called.add('not-future'));
        expect(called, equals(['sync', 'async', 'not-future']));

        var node = doc.select('#btn');
        expect(node.elementAs<Element?>().element, isNotNull);

        var chain = context.document.selectUntil('#btn');
        expect((await chain.map((e) => e.id)).element, equals('btn'));
        expect((await chain.elementAs<Element>()).element.id, equals('btn'));
        await chain.call((e) => called.add('future-call'));
        await chain.callAsync((e) async => called.add('future-async'));
        expect(called, containsAll(['future-call', 'future-async']));
      });

      test('element text / html accessors', () async {
        var btn = context.document.select('#btn');
        expect(btn.text, equals('Click'));
        expect(btn.innerHtml, equals('Click'));
        expect(btn.outerHtml, startsWith('<button'));

        var chain = context.document.selectUntil('#btn');
        expect(await chain.text, equals('Click'));
        expect(await chain.innerHtml, equals('Click'));
        expect(await chain.outerHtml, startsWith('<button'));
      });

      test('logs', () {
        var doc = context.document;

        var lines = _capturePrints(() {
          doc.log(msg: 'info message');
          doc.log(msg: 'with prefix', prefix: '>>');
          doc.warn(msg: 'warn message');
          doc.logMapped((e) => 'mapped:${e.tagName.toLowerCase()}');
          doc.warnMapped((e) => 'warn-mapped');
          doc.logRoute();
          doc.logMessage(' debug ', [1, 2].map((e) => e * 2));
        });

        expect(lines, contains('[INFO] info message'));
        expect(lines, contains('[INFO] >> with prefix'));
        expect(lines, contains('[WARN] warn message'));
        expect(lines, contains('[INFO] mapped:html'));
        expect(lines, contains('[WARN] warn-mapped'));
        expect(
          lines.any((l) => l.startsWith('[INFO] UINavigator.currentRoute:')),
          isTrue,
        );
        // Iterables are normalized to lists:
        expect(lines, contains('[DEBUG] [2, 4]'));
      });

      test('logDocument', () {
        var doc = context.document;

        var plain = _capturePrints(() => doc.logDocument(id: 'my doc'));
        expect(plain.single, startsWith('[DOCUMENT] [my_doc]<<<<<<\n<html'));
        expect(plain.single, matches(RegExp(r'>>>>>>\d+$')));

        var gzip = _capturePrints(
          () => doc.logDocument(id: 'gz', compressed: true),
        );
        expect(gzip.single, startsWith('[DOCUMENT] [gz]<<<<<<(GZIP: '));
        expect(gzip.single, matches(RegExp(r'>>>>>>\d+$')));

        var noId = _capturePrints(doc.logDocument);
        expect(noId.single, startsWith('[DOCUMENT] [?]<<<<<<'));
      });

      test('expectations', () async {
        var doc = context.document;
        var btn = doc.select('#btn');

        btn.expect(1, equals(1));
        btn.expect(() => 2, equals(2));
        btn.expectMatch(isNotNull);
        btn.expectMapped((e) => e!.id, equals('btn'));
        await btn.expectLater(Future.value(3), completion(equals(3)));
        await btn.expectMatchLater(isNotNull);
        await btn.expectMappedLater((e) => e!.id, equals('btn'));
        btn.expectElement('#btn', root: document.documentElement);
        doc.expectElement('#list li', validator: (l) => l.length == 3);
        doc.expectElement('#list li', mapper: (l) => l.take(1).toList());

        expect(
          () => doc.expectElement('.never-here'),
          throwsA(isA<TestFailure>()),
        );
        expect(() => btn.expect(1, equals(2)), throwsA(isA<TestFailure>()));

        UINavigator.navigateTo('home');
        await testUISleepUntilRoute('home', timeoutMs: 1000, expected: true);
        doc.expectRoute('home');
        doc.expectRoutes(['home', 'second']);
      });

      test('Future chain expectations', () async {
        var chain = context.document.selectUntil('#btn');

        await chain.expect(() => 1, equals(1));
        await chain.expectMatch(isNotNull);
        await chain.expectMapped((e) => e.id, equals('btn'));
        await chain.expectLater(Future.value(1), completion(1));
        await chain.expectMatchLater(isNotNull);
        await chain.expectMappedLater((e) => (e as Element).id, equals('btn'));
        await chain.expectRoute('home');
        await chain.expectRoutes(['home']);
        await chain.expectElement('#btn', root: document.documentElement);

        await chain.log(msg: 'x');
        await chain.warn(msg: 'y');
        await chain.logMessage('info', 'z');
        await chain.logMapped((e) => e.id);
        await chain.warnMapped((e) => (e as Element).id);
        await chain.logRoute();
        await chain.logDocument(id: 'future');
      });

      test('Future chain navigation and sleeps', () async {
        var chain = Future.value(context.document);

        expect(await chain.testChainRoot, isA<UITestChainRoot<_Root>>());
        expect(await chain.parent, isNotNull);
        expect(await chain.parentNotNull, isNotNull);

        await chain.sleep(ms: 5);
        await chain.sleepUntil(() => true);
        await chain.sleepUntilRoute('home');
        await chain.sleepUntilRoutes(['home']);
        await chain.sleepUntilElement('#btn');

        var doc = context.document;
        await doc.sleep(ms: 5);
        await doc.sleepUntil(() => true);
        await doc.sleepUntilRoute('home');
        await doc.sleepUntilRoutes(['home']);
        await doc.sleepUntilElement('#btn');
      });

      test('Future chain selects', () async {
        var chain = context.document.selectUntil('#chain-page');
        bool isB(Element e) => e.textContent!.contains('B');

        expect((await chain.select('#btn')).element, isNotNull);
        expect(
          (await chain.selectTyped('#btn', Web.HTMLButtonElement)).element,
          isNotNull,
        );
        expect((await chain.selectExpected('#btn')).element.id, 'btn');
        expect(
          (await chain.selectTypedExpected(
            '#btn',
            Web.HTMLButtonElement,
          )).element,
          isA<HTMLButtonElement>(),
        );
        expect((await chain.selectAll('li')).element, hasLength(3));
        expect(
          (await chain.selectAllTyped('li', Web.HTMLLIElement)).element,
          hasLength(3),
        );
        expect((await chain.querySelectorNonTyped('#btn')).element, isNotNull);
        expect(
          (await chain.querySelectorTyped(
            '#btn',
            Web.HTMLButtonElement,
          )).element,
          isNotNull,
        );
        expect(
          (await chain.querySelectorAllNonTyped('li')).element,
          hasLength(3),
        );
        expect(
          (await chain.querySelectorAllTyped('li', Web.HTMLLIElement)).element,
          hasLength(3),
        );
        expect((await chain.selectWhere('li', isB)).element, hasLength(1));
        expect(
          (await chain.selectWhereTyped('li', Web.HTMLLIElement, isB)).element,
          hasLength(1),
        );
        expect((await chain.selectFirstWhere('li', isB)).element, isNotNull);
        expect(
          (await chain.selectFirstWhereTyped(
            'li',
            Web.HTMLLIElement,
            isB,
          )).element,
          isNotNull,
        );
        expect((await chain.selectWhereUntil('li', isB)).element, hasLength(1));
        expect(
          (await chain.selectWhereUntilTyped(
            'li',
            Web.HTMLLIElement,
            isB,
          )).element,
          hasLength(1),
        );
        expect(
          (await chain.selectFirstWhereUntil('li', isB)).element,
          isNotNull,
        );
        expect(
          (await chain.selectFirstWhereUntilTyped(
            'li',
            Web.HTMLLIElement,
            isB,
          )).element,
          isNotNull,
        );
        expect((await chain.selectUntil('#btn')).element.id, 'btn');
        expect(
          (await chain.selectUntilTyped('#btn', Web.HTMLButtonElement)).element,
          isA<HTMLButtonElement>(),
        );
      });
    });

    group('UITestChain: lists', () {
      test('list accessors', () async {
        var items = context.document.selectAll('#list li');

        expect(items.elementsLength, equals(3));
        items.expectElementsLength(3);
        expect(items.elementAt(1).element.text, contains('B'));
        expect(items.first.element.text, contains('A'));
        expect(items.firstOr().element, isNotNull);
        expect(
          items.firstWhere((e) => e.textContent!.contains('C')).element.text,
          contains('C'),
        );
        expect(
          items.firstWhereOrNull((e) => e.textContent!.contains('Z')).element,
          isNull,
        );
        expect(
          items.where((e) => e.textContent!.contains('B')).element,
          hasLength(1),
        );

        var empty = context.document.selectAll('.none');
        expect(empty.firstOr().element, isNull);
        expect(() => empty.first, throwsStateError);
        expect(() => empty.elementAt(0), throwsRangeError);
        expect(() => empty.firstWhere((e) => true), throwsStateError);
        expect(
          () => items.where((e) => throw StateError('x')),
          throwsStateError,
        );
        expect(() => items.firstOr(), returnsNormally);

        var future = Future.value(items);
        expect(await future.elementsLength, equals(3));
        await future.expectElementsLength(3);
        expect((await future.elementAt(0)).element, isNotNull);
        expect((await future.first).element, isNotNull);
        expect((await future.firstOr()).element, isNotNull);
        expect((await future.firstWhere((e) => true)).element, isNotNull);
        expect((await future.firstWhereOrNull((e) => false)).element, isNull);
        expect((await future.where((e) => true)).element, hasLength(3));
      });
    });

    group('Element / component / string extensions', () {
      test('TestElementExtension', () {
        Element? none;
        var page = document.querySelector('#chain-page');

        expect(none.querySelectorNonTyped('#btn'), isNull);
        expect(page.querySelectorNonTyped(null), isNull);
        expect(page.querySelectorNonTyped(''), isNull);
        expect(page.select('#btn'), isNotNull);
        expect(none.querySelectorTyped('#btn', Web.HTMLButtonElement), isNull);
        expect(page.selectTyped('#btn', Web.HTMLButtonElement), isNotNull);
        expect(page.selectExpected('#btn').id, equals('btn'));
        expect(() => page.selectExpected('#none'), throwsA(isA<TestFailure>()));
        expect(() => none.selectExpected('#btn'), throwsA(isA<TestFailure>()));
        expect(
          page.selectTypedExpected('#btn', Web.HTMLButtonElement),
          isA<HTMLButtonElement>(),
        );
        expect(
          () => page.selectTypedExpected('#none', Web.HTMLButtonElement),
          throwsA(isA<TestFailure>()),
        );
        expect(page.selectAll('li'), hasLength(3));
        expect(none.selectAll('li'), isEmpty);
        expect(page.selectAllTyped('li', Web.HTMLLIElement), hasLength(3));
        expect(none.selectAllTyped('li', Web.HTMLLIElement), isEmpty);
      });

      test('TestFutureElementExtension', () async {
        var clicksBefore = context.uiRoot.page.clicks;
        Future<Element?> page() =>
            Future.value(document.querySelector('#chain-page'));

        await page().click('#btn');
        await testUISleep(ms: 20);
        expect(context.uiRoot.page.clicks, equals(clicksBefore + 1));

        expect(await page().select('#btn'), isNotNull);
        expect(await page().select(null), isNull);
        expect(
          await page().selectTyped('#btn', Web.HTMLButtonElement),
          isNotNull,
        );
        expect(await page().selectTyped(null, Web.HTMLButtonElement), isNull);
        expect((await page().selectExpected('#btn')).id, equals('btn'));
        expect(await page().selectAll('li'), hasLength(3));
        expect(await page().selectAll(null), isEmpty);
        expect(
          await page().selectAllTyped('li', Web.HTMLLIElement),
          hasLength(3),
        );
        expect(await page().selectAllTyped(null, Web.HTMLLIElement), isEmpty);
      });

      test('UIComponent extensions', () async {
        UIComponent? none;
        UIComponent page = context.uiRoot.page;

        expect(none.select('#btn'), isNull);
        expect(page.select(''), isNull);
        expect(page.select('#btn'), isNotNull);
        expect(none.selectTyped('#btn', Web.HTMLButtonElement), isNull);
        expect(page.selectTyped('#btn', Web.HTMLButtonElement), isNotNull);
        expect(page.selectExpected('#btn').id, equals('btn'));
        expect(() => none.selectExpected('#btn'), throwsA(isA<TestFailure>()));
        expect(
          page.selectExpectedTyped('#btn', Web.HTMLButtonElement),
          isA<HTMLButtonElement>(),
        );
        expect(
          () => page.selectExpectedTyped('#none', Web.HTMLButtonElement),
          throwsA(isA<TestFailure>()),
        );
        expect(page.selectAll('li'), hasLength(3));
        expect(none.selectAll('li'), isEmpty);
        expect(page.selectAllTyped('li', Web.HTMLLIElement), hasLength(3));
        expect(none.selectAllTyped('li', Web.HTMLLIElement), isEmpty);
        expect(page.simplify(), contains('item b'));
        expect(none.simplify(), isEmpty);

        Future<UIComponent?> fPage() => Future.value(page);
        var clicksBefore = context.uiRoot.page.clicks;
        await fPage().click('#btn');
        await testUISleep(ms: 20);
        expect(context.uiRoot.page.clicks, equals(clicksBefore + 1));
        expect(await fPage().select('#btn'), isNotNull);
        expect(
          await fPage().selectTyped('#btn', Web.HTMLButtonElement),
          isNotNull,
        );
        expect((await fPage().selectExpected('#btn')).id, equals('btn'));
        expect(
          await fPage().selectExpectedTyped('#btn', Web.HTMLButtonElement),
          isA<HTMLButtonElement>(),
        );
        expect(await fPage().selectAll('li'), hasLength(3));
        expect(
          await fPage().selectAllTyped('li', Web.HTMLLIElement),
          hasLength(3),
        );
      });

      test('simplify', () {
        expect(TestStringExtension(null).simplify(), isEmpty);
        expect(TestStringExtension(null).simplify(nullValue: 'N'), equals('N'));
        expect('  Hello   World '.simplify(), equals('hello world'));
        expect(
          '  Hello   World '.simplify(
            trim: false,
            collapseSpaces: false,
            lowerCase: false,
          ),
          equals('  Hello   World '),
        );

        var strings = [' A ', 'B  b'];
        expect(strings.simplify(), equals(['a', 'b b']));
        expect(strings.simplifyAll(), equals('a , b b'));
        expect(strings.simplifyAll(separator: '|'), equals('a|b b'));
        expect(strings.simplifyAt(1), equals('b b'));
        expect(strings.simplifyAt(5), isEmpty);
        expect(strings.simplifyFirst(), equals('a'));
        expect(strings.simplifyLast(), equals('b b'));

        Iterable<String>? noStrings;
        expect(noStrings.simplify(), isEmpty);
        expect(noStrings.simplifyAll(), isEmpty);
        expect(noStrings.simplifyAt(0), isEmpty);
        expect(noStrings.simplifyFirst(), isEmpty);
        expect(noStrings.simplifyLast(), isEmpty);

        var items = document.querySelectorAll('#list li').toElements();
        expect(items.first.simplify(), equals('item a'));
        expect(items.simplify(), equals(['item a', 'item b', 'item c']));
        expect(items.simplifyAll(), equals('item a , item b , item c'));
        expect(items.simplifyAt(2), equals('item c'));
        expect(items.simplifyAt(9), isEmpty);
        expect(items.simplifyFirst(), equals('item a'));
        expect(items.simplifyLast(), equals('item c'));

        Node? noNode;
        expect(noNode.simplify(), isEmpty);
        Iterable<Node>? noNodes;
        expect(noNodes.simplify(), isEmpty);
        expect(noNodes.simplifyAll(), isEmpty);
        expect(noNodes.simplifyAt(0), isEmpty);
        expect(noNodes.simplifyFirst(), isEmpty);
        expect(noNodes.simplifyLast(), isEmpty);

        var lists = document.querySelectorAll('#list').toElements();
        expect(lists.selectAll('li'), hasLength(3));
        expect(lists.selectAll(null), isEmpty);
      });

      test('TestFutureExtension', () async {
        await Future.value(1).expect(() => 1, equals(1));
        await Future.value(2).expectMatch(equals(2));
        await Future.value(3).expectMapped((v) => v * 2, equals(6));
        await Future.value(4).expectLater(Future.value(4), completion(4));
        await Future.value(5).expectMatchLater(equals(5));
        await Future.value(6)
            .expectMappedLater((v) => Future.value(v), completion(6));
        expect(await Future.value(7).thenChain((v) => v + 1), equals(8));

        await expectLater(
          Future.value(1).expectMatch(equals(2)),
          throwsA(isA<TestFailure>()),
        );
      });
    });

    // Last: `callRenderAndWait` doesn't clear the previous render, so
    // re-rendering appends the page content again.
    group('UITestChain: renders', () {
      test('renderAndWait / renderTestUI', () async {
        var doc = context.document;
        await Future.value(doc).renderAndWait();
        await doc.renderAndWait();
        await doc.renderTestUI(ms: 5);
        await context.root.renderTestUI(ms: 5);
        await context.root.map((r) => r.page).renderTestUI(ms: 5);
        expect(await context.uiRoot.page.renderTestUI(ms: 5), equals(5));
        expect(document.querySelector('#btn'), isNotNull);
      });
    });
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'generator-explorer-root');

  late final _Page page = _Page(content);

  @override
  UIComponent? renderContent() => page;
}

class _Page extends UIComponent {
  int clicks = 0;

  late final _FieldComp field = _FieldComp(content);

  late final _Nav nav = _Nav(content);

  _Page(super.parent) : super(id: 'page-component');

  @override
  dynamic render() {
    var button = $button(id: 'btn', content: 'Click');
    button.onClick.listen((_) => clicks++);

    return [
      $div(
        id: 'chain-page',
        content: [
          $input(id: 'in-text', type: 'text', value: 'a'),
          $checkbox(id: 'in-check'),
          $textarea(id: 'in-area'),
          $select(id: 'in-select', options: ['x', 'y', 'z']),
          $div(id: 'plain-div', content: 'plain'),
          button,
          $ul(
            id: 'list',
            content: [
              $li(classes: 'item', content: ' Item  A '),
              $li(classes: 'item', content: 'Item B'),
              $li(classes: 'item', content: 'Item C'),
            ],
          ),
        ],
      ),
      field,
      nav,
    ];
  }
}

class _FieldComp extends UIComponent implements UIField<String> {
  String? _value;

  _FieldComp(super.parent) : super(id: 'field-comp');

  @override
  String get fieldName => 'field';

  @override
  String? getFieldValue() => _value;

  @override
  void setFieldValue(String? value) => _value = value;

  @override
  dynamic render() => $input(id: 'field-input', type: 'text');
}

class _Nav extends UINavigableComponent {
  _Nav(Object? parent) : super(parent, ['home', 'second']);

  @override
  String? getRouteName(String route) => route.toUpperCase();

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) =>
      '<div class="route-content">route: $route</div>';
}

class _GenComp extends UIComponent {
  static final UIComponentGenerator<_GenComp> generator =
      UIComponentGenerator<_GenComp>(
        'ui-test-gen',
        'div',
        'ui-test-gen',
        'color: red',
        (parent, attributes, contentHolder, contentNodes) =>
            _GenComp(parent, label: attributes['label']?.value),
        [
          UIComponentAttributeHandler<_GenComp, String>(
            'label',
            parser: parseString,
            getter: (c) => c.label,
            setter: (c, v) => c.label = v,
            cleaner: (c) => c.label = 'CLEARED',
          ),
          UIComponentAttributeHandler<_GenComp, String>(
            'tags',
            getter: (c) => c.tags,
            setter: (c, v) => c.tags = v,
            appender: (c, v) => c.tags = '${c.tags ?? ''}${v ?? ''}',
          ),
        ],
      );

  String? label;

  String? tags;

  _GenComp(super.parent, {this.label})
    : super(componentClass: 'ui-test-gen', inline: false, generator: generator);

  @override
  dynamic render() => 'label: $label';
}

class _ElemGen extends ElementGeneratorBase {
  @override
  String get tag => 'x-elem';

  @override
  Node generate(
    DOMGenerator<Node> domGenerator,
    DOMTreeMap<Node> treeMap,
    String? tag,
    DOMElement? domParent,
    Node? parent,
    DOMNode domNode,
    Map<String, DOMAttribute> attributes,
    Node? contentHolder,
    List<DOMNode>? contentNodes,
    DOMContext<Node>? context,
  ) => HTMLDivElement();

  @override
  DOMElement? revert(
    DOMGenerator<Node> domGenerator,
    DOMTreeMap<Node>? treeMap,
    DOMElement? domParent,
    Node? parent,
    Node? node,
  ) => null;
}
