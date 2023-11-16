import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:html' as dart_html;
import 'dart:html';
import 'dart:js' as js;
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart' as pkg_test;
import 'package:test/test.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart' as pkg_test_invoker;

import 'bones_ui.dart';
import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_extension.dart';
import 'bones_ui_navigator.dart';
import 'bones_ui_root.dart';

const bonesUiTestToolTitle = 'Bones_UI/${BonesUI.version} - Test';

/// Prints the Bones_UI Test Tool title.
/// Used by [initializeTestUIRoot].
void printTestToolTitle({
  bool showUserAgent = true,
}) {
  var userAgent = window.navigator.userAgent;

  var lines = [
    bonesUiTestToolTitle,
    if (showUserAgent) '» User Agent: $userAgent',
    if (isHeadlessUI()) '» Headless',
  ];

  print(
      '╔═════════════════════════════════════════════════════════════════════\n'
      '${lines.map((l) => '║ $l\n').join()}'
      '╚═════════════════════════════════════════════════════════════════════');
}

/// Returns `true` if the browser is running on `headless` mode.
bool isHeadlessUI() {
  var userAgent = window.navigator.userAgent;

  if (userAgent.toLowerCase().contains('headless')) return true;

  return false;
}

/// Initializes the test [UIRoot] using the [uiRootInstantiator] to instantiate it.
Future<U> initializeTestUIRoot<U extends UIRoot>(
        U Function(Element rootContainer) uiRootInstantiator,
        {String outputDivID = 'test-output',
        Duration initialRenderTimeout = const Duration(seconds: 5)}) =>
    _chainCapture(() => _initializeTestUIRootImpl<U>(
        uiRootInstantiator, outputDivID, initialRenderTimeout));

Future<U> _initializeTestUIRootImpl<U extends UIRoot>(
    U Function(Element rootContainer) uiRootInstantiator,
    String outputDivID,
    Duration initialRenderTimeout) async {
  printTestToolTitle();

  if (!isHeadlessUI()) {
    slowUI();
  }

  print('** Starting test `UIRoot`...');

  clearTestUIOutputDiv(outputDivID);

  document.body!.appendHtml('<div id="$outputDivID"></div>');

  var output = querySelector('#$outputDivID');
  output!.children.clear();

  // Reset the URL route/fragment.
  // Usually the browser test plugin adds some parameters in the URL fragment.
  {
    var locationHref = window.location.href;
    var locationUrl = Uri.parse(locationHref);
    var fragment = locationUrl.fragment;

    if (fragment.isNotEmpty) {
      var locationUrlReset = fragment.isNotEmpty
          ? locationUrl.removeFragment().toString()
          : locationHref;

      window.history.pushState({}, 'Test UIRoot: init', locationUrlReset);

      print('-- Removed URL fragment> ${Uri.decodeFull(fragment)}');
    }
  }

  var uiRoot = uiRootInstantiator(output);
  print('-- Instantiated: $uiRoot');

  uiRoot.content!.classes.add('__bones_ui_test__');

  uiRoot.initialize();

  var ready = await uiRoot.isReady();
  expect(ready, anyOf(isTrue, isNull),
      reason: "`UIRoot` should be ready: $uiRoot");

  print('-- Ready: $uiRoot');

  UINavigator.navigateTo('');

  print('-- Calling initial render...');
  await uiRoot.callRenderAndWait(timeout: initialRenderTimeout);

  print('-- Initialized: $uiRoot');

  return uiRoot;
}

/// Clears the DIV with the ID ([outputDivID]).
/// Used by [initializeTestUIRoot].
/// See [testUI].
void clearTestUIOutputDiv(String outputDivID) {
  var prevOutputs = querySelectorAll('#$outputDivID');
  for (var e in prevOutputs) {
    e.remove();
  }
}

/// Expects [route] at [UINavigator.currentRoute].
void expectUIRoute(String route, {String? reason, skip}) =>
    expect(UINavigator.currentRoute, equals(route),
        reason: reason ?? 'Expected route: `$route`', skip: skip);

/// Expects [routeName] at [UINavigator.currentRoute].
void expectUIRoutes(List<String> routes, {String? reason, skip}) {
  if (routes.isEmpty) {
    throw ArgumentError("Empty `routes`");
  }

  var currentRoute = UINavigator.currentRoute ?? '';

  expect(routes.contains(currentRoute), isTrue,
      reason: reason ?? 'Expected one of routes: $routes', skip: skip);
}

double _speedFactor = 1;

/// Test UI sleep.
Future<int> testUISleep({int? frames, int? ms}) =>
    _testUISleepImpl(frames: frames, ms: ms);

/// Unsafe version of [testUISleep].
@Deprecated("Do not use this in production code!")
Future<int> testUISleepUnsafe({int? frames, int? ms}) =>
    _testUISleepImpl(frames: frames, ms: ms, maxMs: 9999999);

Future<int> _testUISleepImpl({int? frames, int? ms, int maxMs = 10000}) {
  ms = _sleepMs(ms, frames, maxMs);
  print('** Test UI Sleep: $ms ms');
  var duration = Duration(milliseconds: ms);
  return _chainCapture(() => Future.delayed(duration, () => ms!));
}

/// Test UI sleep until [ready]. Returns `bool` if [ready].
/// - [timeoutMs] is the sleep timeout is ms.
/// - [intervalMs] is the interval to check if it's [ready].
/// - [minMs] is the minimal sleep time in ms.
/// - [readyTitle] is the ready message to show in the log: `** Test UI Sleep Until $readyTitle`
Future<bool> testUISleepUntil(FutureOr<bool> Function() ready,
        {String readyTitle = 'ready',
        int? timeoutMs,
        int? intervalMs,
        int? minMs}) =>
    _chainCapture(() =>
        _testUISleepUntilImpl(ready, readyTitle, timeoutMs, intervalMs, minMs));

Future<bool> _testUISleepUntilImpl(FutureOr<bool> Function() ready,
    String readyTitle, int? timeoutMs, int? intervalMs, int? minMs) async {
  var isReady = await ready();
  if (isReady) return true;

  timeoutMs = _sleepMs(timeoutMs ?? 1000, null, 90000);

  intervalMs = intervalMs != null
      ? _sleepMs(intervalMs, null, 9999999)
      : (timeoutMs ~/ 10).clamp(1, timeoutMs);

  intervalMs = intervalMs.clamp(1, timeoutMs);

  if (minMs != null) {
    minMs = _sleepMs(minMs, null, 9999999);
    minMs = minMs.clamp(1, timeoutMs);
  }

  print('** Test UI Sleep Until $readyTitle> sleep: $timeoutMs ms '
      '(interval: $intervalMs ms${minMs != null ? ' ; min: $minMs ms' : ''})');

  var initTime = DateTime.now();

  while (true) {
    isReady = await ready();

    if (isReady) {
      var elapsedTime = DateTime.now().difference(initTime).inMilliseconds;
      print(
          '-- Test UI Sleep Until $readyTitle> READY (elapsedTime: $elapsedTime ms)');
      return true;
    }

    var elapsedTime = DateTime.now().difference(initTime).inMilliseconds;

    await Future.delayed(Duration(milliseconds: intervalMs));

    if (elapsedTime >= timeoutMs) break;
  }

  isReady = await ready();

  print(
      '-- Test UI Sleep Until $readyTitle> ${isReady ? 'READY' : 'NOT READY'}');

  if (minMs != null) {
    var elapsedTime = DateTime.now().difference(initTime).inMilliseconds;
    var remainingTime = timeoutMs - elapsedTime;

    if (remainingTime > 0) {
      print(
          '-- Test UI Sleep Until $readyTitle> minimal sleep: $minMs ms (elapsed: $elapsedTime ms ; remaining: $remainingTime ms)');

      await Future.delayed(Duration(milliseconds: remainingTime));
    }
  }

  return ready();
}

