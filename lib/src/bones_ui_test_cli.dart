import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bones_ui/src/bones_ui.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as pack_path;
import 'package:test/src/runner/browser/platform.dart'; // ignore: implementation_imports
import 'package:test/src/runner/executable_settings.dart'; // ignore: implementation_imports
import 'package:test/test.dart';
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
// ignore: implementation_imports
import 'package:test_core/src/executable.dart' as test_executable;
import 'package:test_core/src/runner/configuration.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/hack_register_platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/plugin/customizable_platform.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/runner_suite.dart'; // ignore: implementation_imports
import 'package:test_core/src/runner/suite.dart'; // ignore: implementation_imports
import 'package:yaml/src/yaml_node.dart'; // ignore: implementation_imports

const bonesUiTestCliTitle = 'Bones_UI/${BonesUI.version} - Test Tool';

/// Prints the Bones_UI Test CLI title.
void printTestCliTitle(
    {bool showDartVersion = true,
    bool showOSVersion = true,
    String? testPlatform}) {
  var dartVersion = Platform.version;
  var os = Platform.operatingSystem;
  var osVer = Platform.operatingSystemVersion;

  var lines = [
    bonesUiTestCliTitle,
    if (showDartVersion) '» Dart: $dartVersion',
    if (showOSVersion) '» OS: $os/$osVer',
    if (testPlatform != null && testPlatform.isNotEmpty)
      '» Platform: $testPlatform',
  ];

  printBox(lines);
}

void printBox(List<String> lines) {
  print(
      '╔═════════════════════════════════════════════════════════════════════\n'
      '${lines.map((l) => '║ $l\n').join()}'
      '╚═════════════════════════════════════════════════════════════════════');
}

bool isJustHelpArgs(List<String> args) =>
    args.length == 1 && (args[0] == '-h' || args[0] == '--help');

Future<void> main([List<String> args = const <String>[]]) async {
  if (isJustHelpArgs(args)) {
    printTestCliTitle();
    BonesUITestRunner().showHelp();
    return;
  }

  BonesUITestRunner bonesUITestRunner;

  try {
    bonesUITestRunner = BonesUITestRunner(args: args);
  } catch (e) {
    print('** ERROR Parsing Bones_UI Test Tool ARGS: $args');
    print('-- See `bones_ui test -h` OR `dart test -h` for test parameters.');
    print(e);
    exit(1);
  }

  printTestCliTitle(testPlatform: bonesUITestRunner.platform);

  await bonesUITestRunner.execute();
}

/// A Bones_UI test runner.
class BonesUITestRunner {
  final BonesUIComiler bonesUIComiler;

  /// The Bones_UI test config file. Default: `bones_ui_test_config.yaml`
  late final File bonesUiTestConfigFile;

  /// The Bones_UI test templat HTML file. Default: `bones_ui_test.html.tpl`
  final String bonesUITestTemplateFileName;

  /// The original arguments.
  late final List<String> args;

  /// The parsed test arguments.
  late final Configuration parsedArgs;

  /// Returns `true` if `--show-ui` was passed.
  late final bool showUI;

  /// The [Directory] to save the test logs and reports.
  late final Directory? logDirectory;

  Directory get bonesUICompileDir => bonesUIComiler.compileDir;

  File get bonesUITestTemplateFile =>
      File(pack_path.join(bonesUICompileDir.path, bonesUITestTemplateFileName));

  BonesUITestRunner(
      {List<String>? args,
      Directory? compileDir,
      String bonesUITestConfigFileName = 'bones_ui_test_config.yaml',
      this.bonesUITestTemplateFileName = 'bones_ui_test.html.tpl'})
      : args = args ?? <String>[],
        bonesUIComiler = BonesUIComiler(compileDir: compileDir) {
    var args = this.args.toList();

    bonesUiTestConfigFile =
        File(pack_path.join(bonesUICompileDir.path, bonesUITestConfigFileName));

    var argHeadless = args.remove('--headless');
    var argShowUI = args.remove('--show-ui');

    String? logDir;
    {
      var idx = args.indexOf('--log-dir');
      if (idx < 0) {
        idx = args.indexOf('--log-directory');
      }

      if (idx >= 0) {
        args.removeAt(idx);
        var dir = args.removeAt(idx);
        dir = pack_path.normalize(dir.trim());
        if (dir.isNotEmpty) {
          logDir = dir;
        }
      }
    }

    showUI = argShowUI && !argHeadless;

    logDirectory = logDir != null ? Directory(logDir) : null;

    var configuration =
        args.isNotEmpty ? Configuration.parse(args) : Configuration.empty;

    try {
      if (File(configuration.configurationPath).existsSync()) {
        var fileConfiguration =
            Configuration.load(configuration.configurationPath);

        configuration = fileConfiguration.merge(configuration);
      }
    } catch (_) {}

    parsedArgs = configuration;
  }

