// A minimal app for `register_components_tree_shaking_test.dart`: both its
// roots register only `<ui-dialog>`.
import 'package:bones_ui/bones_ui.dart';
import 'package:web/web.dart';

void main() {
  if (window.location.hash.isEmpty) {
    _Root(document.body!).initialize();
  } else {
    _OtherRoot(document.body!).initialize();
  }
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(registerComponents: UIDialog.register);

  @override
  UIComponent? renderContent() => null;
}

class _OtherRoot extends UIRoot {
  _OtherRoot(super.rootContainer)
    : super(registerComponents: UIDialog.register);

  @override
  UIComponent? renderContent() => null;
}
