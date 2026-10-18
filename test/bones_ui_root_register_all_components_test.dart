@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// A `UIRoot` without `registerComponents` registers every tag component,
/// as before it existed. Its own file: the components are registered once
/// per app (here, per test file). See
/// `bones_ui_root_register_components_test.dart`.
void main() {
  late final _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  test('registers every tag component', () {
    var registered = UIComponent.domGenerator.registeredElementsGenerators.keys
        .toSet();
    expect(
      registered,
      containsAll([
        'ui-button',
        'ui-button-loader',
        'ui-multi-selection',
        'ui-data-source',
        'ui-document',
        'ui-dialog',
        'ui-svg',
      ]),
    );
  });

  test('`<ui-document>` renders its markdown', () async {
    var holder = web.HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    var component = _Component(
      holder,
      () => '<div><ui-document id="all_doc"># A title</ui-document></div>',
    );
    await component.callRenderAndWait();
    await testUISleep(ms: 200);

    var heading = holder.querySelector('h1');
    expect(heading, isNotNull);
    expect(heading!.textContent, equals('A title'));
  });
}

class _Component extends UIComponent {
  final dynamic Function() renderer;

  _Component(super.parent, this.renderer);

  @override
  dynamic render() => renderer();
}

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'register-all-components-root');

  @override
  UIComponent? renderContent() => null;
}