int _sleepMs(int? ms, int? frames, int maxMs) {
  ms ??= frames != null ? frames * 16 : 30;
  ms = (ms * _speedFactor).toInt();
  ms.clamp(1, maxMs);
  return ms;
}

/// Calls [testUISleepUntil] checking if [route] is the current route ([UINavigator.currentRoute]).
/// - If [parameters] is not `null` will requires a match with [UINavigator.currentRouteParameters].
///   - Accepts [RegExp] or [String] as values.
/// - If [partialParameters] is `true` will allow partial match of [parameters].
Future<bool> testUISleepUntilRoute(String route,
    {Map<String, dynamic>? parameters,
    bool partialParameters = false,
    int? timeoutMs,
    int? intervalMs,
    int? minMs,
    bool expected = false}) {
  var stackTrace = StackTrace.current;

  return testUISleepUntil(
    () {
      if (UINavigator.currentRoute == route) {
        if (parameters != null) {
          return _equalsParameters(
              parameters, UINavigator.currentRouteParameters,
              partialParameters: partialParameters);
        } else {
          return true;
        }
      } else {
        return false;
      }
    },
    readyTitle:
        'route: `$route`${parameters != null ? ' ; parameters: $parameters' : ''}',
    timeoutMs: timeoutMs ?? 2000,
    intervalMs: intervalMs ?? 100,
    minMs: minMs,
  ).thenChain((ok) {
    if (expected && !ok) {
      Error.throwWithStackTrace(
          TestFailure(
              "Expected route: `$route` ; current: `${UINavigator.currentRoute}`"),
          stackTrace);
    }
    return ok;
  });
}

/// Calls [testUISleepUntil] checking if [routes] has the current route ([UINavigator.currentRoute]).
Future<bool> testUISleepUntilRoutes(List<String> routes,
    {int? timeoutMs, int? intervalMs, int? minMs, bool expected = false}) {
  if (routes.isEmpty) {
    throw ArgumentError("Empty `routes`");
  }

  var stackTrace = StackTrace.current;

  return testUISleepUntil(
    () => routes.contains(UINavigator.currentRoute ?? ''),
    readyTitle: 'one of routes $routes',
    timeoutMs: timeoutMs ?? 2000,
    intervalMs: intervalMs ?? 100,
    minMs: minMs,
  ).thenChain((ok) {
    if (expected && !ok) {
      Error.throwWithStackTrace(
          TestFailure(
              "Expected routes: `$routes` ; current: `${UINavigator.currentRoute}`"),
          stackTrace);
    }
    return ok;
  });
}

/// Calls [testUISleepUntil] checking if [root] has an [Element] matching [selectors].
Future<bool> testUISleepUntilElement(Object? root, String selectors,
    {int? timeoutMs,
    int? intervalMs,
    int? minMs,
    Iterable<Element> Function(List<Element> elems)? mapper,
    bool Function(List<Element> elems)? validator,
    bool expected = false}) {
  root ??= document.documentElement;

  if (root is! Element && root is! UIComponent) {
    throw ArgumentError("`root` is not an `Element` or `UIComponent`");
  }

  var stackTrace = StackTrace.current;

  return testUISleepUntil(
    () => _existsElement(root, selectors, mapper, validator),
    readyTitle: 'selectors: $selectors',
    timeoutMs: timeoutMs ?? 2000,
    intervalMs: intervalMs ?? 100,
    minMs: minMs,
  ).thenChain((ok) {
    if (expected && !ok) {
      Error.throwWithStackTrace(
          TestFailure("Expected element: `$selectors` ; root: `$root`"),
          stackTrace);
    }
    return ok;
  });
}

/// Slows the UI sleep by [slowFactor].
///
/// - This will be called by [initializeTestUIRoot] if [isHeadlessUI] is `true`.
void slowUI({int slowFactor = 10}) {
  _speedFactor = slowFactor.clamp(1, 100).toDouble();
  if (_speedFactor == 1) {
    print('** Fast UI');
  } else {
    print('** Slow UI: $_speedFactor');
  }
}

/// Sets the UI to fast mode (default).
/// See [slowUI].
void fastUI({double fastFactor = 1}) {
  _speedFactor = fastFactor.clamp(0.0001, 1);
  print('** Fast UI');
}

/// Configuration passed to [testUI] to call [spawnHybridUri].
class SpawnHybrid {
  /// The URI of the Dart file to spawn.
  final String uri;

  /// The message to pass to the spawned process.
  final Object? message;

  /// Optional callback for the [StreamChannel] returned by [spawnHybridUri] spawn.
  dynamic Function(StreamChannel? channel)? callback;

  SpawnHybrid(this.uri, {this.message, this.callback});

  @override
  String toString() {
    return 'SpawnHibrid{uri: $uri, message: $message}';
  }
}

String? _testMultipleUIPath;

/// Executes multiple [testUI] in the same process/script.
/// - [testsMain] should be a [Map] containing the test path and
///   `main` entrypoint for each test.
///
/// Example:
/// ```dart
/// import 'package:bones_ui/bones_ui_test.dart';
///
/// import 'register_testui.dart' as register_testui;
/// import 'search_testui.dart' as search_testui;
/// import 'orders_testui.dart' as orders_testui;
///
/// Future<void> main() async {
///   await testMultipleUI({
///     'register_testui.dart': register_testui.main,
///     'search_testui.dart': search_testui.main,
///     'orders_testui.dart': orders_testui.main,
///   });
/// }
/// ```
Future<void> testMultipleUI(Map<String, FutureOr<void> Function()> testsMain,
    {bool shuffle = false, int? shuffleSeed}) async {
  var entries = testsMain.entries.toList();

  if (shuffle) {
    shuffleSeed ??= Random().nextInt(999999999);

    var random = Random(shuffleSeed);
    entries.shuffle(random);

    print('testMultipleUI> shuflle(shuffleSeed: $shuffleSeed)');
  }

  print('testMultipleUI> tests:');
  for (var e in testsMain.entries) {
    var testPath = e.key;
    print('  -- $testPath');
  }

  for (var e in entries) {
    var testPath = e.key;
    var main = e.value;
    _testMultipleUIPath = testPath;
    await main();
  }
}

/// Executes a group of tests using an instnatiated [UIRoot].
///
/// - [testUIName] is the name of the test group.
/// - [uiRootInstantiator] is the function that isntantiates the [UIRoot].
/// - [body] is the function that will declare the [test]s for the [UIRoot].
/// - [outputDivID] defines the ID of the `div` that will render the [UIRoot].
/// - [initialRenderTimeout] is the timeout for the initial render. See [initializeTestUIRoot].
/// - If [spawnHybrid] is provided it will spawn a VM isolate for the given [uri]. See function [spawnHybridUri].
/// - [preSetup] and [posSetup] are optinal and are called before and after the group [setUpAll].
/// - [teardown] is called after the group [tearDownAll].
/// - See [UITestContext].
///
/// **NOTE**: all the [test]s declared inside [testUI] are executed in the
/// declaration order, and if any test fails it will abort the following tests,
/// since the UI will be in an undefined state.
void testUI<U extends UIRoot>(
  String testUIName,
  U Function(Element rootContainer) uiRootInstantiator,
  void Function(UITestContext<U> context) body, {
  String outputDivID = 'test-output',
  Duration initialRenderTimeout = const Duration(seconds: 5),
  SpawnHybrid? spawnHybrid,
  dynamic Function()? preSetup,
  dynamic Function(UITestContext<U> context)? posSetup,
  dynamic Function(UITestContext<U> context)? teardown,
}) =>
    _chainCapture(() => _testUIImpl(
        testUIName,
        uiRootInstantiator,
        body,
        outputDivID,
        initialRenderTimeout,
        spawnHybrid,
        preSetup,
        posSetup,
        teardown));

