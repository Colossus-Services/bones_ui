@TestOn('vm')
library;

import 'dart:io';

import 'package:bones_ui/src/bones_ui.dart';
import 'package:path/path.dart' as pack_path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('BonesUI.version', () {
    setUp(() {});

    test('Check Version', () async {
      var projectDirectory = _getProjectDirectory();

      print(projectDirectory);

      var pubspecFile =
          File(pack_path.join(projectDirectory.path, 'pubspec.yaml'));

      print('pubspecFile: $pubspecFile');

      var pubSpec = loadYaml(pubspecFile.readAsStringSync()) as Map;

      var pubSpecName = pubSpec['name'];
      var pubSpecVer = pubSpec['version'];

      print('PubSpec.name: $pubSpecName');
      print('PubSpec.version: $pubSpecVer');

      var version = BonesUI.version;

      print('BonesUI.version: $version');

      expect(pubSpecName, equals('bones_ui'),
          reason: 'PubSpec.name[$pubSpecName] != `bones_ui`');

      expect(pubSpecVer, equals(version),
          reason: 'BonesUI.version[$version] != PubSpec.version[$pubSpecVer]');
    });
  });
}

Directory _getProjectDirectory() {
  var current = Directory.current.absolute;
  var parent = current.parent;

  var knownFile = 'bones_ui_version_test.dart';

  var files = [
    File(pack_path.join(current.path, 'test/$knownFile')),
    File(pack_path.join(parent.path, 'test/$knownFile')),
  ];

  var fileOk = files.where((f) => f.existsSync()).first;

  var projectDir = fileOk.parent.parent;

  return projectDir;
}
