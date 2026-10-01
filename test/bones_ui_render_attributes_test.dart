@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

/// Tests of the attributes parsed after a render (`navigate`, `action`,
/// `onEventClick`, `uiLayout`), on the top-level rendered elements and on
/// nested ones (selected through `querySelectorAll`).
void main() {
  late _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot(_Root.new);
    await uiRoot.callRenderAndWait();
  });

  test('nested `action` / `onEventClick` / `navigate`', () async {
    final c = _Actions(uiRoot.content);
    addTearDown(c.delete);
    await c.callRenderAndWait();

    (c.querySelectorNonTyped('#top-act')! as HTMLElement).click();
    (c.querySelectorNonTyped('#deep-act')! as HTMLElement).click();
    (c.querySelectorNonTyped('#deep-evt')! as HTMLElement).click();

    expect(c.actions, equals(['top-action', 'deep-action', 'deep-click']));

    final nav = c.querySelectorNonTyped('#deep-nav')!;
    expect(UINavigator.getNavigateOnClick(nav), equals('deep-route'));
  });

  test('nested attributes from an HTML render', () async {
    final c = _HTMLActions(uiRoot.content);
    addTearDown(c.delete);
    await c.callRenderAndWait();

    (c.querySelectorNonTyped('#html-act')! as HTMLElement).click();
    expect(c.actions, equals(['html-action']));
  });

  test('nested `uiLayout`, not inside SVG', () async {
    final c = _Layouts(uiRoot.content);
    addTearDown(c.delete);
    await c.callRenderAndWait();

    final top = c.querySelectorNonTyped('#layout-top')! as HTMLElement;
    final deep = c.querySelectorNonTyped('#layout-deep')! as HTMLElement;
    final inSVG = c.querySelectorNonTyped('#layout-svg')!;

    expect(top.style.position, equals('relative'));
    expect(deep.style.position, equals('relative'));

    // Not reachable through `HTMLElement`s only: not parsed.
    expect(inSVG.getAttribute('style'), isNull);
  });

  test('re-render parses the new elements', () async {
    final c = _Actions(uiRoot.content);
    addTearDown(c.delete);
    await c.callRenderAndWait();

    c.refresh();

    (c.querySelectorNonTyped('#deep-act')! as HTMLElement).click();
    expect(c.actions, equals(['deep-action']));
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer);

  @override
  UIComponent? renderContent() => null;
}

class _Actions extends UIComponent {
  final List<String> actions = [];

  _Actions(super.parent);

  @override
  dynamic render() => [
    $button(id: 'top-act', attributes: {'action': 'top-action'}, content: 't'),
    $div(
      content: [
        $div(
          content: [
            $button(
              id: 'deep-act',
              attributes: {'action': 'deep-action'},
              content: 'a',
            ),
            $button(
              id: 'deep-evt',
              attributes: {'onEventClick': 'deep-click'},
              content: 'b',
            ),
          ],
        ),
        $span(id: 'deep-nav', attributes: {'navigate': 'deep-route'}),
      ],
    ),
  ];

  @override
  void action(String action) => actions.add(action);
}

class _HTMLActions extends UIComponent {
  final List<String> actions = [];

  _HTMLActions(super.parent);

  @override
  dynamic render() =>
      '<div><p><b id="html-act" action="html-action">x</b></p></div>';

  @override
  void action(String action) => actions.add(action);
}

class _Layouts extends UIComponent {
  _Layouts(super.parent);

  @override
  dynamic render() =>
      '<div id="layout-top" uiLayout="container">'
      '<div><div id="layout-deep" uiLayout="container"></div></div>'
      '<svg><g id="layout-svg" uiLayout="container"></g></svg>'
      '</div>';
}