int _testUIIDCount = 0;

void _testUIImpl<U extends UIRoot>(
  String testUIName,
  U Function(Element rootContainer) uiRootInstantiator,
  void Function(UITestContext<U> context) body,
  String outputDivID,
  Duration initialRenderTimeout,
  SpawnHybrid? spawnHybrid,
  dynamic Function()? preSetup,
  dynamic Function(UITestContext<U> context)? posSetup,
  dynamic Function(UITestContext<U> context)? teardown,
) async {
  final testMultipleUIPath = _testMultipleUIPath;
  final context = UITestContext<U>(testUIName, testUIId: ++_testUIIDCount);

  group(testUIName, () {
    U? uiRoot;

    setUpAll(() async {
      if (testMultipleUIPath != null) {
        print('[Bones_UI] testMultipleUI> path: $testMultipleUIPath');
      }

      clearTestUIOutputDiv(outputDivID);

      context.setTestWindowTitle('setUp');

      if (preSetup != null) {
        await preSetup();
      }

      StreamChannel? channel;

      if (spawnHybrid != null) {
        context.setTestWindowTitle('spawnHybridUri: ${spawnHybrid.uri} ...');

        context._channel = channel = pkg_test.spawnHybridUri(spawnHybrid.uri,
            message: spawnHybrid.message);

        var callback = spawnHybrid.callback;
        if (callback != null) {
          context.setTestWindowTitle('spawnHybridUri.callback ...');
          await callback(channel);
        }

        context.setTestWindowTitle('started');
      }

      context._uiRoot = uiRoot = await initializeTestUIRoot(uiRootInstantiator,
          outputDivID: outputDivID, initialRenderTimeout: initialRenderTimeout);

      if (posSetup != null) {
        await posSetup(context);
      }
    });

    tearDownAll(() async {
      context.setTestWindowTitle('tearDown');

      if (uiRoot != null) {
        uiRoot!.close();
        await testUISleep(ms: 100);
      }

      if (teardown != null) {
        teardown(context);
      }
    });

    setUp(() {
      if (context.hasErrors) {
        fail("ABORTING TEST: `testUI` with a previous error!");
      }

      var liveTest = pkg_test_invoker.Invoker.current?.liveTest;
      liveTest?.onError.listen((error) => context._errors.add(error));

      context.setTestWindowTitle(liveTest?.individualName);
    });

    body(context);

    test('close', () async {
      context.setTestWindowTitle('tearDown');

      if (uiRoot != null) {
        await uiRoot!.callRenderAndWait();
        await testUISleep(ms: 100);

        uiRoot!.close();

        expect(uiRoot!.isClosed, isTrue);

        await testUISleep(ms: 200);
      }
    });
  });
}

/// The context of a [testUI] execution.
class UITestContext<U extends UIRoot> {
  final String testUIName;

  final int testUIId;

  UITestContext(this.testUIName, {this.testUIId = 0});

  U? _uiRoot;

  /// The instantiated [UIRoot] for the test.
  U get uiRoot {
    var uiRoot = _uiRoot;
    if (uiRoot == null) {
      throw StateError("Null `uiRoot`.");
    }
    return uiRoot;
  }

  /// Returns `true` if [uiRoot] was initialized.
  bool get isInitialized => _uiRoot != null;

  StreamChannel? _channel;

  /// The [StreamChannel] if a `spawnHybridUri` is passed to [testUI].
  StreamChannel? get channel => _channel;

  UITestChainRoot<U> get root => UITestChainRoot(this);

  UITestChainNode<U, Element, UITestChainRoot<U>> get document => root.document;

  final List<Object> _errors = <Object>[];

  /// Returns the current [testUI] errors.
  UnmodifiableListView<Object> get errors => UnmodifiableListView(_errors);

  /// Returns true if the current [testUI] has errors.
  bool get hasErrors => _errors.isNotEmpty;

  /// Sets the test window title.
  void setTestWindowTitle([String? step]) {
    cleanText(String? s) =>
        s
            ?.replaceAll(RegExp(r'"+'), ' ')
            .replaceAll(RegExp(r'[\[\]]'), ' ')
            .replaceAll(RegExp(r'-+'), '_')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';

    step = cleanText(step);

    var testName = cleanText(testUIName);

    var uiName = isInitialized ? uiRoot.name : null;
    uiName = cleanText(uiName);

    var prefix = [uiName, testName]
        .whereNotNull()
        .where((e) => e.isNotEmpty)
        .join(' - ');

    var parts = [
      if (prefix.isNotEmpty) '[$prefix]',
      step,
    ];

    var title = parts.where((e) => e.isNotEmpty).join(' ');

    try {
      js.context.callMethod("eval", [
        '''
        window.top.document.title = "$title";
      '''
      ]);
    } catch (_) {}
  }

  @override
  String toString() {
    var uiRoot = _uiRoot;
    return 'UITestContext[$testUIName#$testUIId]${uiRoot != null ? '@$uiRoot' : ''}';
  }
}

