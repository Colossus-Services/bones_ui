@TestOn('vm')
@Timeout(Duration(minutes: 6))
library;

import 'dart:io';

import 'package:path/path.dart' as pack_path;
import 'package:test/test.dart';

/// What `UIRoot(registerComponents: ...)` is for: the tag components an app
/// does not register are left out of its compiled JavaScript.
///
/// Compiles the minimal apps in `test/register_components/` with
/// `dart compile js -O2` and looks for what each component brings in:
/// its tag name, and for `<ui-document>` the `markdown` package's HTML
/// entity table.
void main() {
  late final Directory outDir;
  final compiled = <String, String>{};

  setUpAll(() async {
    outDir = Directory.systemTemp.createTempSync('bones_ui_tree_shaking_');

    Future<void> compile(String app) async {
      var out = pack_path.join(outDir.path, '$app.js');
      var result = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'js',
        '-O2',
        '-o',
        out,
        pack_path.join('test', 'register_components', 'app_$app.dart'),
      ]);
      if (result.exitCode != 0) {
        fail(
          'dart compile js app_$app.dart:\n${result.stdout}${result.stderr}',
        );
      }
      compiled[app] = File(out).readAsStringSync();
    }

    await Future.wait([
      for (var app in ['all', 'none', 'dialog', 'mixed']) compile(app),
    ]);
  });

  tearDownAll(() {
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  });

  /// The `markdown` package's HTML entity table, brought in by
  /// `<ui-document>`.
  bool hasMarkdown(String js) => js.contains('&AElig;');

  bool hasTag(String js, String tag) => js.contains('"$tag"');

  int gzipped(String js) => gzip.encode(js.codeUnits).length;

  const tags = ['ui-document', 'ui-svg', 'ui-dialog', 'ui-button-loader'];

  test('without `registerComponents`, every component is compiled in', () {
    var js = compiled['all']!;
    expect(hasMarkdown(js), isTrue);
    for (var tag in tags) {
      expect(hasTag(js, tag), isTrue, reason: tag);
    }
  });

  test('registering none leaves them all out, `markdown` included', () {
    var js = compiled['none']!;
    expect(hasMarkdown(js), isFalse);
    for (var tag in tags) {
      expect(hasTag(js, tag), isFalse, reason: tag);
    }

    // About 30% smaller than the same app registering all of them.
    expect(gzipped(js), lessThan(gzipped(compiled['all']!) * 0.8));
  });

  test('registering one keeps that one alone', () {
    var js = compiled['dialog']!;
    expect(hasTag(js, 'ui-dialog'), isTrue);
    expect(hasMarkdown(js), isFalse);
    for (var tag in ['ui-document', 'ui-svg', 'ui-button-loader']) {
      expect(hasTag(js, tag), isFalse, reason: tag);
    }
    expect(gzipped(js), lessThan(gzipped(compiled['all']!) * 0.8));
  });

  test('one root without `registerComponents` keeps them all', () {
    // As documented: every `UIRoot` of the app must pass it.
    var js = compiled['mixed']!;
    expect(hasMarkdown(js), isTrue);
    for (var tag in tags) {
      expect(hasTag(js, tag), isTrue, reason: tag);
    }
  });
}
