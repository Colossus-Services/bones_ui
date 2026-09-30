// Compares `BONES_UI_BENCH` results (from `render_benchmark.dart`, or any
// benchmark printing the same kind of JSON line).
//
//   dart run benchmark/compare.dart <baseline files...> -- <candidate files...>
//
// Each file can hold any number of `BONES_UI_BENCH {...}` lines (runs).
// Results are grouped by `compiler` (when present), every numeric leaf is
// reduced to the median across runs, and the candidate is printed next to the
// baseline with the relative change.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final sep = args.indexOf('--');
  if (sep <= 0 || sep == args.length - 1) {
    stderr.writeln(
      'Usage: dart run benchmark/compare.dart <baseline...> -- <candidate...>',
    );
    exit(64);
  }

  final baseline = _load(args.sublist(0, sep));
  final candidate = _load(args.sublist(sep + 1));

  for (final group in {...baseline.keys, ...candidate.keys}) {
    final b = baseline[group] ?? const {};
    final c = candidate[group] ?? const {};

    print('\n## $group (runs: ${_runs(b)} -> ${_runs(c)})\n');
    print('| metric | baseline | candidate | change |');
    print('|---|---:|---:|---:|');

    for (final key in {...b.keys, ...c.keys}) {
      if (key == _runsKey) continue;
      final bv = _median(b[key]);
      final cv = _median(c[key]);
      print('| $key | ${_fmt(bv)} | ${_fmt(cv)} | ${_change(bv, cv)} |');
    }
  }
}

const _runsKey = '#runs';

/// `compiler -> metric path -> samples`.
Map<String, Map<String, List<num>>> _load(List<String> paths) {
  final groups = <String, Map<String, List<num>>>{};

  for (final path in paths) {
    for (final line in File(path).readAsLinesSync()) {
      final idx = line.indexOf('BONES_UI_BENCH ');
      if (idx < 0) continue;

      final result = json.decode(line.substring(idx + 15)) as Map;
      final group = result['compiler']?.toString() ?? 'default';
      final metrics = groups[group] ??= {};

      (metrics[_runsKey] ??= []).add(1);
      _flatten(result, '', metrics);
    }
  }

  return groups;
}

void _flatten(Object? value, String path, Map<String, List<num>> out) {
  if (value is num) {
    (out[path] ??= []).add(value);
  } else if (value is Map) {
    for (final e in value.entries) {
      _flatten(e.value, path.isEmpty ? '${e.key}' : '$path.${e.key}', out);
    }
  }
}

int _runs(Map<String, List<num>> m) => m[_runsKey]?.length ?? 0;

num? _median(List<num>? l) {
  if (l == null || l.isEmpty) return null;
  final s = [...l]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

String _fmt(num? v) {
  if (v == null) return '-';
  if (v is int || v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(2);
}

String _change(num? b, num? c) {
  if (b == null || c == null) return '-';
  if (b == 0) return c == 0 ? '0%' : '-';
  final pct = (c - b) / b.abs() * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
}