  /// Returns `true` if running the browser in headless mode.
  /// - Options `--show-ui` and `--pause-after-load` will deativate `headless` mode.
  /// - See [showUI].
  bool get headleass => !showUI && !pauseAfterLoad;

  /// Returns `true` if in debug mode.
  bool get debug => parsedArgs.debug;

  /// Returns `trur` if `--pause-after-load` was passed.
  bool get pauseAfterLoad => parsedArgs.pauseAfterLoad;

  /// The parsed `--platform` parameter.
  String? get parsedArgsPlatform =>
      parsedArgs.suiteDefaults.runtimes.firstOrNull;

  /// The selected platform to run the tests.
  String get platform {
    var parsedPlatform = parsedArgsPlatform;
    return _isValidPlatform(parsedPlatform) ? parsedPlatform! : 'chrome';
  }

  bool _isValidPlatform(String? parsedPlatform) =>
      parsedPlatform != null &&
      parsedPlatform != 'vm' &&
      parsedPlatform != 'node' &&
      !parsedPlatform.contains('wasm');

  /// Returns all the known platforms for the `test` package.
  List<String> get allKnownPlatforms => <String>{
        ...Runtime.builtIn.map((e) => e.identifier),
        ...parsedArgs.overrideRuntimes.values.map((e) => e.identifier),
        ...parsedArgs.defineRuntimes.values.map((e) => e.identifier),
      }.toList();

  String? get jsonReportFilePath => logDirectory != null
      ? '${logDirectory!.path}/bones_ui_test_report.json'
      : null;

  /// Shows the usage help in the console.
  Future<bool> showHelp() async {
    print('\nUsage: bones_ui test [options] [files or directories...]\n');

    print('Options:');
    print('-h, --help                            Show this usage information.');
    print(
        '    --show-ui                         Run the tests showing the UI in the browser.');

    print('\nOptions from `dart test`:');
    print('-t, --tags                            Select a tag: -t basic');
    print('-x, --exclude-tags                    Exclude a tag: -x slow');
    print(
        '-n, --name                            A substring of the name of the test to run.');
    print(
        '    --pause-after-load                Pauses the browser for debugging before running the tests.');
    print(
        '    --debug                           Run the Chrome tests in debug mode.');

    print(
        '    --timeout                         The default test timeout. For example: 15s, 2x, none, 60s (default)');
    print(
        '    --ignore-timeouts                 Ignore all timeouts (useful if debugging)');
    print(
        '    --run-skipped                     Run skipped tests instead of skipping them.');
    print(
        "    --no-retry                        Don't rerun tests that have retry set.");

    print(
        '    --coverage=<directory>            Gather coverage and output it to the specified directory.');
    print(
        '    --reporter=<option>               Set how to print test results.');
    print(
        '    --file-reporter                   Enable an additional reporter writing test results to a file.');

    print(
        '    --js-trace                        Emit raw JavaScript stack traces for browser tests.');
    print(
        '    --dart2js-args                    Pass arguments to `dart2js` compiler.');

    print(
        '\n** See `dart test --help` or https://dart.dev/tools/dart-test for more details.');

    print('');

    return true;
  }

  Future<void> prepare() async {
    bonesUIComiler.prepare();

    final platform = this.platform;
    final allKnownPlatforms = this.allKnownPlatforms;

    if (!allKnownPlatforms.contains(platform)) {
      print('** Unknown platform: `$platform`');
      print('-- Known platforms: $allKnownPlatforms');

      exit(1);
    }

    final parsedPlatform = parsedArgsPlatform ?? '';

    if (!_isValidPlatform(parsedPlatform) && args.contains(parsedPlatform)) {
      print(
          '** Ignoring `platform` parameter `$parsedPlatform`. Selected platform: `$platform`');
    }
  }

