// A minimal app for `register_components_tree_shaking_test.dart`: one root
// registers none, the other leaves `registerComponents` out, so all of them
// are compiled in.
import 'package:bones_ui/bones_ui.dart';
import 'package:web/web.dart';

void main() {
  if (window.location.hash.isEmpty) {
    _Root(document.body!).initialize();
  } else {
    _DefaultRoot(document.body!).initialize();
  }
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(registerComponents: () {});

  @override
  UIComponent? renderContent() => null;
}

class _DefaultRoot extends UIRoot {
  _DefaultRoot(super.rootContainer);

  @override
  UIComponent? renderContent() => null;
}
