// Render benchmark for `Bones_UI`.
//
// Synthetic scenarios covering the render paths that real apps stress:
// large `DOMElement` lists, HTML strings, deep and wide trees of
// sub-components, async content and repeated create/refresh cycles.
//
// Run it on the `chrome-bench` platform (see `dart_test.yaml`), which exposes
// `gc()` and precise heap sizes:
//
//   dart test benchmark/render_benchmark.dart -p chrome-bench
//
// Each compiler prints one `BONES_UI_BENCH {...}` JSON line. Record the
// results in `doc/benchmarks.md` (see there how to compare them).
@TestOn('browser')
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:js_interop_unsafe';

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

/// Timed iterations per scenario (after [_warmup] iterations).
const _iterations = 9;
const _warmup = 3;

void main() {
  late final _BenchRoot uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot(_BenchRoot.new);
    await uiRoot.callRenderAndWait();
  });

  test('render benchmark', () async {
    final results = <String, Object?>{};

    // Discarded pass, so that one-time allocations (code, caches) aren't
    // counted in the first scenario:
    await _runScenario(uiRoot, _scenarios.first);

    for (final scenario in _scenarios) {
      results[scenario.name] = await _runScenario(uiRoot, scenario);
    }

    final report = {
      'compiler': _compiler,
      'iterations': _iterations,
      'scenarios': results,
      'totalMedianMs': _round(
        results.values
            .map((r) => (r as Map)['medianMs'] as double)
            .fold(0.0, (a, b) => a + b),
      ),
    };

    print('BONES_UI_BENCH ${json.encode(report)}');
  });
}

String get _compiler =>
    const bool.fromEnvironment('dart.tool.dart2wasm') ? 'dart2wasm' : 'dart2js';

class _Scenario {
  final String name;

  /// Creates the component under test, attached to `parent`.
  final UIComponent Function(Element parent) create;

  /// Awaited after each render (for async scenarios).
  final bool async;

  const _Scenario(this.name, this.create, {this.async = false});
}

final _scenarios = <_Scenario>[
  // 1000 rows built with `DOMElement`s (classes, attributes, nested nodes).
  _Scenario('dom_list_1000', (p) => _DOMList(p, 1000)),
  // 500 rows rendered from an HTML string.
  _Scenario('html_list_500', (p) => _HTMLList(p, 500)),
  // One component with 500 direct sub-components.
  _Scenario('wide_components_500', (p) => _Wide(p, 500)),
  // A tree of sub-components: depth 5, fan-out 4 (341 components).
  _Scenario('deep_components_341', (p) => _Tree(p, 5, 4)),
  // 200 `Future` contents resolved after render.
  _Scenario('async_content_200', (p) => _Async(p, 200), async: true),
];

Future<Map<String, Object?>> _runScenario(
  _BenchRoot uiRoot,
  _Scenario scenario,
) async {
  final host = uiRoot.host;

  await uiRoot.purgeRoot(disposePurgedComponents: true);
  final heapBefore = await _heapAfterGC();

  // First render (construction + render):
  final sw = Stopwatch()..start();
  final component = scenario.create(host);
  component.callRender();
  sw.stop();
  final firstRenderMs = sw.elapsedMicroseconds / 1000;
  if (scenario.async) await _settle();

  // Re-renders (`refresh` clears and renders again, recreating any
  // sub-component instantiated in `render`):
  final samples = <double>[];
  for (var i = 0; i < _warmup + _iterations; ++i) {
    sw
      ..reset()
      ..start();
    component.refresh();
    if (scenario.async) await _settle();
    sw.stop();
    if (i >= _warmup) samples.add(sw.elapsedMicroseconds / 1000);
  }

  final nodes = host.getElementsByTagName('*').length;

  // Retained heap while rendered, relative to before creation:
  final heapRendered = await _heapAfterGC();

  component.delete();
  host.clear();

  // Heap after the automatic purge of the `UIRoot`, that runs after the
  // rendering finishes (the state of a running app):
  await Future.delayed(_autoPurgeDelay);
  final heapAutoPurged = await _heapAfterGC();

  await uiRoot.purgeRoot(disposePurgedComponents: true);

  // Heap not released after deleting the component and explicitly purging:
  final heapAfter = await _heapAfterGC();

  samples.sort();

  return {
    'firstRenderMs': _round(firstRenderMs),
    'medianMs': _round(samples[samples.length ~/ 2]),
    'minMs': _round(samples.first),
    'maxMs': _round(samples.last),
    'domNodes': nodes,
    if (heapBefore != null &&
        heapRendered != null &&
        heapAutoPurged != null &&
        heapAfter != null) ...{
      'heapRenderedKB': (heapRendered - heapBefore) ~/ 1024,
      'heapAutoPurgedKB': (heapAutoPurged - heapBefore) ~/ 1024,
      'heapRetainedKB': (heapAfter - heapBefore) ~/ 1024,
    },
  };
}