  /// Executes the tests.
  Future<bool> execute() async {
    if (parsedArgs.help) {
      return showHelp();
    }

    prepare();

    var testArgs = resolveTestArgs();

    await bonesUIComiler.compile();

    var configurationPath = resolveTestConfigurationPath(parsedArgs);

    registerPlatformPlugin([
      Runtime.chrome,
      Runtime.firefox,
      Runtime.safari,
      Runtime.internetExplorer
    ], () => BonesUIPlatform.create(bonesUIComiler, showUI: showUI));

    print(
        '\n══════════════════════════════════════════════════════════════════════');
    print(
        '** Show UI: $showUI ${headleass ? '(headless)' : '(showing browser)'}');
    print('** Test ARGS: ${testArgs.join(' ')}');
    print('** Executing tests...\n');

    testArgs.insertAll(0, [
      '--configuration',
      configurationPath,
    ]);

    await test_executable.main(testArgs);

    _processJsonReportFile();

    bonesUIComiler.close();

    return true;
  }

  bool _processJsonReportFile() {
    var jsonReportFilePath = this.jsonReportFilePath;
    if (jsonReportFilePath == null) return false;

    var logDir = logDirectory;
    if (logDir == null) return false;

    var jsonReportFile = File(jsonReportFilePath);
    if (!jsonReportFile.existsSync()) return false;

    var jsonReport = jsonReportFile.readAsStringSync();

    var lines = jsonReport.split(RegExp(r'}\n'));

    var jsons = lines.where((e) => e.isNotEmpty).map((e) => jsonDecode('$e}'));

    var suites = jsons.splitBefore((e) {
      var p = e['suite']?['path'];
      return p is String && p.endsWith("_test.dart");
    });

    var documentLogs = suites.expand((l) {
      var suite = l.firstWhereOrNull((e) {
        var p = e['suite']?['path'];
        return p is String && p.endsWith("_test.dart");
      });

      if (suite == null) return <_DocumentLog>[];

      var suitePath = suite['suite']['path'];

      return l
          .whereType<Map>()
          .where((e) => e['messageType'] == 'print')
          .where((e) => _DocumentLog.matches(e['message']))
          .map((e) => _DocumentLog.parse(e['message'], testPath: suitePath));
    }).toList();

    if (documentLogs.isNotEmpty) {
      printBox([
        'LOG DIRECTORY: ${logDir.path}',
        '» JSON report: ${jsonReportFile.path}',
        '» Document logs: ${documentLogs.length}',
      ]);

      var logBuildDir = Directory(pack_path.join(logDir.path, 'build'));
      logBuildDir.createSync();

      _copyPathSync(bonesUICompileDir.path, logBuildDir.path,
          clearIfExists: true);

      for (var e in documentLogs) {
        var id = e.id.trim().replaceAll(RegExp(r'\W+'), '_');

        var testPath = e.testPath;

        String documentsLogDirPath;
        String basePath;
        if (testPath != null) {
          var basename = pack_path.basename(testPath);
          basename = pack_path.withoutExtension(basename);
          basename = basename.replaceAll(RegExp(r'\W+'), '_');
          documentsLogDirPath = pack_path.join(logDir.path, 'test', basename);
          basePath = '../../build/web/';
        } else {
          documentsLogDirPath = pack_path.join(logDir.path, 'test');
          basePath = '../build/web/';
        }

        var documentsLogDir = Directory(documentsLogDirPath)
          ..createSync(recursive: true);

        var fPath = pack_path.join(documentsLogDir.path,
            'document_log--$id--${e.time.millisecondsSinceEpoch}.html');

        var content = e.contentResolved(basePath: basePath, title: e.id);

        var f = File(fPath);
        f.writeAsStringSync(content);

        print('  -- $e\n     >> $fPath');
      }
    }

    return true;
  }

