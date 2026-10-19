@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// `UIRoot.close` (its components disposed, their async contents stopped,
/// waited) and `UIRoot.whenIdle`. Each test has its own root (a closed root
/// stays closed).
void main() {
  /// A new root, settled (its navigation render done: it would clear the
  /// elements attached to it before).
  Future<_Root> newRoot() async {
    var uiRoot = await initializeTestUIRoot(_Root.new);
    await uiRoot.callRenderAndWait();
    await testUISleep(ms: 100);
    return uiRoot;
  }

  /// A container attached to [uiRoot].
  web.HTMLDivElement newHost(UIRoot uiRoot) {
    var host = web.HTMLDivElement();
    uiRoot.content!.append(host);
    return host;
  }

  group('UIRoot.close', () {
    test('shuts the root down before returning', () async {
      var uiRoot = await newRoot();
      var host = newHost(uiRoot);

      var autoRefresh = _AutoRefresh(host, Duration(milliseconds: 100));
      var plain = _Plain(host);
      var selection = UIMultiSelection(host, {'a': 'A', 'b': 'B'});

      await autoRefresh.callRenderAndWait();
      await plain.callRenderAndWait();
      await selection.callRenderAndWait();
      await testUISleep(ms: 450);
      expect(autoRefresh.loads, greaterThan(1), reason: 'Auto refresh');

      // The selection's options panel open (in the `body`):
      var input = selection.content!.querySelector(
        '.ui-multi-selection-input',
      ) as web.HTMLElement;
      var panel = selection.content!.querySelector(
        '.ui-multi-selection-options-menu',
      ) as web.HTMLElement;
      input.click();
      expect(panel.parentNode, equals(web.document.body));

      var closes = 0;
      String? textOnClose;
      uiRoot.onClose.listen((_) {
        closes++;
        textOnClose = uiRoot.content!.textContent;
      });

      expect(await uiRoot.close(), isTrue);

      // Already done when `close` returns:
      expect(autoRefresh.isDisposed, isTrue);
      expect(plain.isDisposed, isTrue);
      expect(selection.isDisposed, isTrue);
      expect(panel.isConnected, isFalse, reason: 'Panel hidden by dispose');
      expect(uiRoot.content!.textContent, equals('CLOSED'));

      // `onClose` (an `EventStream`) notifies its listeners asynchronously:
      await testUISleep(ms: 50);
      expect(closes, equals(1));
      expect(textOnClose, equals('CLOSED'), reason: 'After the closed render');

      // Its auto refresh stopped:
      var loadsAtClose = autoRefresh.loads;
      await testUISleep(ms: 400);
      expect(autoRefresh.loads, equals(loadsAtClose));

      expect(await uiRoot.close(), isFalse, reason: 'Already closed');
      expect(closes, equals(1));
    });

    test('a pending async content is stopped (not rendered later)', () async {
      var uiRoot = await newRoot();
      var host = newHost(uiRoot);

      var completer = Completer<String>();
      var pending = _Async(host, () => completer.future);
      await pending.callRenderAndWait();
      expect(pending.hasPendingUIAsyncContent, isTrue);

      expect(await uiRoot.close(), isTrue);
      expect(pending.isDisposed, isTrue);
      expect(pending.hasPendingUIAsyncContent, isFalse, reason: 'Stopped');
      expect(pending.isLoadingUIAsyncContent, isFalse);

      completer.complete('late');
      await testUISleep(ms: 100);
      expect(uiRoot.content!.textContent, equals('CLOSED'));
    });
  });

  group('UIRoot.whenIdle', () {
    test('idle, not while an async content loads, then idle', () async {
      var uiRoot = await newRoot();

      expect(await uiRoot.whenIdle(timeout: Duration(seconds: 2)), isTrue);

      var completer = Completer<String>();
      var pending = _Async(newHost(uiRoot), () => completer.future);
      await pending.callRenderAndWait();

      expect(
        await uiRoot.whenIdle(timeout: Duration(milliseconds: 300)),
        isFalse,
        reason: 'Loading',
      );

      var idle = uiRoot.whenIdle(timeout: Duration(seconds: 3));
      Future.delayed(
        Duration(milliseconds: 200),
        () => completer.complete('loaded'),
      );
      expect(await idle, isTrue);
      expect(pending.content!.textContent, contains('loaded'));
    });

    test('a loaded content with auto refresh is idle', () async {
      var uiRoot = await newRoot();

      var autoRefresh = _AutoRefresh(
        newHost(uiRoot),
        Duration(milliseconds: 500),
      );
      await autoRefresh.callRenderAndWait();
      await testUISleep(ms: 100);
      expect(autoRefresh.loads, equals(1));

      expect(await uiRoot.whenIdle(timeout: Duration(seconds: 2)), isTrue);
      expect(autoRefresh.isLoadingUIAsyncContent, isTrue, reason: 'Kept');
      expect(autoRefresh.hasPendingUIAsyncContent, isFalse);
    });
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'root-close-root');

  @override
  UIComponent? renderContent() => null;

  @override
  web.Element? renderClosed() => web.HTMLSpanElement()..textContent = 'CLOSED';
}

class _Plain extends UIComponent {
  _Plain(super.parent);

  @override
  dynamic render() => 'plain';
}

/// An [UIComponentAsync] with auto refresh, counting its [loads].
class _AutoRefresh extends UIComponentAsync {
  int loads = 0;

  _AutoRefresh(Object? parent, Duration refreshInterval)
    : super(
        parent,
        null,
        null,
        'loading...',
        'error!',
        refreshInterval: refreshInterval,
      );

  // Stable properties: the same async content (refreshed) on each render.
  @override
  Map<String, dynamic> renderPropertiesProvider() => {'v': 1};

  @override
  Future<dynamic>? renderAsync(Map<String, dynamic> properties) {
    var n = ++loads;
    return Future.delayed(Duration(milliseconds: 20), () => 'load #$n');
  }
}

/// Renders an [UIAsyncContent] of [provider].
class _Async extends UIComponent {
  final Future<String> Function() provider;

  _Async(super.parent, this.provider);

  UIAsyncContent? _asyncContent;

  @override
  dynamic render() =>
      _asyncContent ??= UIAsyncContent.provider(provider, 'loading');
}
