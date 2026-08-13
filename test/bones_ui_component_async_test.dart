@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

void main() {
  group('UIComponentAsync', () {
    late final _AsyncRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _AsyncRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    test('renders the loading content and then the async content', () async {
      var component = UIComponentAsync(
        uiRoot.content,
        () => {'k': 'v'},
        (properties) => Future.delayed(
          Duration(milliseconds: 100),
          () => 'loaded: ${properties['k']}',
        ),
        'loading...',
        'error!',
      );

      await component.callRenderAndWait();

      expect(component.isLoaded, isFalse);
      expect(component.content!.text, contains('loading...'));

      await testUISleep(ms: 400);

      expect(component.isLoaded, isTrue);
      expect(component.isOK, isTrue);
      expect(component.isWithError, isFalse);
      expect(component.loadCount, equals(1));
      expect(component.loadTime, isNotNull);
      expect(component.content!.text, contains('loaded: v'));
      expect(component.asyncContentProperties, equals({'k': 'v'}));
    });

    test('renders the error content when the `Future` fails', () async {
      var component = UIComponentAsync(
        uiRoot.content,
        () => {},
        (properties) => Future.delayed(
          Duration(milliseconds: 50),
          () => throw StateError('boom'),
        ),
        'loading...',
        'the error content',
      );

      await component.callRenderAndWait();
      await testUISleep(ms: 400);

      expect(component.isLoaded, isTrue);
      expect(component.isOK, isFalse);
      expect(component.isWithError, isTrue);
      expect(component.content!.text, contains('the error content'));
    });

    test('a subclass provides the properties and the async render', () async {
      var component = _AsyncSubComponent(uiRoot.content);

      await component.callRenderAndWait();
      await testUISleep(ms: 300);

      expect(component.isOK, isTrue);
      expect(component.renderAsyncCount, equals(1));
      expect(component.content!.text, contains('async #1'));
    });

    test('re-renders with the same properties reuse the content', () async {
      var component = _AsyncSubComponent(uiRoot.content);

      await component.callRenderAndWait();
      await testUISleep(ms: 300);
      expect(component.renderAsyncCount, equals(1));

      component.refresh();
      await testUISleep(ms: 300);

      expect(
        component.renderAsyncCount,
        equals(1),
        reason: 'The async content should be reused for the same properties',
      );
      expect(component.asyncContentEqualsProperties({'v': 1}), isTrue);
    });

    test('changing the properties triggers a new async render', () async {
      var component = _AsyncSubComponent(uiRoot.content);

      await component.callRenderAndWait();
      await testUISleep(ms: 300);
      expect(component.renderAsyncCount, equals(1));

      component.propertyValue = 2;
      expect(component.isNotValid(), isTrue);

      component.refresh();
      await testUISleep(ms: 300);

      expect(component.renderAsyncCount, equals(2));
      expect(component.content!.text, contains('async #2'));
    });

    test('`stop` prevents further loads', () async {
      var component = _AsyncSubComponent(uiRoot.content);

      await component.callRenderAndWait();
      await testUISleep(ms: 300);

      component.stop();
      expect(component.stopped, isTrue);

      component.refreshAsyncContent();
      await testUISleep(ms: 200);

      expect(component.renderAsyncCount, equals(1));
    });

    test('`onLoadAsyncContent` is notified', () async {
      var component = _AsyncSubComponent(uiRoot.content);

      var loaded = <Object?>[];
      component.onLoadAsyncContent.listen(loaded.add);

      await component.callRenderAndWait();
      await testUISleep(ms: 400);

      expect(loaded, isNotEmpty);
    });

    test('`isValidComponentAsync` static checks', () async {
      expect(UIComponentAsync.isValidComponentAsync(null), isFalse);

      var component = _AsyncSubComponent(uiRoot.content);
      expect(
        UIComponentAsync.isValidComponentAsync(component),
        isFalse,
        reason: 'Not rendered yet: there is no async content',
      );

      await component.callRenderAndWait();
      await testUISleep(ms: 300);

      expect(UIComponentAsync.isValidComponentAsync(component, {'v': 1}), true);
      expect(
        UIComponentAsync.isValidLocaleComponentAsync(component),
        isTrue,
        reason: 'The locale did not change',
      );
    });
  });

  group('UILoadingConfig', () {
    test('parses inline properties', () {
      var config = UILoadingConfig.parse(
        'type: roller; color: #fff; zoom: 0.5',
      );

      expect(config, isNotNull);
      expect(config!.type, equals(UILoadingType.roller));
      expect(config.color, equals('#fff'));
      expect(config.zoom, equals(0.5));
    });

    test('parses the `dualRing` type', () {
      // `getUILoadingType` lower-cases the value before matching:
      expect(getUILoadingType('dualRing'), equals(UILoadingType.dualRing));
      expect(getUILoadingType('dualring'), equals(UILoadingType.dualRing));
      expect(getUILoadingType('dual-ring'), equals(UILoadingType.dualRing));
      expect(getUILoadingType(UILoadingType.ripple), UILoadingType.ripple);
      expect(getUILoadingType('nope'), isNull);
      expect(getUILoadingType(null), isNull);
    });

    test('`toInlineProperties` round-trips', () {
      var config = UILoadingConfig(
        type: UILoadingType.dualRing,
        color: '#123456',
        zoom: 0.75,
        text: 'Wait...',
        textZoom: 1.5,
        withProgress: true,
      );

      var inline = config.toInlineProperties();
      var parsed = UILoadingConfig.parse(inline);

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(UILoadingType.dualRing));
      expect(parsed.color, equals('#123456'));
      expect(parsed.zoom, equals(0.75));
      expect(parsed.text, equals('Wait...'));
      expect(
        parsed.textZoom,
        equals(1.5),
        reason: '`textZoom` should survive the round-trip',
      );
      expect(
        parsed.withProgress,
        isTrue,
        reason: '`withProgress` should survive the round-trip',
      );
    });

    test('`fromMap` accepts the attribute style keys', () {
      var config = UILoadingConfig.fromMap({
        'type': 'spinner',
        'color': '#000',
        'text-zoom': '2.0',
        'with-progress': 'true',
      });

      expect(config, isNotNull);
      expect(config!.type, equals(UILoadingType.spinner));
      expect(config.textZoom, equals(2.0));
      expect(config.withProgress, isTrue);
    });

    test('`fromMap` with a prefix', () {
      var config = UILoadingConfig.fromMap({
        'loading-type': 'ripple',
        'loading-color': '#f00',
      }, 'loading-');

      expect(config, isNotNull);
      expect(config!.type, equals(UILoadingType.ripple));
      expect(config.color, equals('#f00'));
    });

    test('returns null for an empty config', () {
      expect(UILoadingConfig.parse(null), isNull);
      expect(UILoadingConfig.parse(''), isNull);
      expect(UILoadingConfig.fromMap({}), isNull);
      expect(UILoadingConfig.from(null), isNull);
    });

    test('`from` accepts a config, a Map and a String', () {
      var config = UILoadingConfig(type: UILoadingType.blocks);

      expect(identical(UILoadingConfig.from(config), config), isTrue);
      expect(
        UILoadingConfig.from({'type': 'blocks'})?.type,
        equals(UILoadingType.blocks),
      );
      expect(
        UILoadingConfig.from('type: blocks')?.type,
        equals(UILoadingType.blocks),
      );
    });

    test('builds a `div` element', () {
      var config = UILoadingConfig(type: UILoadingType.ring, text: 'Loading');
      var div = config.asDivElement();

      expect(div.text, contains('Loading'));
      expect(div.outerHTML.toString(), contains('ui-loading'));
    });
  });
}

class _AsyncRoot extends UIRoot {
  _AsyncRoot(super.rootContainer) : super(id: 'async-root');

  @override
  UIComponent? renderContent() => null;
}

class _AsyncSubComponent extends UIComponentAsync {
  int propertyValue = 1;

  int renderAsyncCount = 0;

  _AsyncSubComponent(Object? parent)
    : super(parent, null, null, 'loading...', 'error!');

  @override
  Map<String, dynamic> renderPropertiesProvider() => {'v': propertyValue};

  @override
  Future<dynamic> renderAsync(Map<String, dynamic> properties) async {
    ++renderAsyncCount;
    await Future.delayed(Duration(milliseconds: 50));
    return 'async #${properties['v']}';
  }
}
