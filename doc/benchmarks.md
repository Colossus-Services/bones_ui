# Bones_UI benchmarks

History of the `Bones_UI` render benchmarks: how to run them, how to compare
results, and the recorded results of each optimization, for future comparison
and regression checks.

## Benchmarks

### `benchmark/render_benchmark.dart` (synthetic, in this package)

Renders synthetic components on the `chrome-bench` platform (Chrome with
`gc()` exposed and precise heap sizes), once per compiler (`dart2js` and
`dart2wasm`):

| scenario | what it stresses |
|---|---|
| `dom_list_1000` | 1000 rows of `DOMElement`s (classes, attributes, nested nodes): DOM generation and the per-render tree walks |
| `html_list_500` | 500 rows from an HTML string: HTML parsing path |
| `wide_components_500` | one component with 500 direct sub-components: placement of rendered children |
| `deep_components_341` | a tree of sub-components (depth 5, fan-out 4): nested renders, clear and registration |
| `async_content_200` | 200 `Future` contents resolved after render: `UIAsyncContent` path |

For each scenario:

- `firstRenderMs`: construction plus first render.
- `medianMs` / `minMs` / `maxMs`: a full re-render (`refresh()`, which
  recreates any sub-component instantiated in `render`), over 9 iterations
  after 3 warm-up iterations.
- `domNodes`: the number of elements rendered.
- `heapRenderedKB`: the heap while rendered (after all the re-renders),
  relative to before creating the component, after a forced GC.
- `heapRetainedKB`: the heap still held after deleting the component and
  purging the root, relative to before creating it.

Heap values are noisy (±1 MB), so compare them across several runs. Negative
values mean memory from a previous scenario was released.

Run it:

```sh
dart test benchmark/render_benchmark.dart -p chrome-bench
```

### `menu_ici_ui` app benchmark (real app, external)

`test/bones_ui_render_bench.dart` in the `menu_ici_ui` project runs the real
app against its test API server (with `bones_ui` as a path dependency). It
logs in, then:

- navigates through 14 routes, 3 rounds: the synchronous `navigateTo` time and
  the time until the DOM is stable (no mutation for 600 ms);
- fully re-renders the `UIRoot` (`uiRoot.refresh()`) 5 times per route;
- records the JS heap after a forced GC before navigating, after navigating and
  at the end, plus the DOM element count.

```sh
dart test test/bones_ui_render_bench.dart -p chrome-bench
```

## Comparing results

Both benchmarks print one `BONES_UI_BENCH {...}` JSON line per run (per
compiler). Save the output of several runs (at least 3) for the baseline and
for the candidate, then compare the medians:

```sh
dart test benchmark/render_benchmark.dart -p chrome-bench | grep BONES_UI_BENCH > /tmp/base-1.log
# ... repeat, switch to the candidate code, repeat ...
dart run benchmark/compare.dart /tmp/base-*.log -- /tmp/cand-*.log
```

Run benchmarks with the machine otherwise idle, since CPU contention (for
example a test suite running at the same time) distorts the timings.

## Profiling

The `chrome-prof` platform runs Chrome with the V8 tick profiler, writing
`/tmp/bones_ui_v8.log`. Profile a benchmark (a single compiler, `dart2js`
keeps readable function names), then process the log with Node.js:

```sh
dart test benchmark/render_benchmark.dart -p chrome-prof -c dart2js
node --prof-process /tmp/bones_ui_v8.log > /tmp/bones_ui_prof.txt
```

The "Bottom up (heavy) profile" section attributes the ticks to callers.
Ticks under `_currentTrace` / `_stack_zone_specification` come from the test
runner's stack-chain zone, not from `Bones_UI`.

## History

Environment of the recorded results, unless noted: Apple M5, macOS 26.6.2,
Chrome 154 (headless), Dart 3.13.5.

<!-- Add new entries at the top. Keep the baseline of each series. -->

### Baseline: `bones_ui` 3.1.0 (`dart-3.13` @ `06db0df`)

Medians of 3 runs.

`benchmark/render_benchmark.dart` (re-render `medianMs` / first render ms /
`heapRenderedKB`):

| scenario | dart2js | dart2wasm |
|---|---:|---:|
| `dom_list_1000` | 26.2 / 46.9 / 1220 | 27.2 / 72.2 / 419 |
| `html_list_500` | 12.3 / 30.3 / 424 | 13.6 / 33.7 / 161 |
| `wide_components_500` | 16.5 / 33.8 / 4076 | 85.0 / 51.5 / 3021 |
| `deep_components_341` | 5.6 / 15.1 / 15401 | 26.0 / 12.1 / -11361 |
| `async_content_200` | 24.1 / 8.1 / -8384 | 30.1 / 8.7 / -6546 |
| **total `medianMs`** | **85.3** | **182.1** |

`menu_ici_ui` app benchmark (dart2js):

| metric | value |
|---|---:|
| navigation: sum of synchronous `navigateTo` (14 routes) | 54.8 ms |
| navigation: sum of time until stable DOM | 1451 ms |
| full re-render: sum of synchronous `uiRoot.refresh()` (14 routes) | 325.2 ms |
| full re-render: sum of time until stable DOM | 1415 ms |
| heap: start / after 42 navigations / after 70 re-renders | 82.8 / 99.5 / 119.6 MB |

Findings (V8 tick profile of the synthetic scenarios, dart2js):

- `setTreeElementsBackgroundBlur` (5 `querySelectorAll` per call) runs after
  every generated `DOMNode` and every render: ~11% of the ticks.
- `_parseAttributes` and `_parseAttributesPosRender` walk the whole rendered
  tree through JS interop on every render (6 `getAttribute` per element):
  ~9%.
- `_addElementToRenderList` calls `childNodes.indexOf` (O(n) through
  interop) twice per rendered element, making a render O(n²): ~4%.
- `setTreeElementsDivCentered` (4 `querySelectorAll`) after every generated
  `DOMNode`: ~4%.
- With `dart2wasm`, JS objects have a constant Dart `hashCode` (`0`), so the
  `UIRootComponent` tree of components (a `Map` keyed by DOM nodes) is a
  linear scan: registration and lookup are O(n) (`wide_components_500` is 5x
  slower than with `dart2js`).
- Purged components (no longer in the tree) are strongly held for 1 minute
  (`keepPurgedKeys` of `DOMTreeReferenceMap`), with their detached DOM: the
  heap grows with every navigation and re-render.
