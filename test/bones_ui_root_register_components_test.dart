@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// `UIRoot(registerComponents: ...)`: an app registers only the tag
/// components its markup uses.
///
/// Its own file: the components are registered once per app (here, per test
/// file), by the first `UIRoot` constructed. The default, all of them, is
/// `bones_ui_root_register_all_components_test.dart`; that the others are
/// left out of the compiled app is `register_components_tree_shaking_test.dart`.
void main() {
  late final _Root uiRoot;

  Set<String> registered() =>
      UIComponent.domGenerator.registeredElementsGenerators.keys.toSet();

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  tearDown(() {
    UIDialog.removeAllDialogs();
  });

  /// Renders [render] in a new component, attached to the root.
  Future<web.HTMLElement> renderComponent(dynamic Function() render) async {
    var holder = web.HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    var component = _Component(holder, render);
    await component.callRenderAndWait();
    await testUISleep(ms: 50);
    return component.content!;
  }

  group('UIRoot `registerComponents`', () {
    test('registers what the app passes, in place of all of them', () {
      expect(_Root.registrations, equals(1));
      expect(registered(), contains('ui-dialog'));
      for (var tag in [
        'ui-button',
        'ui-button-loader',
        'ui-multi-selection',
        'ui-data-source',
        'ui-document',
        'ui-svg',
      ]) {
        expect(registered(), isNot(contains(tag)), reason: tag);
      }
    });

    test('is called once, by the first root', () {
      var second = _Root(createDivInline());
      addTearDown(() => second.content?.remove());
      expect(_Root.registrations, equals(1));
      expect(registered(), isNot(contains('ui-document')));
    });

    test('runs before the first root renders', () {
      expect(_Root.registeredBeforeRender, isTrue);
      expect(uiRoot.isRendered, isTrue);
    });
  });

  group('rendered markup', () {
    test('a registered tag becomes its component', () async {
      var content = await renderComponent(
        () =>
            '<div>'
            '<span id="open_reg" action="#reg_dialog.show()">open</span>'
            '<ui-dialog id="reg_dialog" remove-on-hide="false">'
            '<b id="reg_dialog_text">in the dialog</b>'
            '</ui-dialog>'
            '</div>',
      );

      expect(content.querySelector('ui-dialog'), isNull);
      (content.querySelector('#open_reg') as web.HTMLElement).click();
      await testUISleep(ms: 100);

      var text = web.document.querySelector('#reg_dialog_text');
      expect(text, isNotNull);
      expect(text!.textContent, equals('in the dialog'));
    });

    test('an unregistered tag stays a plain element', () async {
      var content = await renderComponent(
        () => '<div><ui-document id="unreg_doc"># A title</ui-document></div>',
      );

      var doc = content.querySelector('#unreg_doc');
      expect(doc, isNotNull);
      expect(doc!.tagName.toLowerCase(), equals('ui-document'));
      // Not rendered as markdown: no heading, the text as written.
      expect(doc.querySelector('h1'), isNull);
      expect(doc.textContent, equals('# A title'));
      expect(UIComponent.getContentUIComponent(doc), isNull);
    });

    test('a component created in code needs no registration', () async {
      var dialog = UIDialog($div(content: 'from code'));
      dialog.show();
      await testUISleep(ms: 50);
      expect(dialog.isShowing, isTrue);
      expect(dialog.content!.textContent, contains('from code'));
    });
  });
}

class _Component extends UIComponent {
  final dynamic Function() renderer;

  _Component(super.parent, this.renderer);

  @override
  dynamic render() => renderer();
}

class _Root extends UIRoot {
  static int registrations = 0;

  /// Whether the registration ran before the first root's render.
  static bool registeredBeforeRender = false;

  static bool _rendering = false;

  _Root(super.rootContainer)
    : super(
        id: 'register-components-root',
        registerComponents: () {
          registrations++;
          registeredBeforeRender = !_rendering;
          UIDialog.register();
        },
      );

  @override
  UIComponent? renderContent() {
    _rendering = true;
    return null;
  }
}
