import 'dart:html';

import 'package:test/test.dart';

import 'bones_ui.dart';
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
    Duration initialRenderTimeout = const Duration(seconds: 5)}) async {
  printTestToolTitle();

  if (!isHeadlessUI()) {
    slowUI();
  }

  print('** Starting test `UIRoot`...');

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

  uiRoot.initialize();

  var ready = await uiRoot.isReady();
  expect(ready, isTrue, reason: "`UIRoot` should be ready: $uiRoot");

  print('-- Ready: $uiRoot');

  UINavigator.navigateTo('');

  print('-- Calling initial render...');
  await uiRoot.callRenderAndWait(timeout: initialRenderTimeout);

  print('-- Initialized: $uiRoot');

  return uiRoot;
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

int _slowFactor = 1;

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
  return Future.delayed(Duration(milliseconds: ms), () => ms!);
}

/// Test UI sleep until [ready]. Returns `bool` if [ready].
/// - [timeoutMs] is the sleep timeout is ms.
/// - [intervalMs] is the interval to check if it's [ready].
/// - [minMs] is the minimal sleep time in ms.
/// - [readyTitle] is the ready message to show in the log: `** Test UI Sleep Until $readyTitle`
Future<bool> testUISleepUntil(bool Function() ready,
    {String readyTitle = 'ready',
    int? timeoutMs,
    int? intervalMs,
    int? minMs}) async {
  timeoutMs = _sleepMs(timeoutMs ?? 1000, null, 9999999);

  intervalMs = intervalMs != null
      ? _sleepMs(intervalMs, null, 9999999)
      : (timeoutMs ~/ 10).clamp(1, timeoutMs);

  intervalMs = intervalMs.clamp(1, timeoutMs);

  if (minMs != null) {
    minMs = _sleepMs(minMs, null, 9999999);
  }

  print('** Test UI Sleep Until $readyTitle> sleep: $timeoutMs ms '
      '(interval: $intervalMs ms${minMs != null ? ' ; min: $minMs ms' : ''})');

  var initTime = DateTime.now();

  while (true) {
    if (ready()) {
      var elapsedTime = DateTime.now().difference(initTime).inMilliseconds;
      print(
          '-- Test UI Sleep Until $readyTitle> READY (elapsedTime: $elapsedTime ms)');
      return true;
    }

    var elapsedTime = DateTime.now().difference(initTime).inMilliseconds;

    await Future.delayed(Duration(milliseconds: intervalMs));

    if (elapsedTime >= timeoutMs) break;
  }

  var isReady = ready();

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
  ms = ms * _slowFactor;
  ms.clamp(1, maxMs);
  return ms;
}

/// Calls [testUISleepUntil] checking if [route] is the current route ([UINavigator.currentRoute]).
Future<bool> testUISleepUntilRoute(String route,
        {int? timeoutMs, int? intervalMs, int? minMs}) =>
    testUISleepUntil(
      () => UINavigator.currentRoute == route,
      readyTitle: 'route `$route`',
      timeoutMs: timeoutMs,
      intervalMs: intervalMs,
      minMs: minMs,
    );

/// Calls [testUISleepUntil] checking if [routes] has the current route ([UINavigator.currentRoute]).
Future<bool> testUISleepUntilRoutes(List<String> routes,
    {int? timeoutMs, int? intervalMs, int? minMs}) {
  if (routes.isEmpty) {
    throw ArgumentError("Empty `routes`");
  }

  return testUISleepUntil(
    () => routes.contains(UINavigator.currentRoute ?? ''),
    readyTitle: 'one of routes $routes',
    timeoutMs: timeoutMs,
    intervalMs: intervalMs,
    minMs: minMs,
  );
}

/// Slows the UI sleep by [slowFactor].
///
/// - This will be called by [initializeTestUIRoot] if [isHeadlessUI] is `true`.
void slowUI({int slowFactor = 10}) {
  _slowFactor = slowFactor.clamp(1, 100);
  if (_slowFactor == 1) {
    print('** Fast UI');
  } else {
    print('** Slow UI: $_slowFactor');
  }
}

/// Resets the UI to fast mode (default).
/// See [slowUI].
void fastUI() {
  _slowFactor = 1;
  print('** Fast UI');
}
