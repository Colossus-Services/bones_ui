import 'package:bones_ui/src/bones_ui_test_cli.dart' as bones_ui_test_cli;

/// To run a `Bones_UI` project tests properly,
/// this executable should be called by `bones_ui test`:
///
/// ```bash
///   dart run bones_ui:bones_ui_test %args
/// ```
///
/// This is a similar approch of `dart test`,
/// that actually calls `dart run test:test %args`.
Future<void> main(List<String> args) async {
  await bones_ui_test_cli.main(args);
}