  /// Copies a directory respecting relative links.
  void _copyPathSync(String from, String to, {bool clearIfExists = false}) {
    if (pack_path.canonicalize(from) == pack_path.canonicalize(to)) {
      return;
    }

    if (pack_path.isWithin(from, to)) {
      throw ArgumentError('Cannot copy from $from to $to');
    }

    var toDir = Directory(to);

    if (clearIfExists && toDir.existsSync()) {
      print('-- CLEARING DIRECTORY: $to');
      toDir.deleteSync(recursive: true);
    }

    print('-- COPYING: $from -> $to');
    toDir.createSync(recursive: true);

    var dirList = Directory(from).listSync(recursive: true, followLinks: false);

    for (final file in dirList) {
      var filePath = pack_path.relative(file.path, from: from);

      final copyTo = pack_path.join(to, filePath);

      if (file is Directory) {
        Directory(copyTo).createSync(recursive: true);
      } else if (file is File) {
        File(file.path).copySync(copyTo);
      } else if (file is Link) {
        var target = file.targetSync();

        if (pack_path.isWithin(from, target)) {
          var targetRelative = pack_path.relative(target, from: from);
          var targetTo = pack_path.join(to, targetRelative);
          var copyToDir = pack_path.dirname(copyTo);
          var targetToRelative = pack_path.relative(targetTo, from: copyToDir);
          target = targetToRelative;
        }

        Link(copyTo).createSync(target, recursive: true);
      }
    }
  }

  /// Resolves the test args to pass to the `test` package.
  List<String> resolveTestArgs() {
    var testPlatform = platform;
    var testPauseAfterLoad = parsedArgs.pauseAfterLoad;
    var testDebug = parsedArgs.debug;
    var includeTags = parsedArgs.includeTags.variables.toList();
    var excludeTags = parsedArgs.excludeTags.variables.toList();
    var testsNames = parsedArgs.globalPatterns;
    var testCoverage = parsedArgs.coverage;
    var testReporter = parsedArgs.reporter;
    var testFileReporters = parsedArgs.fileReporters;
    var testNoRetry = parsedArgs.noRetry;

    final suiteDefaults = parsedArgs.suiteDefaults;

    var testTimeout =
        !headleass ? Timeout.none : suiteDefaults.metadata.timeout;

    var testIgnoreTimeouts = suiteDefaults.ignoreTimeouts;
    var testRunSkipped = suiteDefaults.runSkipped;
    var testDart2jsArgs2 = suiteDefaults.dart2jsArgs;
    var testJsTrace = suiteDefaults.jsTrace;

    var testSelections = parsedArgs.testSelections;

    var testsPaths =
        testSelections.keys.where((p) => p.endsWith('.dart')).toList();

    var jsonReportFilePath = this.jsonReportFilePath;

    var logDirectory = this.logDirectory;
    if (logDirectory != null) {
      logDirectory.createSync(recursive: true);
    }

    var testArgs = <String>[
      '--platform',
      testPlatform,
      if (testPauseAfterLoad) '--pause-after-load',
      if (testDebug || showUI) '--debug',
      if (testTimeout !=
          Configuration.empty.suiteDefaults.metadata.timeout) ...[
        '--timeout',
        testTimeout.toString()
      ],
      if (testIgnoreTimeouts) '--ignore-timeouts',
      if (testRunSkipped) '--run-skipped',
      if (testNoRetry) '--no-retry',
      if (testReporter.isNotEmpty) ...['--reporter', testReporter],
      if (testFileReporters.isNotEmpty)
        ...testFileReporters.entries
            .expand((e) => ['--file-reporter', '${e.key}:${e.value}']),
      if (jsonReportFilePath != null) ...[
        '--file-reporter',
        'json:$jsonReportFilePath'
      ],
      if (includeTags.isNotEmpty) ...includeTags.expand((t) => ['-t', t]),
      if (excludeTags.isNotEmpty) ...excludeTags.expand((t) => ['-x', t]),
      if (testsNames.isNotEmpty)
        ...testsNames
            .expand((p) => ['-n', p is RegExp ? p.pattern : p.toString()]),
      if (testCoverage != null && testCoverage.isNotEmpty) ...[
        '--coverage',
        testCoverage
      ],
      if (testJsTrace) '--js-trace',
      if (testDart2jsArgs2.isNotEmpty) ...[
        '--dart2js-args',
        testDart2jsArgs2.join(' ')
      ],
      ...testsPaths
    ];

    return testArgs;
  }

  /// Resolves the test configuration path. Defaults to [bonesUiTestConfigFile].
  String resolveTestConfigurationPath(Configuration testConfiguration) {
    String configurationPath;

    if (testConfiguration.configurationPath == 'dart_test.yaml') {
      if (!bonesUiTestConfigFile.existsSync()) {
        generateBonesUITestConfigFile();
      }

      configurationPath = bonesUiTestConfigFile.path;
    } else {
      configurationPath = testConfiguration.configurationPath;
    }

    return configurationPath;
  }

