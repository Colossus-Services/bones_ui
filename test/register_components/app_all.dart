// A minimal app for `register_components_tree_shaking_test.dart`: its root
// leaves out `registerComponents`, so every tag component is registered.
import 'package:bones_ui/bones_ui.dart';
import 'package:web/web.dart';

void main() {
  _Root(document.body!).initialize();
}

class _Root extends UIRoot {
  _Root(super.rootContainer);

  @override
  UIComponent? renderContent() => null;
}
