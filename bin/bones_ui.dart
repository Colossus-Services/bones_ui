import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bones_ui/src/bones_ui.dart';
import 'package:bones_ui/src/bones_ui_test_cli.dart' as bones_ui_test_cli;
import 'package:project_template/project_template_cli.dart';
import 'package:resource_portable/resource.dart';

void _consolePrinter(Object? o) {
  print(o);
}

const String cliTitle = '[Bones_UI/${BonesUI.version}]';

List<String> _cmdTestSubArgs = <String>[];

void main(List<String> args) async {
  var commandInfo = MyCommandInfo(cliTitle, _consolePrinter);
  var commandCreate = MyCommandCreate(cliTitle, _consolePrinter);
  var commandTest = MyCommandTest(cliTitle, _consolePrinter);

  await commandInfo.configure();
  await commandCreate.configure();

  var commandRunner = CommandRunner<bool>('bones_api', '$cliTitle - CLI Tool')
    ..addCommand(commandInfo)
    ..addCommand(commandCreate)
    ..addCommand(commandTest);

  commandRunner.argParser.addFlag('version',
      abbr: 'v', negatable: false, defaultsTo: false, help: 'Show version.');

  {
    if (args.isNotEmpty && args[0] == 'test') {
      _cmdTestSubArgs = args.sublist(1).toList();
      args = <String>['test'];
    }

    var argsResult = commandRunner.argParser.parse(args);

    if (argsResult['version']) {
      showVersion();
      return;
    }
  }

  var ok = (await commandRunner.run(args)) ?? false;

  exit(ok ? 0 : 1);
}

void showVersion() {
  print('Bones_UI/${BonesUI.version} - CLI Tool');
}

mixin DefaultTemplate {
  static Uri? _defaultTemplateUri;

  Future<bool> configure() async {
    if (_defaultTemplateUri == null) {
      var resource = Resource(
          'package:bones_ui/src/template/bones_ui_app_template.tar.gz');
      _defaultTemplateUri = await resource.uriResolved;
    }

    return true;
  }

  String? get defaultTemplate {
    return _defaultTemplateUri!.toFilePath();
  }

  String usageWithDefaultTemplate(String usage) {
    var lines = usage.split(RegExp(r'[\r\n]'));

    var idx = lines.lastIndexOf('');

    lines.insert(
      idx,
      '\nDefault Template:\n'
      '  ** Bones_UI App:\n'
      '     $defaultTemplate\n\n'
      'See also:\n'
      '  https://pub.dev/packages/bones_ui#cli',
    );

    return lines.join('\n');
  }
}

class MyCommandInfo extends CommandInfo with DefaultTemplate {
  MyCommandInfo(String cliTitle, ConsolePrinter consolePrinter)
      : super(cliTitle, consolePrinter);

  @override
  String get usage => usageWithDefaultTemplate(super.usage);

  @override
  String? get argTemplate => super.argTemplate ?? defaultTemplate;
}

class MyCommandCreate extends CommandCreate with DefaultTemplate {
  MyCommandCreate(String cliTitle, ConsolePrinter consolePrinter)
      : super(cliTitle, consolePrinter);

  @override
  String get usage => usageWithDefaultTemplate(super.usage);

  @override
  String? get argTemplate => super.argTemplate ?? defaultTemplate;
}

class MyCommandTest extends CommandBase {
  @override
  final String description = 'Run the unit tests of a Bones_UI project.';

  @override
  final String name = 'test';

  MyCommandTest(super.cliTitle, super.consolePrinter) : super();

  @override
  FutureOr<bool> run() async {
    if (bones_ui_test_cli.isJustHelpArgs(_cmdTestSubArgs)) {
      await bones_ui_test_cli.main(['--help']);
      return true;
    }

    var dartRunner = bones_ui_test_cli.DartRunner();

    var exitCode = await dartRunner.runDartCommand(
        ['run', 'bones_ui:bones_ui_test', ..._cmdTestSubArgs],
        inheritStdio: true);

    if (exitCode != 0) {
      // Exit with the dart command exit code:
      exit(exitCode);
    }

    return true;
  }
}
