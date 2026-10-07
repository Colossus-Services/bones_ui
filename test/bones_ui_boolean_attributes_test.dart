@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';
import 'package:web_utils/web_utils.dart' as web;

/// Boolean attributes in rendered components: a `"true"` (or bare) one is on,
/// a `"false"` one is off. Every `selected="false"` option used to be
/// selected (`dom_builder` < 3.1.1), so a `<select>` showed its last option.
void main() {
  late final _Root uiRoot;

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

  web.HTMLSelectElement selectOf(web.HTMLElement content) =>
      content.querySelector('select') as web.HTMLSelectElement;

  List<String> selectedValues(web.HTMLSelectElement select) => [
    for (var i = 0; i < select.options.length; i++)
      if ((select.options.item(i)! as web.HTMLOptionElement).selected)
        (select.options.item(i)! as web.HTMLOptionElement).value,
  ];

  const options =
      '<option value="en" selected="false">EN</option>'
      '<option value="pt" selected="true">PT</option>'
      '<option value="es" selected="false">ES</option>';

  group('selected options in a rendered select', () {
    test('from an HTML string', () async {
      var content = await renderComponent(() => '<select>$options</select>');
      var select = selectOf(content);
      expect(select.value, equals('pt'));
      expect(selectedValues(select), equals(['pt']));
    });

    test('with an `action` (as an app\'s language select)', () async {
      var content = await renderComponent(
        () => '<select action="#nothing.hide()">$options</select>',
      );
      var select = selectOf(content);
      expect(select.value, equals('pt'));
      expect(selectedValues(select), equals(['pt']));
    });

    test('none selected: the first one shows', () async {
      var content = await renderComponent(
        () =>
            '<select>'
            '<option value="en" selected="false">EN</option>'
            '<option value="pt" selected="false">PT</option>'
            '</select>',
      );
      expect(selectOf(content).value, equals('en'));
    });

    test(r'from $select / $option', () async {
      var content = await renderComponent(
        () => $select(
          options: [
            $option(value: 'a', text: 'A', selected: false),
            $option(value: 'b', text: 'B', selected: true),
            $option(value: 'c', text: 'C', selected: false),
          ],
        ),
      );
      var select = selectOf(content);
      expect(select.value, equals('b'));
      expect(selectedValues(select), equals(['b']));
    });

    test('from a <ui-template> condition', () async {
      var context = UIComponent.domGenerator.domContext!;
      context.putVariable('lang', 'pt');
      addTearDown(() => context.putVariable('lang', null));

      var content = await renderComponent(
        () =>
            '<ui-template><select>'
            '${[
              for (var l in ['en', 'pt', 'es', 'ga']) '<option value="$l" selected="{{:lang==\'$l\'}}true{{?}}false{{/}}">$l</option>',
            ].join()}'
            '</select></ui-template>',
      );
      var select = selectOf(content);
      expect(select.value, equals('pt'));
      expect(selectedValues(select), equals(['pt']));
    });

    test('in a <ui-dialog>, with an `action` and a <ui-template>', () async {
      var context = UIComponent.domGenerator.domContext!;
      context.putVariable('lang', 'es');
      addTearDown(() => context.putVariable('lang', null));

      var content = await renderComponent(
        () =>
            '<div>'
            '<span id="open_lang" action="#bool_lang_dialog.show()">L</span>'
            '<ui-dialog id="bool_lang_dialog" remove-on-hide="false">'
            '<ui-template>'
            '<select action="#bool_lang_dialog.hide()">'
            '${[
              for (var l in ['en', 'pt', 'es', 'ga']) '<option value="$l" selected="{{:lang==\'$l\'}}true{{?}}false{{/}}">$l</option>',
            ].join()}'
            '</select>'
            '</ui-template>'
            '</ui-dialog>'
            '</div>',
      );
      (content.querySelector('#open_lang') as web.HTMLElement).click();
      await testUISleep(ms: 100);

      var select = web.document.querySelector(
        '#bool_lang_dialog select',
      ) as web.HTMLSelectElement;
      expect(select.value, equals('es'));
      expect(selectedValues(select), equals(['es']));
    });
  });

  group('a language dialog as an app declares it', () {
    // As menu_ici_ui's top menu: intl texts in the template, the options
    // marked by the `locale` context variable.
    test('selects the current locale', () async {
      var content = await renderComponent(
        () =>
            '<div>'
            '<img id="app_lang_btn" action="#app_lang_dialog.show()" src="x.svg">'
            '<ui-dialog id="app_lang_dialog" class="language-dialog" remove-on-hide="false">'
            '<br>'
            '<div class="language-dialog-box">'
            '<ui-template>'
            '{{intl:language}}:'
            '<select style="border-radius: 8px" action="#app_lang_dialog.hide(); locale()">'
            '${[
              for (var l in ['en', 'pt', 'es', 'ga']) '<option value="$l" selected="{{:locale==\'$l\'}}true{{?}}false{{/}}">{{intl:locale_$l}}</option>',
            ].join()}'
            '</select>'
            '</ui-template>'
            '</div>'
            '</ui-dialog>'
            '</div>',
      );
      (content.querySelector('#app_lang_btn') as web.HTMLElement).click();
      await testUISleep(ms: 100);

      var select = web.document.querySelector(
        '#app_lang_dialog select',
      ) as web.HTMLSelectElement;
      var current = UIRoot.getCurrentLocale();
      expect(
        selectedValues(select),
        equals([
          if (['en', 'pt', 'es', 'ga'].contains(current)) current else 'en',
        ]),
        reason: 'locale: $current',
      );
    });
  });

  group('other boolean attributes in a rendered component', () {
    test('hidden="false" does not hide, hidden="true" hides', () async {
      var content = await renderComponent(
        () =>
            '<div>'
            '<span class="off" hidden="false">off</span>'
            '<span class="on" hidden="true">on</span>'
            '</div>',
      );
      var off = content.querySelector('.off') as web.HTMLElement;
      var on = content.querySelector('.on') as web.HTMLElement;
      expect(off.hidden.dartify(), isNot(isTrue));
      expect(on.hidden.dartify(), isTrue);
    });

    test('checked / disabled: "false" off, "true" on', () async {
      var content = await renderComponent(
        () =>
            '<div>'
            '<input class="c0" type="checkbox" checked="false">'
            '<input class="c1" type="checkbox" checked="true">'
            '<button class="d0" disabled="false">x</button>'
            '<button class="d1" disabled="true">x</button>'
            '</div>',
      );
      expect(
        (content.querySelector('.c0') as web.HTMLInputElement).checked,
        isFalse,
      );
      expect(
        (content.querySelector('.c1') as web.HTMLInputElement).checked,
        isTrue,
      );
      expect(
        (content.querySelector('.d0') as web.HTMLButtonElement).disabled,
        isFalse,
      );
      expect(
        (content.querySelector('.d1') as web.HTMLButtonElement).disabled,
        isTrue,
      );
    });

    test('multiple="false" select is single', () async {
      var content = await renderComponent(
        () => '<select multiple="false">$options</select>',
      );
      expect(selectOf(content).multiple, isFalse);
    });
  });

  group('component boolean attributes, read as HTML does', () {
    Map<String, DOMAttribute> attrs(Map<String, String> m) => {
      for (var e in m.entries) e.key: DOMAttribute.from(e.key, e.value)!,
    };

    test('parseAttributeBool', () {
      for (var on in ['', 'show', 'SHOW', 'true', '1', 'yes']) {
        expect(
          parseAttributeBool(attrs({'show': on}), 'show', false),
          isTrue,
          reason: 'show="$on"',
        );
      }
      for (var off in ['false', '0', 'no']) {
        expect(
          parseAttributeBool(attrs({'show': off}), 'show', true),
          isFalse,
          reason: 'show="$off"',
        );
      }
      // Absent: the default.
      expect(parseAttributeBool(attrs({}), 'show', true), isTrue);
      expect(parseAttributeBool(attrs({}), 'show', false), isFalse);
      expect(parseAttributeBool(attrs({}), 'show'), isNull);
    });

    test('<bui hide-from-menu>', () {
      bool hidden(String attr) =>
          BUIView(buiCode: '<bui route="r" $attr>x</bui>').isHideFromMenu;
      expect(hidden('hide-from-menu'), isTrue);
      expect(hidden('hide-from-menu=""'), isTrue);
      expect(hidden('hide-from-menu="hide-from-menu"'), isTrue);
      expect(hidden('hide-from-menu="true"'), isTrue);
      expect(hidden('hide-from-menu="false"'), isFalse);
      expect(hidden(''), isFalse);
    });

    UIDialogBase dialogOf(String id) =>
        UIDialog.getAllDialogs().firstWhere((d) => d.content!.id == id);

    test('<ui-dialog show> is shown, show="false" is not', () async {
      await renderComponent(
        () =>
            '<div>'
            '<ui-dialog id="bool_dlg_bare" show>a</ui-dialog>'
            '<ui-dialog id="bool_dlg_name" show="show">b</ui-dialog>'
            '<ui-dialog id="bool_dlg_false" show="false" '
            'remove-on-hide="false">c</ui-dialog>'
            '</div>',
      );
      expect(dialogOf('bool_dlg_bare').isShowing, isTrue);
      expect(dialogOf('bool_dlg_name').isShowing, isTrue);
      expect(dialogOf('bool_dlg_false').isShowing, isFalse);
    });

    test('<ui-dialog remove-on-hide="false">', () async {
      await renderComponent(
        () =>
            '<div>'
            '<ui-dialog id="bool_dlg_keep" remove-on-hide="false">a</ui-dialog>'
            '<ui-dialog id="bool_dlg_bare_rm" show remove-on-hide>b</ui-dialog>'
            '</div>',
      );
      expect(
        (dialogOf('bool_dlg_keep') as UIDialog).removeFromDomOnHide,
        isFalse,
      );
      expect(
        (dialogOf('bool_dlg_bare_rm') as UIDialog).removeFromDomOnHide,
        isTrue,
      );
    });
  });

  group('InputConfig: a form reset keeps the configured state', () {
    web.HTMLFormElement formWith(web.HTMLElement input) {
      var form = web.HTMLFormElement()..append(input);
      uiRoot.content!.append(form);
      addTearDown(() => form.remove());
      return form;
    }

    test('checkbox', () {
      var on =
          InputConfig('c1', 'C1', type: 'checkbox', checked: true).renderInput()
              as web.HTMLInputElement;
      var off =
          InputConfig(
                'c0',
                'C0',
                type: 'checkbox',
                checked: false,
              ).renderInput()
              as web.HTMLInputElement;

      expect(on.checked, isTrue);
      expect(on.hasAttribute('checked'), isTrue);
      expect(off.checked, isFalse);
      expect(off.hasAttribute('checked'), isFalse);

      var form = formWith(
        web.HTMLDivElement()
          ..append(on)
          ..append(off),
      );
      on.checked = false;
      off.checked = true;
      form.reset();
      expect(on.checked, isTrue);
      expect(off.checked, isFalse);
    });

    test('select', () {
      var select =
          InputConfig(
                's',
                'S',
                type: 'select',
                options: {'en': 'EN', 'pt': 'PT', 'es': 'ES'},
                value: 'pt',
              ).renderInput()
              as web.HTMLSelectElement;

      expect(select.value, equals('pt'));
      expect(selectedValues(select), equals(['pt']));
      expect(
        select.querySelector('option[selected]')?.getAttribute('value'),
        equals('pt'),
      );

      var form = formWith(select);
      select.value = 'es';
      form.reset();
      expect(select.value, equals('pt'));
    });

    test('select with a `*` option', () {
      var select =
          InputConfig(
                's',
                'S',
                type: 'select',
                options: {'en': 'EN', 'pt*': 'PT', 'es': 'ES'},
              ).renderInput()
              as web.HTMLSelectElement;

      var form = formWith(select);
      select.value = 'es';
      form.reset();
      expect(select.value, equals('pt'));
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
  _Root(super.rootContainer) : super(id: 'boolean-attributes-root');

  @override
  UIComponent? renderContent() => null;
}
