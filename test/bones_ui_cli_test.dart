@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:bones_ui/src/bones_ui.dart';
import 'package:bones_ui/src/bones_ui_test_cli.dart' hide main;
import 'package:bones_ui/src/bones_ui_test_cli.dart' as cli show main;
import 'package:path/path.dart' as pack_path;
import 'package:test/test.dart';

/// Runs [f] capturing the lines it prints.
Future<List<String>> _capturePrints(FutureOr<void> Function() f) async {
  var lines = <String>[];
  await runZoned(
    () async => await f(),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// A temporary directory, deleted after the test.
Directory _tempDir() {
  var dir = Directory.systemTemp.createTempSync('bones_ui_cli_test_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// A [BonesUITestRunner] with a temporary compile directory.
BonesUITestRunner _runner([List<String> args = const []]) =>
    BonesUITestRunner(args: args, compileDir: _tempDir());

void main() {
  group('CLI helpers', () {
    test('isJustHelpArgs', () {
      expect(isJustHelpArgs(['-h']), isTrue);
      expect(isJustHelpArgs(['--help']), isTrue);
      expect(isJustHelpArgs([]), isFalse);
      expect(isJustHelpArgs(['-h', 'x']), isFalse);
      expect(isJustHelpArgs(['-x']), isFalse);
    });

    test('printBox / printTestCliTitle', () async {
      var box = await _capturePrints(() => printBox(['a', 'b']));
      expect(box.single, contains('║ a\n║ b\n'));

      var title = (await _capturePrints(
        () => printTestCliTitle(testPlatform: 'chrome'),
      )).join('\n');
      expect(title, contains(bonesUiTestCliTitle));
      expect(title, contains('» Dart: '));
      expect(title, contains('» OS: '));
      expect(title, contains('» Platform: chrome'));

      var short = (await _capturePrints(
        () => printTestCliTitle(showDartVersion: false, showOSVersion: false),
      )).join('\n');
      expect(short, isNot(contains('» Dart:')));
      expect(short, isNot(contains('» OS:')));
      expect(short, isNot(contains('» Platform:')));
    });

    test('bonesUiTestCliTitle', () {
      expect(bonesUiTestCliTitle, contains(BonesUI.version));
    });

    test('main --help', () async {
      var lines = (await _capturePrints(() => cli.main(['--help']))).join('\n');
      expect(lines, contains(bonesUiTestCliTitle));
      expect(lines, contains('Usage: bones_ui test'));
      expect(lines, contains('--show-ui'));
    });
  });

  group('BonesUITestRunner', () {
    test('defaults', () {
      var runner = _runner();

      expect(runner.args, isEmpty);
      expect(runner.showUI, isFalse);
      expect(runner.headless, isTrue);
      expect(runner.debug, isFalse);
      expect(runner.pauseAfterLoad, isFalse);
      // Disabled by default (dart-lang/test#2088):
      expect(runner.enableDeferredLibraries, isFalse);
      expect(runner.logDirectory, isNull);
      expect(runner.jsonReportFilePath, isNull);
      expect(runner.platform, equals('chrome'));
      expect(
        runner.bonesUiTestConfigFile.path,
        endsWith('bones_ui_test_config.yaml'),
      );
      expect(runner.bonesUITestTemplateFileName, 'bones_ui_test.html.tpl');
      expect(
        runner.bonesUITestTemplateFile.path,
        equals(
          pack_path.join(
            runner.bonesUICompileDir.path,
            'bones_ui_test.html.tpl',
          ),
        ),
      );
    });

    test('default compile directory is a new temporary directory', () {
      var runner = BonesUITestRunner();
      addTearDown(runner.bonesUICompiler.close);

      var dir = runner.bonesUICompileDir;
      expect(dir.existsSync(), isTrue);
      expect(pack_path.basename(dir.path), startsWith('dart_test_bones_ui_'));
    });

    test('--show-ui / --headless', () {
      var show = _runner(['--show-ui']);
      expect(show.showUI, isTrue);
      expect(show.headless, isFalse);

      var both = _runner(['--show-ui', '--headless']);
      expect(both.showUI, isFalse);
      expect(both.headless, isTrue);

      var paused = _runner(['--pause-after-load']);
      expect(paused.pauseAfterLoad, isTrue);
      expect(paused.headless, isFalse);

      expect(_runner(['--debug']).debug, isTrue);
    });

    test('deferred libraries flags', () {
      expect(
        _runner(['--enable-deferred-libraries']).enableDeferredLibraries,
        isTrue,
      );
      expect(
        _runner(['--enable-deferred-library']).enableDeferredLibraries,
        isTrue,
      );
      expect(
        _runner(['--disable-deferred-libraries']).enableDeferredLibraries,
        isFalse,
      );
      expect(
        _runner(['--disable-deferred-library']).enableDeferredLibraries,
        isFalse,
      );
    });

    test('--log-dir / --log-directory', () {
      var logDir = pack_path.join(_tempDir().path, 'logs');

      var runner = _runner(['--log-dir', ' $logDir/ ']);
      expect(runner.logDirectory!.path, equals(logDir));
      expect(
        runner.jsonReportFilePath,
        equals('$logDir/bones_ui_test_report.json'),
      );

      var runner2 = _runner(['--log-directory', logDir]);
      expect(runner2.logDirectory!.path, equals(logDir));

      // Regression: an empty value was normalized to `.` (the current
      // directory) and used as the log directory.
      var empty = _runner(['--log-dir', '  ']);
      expect(empty.logDirectory, isNull);
      expect(empty.jsonReportFilePath, isNull);
    });

    test('platform', () {
      expect(_runner(['-p', 'firefox']).platform, equals('firefox'));
      expect(_runner(['-p', 'vm']).platform, equals('chrome'));
      expect(_runner(['-p', 'node']).platform, equals('chrome'));

      var known = _runner().allKnownPlatforms;
      expect(known, containsAll(['chrome', 'firefox', 'vm']));
      // Defined in `dart_test.yaml`:
      expect(known, contains('firefox-esr'));
    });

    test('invalid args are reported by the constructor', () {
      expect(() => _runner(['--not-a-test-option']), throwsA(anything));
    });

    test('resolveTestArgs', () {
      var args = _runner([
        '-t',
        'slow',
        '-x',
        'fast',
        '-n',
        'my test',
        '--run-skipped',
        '--no-retry',
        '--reporter',
        'json',
        '--coverage',
        'cov',
        '--ignore-timeouts',
        '--js-trace',
        'test/a_test.dart',
        'test/dir',
      ]).resolveTestArgs();

      expect(args.take(2), equals(['--platform', 'chrome']));
      expect(args, containsAllInOrder(['-t', 'slow']));
      expect(args, containsAllInOrder(['-x', 'fast']));
      expect(args, containsAllInOrder(['-n', 'my test']));
      expect(args, contains('--run-skipped'));
      expect(args, contains('--no-retry'));
      expect(args, containsAllInOrder(['--reporter', 'json']));
      expect(args, containsAllInOrder(['--coverage', 'cov']));
      expect(args, contains('--ignore-timeouts'));
      expect(args, contains('--js-trace'));
      // Deferred libraries are disabled by default:
      expect(
        args,
        containsAllInOrder(['--dart2js-args', '--disable-program-split']),
      );
      // Only `.dart` paths:
      expect(args.last, equals('test/a_test.dart'));
      expect(args, isNot(contains('test/dir')));
      // `--coverage` implies debug mode (`Configuration.debug`):
      expect(args, contains('--debug'));
    });

    test('resolveTestArgs: deferred libraries enabled', () {
      var args = _runner([
        '--enable-deferred-libraries',
        '--dart2js-args',
        '--disable-program-split',
      ]).resolveTestArgs();
      expect(args, isNot(contains('--disable-program-split')));
      expect(args, isNot(contains('--dart2js-args')));
    });

    test('resolveTestArgs: show UI / debug / pause', () {
      var show = _runner(['--show-ui']).resolveTestArgs();
      expect(show, contains('--debug'));
      expect(show, containsAllInOrder(['--timeout', 'none']));

      var pause = _runner(['--pause-after-load']).resolveTestArgs();
      expect(pause, contains('--pause-after-load'));

      expect(_runner(['--debug']).resolveTestArgs(), contains('--debug'));
      expect(_runner().resolveTestArgs(), isNot(contains('--debug')));
    });

    test('resolveTestArgs: log directory', () {
      var logDir = pack_path.join(_tempDir().path, 'logs', 'sub');
      var runner = _runner(['--log-dir', logDir]);

      var args = runner.resolveTestArgs();
      expect(Directory(logDir).existsSync(), isTrue);
      expect(
        args,
        containsAllInOrder([
          '--file-reporter',
          'json:$logDir/bones_ui_test_report.json',
        ]),
      );
    });

    test('resolveTestArgs: file reporters', () {
      var args = _runner(['--file-reporter', 'json:out.json'])
          .resolveTestArgs();
      expect(args, containsAllInOrder(['--file-reporter', 'json:out.json']));
    });

    test('resolveTestConfigurationPath', () {
      var runner = _runner();
      expect(runner.bonesUiTestConfigFile.existsSync(), isFalse);

      var path = runner.resolveTestConfigurationPath(runner.parsedArgs);
      expect(path, equals(runner.bonesUiTestConfigFile.path));
      expect(runner.bonesUiTestConfigFile.existsSync(), isTrue);
      expect(runner.bonesUITestTemplateFile.existsSync(), isTrue);

      var config = runner.bonesUiTestConfigFile.readAsStringSync();
      expect(config, contains(bonesUiTestCliTitle));
      expect(config, contains('timeout: 60s'));
      // `dart_test.yaml` exists in the project:
      expect(
        config,
        contains('include: ${File('dart_test.yaml').absolute.path}'),
      );
      expect(
        config,
        contains(
          'custom_html_template_path: ${runner.bonesUITestTemplateFile.path}',
        ),
      );

      // Reuses the generated file:
      runner.bonesUiTestConfigFile.writeAsStringSync('# kept');
      expect(runner.resolveTestConfigurationPath(runner.parsedArgs), path);
      expect(runner.bonesUiTestConfigFile.readAsStringSync(), '# kept');
    });

    test('resolveTestConfigurationPath: custom configuration', () {
      var custom = File(pack_path.join(_tempDir().path, 'custom.yaml'))
        ..writeAsStringSync('timeout: 10s\n');

      var runner = _runner(['--configuration', custom.path]);
      expect(
        runner.resolveTestConfigurationPath(runner.parsedArgs),
        equals(custom.path),
      );
      expect(runner.bonesUiTestConfigFile.existsSync(), isFalse);
    });

    test('buildBonesUITestConfig / buildTestTemplateFile', () {
      var runner = _runner();

      var withoutInclude = runner.buildBonesUITestConfig(false, File('x'));
      expect(withoutInclude, contains('platforms: [chrome]'));
      expect(withoutInclude, isNot(contains('include:')));

      var withInclude = runner.buildBonesUITestConfig(
        true,
        File('/some/dart_test.yaml'),
      );
      expect(withInclude, contains('include: /some/dart_test.yaml'));
      expect(withInclude, isNot(contains('platforms:')));

      var template = runner.buildTestTemplateFile();
      expect(template, contains('{{testName}}'));
      expect(template, contains('{{testScript}}'));
      expect(template, contains('packages/test/dart.js'));

      runner.generateTestTemplateFile();
      expect(runner.bonesUITestTemplateFile.readAsStringSync(), template);
    });

    test('showHelp / execute --help', () async {
      var runner = _runner();
      late bool ok;
      var lines = await _capturePrints(
        () async => ok = await runner.showHelp(),
      );
      expect(ok, isTrue);
      expect(lines.join('\n'), contains('Usage: bones_ui test'));

      var help = _runner(['--help']);
      expect(help.parsedArgs.help, isTrue);
      late bool executed;
      var helpLines = await _capturePrints(
        () async => executed = await help.execute(),
      );
      expect(executed, isTrue);
      expect(helpLines.join('\n'), contains('--show-ui'));
      // No compilation for help:
      expect(help.bonesUICompileDir.listSync(), isEmpty);
    });

    test('prepare with a known platform', () async {
      var runner = _runner(['-p', 'vm']);
      var lines = await _capturePrints(runner.prepare);
      expect(lines.join('\n'), contains('Ignoring `platform` parameter `vm`'));
      expect(runner.bonesUICompileDir.existsSync(), isTrue);
    });
  });

  group('BonesUICompiler', () {
    test('prepare / close', () async {
      var dir = Directory(pack_path.join(_tempDir().path, 'compile'));
      var compiler = BonesUICompiler(compileDir: dir);

      expect(compiler.projectDir.path, equals(Directory.current.absolute.path));
      expect(compiler.compileDir.path, equals(dir.absolute.path));

      await compiler.prepare();
      expect(dir.existsSync(), isTrue);

      compiler.close();
      expect(dir.existsSync(), isFalse);

      // Closing twice is a no-op:
      compiler.close();
    });

    test('linkWebDirToTestDir', () {
      var dir = _tempDir();
      var compiler = BonesUICompiler(compileDir: dir);

      expect(compiler.linkWebDirToTestDir(), isFalse, reason: 'No web/');

      var webDir = Directory(pack_path.join(dir.path, 'web'))..createSync();
      expect(compiler.linkWebDirToTestDir(), isFalse, reason: 'No test/');

      var testDir = Directory(pack_path.join(dir.path, 'test'))..createSync();

      File(pack_path.join(webDir.path, 'styles.css')).writeAsStringSync('a{}');
      File(pack_path.join(webDir.path, '.hidden')).writeAsStringSync('x');
      File(pack_path.join(webDir.path, 'kept.txt')).writeAsStringSync('web');
      File(pack_path.join(testDir.path, 'kept.txt')).writeAsStringSync('test');

      expect(compiler.linkWebDirToTestDir(), isTrue);

      var link = Link(pack_path.join(testDir.path, 'styles.css'));
      expect(link.existsSync(), isTrue);
      expect(
        File(link.path).readAsStringSync(),
        equals('a{}'),
        reason: 'Linked to web/styles.css',
      );

      expect(
        File(pack_path.join(testDir.path, '.hidden')).existsSync(),
        isFalse,
        reason: 'Dot files are not linked',
      );
      expect(
        File(pack_path.join(testDir.path, 'kept.txt')).readAsStringSync(),
        equals('test'),
        reason: 'Existing files are kept',
      );

      // Linking again keeps the existing links:
      expect(compiler.linkWebDirToTestDir(), isTrue);
    });
  });

  group('DartRunner', () {
    test('runDartCommand', () async {
      var runner = DartRunner();

      var exe = await runner.dartExecutable;
      expect(exe, isNotEmpty);
      expect(await runner.dartExecutable, same(exe));

      var exitCode = await runner.runDartCommand(['--version']);
      expect(exitCode, equals(0));

      var exitCode2 = await runner.runDartCommand([
        '--version',
      ], workingDirectory: _tempDir().path);
      expect(exitCode2, equals(0));

      var failed = await runner.runDartCommand(['not-a-dart-command']);
      expect(failed, isNot(equals(0)));
    });
  });

  group('BonesUIPlatform', () {
    test('rejects an invalid compile directory', () async {
      var compiler = BonesUICompiler(compileDir: Directory('/a'));
      await expectLater(
        BonesUIPlatform.create(compiler),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('executables', () {
    test('bin/bones_ui.dart --version', () async {
      var result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'bin/bones_ui.dart',
        '--version',
      ]);
      expect(result.exitCode, equals(0), reason: '${result.stderr}');
      expect(
        '${result.stdout}',
        contains('Bones_UI/${BonesUI.version} - CLI Tool'),
      );
    });

    test('bin/bones_ui.dart test -h', () async {
      var result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'bin/bones_ui.dart',
        'test',
        '-h',
      ]);
      expect(result.exitCode, equals(0), reason: '${result.stderr}');
      expect('${result.stdout}', contains('Usage: bones_ui test'));
    });

    test('bin/bones_ui_test.dart --help', () async {
      var result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'bin/bones_ui_test.dart',
        '--help',
      ]);
      expect(result.exitCode, equals(0), reason: '${result.stderr}');
      expect('${result.stdout}', contains(bonesUiTestCliTitle));
      expect('${result.stdout}', contains('Usage: bones_ui test'));
    });

    test('bin/bones_ui_test.dart with invalid args', () async {
      var result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'bin/bones_ui_test.dart',
        '--not-a-test-option',
      ]);
      expect(result.exitCode, equals(1));
      expect(
        '${result.stdout}',
        contains('ERROR Parsing Bones_UI Test Tool ARGS'),
      );
    });
  });
}