abstract class UITestChain<
    U extends UIRoot,
    E,
    P extends UITestChain<U, dynamic, dynamic, dynamic>,
    T extends UITestChain<U, E, P, T>> {
  UITestContext<U> get context;

  UITestChainRoot<U> get testChainRoot;

  P? get parent;

  P get parentNotNull {
    var p = parent;
    if (p == null) {
      throw StateError("Null `parent` for: $this");
    }
    return p;
  }

  U get uiRoot;

  E get element;

  bool get isNull => element == null;

  bool get isNotNull => element != null;

  UITestChainNode<U, Element, T> get document => UITestChainNode(
      testChainRoot, dart_html.document.documentElement!, this as T);

  T exists() =>
      expect(element, pkg_test.isNotNull, reason: "Null element ($E)");

  /// Alias to [UIComponent.callRenderAndWait].
  Future<T> renderAndWait({Duration timeout = const Duration(seconds: 3)}) =>
      _chainCapture(() => _renderAndWaitImpl(timeout));

  Future<T> _renderAndWaitImpl(Duration timeout) async {
    await uiRoot.callRenderAndWait(timeout: timeout);
    return this as T;
  }

  /// Alias to [testUISleep].
  Future<T> sleep({int? frames, int? ms}) =>
      _chainCapture(() => _sleepImpl(frames, ms));

  Future<T> _sleepImpl(int? frames, int? ms) async {
    await testUISleep(frames: frames, ms: ms);
    return this as T;
  }

  /// Alias to [TestUIComponentExtension.prepareTestRendering].
  Future<T> renderTestUI({int ms = 100}) =>
      _chainCapture(() => _renderTestUIImpl(ms));

  Future<T> _renderTestUIImpl(int ms) async {
    var elem = element;

    if (elem is UIComponent) {
      await elem.renderTestUI(ms: ms);
    } else {
      await uiRoot.renderTestUI(ms: ms);
    }

    return this as T;
  }

  /// Alias to [testUISleepUntil].
  Future<T> sleepUntil(FutureOr<bool> Function() ready,
          {String readyTitle = 'ready',
          int? timeoutMs,
          int? intervalMs,
          int? minMs}) =>
      testUISleepUntil(ready,
              readyTitle: readyTitle,
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs)
          .thenChain((_) => this as T);

  /// Alias to [testUISleepUntilRoute].
  Future<T> sleepUntilRoute(String route,
          {Map<String, dynamic>? parameters,
          bool partialParameters = false,
          int? timeoutMs,
          int? intervalMs,
          int? minMs,
          bool expected = false}) =>
      testUISleepUntilRoute(route,
              parameters: parameters,
              partialParameters: partialParameters,
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs,
              expected: expected)
          .thenChain((_) => this as T);

  /// Alias to [testUISleepUntilRoutes].
  Future<T> sleepUntilRoutes(List<String> routes,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          bool expected = false}) =>
      testUISleepUntilRoutes(routes,
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs,
              expected: expected)
          .thenChain((_) => this as T);

  /// Alias to [testUISleepUntilElement].
  Future<T> sleepUntilElement(String selectors,
          {Element? root,
          int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper,
          bool Function(List<Element> elems)? validator,
          bool expected = false}) =>
      testUISleepUntilElement(root ?? element, selectors,
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs,
              mapper: mapper,
              validator: validator,
              expected: expected)
          .thenChain((_) => this as T);

  /// Alias to [Element.querySelector] or [UIComponent.querySelector].
  UITestChainNode<U, Element?, T> querySelector(String? selectors,
      {bool expected = false}) {
    var e = element;

    Element? elem;
    if (e is UIComponent) {
      elem = e.querySelector(selectors);
    } else if (e is Element) {
      elem = selectors != null ? e.querySelector(selectors) : null;
    } else {
      elem = uiRoot.querySelector(selectors);
    }

    if (expected) {
      expect(elem, pkg_test.isNotNull,
          reason: "Can't find selected element: $selectors");
    }

    return UITestChainNode(testChainRoot, elem, this as T);
  }

  /// Alias to [UIComponent.querySelectorAll].
  UITestChainNode<U, List<O>, T> querySelectorAll<O extends Element>(
      String? selectors,
      {bool expected = false}) {
    var e = element;

    List<O> elems;
    if (e is UIComponent) {
      elems = e.querySelectorAll<O>(selectors);
    } else if (e is Element) {
      elems = selectors != null ? e.querySelectorAll<O>(selectors) : <O>[];
    } else if (e is Iterable<Element>) {
      elems = selectors != null
          ? e.expand((e) => e.querySelectorAll<O>(selectors)).toList()
          : <O>[];
    } else {
      elems = uiRoot.querySelectorAll<O>(selectors);
    }

    if (expected) {
      expect(elems.isNotEmpty, isTrue,
          reason: "Can't find selected elements: $selectors");
    }

    return UITestChainNode(testChainRoot, elems, this as T);
  }

  /// Alias to [querySelector].
  UITestChainNode<U, Element?, T> select(String? selectors,
          {bool expected = false}) =>
      querySelector(selectors, expected: expected);

  /// Alias to [querySelector].
  UITestChainNode<U, Element, T> selectExpected(String? selectors) {
    var o = querySelector(selectors, expected: true);
    return UITestChainNode<U, Element, T>(
        o.testChainRoot, o.element!, o.parent);
  }

  /// Alias to [querySelectorAll].
  UITestChainNode<U, List<O>, T> selectAll<O extends Element>(String? selectors,
          {bool expected = false}) =>
      querySelectorAll<O>(selectors, expected: expected);

  /// Alias to [querySelectorAll] + `where`.
  UITestChainNode<U, List<O>, T> selectWhere<O extends Element>(
      String? selectors, bool Function(Element element) test,
      {bool expected = false}) {
    var sel = querySelectorAll(selectors);
    var elems = sel.element.whereType<O>().where(test).toList();

    if (expected) {
      expect(elems.isNotEmpty, isTrue,
          reason: "Can't find selected elements: $selectors");
    }

    return UITestChainNode(testChainRoot, elems, this as T);
  }

  /// Alias to [querySelectorAll] + `firstWhereOrNull`.
  UITestChainNode<U, O?, T> selectFirstWhere<O extends Element>(
      String? selectors, bool Function(Element element) test,
      {bool expected = false}) {
    var sel = querySelectorAll<O>(selectors);
    var elem = sel.element.whereType<O>().firstWhereOrNull(test);

    if (expected) {
      expect(elem, pkg_test.isNotNull,
          reason: "Can't find selected element: $selectors");
    }

    return UITestChainNode(testChainRoot, elem, this as T);
  }

  /// Alias to [sleepUntilElement] + [querySelectorAll] + `where`.
  Future<UITestChainNode<U, List<O>, T>> selectWhereUntil<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper,
          bool expected = false}) =>
      sleepUntilElement(selectors ?? '*',
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs,
              mapper: mapper,
              validator: (elems) => elems.any(test))
          .selectWhere<O>(selectors, test)
          .thenChain((o) {
        if (expected) {
          var sel =
              selectAll(selectors).element.map((e) => e.simplify()).toList();

          expect(o.element, pkg_test.isNotEmpty,
              reason: "Can't find any selected element: $selectors -> $sel");
        }
        return o as UITestChainNode<U, List<O>, T>;
      });

  /// Alias to [sleepUntilElement] + [querySelectorAll] + `firstWhereOrNull`.
  Future<UITestChainNode<U, O, T>> selectFirstWhereUntil<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper}) =>
      sleepUntilElement(selectors ?? '*',
              timeoutMs: timeoutMs,
              intervalMs: intervalMs,
              minMs: minMs,
              mapper: mapper,
              validator: (elems) => elems.any(test))
          .selectFirstWhere<O>(selectors, test)
          .thenChain((o) {
        var elem = o.element;
        if (elem == null) {
          var sel =
              selectAll(selectors).element.map((e) => e.simplify()).toList();

          expect(elem, pkg_test.isNotNull,
              reason: "Can't find selected element: $selectors -> $sel");
        }
        return UITestChainNode<U, O, T>(
            o.testChainRoot as UITestChainRoot<U>, elem!, this as T);
      });

  UITestChainNode<U, O, T> map<O>(O Function(E e) mapper) =>
      UITestChainNode(testChainRoot, mapper(element), this as T);

  T call(void Function(E e) call) {
    call(element);
    return this as T;
  }

  FutureOr<T> callAsync(dynamic Function(E e) call) {
    var ret = call(element);
    if (ret is Future) {
      return ret.thenChain((_) => this as T);
    } else {
      return this as T;
    }
  }

  T logMessage(String level, Object? message, {Object? prefix}) {
    level = level.trim().toUpperCase();
    message = _normalizeElement(message);

    if (prefix != null) {
      print('[$level] $prefix $message');
    } else {
      print('[$level] $message');
    }

    return this as T;
  }

  T log({Object? msg, String? prefix}) {
    logMessage('INFO', msg ?? element, prefix: prefix);
    return this as T;
  }

  T warn({Object? msg, String? prefix}) {
    logMessage('WARN', msg ?? element, prefix: prefix);
    return this as T;
  }

  T logMapped<R>(R Function(E e) mapper, {String? prefix}) {
    var o = mapper(element);
    log(msg: o, prefix: prefix);
    return this as T;
  }

  T logRoute({String? prefix}) {
    log(
        msg: 'UINavigator.currentRoute: ${UINavigator.currentRoute}',
        prefix: prefix);
    return this as T;
  }

  T logDocument({String? id, bool compressed = false}) {
    id ??= '?';

    id = id
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s'), '_');

    var outerHtml = context.document.element.outerHtml ?? '';
    var timeMs = DateTime.now().millisecondsSinceEpoch;

    String? msg;

    if (compressed && outerHtml.length > 100) {
      var bytes = dart_convert.utf8.encode(outerHtml);

      var gZipEncoder = GZipEncoder();
      var compressed = gZipEncoder.encode(bytes);

      if (compressed != null) {
        var base64 = dart_convert.base64.encode(compressed);
        msg =
            '[$id]<<<<<<(GZIP: ${compressed.length}/${bytes.length})\n$base64\n>>>>>>$timeMs';
      }
    }

    msg ??= '[$id]<<<<<<\n$outerHtml\n>>>>>>$timeMs';

    logMessage('DOCUMENT', msg);

    return this as T;
  }

  T warnMapped<R>(R Function(E e) mapper, {String? prefix}) {
    var o = mapper(element);
    warn(msg: o, prefix: prefix);
    return this as T;
  }

  T expect(dynamic actual, dynamic matcher, {String? reason}) {
    _expect(actual, matcher, reason: reason);
    return this as T;
  }

  T expectMatch(dynamic matcher, {String? reason}) {
    _expect(element, matcher, reason: reason);
    return this as T;
  }

  T expectMapped<R>(R Function(E e) mapper, dynamic matcher, {String? reason}) {
    _expect(mapper(element), matcher, reason: reason);
    return this as T;
  }

  Future<T> expectLater(dynamic actual, dynamic matcher, {String? reason}) {
    return pkg_test
        .expectLater(actual, matcher, reason: reason)
        .thenChain((_) => this as T);
  }

  Future<T> expectMatchLater(dynamic matcher, {String? reason}) {
    return pkg_test
        .expectLater(element, matcher, reason: reason)
        .thenChain((_) => this as T);
  }

  Future<T> expectMappedLater<R>(R Function(E e) mapper, dynamic matcher,
      {String? reason}) {
    return pkg_test
        .expectLater(mapper(element), matcher, reason: reason)
        .thenChain((_) => this as T);
  }

  T expectRoute(String route, {String? reason}) {
    expectUIRoute(route, reason: reason);
    return this as T;
  }

  T expectRoutes(List<String> routes, {String? reason}) {
    expectUIRoutes(routes, reason: reason);
    return this as T;
  }

  T expectElement(String selectors,
      {Object? root,
      String? reason,
      List<Element> Function(List<Element> elems)? mapper,
      bool Function(List<Element> elems)? validator}) {
    root ??= element;
    expect(_existsElement(root, selectors, mapper, validator), isTrue,
        reason: reason ?? "Can't find element: `$selectors` >> root: $root");
    return this as T;
  }

  T click([String? selectors]) {
    _click(this, element, selectors: selectors);
    return this as T;
  }

  T setValue(String? value, [String? selectors]) {
    _setValue(this, element, value, selectors: selectors);
    return this as T;
  }

  T selectIndex(int index, [String? selectors]) {
    _selectIndex(this, element, index, selectors: selectors);
    return this as T;
  }

  T checkbox(bool check, [String? selectors]) {
    _checkbox(this, element, check, selectors: selectors);
    return this as T;
  }
}