/// Longer than the render finish detection (~400 ms) plus the purge delay
/// (300 ms) of `UIComponent`.
const _autoPurgeDelay = Duration(milliseconds: 1500);

/// Lets the event loop run the pending futures and timers.
Future<void> _settle() => Future.delayed(Duration(milliseconds: 1));

Future<int?> _heapAfterGC() async {
  for (var i = 0; i < 3; ++i) {
    if (globalContext.has('gc')) {
      globalContext.callMethod('gc'.toJS);
    }
    await Future.delayed(Duration(milliseconds: 50));
  }

  final memory = (globalContext['performance'] as JSObject)['memory'];
  if (memory == null) return null;
  return ((memory as JSObject)['usedJSHeapSize'] as JSNumber?)?.toDartInt;
}

double _round(double v) => (v * 100).roundToDouble() / 100;

class _BenchRoot extends UIRoot {
  _BenchRoot(super.rootContainer) : super(id: 'bench-root');

  late final HTMLDivElement host = HTMLDivElement()..id = 'bench-host';

  @override
  UIComponent? renderContent() => _HostComponent(content, host);
}

class _HostComponent extends UIComponent {
  final HTMLDivElement host;

  _HostComponent(super.parent, this.host);

  @override
  dynamic render() => host;
}

DOMElement _row(int i) => $div(
  classes: 'row item-row ${i.isEven ? 'even' : 'odd'}',
  attributes: {'data-index': '$i', 'title': 'Row $i'},
  content: [
    $span(classes: 'col-id', content: '#$i'),
    $span(classes: 'col-name', content: 'Item name $i'),
    $span(
      classes: 'col-price',
      style: 'text-align: right',
      content: (i * 1.25).toStringAsFixed(2),
    ),
    $a(href: '#item?id=$i', classes: 'col-link', content: 'open'),
  ],
);

class _DOMList extends UIComponent {
  final int size;

  _DOMList(super.parent, this.size);

  @override
  dynamic render() =>
      $div(classes: 'list', content: [for (var i = 0; i < size; ++i) _row(i)]);
}

class _HTMLList extends UIComponent {
  final int size;

  _HTMLList(super.parent, this.size);

  @override
  dynamic render() {
    final html = StringBuffer('<div class="list">');
    for (var i = 0; i < size; ++i) {
      html.write(
        '<div class="row" data-index="$i">'
        '<span class="col-id">#$i</span>'
        '<span class="col-name">Item name $i</span>'
        '<a href="#item?id=$i">open</a>'
        '</div>',
      );
    }
    html.write('</div>');
    return html.toString();
  }
}

class _Cell extends UIComponent {
  final int index;

  _Cell(super.parent, this.index) : super(componentClass: 'cell');

  @override
  dynamic render() => [
    $span(classes: 'cell-label', content: 'Cell $index'),
    $span(classes: 'cell-value', content: '${index * 3}'),
  ];
}

class _Wide extends UIComponent {
  final int size;

  _Wide(super.parent, this.size);

  @override
  dynamic render() => [for (var i = 0; i < size; ++i) _Cell(null, i)];
}

class _Tree extends UIComponent {
  final int depth;
  final int fanOut;

  _Tree(super.parent, this.depth, this.fanOut)
    : super(componentClass: 'tree-node');

  @override
  dynamic render() => [
    $div(classes: 'tree-label', content: 'depth $depth'),
    if (depth > 1)
      for (var i = 0; i < fanOut; ++i) _Tree(null, depth - 1, fanOut),
  ];
}

class _Async extends UIComponent {
  final int size;

  _Async(super.parent, this.size);

  @override
  dynamic render() => [
    for (var i = 0; i < size; ++i)
      Future.value($div(classes: 'async-row', content: 'Loaded $i')),
  ];
}