  /// Generates the
  void generateBonesUITestConfigFile() {
    if (!bonesUITestTemplateFile.existsSync()) {
      generateTestTemplateFile();
    }

    var dartTestConfigFile = File('dart_test.yaml').absolute;
    var includeDartTestConfig = dartTestConfigFile.existsSync();

    var config =
        buildBonesUITestConfig(includeDartTestConfig, dartTestConfigFile);

    bonesUiTestConfigFile.writeAsStringSync(config);
  }

  /// Builds the [bonesUiTestConfigFile] content.
  /// - If [includeDartTestConfig] is `true` should include the [dartTestConfigFile].
  /// - A detected date test configuration file.
  String buildBonesUITestConfig(
      bool includeDartTestConfig, File dartTestConfigFile) {
    String config = '''
##
## AUTO GENERATED:
##   $bonesUiTestCliTitle
##   ${DateTime.now()}
##

timeout: 60s
''';

    if (includeDartTestConfig) {
      config += '\ninclude: ${dartTestConfigFile.path}\n';
    } else {
      config += '\nplatforms: [chrome]\n';
    }

    config += '\ncustom_html_template_path: ${bonesUITestTemplateFile.path}\n';
    return config;
  }

  void generateTestTemplateFile() {
    var template = buildTestTemplateFile();
    bonesUITestTemplateFile.writeAsStringSync(template);
  }

  String buildTestTemplateFile() {
    var template = '''
<!DOCTYPE html>
<html>
<head>
  <title>{{testName}} - Bones_UI Test</title>
  <meta charset="utf-8">
  <link rel="stylesheet" href="../web/styles.css">
  {{testScript}}
  <script src="packages/test/dart.js"></script>
</head>
</html>
''';
    return template;
  }
}

/// A Bones_UI project compiler.
/// To run the UI tests the project must be compiled first.
class BonesUIComiler {
  /// The project directory. Default: [Directory.current]
  final Directory projectDir;

  /// The compilation directory. Defaylts to a random temporary directory (`dart_test_bones_ui_*`)
  final Directory compileDir;

  BonesUIComiler({Directory? projectDir, Directory? compileDir})
      : projectDir = (projectDir ?? Directory.current).absolute,
        compileDir = (compileDir ?? _createTempBonesUICompilerDir()).absolute;

  /// Prepares the compiler.
  Future<void> prepare() async {
    compileDir.createSync(recursive: true);
  }

  final DartRunner _dartRunner = DartRunner();

  /// Compiles the project to [compileDir].
  Future<bool> compile() async {
    compileDir.create(recursive: true);

    var compileDirPath = compileDir.path;

    var projectPath = Directory.current.path;
    print('\n** Compiling Bone_UI project: $projectPath');

    print('-- BonesUI compile directory: $compileDirPath\n');

    var buildArgs = ['run', 'build_runner', 'build', '-o', compileDirPath];

    // dart run build_runner build -o /tmp/compileDir/
    var exitCode = await _dartRunner.runDartCommand(buildArgs,
        workingDirectory: projectPath);

    if (exitCode != 0) {
      throw StateError("Dart build error. Exit code: $exitCode");
    }

    linkWebDirToTestDir();

    return true;
  }

  /// Links the content of the `web/` directory to the `test/` directory.
  /// This is need to allow proper loading of resources,
  /// since the browser runs the tests at the `test/` directory.
  bool linkWebDirToTestDir() {
    var webDir = Directory(pack_path.join(compileDir.path, 'web'));
    if (!webDir.existsSync()) return false;

    var testDir = Directory(pack_path.join(compileDir.path, 'test'));
    if (!testDir.existsSync()) return false;

    _linkDirectoryFiles(testDir, webDir);

    return true;
  }