class UITestChainRoot<U extends UIRoot> extends UITestChain<U, U,
    UITestChain<U, dynamic, dynamic, dynamic>, UITestChainRoot<U>> {
  @override
  final UITestContext<U> context;

  UITestChainRoot(this.context);

  @override
  UITestChainRoot<U> get testChainRoot => this;

  @override
  U get uiRoot => context.uiRoot;

  @override
  U get element => uiRoot;

  @override
  UITestChain<U, dynamic, dynamic, dynamic>? get parent => null;

  @override
  UITestChainRoot<U> exists() =>
      this.expect(context.isInitialized, isTrue, reason: "Null `uiRoot` ($U)");
}

class UITestChainNode<U extends UIRoot, E,
        P extends UITestChain<U, dynamic, dynamic, dynamic>>
    extends UITestChain<U, E, P, UITestChainNode<U, E, P>> {
  @override
  final UITestChainRoot<U> testChainRoot;

  @override
  final P parent;

  @override
  final E element;

  UITestChainNode(this.testChainRoot, E element, this.parent)
      : element = _normalizeElement<E>(element);

  @override
  U get uiRoot => testChainRoot.uiRoot;

  @override
  UITestContext<U> get context => testChainRoot.context;

  UITestChainNode<U, O, P> elementAs<O>() =>
      UITestChainNode(testChainRoot, element as O, parent);
}

extension UITestChainElementExtension<
    U extends UIRoot,
    E extends Element?,
    O,
    P extends UITestChain<U, O, dynamic, dynamic>,
    T extends UITestChain<U, E, P, T>> on T {
  String? get text => element?.text;

  String? get innerHtml => element?.innerHtml;

  String? get outerHtml => element?.outerHtml;
}

extension UITestChainSelectElementExtension<
    U extends UIRoot,
    E extends SelectElement?,
    O,
    P extends UITestChain<U, O, dynamic, dynamic>,
    T extends UITestChain<U, E, P, T>> on T {
  T selectIndex(int index) {
    element?.selectIndex(index);
    return this;
  }
}

extension UITestChainListExtension<
        U extends UIRoot,
        E,
        O,
        P extends UITestChain<U, O, dynamic, dynamic>,
        T extends UITestChain<U, Iterable<E>?, P, T>>
    on UITestChain<U, Iterable<E>?, P, T> {
  int get elementsLength => element?.length ?? 0;

  T expectElementsLength(int expectedLength) =>
      expectMapped((e) => e?.length, equals(expectedLength));

  UITestChainNode<U, E, T> elementAt(int index) {
    var elems = element ?? <E>[];
    try {
      var e = elems.elementAt(index);
      return UITestChainNode<U, E, T>(testChainRoot, e, this as T);
    } catch (e) {
      print('[ERROR] elementAt> $elems > $test');
      rethrow;
    }
  }

  UITestChainNode<U, E, T> get first {
    var elems = element ?? <E>[];
    try {
      var e = elems.first;
      return UITestChainNode<U, E, T>(testChainRoot, e, this as T);
    } catch (e) {
      print('[ERROR] first> $elems > $test');
      rethrow;
    }
  }

  UITestChainNode<U, E?, T> firstOr([E? defaultElement]) {
    var elems = element ?? <E>[];
    try {
      var e = elems.firstOrNull ?? defaultElement;
      return UITestChainNode<U, E?, T>(testChainRoot, e, this as T);
    } catch (e) {
      print('[ERROR] firstOr> $elems > $test');
      rethrow;
    }
  }

  UITestChainNode<U, E, T> firstWhere(bool Function(E element) test,
      {E Function()? orElse}) {
    var elems = element ?? <E>[];
    try {
      var e = elems.firstWhere(test, orElse: orElse);
      return UITestChainNode<U, E, T>(testChainRoot, e, this as T);
    } catch (e) {
      print('[ERROR] firstWhere> $elems > $test');
      rethrow;
    }
  }

  UITestChainNode<U, E?, T> firstWhereOrNull(bool Function(E element) test) {
    var elems = element ?? <E>[];
    var e = elems.firstWhereOrNull(test);
    return UITestChainNode<U, E?, T>(testChainRoot, e, this as T);
  }

  UITestChainNode<U, List<E>, T> where(bool Function(E element) test) {
    var elems = element ?? <E>[];
    try {
      var e = elems.where(test).toList();
      return UITestChainNode<U, List<E>, T>(testChainRoot, e, this as T);
    } catch (e) {
      print('[ERROR] where> $elems > $test');
      rethrow;
    }
  }
}

extension FutureUITestChainListExtension<
        U extends UIRoot,
        E,
        O,
        P extends UITestChain<U, O, dynamic, dynamic>,
        T extends UITestChain<U, Iterable<E>?, P, T>>
    on Future<UITestChain<U, Iterable<E>?, P, T>> {
  Future<int> get elementsLength => then((o) => o.elementsLength);

  Future<T> expectElementsLength(int expectedLength) =>
      thenChain((o) => o.expectElementsLength(expectedLength));

  Future<UITestChainNode<U, E, T>> elementAt(int index) =>
      thenChain((o) => o.elementAt(index));

  Future<UITestChainNode<U, E, T>> get first => thenChain((o) => o.first);

  Future<UITestChainNode<U, E?, T>> firstOr([E? defaultElement]) =>
      then((o) => o.firstOr(defaultElement));

  Future<UITestChainNode<U, E, T>> firstWhere(bool Function(E element) test,
          {E Function()? orElse}) =>
      thenChain((o) => o.firstWhere(test, orElse: orElse));

  Future<UITestChainNode<U, E?, T>> firstWhereOrNull(
    bool Function(E element) test,
  ) =>
      then((o) => o.firstWhereOrNull(test));

  Future<UITestChainNode<U, List<E>, T>> where(bool Function(E element) test) =>
      then((o) => o.where(test));
}

