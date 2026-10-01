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

### Real app benchmark (external)

A benchmark kept in a real application's repository, using `bones_ui` as a path
dependency, runs the app against its test API server. It logs in, then:

- navigates through 14 routes, 3 rounds: the synchronous `navigateTo` time and
  the time until the DOM is stable (no mutation for 600 ms);
- fully re-renders the `UIRoot` (`uiRoot.refresh()`) 5 times per route;
- records the JS heap after a forced GC before navigating, after navigating and
  at the end, plus the DOM element count.

It runs on a `chrome-bench` platform like this package's, and prints the same
kind of `BONES_UI_BENCH` JSON line (comparable with `benchmark/compare.dart`).

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

### Render optimization series (`perf/1-benchmark` .. `perf/4-purge-slicing`)

Steps, each on its own branch, stacked on `dart-3.13`:

1. `perf/1-benchmark`: the benchmarks (no library change).
2. `perf/2-render-walks`: no full-tree walks per render (`querySelector`
   selections instead), no O(n²) placement of rendered children.
3. `perf/3-components-tree`: `UIComponentsTree`, hashed by JS identity, with
   weakly held purged entries.
4. `perf/4-purge-slicing`: the purge after rendering yields every 8 ms
   instead of after every component.

`benchmark/render_benchmark.dart`, medians of 3 interleaved runs (base,
step 2, step 3 in turns; step 4 right after). Re-render `medianMs`:

| scenario | base | step 2 | step 3 | step 4 |
|---|---:|---:|---:|---:|
| dart2js `dom_list_1000` | 25.7 | 21.7 | 21.0 | 21.9 |
| dart2js `html_list_500` | 12.4 | 11.4 | 10.7 | 10.9 |
| dart2js `wide_components_500` | 16.2 | 8.7 | 8.1 | 8.2 |
| dart2js `deep_components_341` | 5.7 | 4.7 | 4.6 | 4.5 |
| dart2js `async_content_200` | 24.2 | 26.9 | 26.6 | 27.4 |
| **dart2js total** | **83.8** | **72.2** | **71.4** | **72.9** |
| dart2wasm `dom_list_1000` | 25.5 | 21.1 | 22.0 | 22.5 |
| dart2wasm `html_list_500` | 13.7 | 11.7 | 12.1 | 12.6 |
| dart2wasm `wide_components_500` | 84.0 | 76.0 | 7.8 | 8.0 |
| dart2wasm `deep_components_341` | 26.1 | 24.9 | 4.1 | 3.6 |
| dart2wasm `async_content_200` | 30.4 | 30.2 | 28.6 | 29.2 |
| **dart2wasm total** | **179.1** | **163.8** | **74.7** | **76.4** |

Heap after the automatic purge (`heapAutoPurgedKB`), after 12 re-renders and
deleting the component:

| scenario | base | step 2 | step 3 | step 4 |
|---|---:|---:|---:|---:|
| dart2js `wide_components_500` | 3526 | 3389 | 3409 | 2095 |
| dart2js `deep_components_341` | 5077 | 5086 | 5080 | 1347 |
| dart2wasm `wide_components_500` | 3504 | 3462 | 3544 | 1769 |
| dart2wasm `deep_components_341` | 2475 | 2504 | 2570 | 1104 |

Real app benchmark (dart2js), 3 runs each (values per run, since
the spread matters here):

| metric | base | step 2 | step 3 | step 4 |
|---|---|---|---|---|
| full re-render, sum of sync `refresh()` (ms) | 293 / 325 / 337 | 268 / 276 / 290 | 355 / 379 / 383 | 259 / 311 / 345 |
| navigation, sum of sync `navigateTo` (ms, median) | 54.8 | 50.5 | 23.8 | 52.5 |
| navigation, sum until stable DOM (ms, median) | 1451 | 1351 | 1337 | 1370 |
| heap at the end (MB) | 113.7 / 119.6 / 123.1 | 114.7 / 116.0 / 123.4 | 111.5 / 113.6 / 119.7 | 98.5 / 100.1 / 101.7 |
| heap after 42 navigations (MB, median) | 99.5 | 99.4 | 98.7 | 89.0 |

Notes:

- Step 2: all the synthetic scenarios except `async_content_200` improve
  (`wide_components_500` -46% with dart2js), and full re-renders of the app
  are consistently faster (-15% median). A first version of the
  `_ensureAllRendered` shortcut queried the subtree at every level of its
  walk (O(n·depth)) and made the app re-renders +11% slower: it's now only
  done for the entry elements.
- Step 3: fixes the O(n) registration/lookup with `dart2wasm`
  (`wide_components_500` -90%, `deep_components_341` -84%); neutral with
  `dart2js` in the synthetic scenarios. Alone, the app re-renders were
  consistently slower (+16%); recovered by step 4, so steps 3 and 4 should be
  merged together.
- Step 4: the weak purged entries of step 3 only pay off once the purge runs
  promptly. The app heap at the end is -16% (all 3 runs below every baseline
  run) and -10% after navigating. The app re-render times vary too much
  between runs to claim a gain beyond step 2.
- Validation at every step: `bones_ui` tests (1036, and 1050 with the
  `UIComponentsTree` tests from step 3, VM + Chrome dart2js/dart2wasm) and
  the real app's UI test suite (the same passing and failing tests as the
  baseline: failures that pre-exist these changes).

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

Real app benchmark (dart2js):

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