  void _linkDirectoryFiles(Directory linkDst, Directory targetDir) {
    var list = targetDir.listSync();

    print('** Linking directory content:');
    print('  >> ${targetDir.path} -> ${linkDst.path}');

    //var linkDstDirName = pack_path.basename(linkDst.path);

    for (var e in list) {
      var name = pack_path.basename(e.path);
      if (name.isEmpty || name.startsWith('.')) {
        continue;
      }

      var linkPath = pack_path.join(linkDst.path, name);

      var linkFile = File(linkPath);

      if (!linkFile.existsSync() &&
          linkFile.statSync().type == FileSystemEntityType.notFound) {
        var targetPath = e.path;

        var link = Link(linkPath);
        link.createSync(targetPath);
        //print('  >> Linked: $linkDstDirName/$name -> $targetPath');
      }
    }
  }

  void close() {
    if (compileDir.existsSync()) {
      compileDir.deleteSync(recursive: true);
    }
  }
}

class DartRunner {
  String? _dartExecutable;

  FutureOr<String> get dartExecutable async =>
      _dartExecutable ??= await _executablePath('dart');

  Future<int> runDartCommand(List<String> args,
      {String? workingDirectory, bool inheritStdio = false}) async {
    var dartExecutable = await this.dartExecutable;

    workingDirectory ??= Directory.current.path;

    var processMode =
        inheritStdio ? ProcessStartMode.inheritStdio : ProcessStartMode.normal;

    var process = await Process.start(dartExecutable, args,
        workingDirectory: workingDirectory, mode: processMode);

    if (processMode == ProcessStartMode.normal) {
      var outputDecoder = systemEncoding.decoder;

      process.stdout.transform(outputDecoder).forEach((o) => stdout.write(o));
      process.stderr.transform(outputDecoder).forEach((o) => stderr.write(o));
    }

    var exitCode = await process.exitCode;
    return exitCode;
  }

  static final Map<String, String> _whichExecutables = <String, String>{};

  Future<String> _executablePath(String executableName,
      {bool refresh = false}) async {
    executableName = executableName.trim();

    String? binPath;

    if (!refresh) {
      binPath = _whichExecutables[executableName];
      if (binPath != null && binPath.isNotEmpty) {
        return binPath;
      }
    }

    binPath = await _whichExecutable(executableName);
    binPath ??= '';

    _whichExecutables[executableName] = binPath;

    return binPath.isNotEmpty ? binPath : executableName;
  }

  Future<String?> _whichExecutable(String executableName) async {
    var locator = Platform.isWindows ? 'where' : 'which';
    var result = await Process.run(locator, [executableName]);

    if (result.exitCode == 0) {
      var binPath = '${result.stdout}'.trim();
      return binPath;
    } else {
      return null;
    }
  }
}

/// The Bones_UI plugin:
/// a [PlatformPlugin] based on a wrapped [BrowserPlatform] instance and a [BonesUIComiler].
class BonesUIPlatform extends PlatformPlugin
    implements CustomizablePlatform<ExecutableSettings> {
  static Future<BrowserPlatform> _startBrowserPlatformSafe(String root) async {
    while (true) {
      var platform = await BrowserPlatform.start(root: root);
      var url = platform.url;
      var urlPath = url.path.toLowerCase();

      if (!urlPath.contains('%2f') && !urlPath.contains('%5c')) {
        print('** `BrowserPlatform` start OK: $url');
        return platform;
      }

      print('** `BrowserPlatform` URL has invalid characters: $url');
      platform.close();

      print('-- Retrying `BrowserPlatform.start`...');
    }
  }

  /// Instantiates a [BonesUIPlatform].
  static Future<BonesUIPlatform> create(BonesUIComiler bonesUIComiler,
      {bool showUI = false}) async {
    final compileDirPath = bonesUIComiler.compileDir.path;

    if (compileDirPath.length < 5) {
      throw StateError("Invalid compile directory: $compileDirPath");
    }

    var browserPlatform = await _startBrowserPlatformSafe(compileDirPath);
    return BonesUIPlatform(browserPlatform, bonesUIComiler, showUI: showUI);
  }

  /// The wrapped [BrowserPlatform] instance.
  final BrowserPlatform browserPlatform;

  /// The Bones_UI project compiler.
  final BonesUIComiler bonesUIComiler;

  /// If `true` runs the tests showing the UI in the browser.
  final bool showUI;

  BonesUIPlatform(this.browserPlatform, this.bonesUIComiler,
      {this.showUI = false});

  bool get headleass => !showUI;

  @override
  Future<RunnerSuite?> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Map<String, Object?> message) async {
    print('** Compiling test...');

    var prevWorkingDir = Directory.current;

    var bonesUICompileDir = bonesUIComiler.compileDir;

    Directory.current = bonesUICompileDir;

    var runnerSuite =
        await browserPlatform.load(path, platform, suiteConfig, message);

    Directory.current = prevWorkingDir;

    return runnerSuite;
  }

  @override
  void customizePlatform(Runtime runtime, ExecutableSettings settings) =>
      browserPlatform.customizePlatform(runtime, settings);

  @override
  ExecutableSettings mergePlatformSettings(
          ExecutableSettings settings1, ExecutableSettings settings2) =>
      browserPlatform.mergePlatformSettings(settings1, settings2);

  @override
  ExecutableSettings parsePlatformSettings(YamlMap settings) {
    var map = Map.from(settings);
    map['headless'] = headleass;

    var settings2 = YamlMap.wrap(map);

    return browserPlatform.parsePlatformSettings(settings2);
  }

  /// Closes this instance, the [bonesUIComiler] and the wrapped [browserPlatform].
  @override
  Future close() async {
    await browserPlatform.close();

    return super.close();
  }
}