extension FutureUITestChainExtension<
    U extends UIRoot,
    E,
    O,
    P extends UITestChain<U, O, dynamic, dynamic>,
    T extends UITestChain<U, E, P, T>> on Future<T> {
  Future<UITestChainRoot<U>> get testChainRoot => then((o) => o.testChainRoot);

  Future<P?> get parent => then((o) => o.parent);

  Future<P> get parentNotNull => thenChain((o) => o.parentNotNull);

  Future<T> click([String? selectors]) => thenChain((o) {
        _click(this, o.element, selectors: selectors);
        return o;
      });

  Future<T> setValue(String? value, [String? selectors]) => thenChain((o) {
        _setValue(this, o.element, value, selectors: selectors);
        return o;
      });

  Future<T> selectIndex(int index, [String? selectors]) => thenChain((o) {
        _selectIndex(this, o.element, index, selectors: selectors);
        return o;
      });

  Future<T> checkbox(bool check, [String? selectors]) => thenChain((o) {
        _checkbox(this, o.element, check, selectors: selectors);
        return o;
      });

  Future<T> sleepUntil(FutureOr<bool> Function() ready,
          {String readyTitle = 'ready',
          int? timeoutMs,
          int? intervalMs,
          int? minMs}) =>
      then((o) => o.sleepUntil(ready,
          readyTitle: readyTitle,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs));

  Future<T> sleepUntilRoute(String route,
          {Map<String, dynamic>? parameters,
          bool partialParameters = false,
          int? timeoutMs,
          int? intervalMs,
          int? minMs,
          bool expected = false}) =>
      thenChain((o) => o.sleepUntilRoute(route,
          parameters: parameters,
          partialParameters: partialParameters,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          expected: expected));

  Future<T> sleepUntilRoutes(List<String> routes,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          bool expected = false}) =>
      thenChain((o) => o.sleepUntilRoutes(routes,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          expected: expected));

  Future<T> sleepUntilElement(String selectors,
          {Element? root,
          int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper,
          bool Function(List<Element> elems)? validator,
          bool expected = false}) =>
      thenChain((o) => o.sleepUntilElement(selectors,
          root: root,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          mapper: mapper,
          validator: validator,
          minMs: minMs,
          expected: expected));

  Future<T> renderAndWait({Duration timeout = const Duration(seconds: 3)}) =>
      then((o) => o.renderAndWait(timeout: timeout));

  Future<T> sleep({int? frames, int? ms}) =>
      then((o) => o.sleep(frames: frames, ms: ms));

  Future<UITestChainNode<U, Element?, T>> querySelector(String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.querySelector(selectors, expected: expected));

  Future<UITestChainNode<U, List<Q>, T>> querySelectorAll<Q extends Element>(
          String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.querySelectorAll<Q>(selectors, expected: expected));

  Future<UITestChainNode<U, Element?, T>> select(String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.select(selectors, expected: expected));

  Future<UITestChainNode<U, Element, T>> selectExpected(String? selectors) =>
      thenChain((o) => o.selectExpected(selectors));

  Future<UITestChainNode<U, List<Q>, T>> selectAll<Q extends Element>(
          String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.selectAll<Q>(selectors, expected: expected));

  Future<UITestChainNode<U, List<Q>, T>> selectWhere<Q extends Element>(
          String? selectors, bool Function(Element element) test,
          {bool expected = false}) =>
      thenChain((o) => o.selectWhere<Q>(selectors, test, expected: expected));

  Future<UITestChainNode<U, Q?, T>> selectFirstWhere<Q extends Element>(
          String? selectors, bool Function(Element element) test,
          {bool expected = false}) =>
      thenChain(
          (o) => o.selectFirstWhere<Q>(selectors, test, expected: expected));

  Future<UITestChainNode<U, List<Q>, T>> selectWhereUntil<Q extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper,
          bool expected = false}) =>
      thenChain((o) => o.selectWhereUntil<Q>(selectors, test,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          mapper: mapper,
          expected: expected));

  Future<UITestChainNode<U, Q, T>> selectFirstWhereUntil<Q extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper}) =>
      thenChain((o) => o.selectFirstWhereUntil<Q>(selectors, test,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          mapper: mapper));

  Future<UITestChainNode<U, R, T>> map<R>(R Function(E e) mapper) =>
      then((o) => o.map<R>(mapper));

  Future<T> call(void Function(E e) call) => then((o) => o.call(call));

  Future<T> callAsync(dynamic Function(E e) call) =>
      then((o) => o.callAsync(call));

  Future<T> logMessage(String level, Object? message) =>
      then((o) => o.logMessage(level, message));

  Future<T> log({Object? msg, String? prefix}) =>
      then((o) => o.log(msg: msg, prefix: prefix));

  Future<T> warn({Object? msg, String? prefix}) =>
      then((o) => o.warn(msg: msg, prefix: prefix));

  Future<T> logMapped<R>(R Function(E e) mapper, {String? prefix}) =>
      then((o) => o.logMapped(mapper, prefix: prefix));

  Future<T> logRoute({String? prefix}) =>
      then((o) => o.logRoute(prefix: prefix));

  Future<T> logDocument({String? id, bool compressed = false}) =>
      then((o) => o.logDocument(id: id, compressed: compressed));

  Future<T> warnMapped<R>(R Function(E e) mapper) =>
      then((o) => o.warnMapped(mapper));

  Future<T> expect(dynamic Function() actual, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => o.expect(actual, matcher, reason: reason));

  Future<T> expectMatch(dynamic matcher, {String? reason}) =>
      thenChain((o) => o.expectMatch(matcher, reason: reason));

  Future<T> expectMapped<R>(R Function(E e) mapper, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => o.expectMapped(mapper, matcher, reason: reason));

  Future<T> expectLater(dynamic actual, dynamic matcher, {String? reason}) =>
      thenChain((o) => o.expectLater(actual, matcher, reason: reason));

  Future<T> expectMatchLater(dynamic matcher, {String? reason}) =>
      thenChain((o) => o.expectMatchLater(matcher, reason: reason));

  Future<T> expectMappedLater<R>(R Function(E e) mapper, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => o.expectMappedLater<R>(mapper, matcher, reason: reason));

  Future<T> expectRoute(String route, {String? reason}) =>
      thenChain((o) => o.expectRoute(route, reason: reason));

  Future<T> expectRoutes(List<String> routes, {String? reason}) =>
      thenChain((o) => o.expectRoutes(routes, reason: reason));

  Future<T> expectElement(String selectors,
          {Object? root,
          String? reason,
          List<Element> Function(List<Element> elems)? mapper,
          bool Function(List<Element> elems)? validator}) =>
      thenChain((o) => o.expectElement(selectors,
          root: root, reason: reason, mapper: mapper, validator: validator));
}

