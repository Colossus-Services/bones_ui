import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bones_ui/src/bones_ui.dart';
import 'package:project_template/project_template_cli.dart';
import 'package:resource_portable/resource.dart';

void _consolePrinter(Object? o) {
  print(o);
}

const String cliTitle = '[Bones_UI/${BonesUI.version}]';

void main(List<String> args) async {
  var commandInfo = MyCommandInfo(cliTitle, _consolePrinter);
  var commandCreate = MyCommandCreate(cliTitle, _consolePrinter);

  await commandInfo.configure();
  await commandCreate.configure();

  var commandRunner = CommandRunner<bool>('bones_api', '$cliTitle - CLI Tool')
    ..addCommand(commandInfo)
    ..addCommand(commandCreate);

  commandRunner.argParser.addFlag('version',
      abbr: 'v', negatable: false, defaultsTo: false, help: 'Show version.');

  {
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
      '  https://pub.dev/packages/bones_ui#CLI',
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