Directory _createTempBonesUICompilerDir() {
  var tempDir = Directory(Directory.systemTemp.path)
      .createTempSync('dart_test_bones_ui_');
  return Directory(tempDir.resolveSymbolicLinksSync());
}

class _DocumentLog {
  static bool matches(Object? o) {
    if (o == null) return false;
    var s = o.toString();
    return RegExp(r'>>>>>>\d+$').hasMatch(s) &&
        RegExp(r'^\[DOCUMENT\]\s*\[.*?\]<<<<<<.*').hasMatch(s);
  }

  final String id;

  final String content;

  final DateTime time;

  final bool decompressed;

  final String? testPath;

  _DocumentLog(this.id, this.content, this.time,
      {this.decompressed = false, this.testPath});

  factory _DocumentLog.parse(String msg, {String? testPath}) {
    var match = RegExp(
            r'^\[DOCUMENT\]\s*\[(.*?)\]<<<<<<(\(GZIP:.*?\))?\n?(.*?)\n?>>>>>>(\d+)$',
            dotAll: true)
        .firstMatch(msg.trim());

    var id = match!.group(1)!;
    var gzip = match.group(2);
    var content = match.group(3)!;
    var time = int.parse(match.group(4)!);

    var decompressed = false;
    if (gzip != null && gzip.isNotEmpty) {
      decompressed = true;
      content = content.trim();
      var compressed = base64.decode(content);
      var bytes = GZipDecoder().decodeBytes(compressed);
      content = utf8.decode(bytes);
    }

    return _DocumentLog(id, content, DateTime.fromMillisecondsSinceEpoch(time),
        decompressed: decompressed, testPath: testPath);
  }

  String contentResolved({String? basePath, String? title}) {
    var content = this.content;

    if (basePath != null && basePath.isNotEmpty) {
      content = _setContentBasePath(content, basePath);
    }

    if (title != null && title.trim().isNotEmpty) {
      content = _setContentTitle(content, title);
    }

    return content;
  }

  String _setContentBasePath(String content, String basePath) {
    var m = RegExp(r'<base\s+href="(.*?)"(.*?)>',
            caseSensitive: false, dotAll: true)
        .firstMatch(content);

    if (m != null) {
      var attrs = m.group(2) ?? '';

      content = content.replaceFirst(
          RegExp(r'<base\s.*?>'), '<base href="$basePath"$attrs>');
    } else {
      content = content.replaceFirst(
          RegExp(r'<head>'), '<head><base href="$basePath">');
    }
    return content;
  }

  String _setContentTitle(String content, String title) {
    title = title.trim();

    var m = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true)
        .firstMatch(content);

    if (m != null) {
      var prevTitle = m.group(1) ?? '';

      content = content.replaceFirst(
          RegExp(r'<title>.*?</title>'), '<title>$prevTitle - $title</title>');
    } else {
      content = content.replaceFirst(
          RegExp(r'<title>.*?</title>'), '<title>$title</title>');
    }
    return content;
  }

  @override
  String toString({bool withContent = false}) {
    var head =
        'DOCUMENT[$id][$time]${decompressed ? '[decompressed]' : ''}${testPath != null ? '@$testPath' : ''}';
    return withContent
        ? '$head:\n\n$content'
        : '$head{content: ${content.length}}';
  }
}