extension FutureUITestChainNodeExtension<
    U extends UIRoot,
    E,
    P extends UITestChain<U, dynamic, dynamic, dynamic>,
    T extends UITestChainNode<U, E, P>> on Future<UITestChainNode<U, E, P>> {
  Future<P?> get parent => then((o) => o.parent);

  Future<P> get parentNotNull => thenChain((o) => o.parentNotNull);

  Future<UITestChainNode<U, O, P>> elementAs<O>() =>
      thenChain((o) => o.elementAs<O>());

  Future<UITestChainNode<U, Element?, T>> querySelector(String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.querySelector(selectors, expected: expected)
          as UITestChainNode<U, Element?, T>);

  Future<UITestChainNode<U, List<O>, T>> querySelectorAll<O extends Element>(
          String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.querySelectorAll<O>(selectors, expected: expected)
          as UITestChainNode<U, List<O>, T>);

  Future<UITestChainNode<U, Element?, T>> select(String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.select(selectors, expected: expected)
          as UITestChainNode<U, Element?, T>);

  Future<UITestChainNode<U, Element, T>> selectExpected(String? selectors) =>
      thenChain(
          (o) => o.selectExpected(selectors) as UITestChainNode<U, Element, T>);

  Future<UITestChainNode<U, List<O>, T>> selectAll<O extends Element>(
          String? selectors,
          {bool expected = false}) =>
      thenChain((o) => o.selectAll<O>(selectors, expected: expected)
          as UITestChainNode<U, List<O>, T>);

  Future<UITestChainNode<U, List<O>, T>> selectWhere<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {bool expected = false}) =>
      thenChain((o) => o.selectWhere<O>(selectors, test, expected: expected)
          as UITestChainNode<U, List<O>, T>);

  Future<UITestChainNode<U, O?, T>> selectFirstWhere<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {bool expected = false}) =>
      thenChain((o) => o.selectFirstWhere<O>(selectors, test,
          expected: expected) as UITestChainNode<U, O?, T>);

  Future<UITestChainNode<U, List<O>, T>> selectWhereUntil<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper,
          bool expected = false}) =>
      thenChain((o) => o.selectWhereUntil<O>(selectors, test,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          mapper: mapper,
          expected: expected) as UITestChainNode<U, List<O>, T>);

  Future<UITestChainNode<U, O?, T>> selectFirstWhereUntil<O extends Element>(
          String? selectors, bool Function(Element element) test,
          {int? timeoutMs,
          int? intervalMs,
          int? minMs,
          Iterable<Element> Function(List<Element> elems)? mapper}) =>
      thenChain((o) => o.selectFirstWhereUntil<O>(selectors, test,
          timeoutMs: timeoutMs,
          intervalMs: intervalMs,
          minMs: minMs,
          mapper: mapper) as UITestChainNode<U, O?, T>);

  Future<UITestChainNode<U, R, T>> map<R>(R Function(E e) mapper) =>
      then((o) => o.map<R>(mapper) as UITestChainNode<U, R, T>);

  Future<T> expectMapped<R>(R Function(E e) mapper, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => o.expectMapped(mapper, matcher, reason: reason) as T);

  Future<T> logMapped<R>(R Function(E e) mapper) =>
      then((o) => o.logMapped(mapper) as T);

  Future<T> call(void Function(E e) call) => then((o) => o.call(call) as T);

  Future<T> callAsync(dynamic Function(E e) call) => then((o) {
        var ret = o.callAsync(call);
        if (ret is Future) {
          final future = ret as Future;
          return future.thenChain((o) => o as T);
        } else {
          return ret as T;
        }
      });
}

extension FutureUITestChainNodeElementExtension<
    U extends UIRoot,
    E extends Element?,
    P extends UITestChain<U, dynamic, dynamic, dynamic>,
    T extends UITestChainNode<U, E, P>> on Future<UITestChainNode<U, E, P>> {
  Future<String?> get text => then((o) => o.element?.text);

  Future<String?> get outerHtml => then((o) => o.element?.outerHtml);

  Future<String?> get innerHtml => then((o) => o.element?.innerHtml);
}

extension FutureUITestChainNodeSelectElementExtension<
    U extends UIRoot,
    E extends SelectElement?,
    P extends UITestChain<U, dynamic, dynamic, dynamic>,
    T extends UITestChainNode<U, E, P>> on Future<UITestChainNode<U, E, P>> {
  Future<T> selectIndex(int index) => thenChain((o) {
        o.selectIndex(index);
        return o as T;
      });
}

extension TestFutureExtension<T> on Future<T> {
  Future<void> expect(dynamic Function() actual, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => _expect(actual, matcher, reason: reason));

  Future<void> expectMatch(dynamic matcher, {String? reason}) =>
      thenChain((o) => _expect(o, matcher, reason: reason));

  Future<void> expectMapped<R>(R Function(T o) mapper, dynamic matcher,
          {String? reason}) =>
      thenChain((o) => _expect(mapper(o), matcher, reason: reason));

  Future expectLater(dynamic actual, dynamic matcher, {String? reason}) =>
      thenChain((o) => pkg_test.expectLater(actual, matcher, reason: reason));

  Future expectMatchLater(dynamic matcher, {String? reason}) =>
      thenChain((o) => pkg_test.expectLater(o, matcher, reason: reason));

  Future expectMappedLater<R>(R Function(T o) mapper, dynamic matcher,
          {String? reason}) =>
      thenChain(
          (o) => pkg_test.expectLater(mapper(o), matcher, reason: reason));

  Future<R> thenChain<R>(FutureOr<R> Function(T value) onValue) =>
      _chainCapture(() => then((o) => onValue(o)));
}

extension TestElementExtension on Element? {
  Element? select(String? selectors) {
    var self = this;
    if (self == null || selectors == null || selectors.isEmpty) return null;
    return self.querySelector(selectors);
  }

  Element selectExpected(String? selectors) {
    var self = this;
    var e = selectors != null && selectors.isNotEmpty
        ? self?.querySelector(selectors)
        : null;
    if (e == null) {
      throw TestFailure("Can't find element: `$selectors`");
    }
    return e;
  }

  List<Element> selectAll<E extends Element>(String? selectors) {
    var self = this;
    if (self == null || selectors == null || selectors.isEmpty) return <E>[];
    return self.querySelectorAll<E>(selectors);
  }
}

extension TestFutureElementExtension<E extends Element> on Future<E?> {
  Future<E?> click([String? selectors]) => thenChain((elem) {
        _click(this, elem, selectors: selectors);
        return elem;
      });

  Future<Element?> select(String? selectors) =>
      thenChain((e) => e.selectExpected(selectors));

  Future<Element> selectExpected(String? selectors) =>
      thenChain((e) => e.selectExpected(selectors));

  Future<List<Element>> selectAll<T extends Element>(String? selectors) =>
      then((e) => e.selectAll<T>(selectors));
}

extension TestUIComponentNullableExtension on UIComponent? {
  Element? select(String? selectors) {
    var self = this;
    if (self == null || selectors == null || selectors.isEmpty) return null;
    return self.querySelector(selectors);
  }

  Element selectExpected(String? selectors) {
    var self = this;
    var e = selectors != null && selectors.isNotEmpty
        ? self?.querySelector(selectors)
        : null;
    if (e == null) {
      throw TestFailure("Can't find element: `$selectors`");
    }
    return e;
  }

  List<Element> selectAll<E extends Element>(String? selectors) {
    var self = this;
    if (self == null || selectors == null || selectors.isEmpty) return <E>[];
    return self.querySelectorAll<E>(selectors);
  }

  String simplify(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.content.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';
}

extension TestUIComponentExtension on UIComponent {
  Future<int> renderTestUI({int ms = 100}) =>
      _chainCapture(() => _renderTestUIImpl(ms));

  Future<int> _renderTestUIImpl(int ms) async {
    await callRenderAndWait();
    return await testUISleep(ms: ms);
  }
}

extension TestFutureUIComponentExtension<E extends UIComponent> on Future<E?> {
  Future<E?> click([String? selectors]) => thenChain((elem) {
        _click(this, elem, selectors: selectors);
        return elem;
      });

  Future<Element?> select(String? selectors) =>
      then((e) => e.select(selectors));

  Future<Element> selectExpected(String? selectors) =>
      thenChain((e) => e.selectExpected(selectors));

  Future<List<Element>> selectAll<T extends Element>(String? selectors) =>
      then((e) => e.selectAll<T>(selectors));
}

extension TestNodeExtension on Node? {
  String simplify(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.text.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';
}

extension TestIterableNodeExtension on Iterable<Node>? {
  List<String> simplify(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this
          ?.map((e) => e.simplify(
              trim: trim,
              collapseSapces: collapseSapces,
              lowerCase: lowerCase,
              nullValue: nullValue))
          .toList() ??
      <String>[];

  String simplifyAll(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = '',
          String separator = ' , '}) =>
      this
          ?.map((e) => e.simplify(
              trim: trim,
              collapseSapces: collapseSapces,
              lowerCase: lowerCase,
              nullValue: nullValue))
          .join(separator) ??
      '';

  String simplifyAt(int index,
      {bool trim = true,
      bool collapseSapces = true,
      bool lowerCase = true,
      String nullValue = ''}) {
    var self = this;
    return self != null && index < self.length
        ? self.elementAt(index).simplify(
            trim: trim,
            collapseSapces: collapseSapces,
            lowerCase: lowerCase,
            nullValue: nullValue)
        : '';
  }

  String simplifyFirst(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.firstOrNull.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';

  String simplifyLast(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.lastOrNull.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';
}

extension TestIterableElementExtension on Iterable<Element>? {
  List<Element> selectAll(String? selectors) {
    var self = this;
    return selectors != null && self != null
        ? self.expand((e) => e.querySelectorAll(selectors)).toList()
        : <Element>[];
  }
}

extension TestStringExtension on String? {
  String simplify(
      {bool trim = true,
      bool collapseSapces = true,
      bool lowerCase = true,
      String nullValue = ''}) {
    var self = this;
    if (self == null) return nullValue;

    if (collapseSapces) {
      self = self.replaceAll(RegExp(r'\s+'), ' ');
    }

    if (trim) {
      self = self.trim();
    }

    if (lowerCase) {
      self = self.toLowerCase();
    }

    return self;
  }
}

extension TestIterableStringExtension on Iterable<String>? {
  List<String> simplify(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this
          ?.map((e) => e.simplify(
              trim: trim,
              collapseSapces: collapseSapces,
              lowerCase: lowerCase,
              nullValue: nullValue))
          .toList() ??
      <String>[];

  String simplifyAll(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = '',
          String separator = ' , '}) =>
      this
          ?.map((e) => e.simplify(
              trim: trim,
              collapseSapces: collapseSapces,
              lowerCase: lowerCase,
              nullValue: nullValue))
          .join(separator) ??
      '';

  String simplifyAt(int index,
      {bool trim = true,
      bool collapseSapces = true,
      bool lowerCase = true,
      String nullValue = ''}) {
    var self = this;
    return self != null && index < self.length
        ? self.elementAt(index).simplify(
            trim: trim,
            collapseSapces: collapseSapces,
            lowerCase: lowerCase,
            nullValue: nullValue)
        : '';
  }

  String simplifyFirst(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.firstOrNull.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';

  String simplifyLast(
          {bool trim = true,
          bool collapseSapces = true,
          bool lowerCase = true,
          String nullValue = ''}) =>
      this?.lastOrNull.simplify(
          trim: trim,
          collapseSapces: collapseSapces,
          lowerCase: lowerCase,
          nullValue: nullValue) ??
      '';
}

void _expect(dynamic actual, dynamic matcher, {String? reason}) {
  if (actual is Future Function()) {
    pkg_test.expect(actual, matcher, reason: reason);
  } else if (actual is Function()) {
    var ret = actual();
    pkg_test.expect(ret, matcher, reason: reason);
  } else {
    pkg_test.expect(actual, matcher, reason: reason);
  }
}

bool _existsElement(
    Object? root,
    String selectors,
    Iterable<Element> Function(List<Element> elems)? mapper,
    bool Function(List<Element> elems)? validator) {
  List<Element> elem;
  if (root is Element) {
    elem = root.querySelectorAll(selectors);
  } else if (root is UIComponent) {
    elem = root.querySelectorAll(selectors);
  } else {
    throw StateError("`root` is not an `Element` or `UIComponent`");
  }

  if (mapper != null) {
    elem = mapper(elem).toList();
  }

  if (validator != null) {
    return validator(elem);
  } else {
    return elem.isNotEmpty;
  }
}

void _click(Object root, Object? o, {String? selectors, bool expected = true}) {
  String reason;
  if (selectors != null) {
    o = _querySelect(o, selectors);
    reason = "querySelector: `$selectors` >> $root";
  } else {
    reason = "$root";
  }

  if (o is Element) {
    o.click();
  } else if (o is UIComponent) {
    o.click();
  } else if (expected) {
    throw TestFailure("Can't click `null` element. Reason: $reason");
  }
}

void _setValue(Object root, Object? elem, String? value,
    {String? selectors, bool expected = true}) {
  String reason;
  if (selectors != null) {
    elem = _querySelect(elem, selectors);
    reason = "querySelector: `$selectors` >> $root";
  } else {
    reason = "$root";
  }

  if (elem is InputElement) {
    elem.value = value;
  } else if (elem is TextAreaElement) {
    elem.value = value;
  } else if (elem is Element) {
    elem.text = value;
  } else if (elem is UIField) {
    elem.setFieldValue(value);
  } else if (expected) {
    throw TestFailure("Can't set value on `null` element. Reason: $reason");
  }
}

void _selectIndex(Object root, Object? o, int index,
    {String? selectors, bool expected = true}) {
  String reason;
  if (selectors != null) {
    o = _querySelect(o, selectors);
    reason = "querySelector: `$selectors` >> $root";
  } else {
    reason = "$root";
  }

  if (o is SelectElement) {
    o.selectIndex(index);
  } else if (expected) {
    throw TestFailure(
        "Can't call selectIndex(i) on `null` element. Reason: $reason");
  }
}

void _checkbox(Object root, Object? o, bool checked,
    {String? selectors, bool expected = true}) {
  String reason;
  if (selectors != null) {
    o = _querySelect(o, selectors);
    reason = "querySelector: `$selectors` >> $root";
  } else {
    reason = "$root";
  }

  if (o is CheckboxInputElement) {
    o.checked = checked;
  } else if (expected) {
    throw TestFailure("Can't set `checked` on `null` element. Reason: $reason");
  }
}

Element? _querySelect(Object? elem, String selectors) {
  if (elem is Element) {
    return elem.querySelector(selectors);
  } else if (elem is UIComponent) {
    return elem.querySelector(selectors);
  } else {
    return null;
  }
}

E _normalizeElement<E>(E e) {
  if (e is Iterable && e is! List && e is! Set) {
    final e2 = e.toList();
    if (e2 is E) return e2 as E;
  }
  return e;
}

T _chainCapture<T>(T Function() callback) {
  var parentChain = Chain.current();

  // Already in a capture chain:
  if (parentChain.traces.length > 1) {
    return callback();
  }

  return Chain.capture<T>(callback,
      onError: (e, c) => _chainCaptureOnError(e, c, parentChain));
}

_chainCaptureOnError(Object e, Chain c, Chain parentChain) {
  var chainAll = Chain([...c.traces, ...parentChain.traces]);
  var chainAllTerse = chainAll.terse;
  var e2 = AsyncError(e, chainAllTerse);
  Error.throwWithStackTrace(e2, chainAllTerse);
}

bool _equalsParameters(
    Map<String, Object?> parameters, Map<String, String>? currentParameters,
    {required bool partialParameters}) {
  currentParameters ??= {};

  var keysOk = <String>[];

  for (var e in parameters.entries) {
    var key = e.key;
    var v1 = e.value;
    var v2 = currentParameters[key];

    if (v1 is RegExp) {
      if (v2 == null || !v1.hasMatch(v2)) return false;
    } else if (v1 == null) {
      if (v2 != null && v2 != '') return false;
    } else {
      if (v1 != v2) return false;
    }

    keysOk.add(key);
  }

  if (partialParameters) {
    return true;
  } else {
    var notCheckedEntries = currentParameters.entries
        .where((e) => !keysOk.contains(e.key))
        .toList();
    return notCheckedEntries.isEmpty;
  }
}
