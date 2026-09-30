@TestOn('browser')
library;

import 'dart:convert';
import 'dart:math' show Point;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/component/json_render.dart';
import 'package:dynamic_call/dynamic_call.dart'
    show DataSourceHttp, DataSourceOperation, DataSourceOperationHttp;
import 'package:swiss_knife/swiss_knife.dart' show DateTimeWeekDay;
import 'package:test/test.dart';

/// Integration tests (real DOM) for the button, dialog, loading, menu, SVG,
/// color picker, calendar, async, data source and JSON components.

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'components-a-root');

  @override
  UIComponent? renderContent() => null;
}

/// Renders whatever [renderer] returns (e.g. `ui-*` tags resolved by the
/// registered generators).
class _Holder extends UIComponent {
  final Object? Function() renderer;

  _Holder(super.parent, this.renderer);

  @override
  dynamic render() => renderer();
}

class _AsyncCounter extends UIComponentAsync {
  int renders = 0;
  int value = 1;

  _AsyncCounter(Object? parent, {super.cacheRenderAsync, super.refreshInterval})
    : super(parent, null, null, 'loading...', 'error!');

  @override
  Map<String, dynamic> renderPropertiesProvider() => {'v': value};

  @override
  Future<dynamic>? renderAsync(Map<String, dynamic> properties) {
    var n = ++renders;
    return Future.delayed(
      Duration(milliseconds: 20),
      () => 'async ${properties['v']} #$n',
    );
  }
}

/// Matches the same JS object as [expected] (JS `===`): with `dart2wasm` the
/// same JS object can be wrapped by distinct Dart objects.
Matcher _sameJS(JSAny expected) => predicate<Object?>(
  (actual) => (actual as JSAny?).strictEquals(expected).toDart,
  'the same JS object as $expected',
);

/// `EventStream` (swiss_knife) and `DOMElement` listeners are notified
/// asynchronously.
Future<void> _tick() => Future<void>.delayed(Duration(milliseconds: 20));

List<HTMLElement> _children(Element e) =>
    e.children.toList().map((c) => c as HTMLElement).toList();

HTMLElement _child(Element e, int index) =>
    e.children.item(index)! as HTMLElement;

MouseEvent _mouse(String type, Element target, num x, num y) {
  var r = target.getBoundingClientRect();
  return MouseEvent(
    type,
    MouseEventInit(
      clientX: (r.left + x).round(),
      clientY: (r.top + y).round(),
      bubbles: true,
      cancelable: true,
    ),
  );
}

/// The inner elements of a rendered [UIColorPicker] content.
class _PickerParts {
  final HTMLElement viewColor;
  final HTMLElement saturation;
  final HTMLElement saturationBar;
  final HTMLElement luma;
  final HTMLElement lumaBar;
  final HTMLElement square;
  final HTMLElement point;
  final HTMLElement hue;
  final HTMLElement hueBar;

  factory _PickerParts(HTMLElement pickerContent) {
    var all = _child(pickerContent, 0);
    var sls = _child(all, 0);
    var vcs = _child(sls, 0);
    var saturation = _child(vcs, 1);
    var luma = _child(sls, 1);
    var square = _child(sls, 2);
    var hue = _child(all, 1);
    return _PickerParts._(
      _child(vcs, 0),
      saturation,
      _child(saturation, 0),
      luma,
      _child(luma, 0),
      square,
      _child(square, 0),
      hue,
      _child(hue, 0),
    );
  }

  _PickerParts._(
    this.viewColor,
    this.saturation,
    this.saturationBar,
    this.luma,
    this.lumaBar,
    this.square,
    this.point,
    this.hue,
    this.hueBar,
  );
}

Future<HTMLImageElement> _loadImage(String src) async {
  var img = HTMLImageElement();
  var loaded = img.onLoad.first;
  img.src = src;
  await loaded;
  return img;
}

/// A 20x20 PNG: a 4px red border around a blue square.
Future<HTMLImageElement> _borderedImage() {
  var canvas = HTMLCanvasElement()
    ..width = 20
    ..height = 20;
  var ctx = canvas.context2D;
  ctx.fillStyle = 'rgb(255,0,0)'.toJS;
  ctx.fillRect(0, 0, 20, 20);
  ctx.fillStyle = 'rgb(0,0,255)'.toJS;
  ctx.fillRect(4, 4, 12, 12);
  return _loadImage(canvas.toDataUrl('image/png'));
}

Future<List<int>> _pixelOf(String dataURL, int x, int y) async {
  var img = await _loadImage(dataURL);
  var canvas = HTMLCanvasElement()
    ..width = img.naturalWidth
    ..height = img.naturalHeight;
  var ctx = canvas.context2D;
  ctx.drawImage(img, 0, 0);
  return ctx.getImageData(x, y, 1, 1).data.toDart.toList();
}

const _svgIcon =
    '<svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="10" height="10"/></svg>';

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
    // In case a test left it hidden (`hideUIRoot`):
    uiRoot.show();
  });

  group('Changed in 3.1.0', () {
    test('UIButton `fontSize:` (private named parameter)', () async {
      var button = UIButton(uiRoot.content, 'Big', fontSize: '20px');
      await button.callRenderAndWait();

      expect(button.fontSize, equals('20px'));
      var span = button.content!.querySelector('span') as HTMLElement;
      expect(span.style.fontSize, equals('20px'));
      expect(span.textContent, equals('Big'));

      button.fontSize = '';
      expect(button.fontSize, isNull, reason: 'empty is normalized to null');
      await testUISleep(ms: 100);
      expect(button.content!.querySelector('span'), isNull);
      expect(button.content!.textContent, contains('Big'));

      button.fontSize = '12px';
      await testUISleep(ms: 100);
      expect(
        (button.content!.querySelector('span') as HTMLElement).style.fontSize,
        equals('12px'),
      );

      var noSize = UIButton(uiRoot.content, 'Normal');
      await noSize.callRenderAndWait();
      expect(noSize.fontSize, isNull);
      expect(noSize.content!.querySelector('span'), isNull);
    });

    test('UICalendarPopup `buttonText:` (private named parameter)', () async {
      var popup = UICalendarPopup(
        uiRoot.content,
        buttonText: 'Pick a date',
        currentDate: DateTime(2026, 3, 15),
      );
      await popup.callRenderAndWait();

      expect(popup.buttonText, equals('Pick a date'));
      expect(popup.content!.textContent, contains('Pick a date'));

      // Without `buttonText:` the button shows the current date:
      var popup2 = UICalendarPopup(
        uiRoot.content,
        currentDate: DateTime(2026, 3, 15),
        mode: CalendarMode.month,
      );
      await popup2.callRenderAndWait();
      expect(popup2.buttonText, equals('2026/3/15'));
      expect(popup2.content!.textContent, contains('2026/3/15'));

      popup2.currentDate = DateTime(2026, 4, 1);
      await testUISleep(ms: 150);
      expect(popup2.buttonText, equals('2026/4/1'));
      expect(popup2.content!.textContent, contains('2026/4/1'));

      // A fixed `buttonText` doesn't follow the date:
      popup.currentDate = DateTime(2026, 4, 1);
      await testUISleep(ms: 150);
      expect(popup.content!.textContent, contains('Pick a date'));
    });

    test('UICalendar `mode:` defaults to week', () {
      expect(UICalendar(uiRoot.content).mode, equals(CalendarMode.week));
      expect(
        UICalendar(uiRoot.content, mode: CalendarMode.day).mode,
        equals(CalendarMode.day),
      );
      expect(UICalendarPopup(uiRoot.content).mode, equals(CalendarMode.week));
    });

    test(
      'UIColorPickerInput `pickerWidth:`/`pickerHeight:` (default 200)',
      () async {
        var input = UIColorPickerInput(uiRoot.content, value: '#112233');
        await input.callRenderAndWait();
        expect(input.pickerWidth, equals(200));
        expect(input.pickerHeight, equals(200));

        var parts = _PickerParts(
          input.content!.querySelector('.ui-color-picker') as HTMLElement,
        );
        expect(parts.square.style.width, equals('200px'));
        expect(parts.square.style.height, equals('200px'));

        var input2 = UIColorPickerInput(
          uiRoot.content,
          value: '#112233',
          pickerWidth: 120,
          pickerHeight: 80,
        );
        await input2.callRenderAndWait();
        expect(input2.pickerWidth, equals(120));
        expect(input2.pickerHeight, equals(80));

        var parts2 = _PickerParts(
          input2.content!.querySelector('.ui-color-picker') as HTMLElement,
        );
        expect(parts2.square.style.width, equals('120px'));
        expect(parts2.square.style.height, equals('80px'));
      },
    );

    group('UIColorPickerInput initial color (dom_tools 3.1.0 Color.parse)', () {
      Future<_PickerParts> render(String value) async {
        var input = UIColorPickerInput(uiRoot.content, value: value);
        await input.callRenderAndWait();
        expect(input.getFieldValue(), equals(value));
        return _PickerParts(
          input.content!.querySelector('.ui-color-picker') as HTMLElement,
        );
      }

      test('rgb(...)', () async {
        var parts = await render('rgb(10, 20, 30)');
        expect(
          parts.viewColor.style.backgroundColor,
          equals('rgb(10, 20, 30)'),
        );
      });

      test('rgba(...)', () async {
        var parts = await render('rgba(10, 20, 30, 0.5)');
        expect(
          parts.viewColor.style.backgroundColor,
          equals('rgb(10, 20, 30)'),
        );
      });

      test('named', () async {
        var parts = await render('red');
        expect(parts.viewColor.style.backgroundColor, equals('rgb(255, 0, 0)'));
      });

      test('hex', () async {
        var parts = await render('#112233');
        expect(
          parts.viewColor.style.backgroundColor,
          equals('rgb(17, 34, 51)'),
        );
      });

      test('empty (defaults to blue)', () async {
        var parts = await render('');
        expect(parts.viewColor.style.backgroundColor, equals('rgb(0, 0, 255)'));
      });

      test('the parsed `CSSColor.args` keep the alpha', () {
        // The same conversion `UIColorPickerInput` does:
        Color parse(String css) => Color.parse(CSSColor.parse(css)!.args);

        expect(
          parse('rgb(10, 20, 30)'),
          equals(Color.fromARGB(255, 10, 20, 30)),
        );
        expect(parse('red').alpha, equals(255));
        expect(parse('#112233'), equals(Color.fromARGB(255, 17, 34, 51)));

        var rgba = parse('rgba(10, 20, 30, 0.5)');
        expect([rgba.red, rgba.green, rgba.blue], equals([10, 20, 30]));
        expect(rgba.alpha, equals(128));
      });
    });

    test(r'`$ui*` tags accept `Object?` id/classes/style', () {
      var button = $uiButton(
        id: 'b1',
        field: 'f1',
        classes: ['x', 'y'],
        style: 'color: red',
        text: 'T',
      );
      expect(button.tag, equals('ui-button'));
      expect(button.getAttributeValue('id'), equals('b1'));
      expect(button.getAttributeValue('class'), equals('x y'));
      expect(button.getAttributeValue('style'), contains('color: red'));
      expect(button.getAttributeValue('field'), equals('f1'));
      expect(button.text, equals('T'));
      expect($uiButton(field: '').getAttributeValue('field'), isNull);

      var loader = $uiButtonLoader(id: 7, classes: 'a b', style: 'width: 1px');
      expect(loader.tag, equals('ui-button-loader'));
      expect(loader.getAttributeValue('id'), equals('7'));
      expect(loader.getAttributeValue('class'), equals('a b'));
      expect(loader.getAttributeValue('style'), contains('width: 1px'));

      var dialog = $uiDialog(id: 'd1', classes: ['c'], style: 'color: blue');
      expect(dialog.getAttributeValue('id'), equals('d1'));
      expect(dialog.getAttributeValue('class'), equals('c'));
      expect(dialog.getAttributeValue('style'), contains('color: blue'));

      var svg = $uiSVG(
        id: 's1',
        classes: ['i'],
        style: 'margin: 0px',
        width: 24,
        height: 12,
        color: 'red',
        title: 'Icon',
      );
      expect(svg.tag, equals('ui-svg'));
      expect(svg.getAttributeValue('width'), equals('24'));
      expect(svg.getAttributeValue('height'), equals('12'));
      expect(svg.getAttributeValue('color'), equals('red'));
      expect(svg.getAttributeValue('title'), equals('Icon'));
    });

    test(r"`$uiSVG` `'src': ?src`", () {
      expect($uiSVG().getAttribute('src'), isNull);
      expect($uiSVG(src: 'icon.svg').getAttributeValue('src'), 'icon.svg');
    });

    group('UIColorPicker drag handlers (typed `MouseEvent`)', () {
      Future<(UIColorPicker, _PickerParts)> renderPicker() async {
        var picker = UIColorPicker(uiRoot.content, color: Color.BLUE);
        await picker.callRenderAndWait();
        return (picker, _PickerParts(picker.content!));
      }

      test('square: press + drag picks saturation/value', () async {
        var (picker, parts) = await renderPicker();

        var focus = 0;
        picker.onFocus.listen((_) => focus++);

        parts.square.dispatchEvent(_mouse('mousedown', parts.square, 100, 50));
        await _tick();
        expect(focus, equals(1));
        expect(picker.isPressed, isTrue);
        expect(picker.hsvColor!.hue, closeTo(240, 1));
        expect(picker.hsvColor!.saturation, closeTo(0.5, 0.02));
        expect(picker.hsvColor!.value, closeTo(0.75, 0.02));

        parts.square.dispatchEvent(_mouse('mousemove', parts.square, 150, 100));
        expect(picker.hsvColor!.saturation, closeTo(0.75, 0.02));
        expect(picker.hsvColor!.value, closeTo(0.5, 0.02));

        parts.square.dispatchEvent(_mouse('mouseup', parts.square, 150, 100));
        expect(picker.isPressed, isFalse);

        // Not pressed: moving doesn't change the color.
        parts.square.dispatchEvent(_mouse('mousemove', parts.square, 20, 20));
        expect(picker.hsvColor!.saturation, closeTo(0.75, 0.02));

        await testUISleep(ms: 100);
        expect(parts.point.style.left, isNotEmpty);
      });

      test('luma bar drag', () async {
        var (picker, parts) = await renderPicker();

        parts.luma.dispatchEvent(_mouse('mousedown', parts.luma, 5, 10));
        parts.luma.dispatchEvent(_mouse('mousemove', parts.luma, 5, 40));
        expect(picker.hsvColor!.value, closeTo(0.8, 0.02));
        expect(picker.hsvColor!.saturation, closeTo(1, 0.01));

        parts.luma.dispatchEvent(_mouse('mouseup', parts.luma, 5, 40));
        parts.luma.dispatchEvent(_mouse('mousemove', parts.luma, 5, 150));
        expect(picker.hsvColor!.value, closeTo(0.8, 0.02));
      });

      test('saturation bar drag', () async {
        var (picker, parts) = await renderPicker();

        parts.saturation.dispatchEvent(
          _mouse('mousedown', parts.saturation, 10, 5),
        );
        parts.saturation.dispatchEvent(
          _mouse('mousemove', parts.saturation, 150, 5),
        );
        expect(picker.hsvColor!.saturation, closeTo(0.75, 0.02));

        parts.saturation.dispatchEvent(
          _mouse('mouseup', parts.saturation, 150, 5),
        );
        parts.saturation.dispatchEvent(
          _mouse('mousemove', parts.saturation, 20, 5),
        );
        expect(picker.hsvColor!.saturation, closeTo(0.75, 0.02));
      });

      test('hue bar drag', () async {
        var (picker, parts) = await renderPicker();

        var hueWidth = parts.hue.getBoundingClientRect().width;
        expect(hueWidth, equals(225), reason: 'width + bar size (200 / 8)');

        parts.hue.dispatchEvent(_mouse('mousedown', parts.hue, 10, 5));
        parts.hue.dispatchEvent(_mouse('mousemove', parts.hue, 90, 5));
        expect(picker.hsvColor!.hue, closeTo(90 / 225 * 360, 3));

        parts.hue.dispatchEvent(_mouse('mouseup', parts.hue, 90, 5));
        parts.hue.dispatchEvent(_mouse('mousemove', parts.hue, 200, 5));
        expect(picker.hsvColor!.hue, closeTo(90 / 225 * 360, 3));
      });

      test('mouseleave releases all presses', () async {
        var (picker, parts) = await renderPicker();

        parts.square.dispatchEvent(_mouse('mousedown', parts.square, 50, 50));
        expect(picker.isPressed, isTrue);

        picker.content!.dispatchEvent(MouseEvent('mouseleave'));
        expect(picker.isPressed, isFalse);
      });
    });
  });

  group('Regressions', () {
    // (The bar colors are now valid CSS `rgb(...)`; the missing `)` was
    // tolerated by browsers, which auto-close functions at the end of input.)
    test('UIColorPicker luma/hue bars are colored', () async {
      var picker = UIColorPicker(
        uiRoot.content,
        color: Color.fromRGBO(255, 0, 0),
      );
      await picker.callRenderAndWait();
      var parts = _PickerParts(picker.content!);

      expect(parts.lumaBar.style.backgroundColor, equals('rgb(255, 0, 0)'));
      expect(parts.hueBar.style.backgroundColor, equals('rgb(0, 255, 255)'));
    });

    // Regression: the month grid dropped the last day of the month when it
    // fell in the 1st column of a week (it was taken from the remaining days
    // before being placed, ending the loop).
    test('UICalendar month shows every day of the month', () async {
      Future<List<int>> monthDays(DateTime date, DateTimeWeekDay first) async {
        var calendar = UICalendar(
          uiRoot.content,
          mode: CalendarMode.month,
          currentDate: date,
          firstDayOfWeek: first,
        );
        await calendar.callRenderAndWait();

        var cells = calendar.content!
            .querySelectorAll('.ui-calendar-day-cell')
            .toElements();
        expect(cells.length, equals(42), reason: '6 weeks');

        return cells
            .where(
              (c) => !c.classList.contains('ui-calendar-out-of-month-cell'),
            )
            .map((c) => int.parse(c.children.item(0)!.textContent!.trim()))
            .toList();
      }

      // 2026-08-31 is a Monday:
      expect(
        await monthDays(DateTime(2026, 8, 10), DateTimeWeekDay.monday),
        equals(List.generate(31, (i) => i + 1)),
      );

      // 2026-05-31 is a Sunday:
      expect(
        await monthDays(DateTime(2026, 5, 10), DateTimeWeekDay.sunday),
        equals(List.generate(31, (i) => i + 1)),
      );

      // 2026-02 (28 days, starting on a Sunday):
      expect(
        await monthDays(DateTime(2026, 2, 10), DateTimeWeekDay.monday),
        equals(List.generate(28, (i) => i + 1)),
      );
    });

    // Regression: `UILoadingConfig.inline` was ignored (`asDIVElement` kept
    // its `inline = true` default).
    test('UILoadingConfig `inline: false`', () {
      String html(DIVElement div) => div.buildHTML();

      expect(
        html(UILoading.asDIVElement(UILoadingType.ring)),
        contains('display: inline-block'),
      );
      expect(
        html(
          UILoading.asDIVElement(null, config: UILoadingConfig(inline: false)),
        ),
        isNot(contains('display: inline-block')),
      );
      expect(html($uiLoading(inline: false)), isNot(contains('inline-block')));
      expect(html($uiLoading(inline: true)), contains('inline-block'));
    });

    // Regression: the content `display` was set to `node` (ignored).
    test('UIDataSource content is hidden', () async {
      var ds = UIDataSource(uiRoot.content, _dataSource());
      await ds.callRenderAndWait();
      expect(ds.content!.style.display, equals('none'));
      expect(ds.content!.style.visibility, equals('hidden'));
    });

    test('UIDataSource without a data source', () async {
      var ds = UIDataSource(uiRoot.content, null);
      expect(ds.dataSource, isNull);
      expect(await ds.callRenderAndWait(), isTrue);
      expect(ds.isRenderedWithError, isFalse);
      expect(ds.content!.querySelector('pre'), isNull);
    });

    // Regression: strings inside a JSON map/list were parsed as HTML.
    test('UIJsonRender escapes HTML inside JSON', () async {
      var render = UIJsonRender(
        uiRoot.content,
        json: {
          'html': '<b>bold</b>',
          'list': ['<i>x</i>', 1, true, null],
        },
      );
      await render.callRenderAndWait();

      expect(render.content!.querySelector('b'), isNull);
      expect(render.content!.querySelector('i'), isNull);
      var text = render.content!.querySelector('pre')!.textContent!;
      expect(text, contains('"html": "<b>bold</b>"'));
      expect(text, contains('"<i>x</i>"'));
    });

    // Regression: `htmlAsSvgContent` ignored `rootClass` (added `ui-render`)
    // and put the whole `<title>` element (not its text) in the SVG title.
    test('htmlAsSvgContent rootClass and title', () {
      var svg = htmlAsSvgContent(
        '<div><title>My Title</title><p>x</p></div>',
        width: 10,
        height: 20,
        rootClass: 'my-root',
        style: 'p { color: red; }',
      )!;

      expect(svg, contains('viewBox="0 0 10 20"'));
      expect(svg, contains('width="10px" height="20px"'));
      expect(svg, contains('<title>My Title</title>'));
      expect(svg, contains('my-root'));
      expect(svg, isNot(contains('ui-render')));
      expect(svg, contains('p { color: red; }'));

      var noTitle = htmlAsSvgContent('<div>y</div>', width: 1, height: 1)!;
      expect(noTitle, contains('<title>HTML as SVG</title>'));
    });

    // Regression: `renderedElement` wasn't set when rendering from
    // `svgContent` (only from `src`).
    test('UISVG renderedElement from svgContent', () async {
      var svg = UISVG(uiRoot.content, svgContent: _svgIcon);
      await svg.callRenderAndWait();

      expect(svg.renderedElement, isNotNull);
      expect(svg.isRenderedAsSVG, isTrue);
      expect(svg.isRenderedAsImage, isFalse);
      expect(svg.content!.querySelector('svg'), _sameJS(svg.renderedElement!));
    });
  });

  group('UIButton', () {
    test('small, text, content and width', () async {
      var button = UIButton(uiRoot.content, 'A', small: true);
      await button.callRenderAndWait();

      expect(button.content!.classList.contains('ui-button-small'), isTrue);
      expect(button.text, equals('A'));

      button.text = 'B';
      await testUISleep(ms: 100);
      expect(button.buttonContent, equals('B'));
      expect(button.content!.textContent, contains('B'));

      button.buttonContent = $b(content: 'bold');
      await testUISleep(ms: 100);
      expect(button.content!.querySelector('b')!.textContent, equals('bold'));

      button.setWideButton();
      expect(button.content!.style.width, equals('80%'));
      button.setNormalButton();
      expect(button.content!.style.width, isEmpty);

      button.disabled = true;
      await testUISleep(ms: 50);
      expect(button.content!.style.opacity, equals('0.7'));
      button.disabled = false;
      await testUISleep(ms: 50);
      expect(button.content!.style.opacity, isEmpty);
    });

    test('generator: `ui-button` tag', () async {
      var holder = _Holder(
        uiRoot.content,
        () => $div(content: [$uiButton(text: 'Generated')]),
      );
      await holder.callRenderAndWait();
      await testUISleep(ms: 100);

      var button = holder.content!.querySelector('button')!;
      expect(button.textContent, contains('Generated'));
      expect(button.classList.contains('ui-button'), isTrue);
    });

    test('click events and listeners', () async {
      var button = UIButton(uiRoot.content, 'Click');
      await button.callRenderAndWait();

      var events = 0;
      button.registerClickListener((_, _) => events++);

      var changes = 0;
      button.onChange.listen((_) => changes++);

      button.content!.dispatchEvent(
        MouseEvent('click', MouseEventInit(clientX: 1)),
      );
      await testUISleep(ms: 50);
      expect(events, equals(1));
      expect(changes, equals(1));
    });
  });

  group('UIButtonLoader', () {
    test('loading states', () async {
      var loader = UIButtonLoader(
        uiRoot.content,
        'Send',
        loadedTextOK: 'Done',
        loadedTextError: 'Failed',
        loadedTextClass: 'ok-a ok-b',
        loadedTextErrorClass: 'err',
        loadedTextStyle: 'color: green',
        buttonClasses: 'btn',
        buttonStyle: 'font-weight: bold',
      );
      await loader.callRenderAndWait();

      var parts = _children(loader.content!);
      expect(parts.length, equals(3));
      var button = parts[0];
      var loading = parts[1];
      var message = parts[2];

      expect(button.tagName.toLowerCase(), equals('button'));
      expect(button.textContent, equals('Send'));
      expect(button.classList.contains('btn'), isTrue);
      expect(button.style.fontWeight, equals('bold'));
      expect(loading.style.display, equals('none'));
      expect(message.style.display, equals('none'));
      expect(loader.text, equals('Send'));

      // Click starts loading:
      button.dispatchEvent(MouseEvent('click', MouseEventInit(bubbles: true)));
      await testUISleep(ms: 50);
      expect(loading.style.display, equals('inline-block'));
      expect(button.style.display, equals('none'));

      loader.setProgress(0.5);
      expect(loading.querySelector('.ui-loading-progress')!.textContent, '50%');
      loader.setProgress(null);
      expect(loading.querySelector('.ui-loading-progress')!.textContent, '');

      // Error: the button is back, with the error message:
      loader.stopLoading(false);
      expect(loading.style.display, equals('none'));
      expect(button.style.display, isEmpty);
      expect(message.style.display, isEmpty);
      expect(message.textContent, equals('Failed'));
      expect(message.classList.contains('err'), isTrue);
      expect(message.classList.contains('ok-a'), isFalse);

      loader.stopLoading(false, errorMessage: 'Oops');
      expect(message.textContent, equals('Oops'));

      // Reset:
      loader.stopLoading(null);
      expect(button.style.display, isEmpty);
      expect(message.style.display, equals('none'));

      // OK: the button is replaced by the OK message and disabled:
      loader.startLoading();
      loader.stopLoading(true);
      expect(button.style.display, equals('none'));
      expect(message.textContent, equals('Done'));
      expect(message.classList.contains('ok-a'), isTrue);
      expect(message.classList.contains('ok-b'), isTrue);
      expect(message.classList.contains('err'), isFalse);
      expect(message.style.color, equals('green'));
      expect(loader.disabled, isTrue);

      loader.stopLoading(true, okMessage: 'Saved');
      expect(message.textContent, equals('Saved'));
    });

    test('`withProgress` and generator', () async {
      var holder = _Holder(
        uiRoot.content,
        () => $div(
          content: [
            $uiButtonLoader(
              content: 'Upload',
              buttonClasses: 'btn-up',
              withProgress: true,
              loadedTextOK: 'Uploaded',
            ),
          ],
        ),
      );
      await holder.callRenderAndWait();
      await testUISleep(ms: 100);

      var loaderContent = holder.content!.querySelector('.ui-button-loader')!;
      var button = loaderContent.querySelector('button')!;
      expect(button.textContent, contains('Upload'));
      expect(button.classList.contains('btn-up'), isTrue);
      expect(
        loaderContent.querySelector('.ui-loading-progress')!.textContent,
        equals('0%'),
      );
    });

    test('`loadingConfig`', () async {
      var loader = UIButtonLoader(
        uiRoot.content,
        'Go',
        loadingConfig: UILoadingConfig(
          type: UILoadingType.spinner,
          color: 'red',
        ),
      );
      await loader.callRenderAndWait();

      var loading = loader.content!.querySelector('.ui-loading')!;
      expect(loading.children.length, equals(12));
      expect(
        loading.classList.toList().any(
          (c) => c.startsWith('ui-loading-spinner'),
        ),
        isTrue,
      );
    });
  });

  group('UIDialog', () {
    test('not full screen', () async {
      var dialog = UIDialog(
        $div(content: 'small'),
        show: true,
        fullScreen: false,
        backgroundAlpha: 1.0,
        backgroundGrey: 16,
        padding: '10px',
      );
      await testUISleep(ms: 100);

      var style = dialog.content!.style;
      expect(style.left, equals('50%'));
      expect(style.top, equals('50%'));
      expect(style.transform, equals('translate(-50%, -50%)'));
      expect(style.backgroundColor, equals('rgb(16, 16, 16)'));
      expect(style.padding, equals('10px'));
      expect(dialog.content!.textContent, contains('small'));
    });

    test('dialog content as a function', () async {
      var calls = 0;
      var dialog = UIDialog(() {
        calls++;
        return $div(content: 'lazy');
      }, show: true);
      await testUISleep(ms: 100);

      expect(calls, greaterThanOrEqualTo(1));
      expect(dialog.content!.textContent, contains('lazy'));
    });

    test('a dialog button hides; a cancel button cancels', () async {
      var clicked = <String>[];

      var dialog = UIDialog(
        $div(
          content: [
            $button(classes: UIDialogBase.dialogButtonClass, content: 'Go'),
            $button(
              classes: [
                UIDialogBase.dialogButtonClass,
                UIDialogBase.dialogButtonCancelClass,
              ],
              content: 'Cancel',
            ),
            $button(content: 'Other'),
          ],
        ),
        show: true,
        onClickListenOnlyForDialogButtonClass: true,
      );
      dialog.onHide.listen((_) => clicked.add('hide'));
      await testUISleep(ms: 100);

      var buttons = dialog.content!.querySelectorAll('button').toElements();
      expect(buttons.length, equals(3));
      expect(dialog.selectDialogButtons().length, equals(2));

      // A button without the dialog class is ignored:
      (buttons[2] as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(dialog.isShowing, isTrue);

      (buttons[0] as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(dialog.isShowing, isFalse);
      expect(dialog.isCanceled, isFalse);
      expect(clicked, equals(['hide']));

      dialog.show();
      await testUISleep(ms: 100);
      var cancel = dialog.content!.querySelectorAll('button').toElements()[1];
      (cancel as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(dialog.isShowing, isFalse);
      expect(dialog.isCanceled, isTrue);
    });

    test('`btn-cancel` class and the close button cancel', () async {
      var dialog = UIDialog(
        $div(
          content: [$button(classes: 'btn-cancel', content: 'No')],
        ),
        show: true,
        showCloseButton: true,
      );
      await testUISleep(ms: 100);

      expect(dialog.cancelButtonClasses, contains('btn-cancel'));

      var no = dialog.content!.querySelector('.btn-cancel')! as HTMLElement;
      expect(dialog.isCancelButton(no), isTrue);
      no.click();
      await testUISleep(ms: 100);
      expect(dialog.isCanceled, isTrue);

      var dialog2 = UIDialog(
        $div(content: 'x'),
        show: true,
        showCloseButton: true,
      );
      await testUISleep(ms: 100);
      var close =
          dialog2.content!.querySelector(
                '.${UIDialogBase.dialogButtonCancelClass}',
              )!
              as HTMLElement;
      expect(close.textContent, contains('×'));
      close.click();
      await testUISleep(ms: 100);
      expect(dialog2.isCanceled, isTrue);
      expect(dialog2.isShowing, isFalse);
    });

    test('`onlyHideOnCancelButton` / `hideOnDialogButtonClick`', () async {
      var dialog = UIDialog(
        $div(content: [$button(content: 'Keep')]),
        show: true,
      )..onlyHideOnCancelButton = true;
      await testUISleep(ms: 100);

      (dialog.content!.querySelector('button')! as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(dialog.isShowing, isTrue);

      var dialog2 = UIDialog(
        $div(content: [$button(content: 'Keep')]),
        show: true,
      )..hideOnDialogButtonClick = false;
      await testUISleep(ms: 100);
      (dialog2.content!.querySelector('button')! as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(dialog2.isShowing, isTrue);
    });

    test('`removeOnDialogButtonClick` / `removeFromDomOnHide`', () async {
      var dialog = UIDialog(
        $div(content: [$button(content: 'X')]),
        show: true,
        removeFromDomOnHide: false,
      );
      await testUISleep(ms: 100);

      dialog.hide();
      expect(isNodeInDOM(dialog.content!), isTrue);
      expect(dialog.isShowing, isFalse);

      dialog.show();
      dialog.removeOnDialogButtonClick = true;
      await testUISleep(ms: 100);
      (dialog.content!.querySelector('button')! as HTMLElement).click();
      await testUISleep(ms: 100);
      expect(isNodeInDOM(dialog.content!), isFalse);
    });

    test('UIDialogAlert button hides it', () async {
      var dialog = UIDialogAlert('Hello', 'OK', buttonClasses: 'btn-ok');
      var wait = dialog.showAndWait();
      await testUISleep(ms: 100);

      (dialog.content!.querySelector('.btn-ok')! as HTMLElement).click();
      expect(await wait, isTrue);
      expect(dialog.isShowing, isFalse);
    });

    // Regression: the dialog constructor called `_callOnShow`, hiding the
    // `UIRoot` (and firing `onShow`) for a dialog that wasn't shown.
    test('`hideUIRoot`', () async {
      var dialog = UIDialog($div(content: 'x'), hideUIRoot: true);
      var shown = 0;
      dialog.onShow.listen((_) => shown++);
      await _tick();
      expect(uiRoot.content!.style.display, isNot(equals('none')));
      expect(uiRoot.isShowing, isTrue);
      expect(shown, equals(0));

      dialog.show();
      await _tick();
      expect(shown, equals(1));
      await testUISleep(ms: 50);
      expect(uiRoot.content!.style.display, equals('none'));

      dialog.hide();
      await testUISleep(ms: 50);
      expect(uiRoot.content!.style.display, isNot(equals('none')));
    });

    test('background blur', () async {
      var dialog = UIDialog($div(content: 'x'), show: true, backgroundBlur: 3);
      await testUISleep(ms: 50);
      expect(dialog.content!.getAttribute('style'), contains('blur(3px)'));
    });
  });

  group('UIDialogEditImage', () {
    test('zoom in/out and the edited image', () async {
      var image = await _borderedImage();
      var dialog = UIDialogEditImage(image);
      dialog.show();
      await testUISleep(ms: 300);

      var canvas = dialog.content!.querySelector('canvas') as HTMLCanvasElement;
      expect(canvas.width, equals(20));
      expect(canvas.height, equals(20));

      var url = dialog.editedImageDataURL!;
      expect(url, startsWith('data:image/jpeg'));
      expect(dialog.editedImage, isNotNull);

      // At the fit zoom the corner is the red border:
      var corner = await _pixelOf(url, 0, 0);
      expect(corner[0], greaterThan(200), reason: '$corner');
      expect(corner[2], lessThan(60), reason: '$corner');

      var buttons = dialog.content!.querySelectorAll('button').toElements();
      HTMLElement buttonWithText(String text) =>
          buttons.firstWhere((b) => b.textContent!.trim() == text)
              as HTMLElement;

      var plus = buttonWithText('+');
      for (var i = 0; i < 60; ++i) {
        plus.click();
      }
      await testUISleep(ms: 50);

      // Zoomed in (2.2x, centered): the corner is now inside the blue square:
      corner = await _pixelOf(dialog.editedImageDataURL!, 0, 0);
      expect(corner[2], greaterThan(200), reason: '$corner');
      expect(corner[0], lessThan(60), reason: '$corner');

      var minus = buttonWithText('-');
      for (var i = 0; i < 80; ++i) {
        minus.click();
      }
      await testUISleep(ms: 50);

      // Can't zoom out below the fit zoom:
      corner = await _pixelOf(dialog.editedImageDataURL!, 0, 0);
      expect(corner[0], greaterThan(200), reason: '$corner');

      buttonWithText('OK').click();
      await testUISleep(ms: 50);
      expect(dialog.isShowing, isFalse);
    });

    test('drag translates the image', () async {
      var image = await _borderedImage();
      var dialog = UIDialogEditImage(image);
      dialog.show();
      await testUISleep(ms: 300);

      var canvas = dialog.content!.querySelector('canvas') as HTMLCanvasElement;

      // Zoom in so there's room to move:
      var plus =
          dialog.content!
                  .querySelectorAll('button')
                  .toElements()
                  .firstWhere((b) => b.textContent!.trim() == '+')
              as HTMLElement;
      for (var i = 0; i < 50; ++i) {
        plus.click();
      }
      await testUISleep(ms: 50);

      var before = dialog.editedImageDataURL;

      canvas.dispatchEvent(_mouse('mousedown', canvas, 10, 10));
      canvas.dispatchEvent(_mouse('mousemove', canvas, 14, 10));
      canvas.dispatchEvent(_mouse('mouseup', canvas, 14, 10));
      await testUISleep(ms: 50);

      expect(dialog.editedImageDataURL, isNot(equals(before)));
    });
  });

  group('UILoading', () {
    test('getUILoadingType / getUILoadingTypeClass', () {
      expect(getUILoadingType(null), isNull);
      expect(getUILoadingType(UILoadingType.blocks), UILoadingType.blocks);
      expect(getUILoadingType(' Ring '), UILoadingType.ring);
      expect(getUILoadingType('dualRing'), UILoadingType.dualRing);
      expect(getUILoadingType('dual-ring'), UILoadingType.dualRing);
      expect(getUILoadingType('dual_ring'), UILoadingType.dualRing);
      expect(getUILoadingType('roller'), UILoadingType.roller);
      expect(getUILoadingType('spinner'), UILoadingType.spinner);
      expect(getUILoadingType('ripple'), UILoadingType.ripple);
      expect(getUILoadingType('blocks'), UILoadingType.blocks);
      expect(getUILoadingType('ellipsis'), UILoadingType.ellipsis);
      expect(getUILoadingType('unknown'), isNull);

      expect(
        UILoadingType.values.map(getUILoadingTypeClass),
        equals([
          'ui-loading-ring',
          'ui-loading-dual-ring',
          'ui-loading-roller',
          'ui-loading-spinner',
          'ui-loading-ripple',
          'ui-loading-blocks',
          'ui-loading-ellipsis',
        ]),
      );
    });

    test('each type renders its sub-divs and CSS class', () {
      var subDivs = {
        UILoadingType.ring: 4,
        UILoadingType.dualRing: 0,
        UILoadingType.roller: 8,
        UILoadingType.spinner: 12,
        UILoadingType.ripple: 2,
        UILoadingType.blocks: 3,
        UILoadingType.ellipsis: 4,
      };

      for (var e in subDivs.entries) {
        var div = UILoading.asHTMLDivElement(e.key, color: 'red');
        var loading = div.querySelector('.ui-loading')!;
        expect(loading.children.length, equals(e.value), reason: '${e.key}');

        var typeClass = '${getUILoadingTypeClass(e.key)}-red';
        expect(
          loading.classList.contains(typeClass),
          isTrue,
          reason: typeClass,
        );

        var css = document
            .querySelectorAll('style')
            .toElements()
            .map((s) => s.textContent ?? '')
            .join('\n');
        expect(css, contains('.$typeClass'), reason: typeClass);
      }
    });

    test('text, zoom, textZoom, withProgress, cssContext', () {
      var div = UILoading.asHTMLDivElement(
        UILoadingType.ring,
        color: 'blue',
        zoom: 0.5,
        text: 'Loading...',
        textZoom: 1.5,
        withProgress: true,
        inline: false,
      );

      expect(div.style.getPropertyValue('zoom'), equals('0.5'));
      expect(div.style.display, isNot(equals('inline-block')));

      var text = div.querySelector('.ui-loading-text') as HTMLElement;
      expect(text.textContent, equals('Loading...'));
      expect(text.style.color, equals('blue'));
      expect(text.style.fontSize, equals('150%'));

      var progress = div.querySelector('.ui-loading-progress') as HTMLElement;
      expect(progress.textContent, equals('0%'));

      // Color from a CSS context:
      var context = HTMLDivElement()..style.color = 'rgb(0, 128, 0)';
      var div2 = UILoading.asHTMLDivElement(
        UILoadingType.ring,
        cssContext: context,
      );
      var loading2 = div2.querySelector('.ui-loading')!;
      expect(
        loading2.classList.toList().any(
          (c) => c.startsWith('ui-loading-ring-rgb'),
        ),
        isTrue,
        reason: loading2.className,
      );
    });

    test('UILoadingConfig', () {
      var config = UILoadingConfig(
        type: UILoadingType.blocks,
        inline: 'false',
        color: 'red',
        zoom: '0.8',
        text: 'Wait',
        textZoom: 1.2,
        withProgress: true,
      );

      expect(config.type, equals(UILoadingType.blocks));
      expect(config.inline, isFalse);
      expect(config.color, equals('red'));
      expect(config.zoom, equals(0.8));
      expect(config.text, equals('Wait'));
      expect(config.textZoom, equals(1.2));

      var inline = config.toInlineProperties();
      expect(
        inline,
        equals(
          'type: blocks; inline: false; color: red; zoom: 0.8; '
          'textZoom: 1.2; text: Wait; withProgress: true',
        ),
      );
      expect(config.toString(), equals('UILoadingConfig{$inline}'));

      var parsed = UILoadingConfig.parse(inline)!;
      expect(parsed.toInlineProperties(), equals(inline));

      expect(UILoadingConfig.from(null), isNull);
      expect(UILoadingConfig.from(config), same(config));
      expect(UILoadingConfig.from(inline)!.toInlineProperties(), inline);
      expect(
        UILoadingConfig.from({
          'x-type': 'ripple',
          'x-text-zoom': '2.5',
        }, 'x-')!.toInlineProperties(),
        equals('type: ripple; textZoom: 2.5'),
      );
      expect(UILoadingConfig.fromMap({'with-progress': 'true'}), isNull);
      expect(UILoadingConfig.parse(''), isNull);

      var html = config.asDivElement();
      expect(html.querySelector('.ui-loading')!.children.length, equals(3));
      expect(html.querySelector('.ui-loading-text')!.textContent, 'Wait');
      expect(config.asDOMElement.buildHTML(), contains('ui-loading-blocks'));
    });

    test('resolveLoadingElements', () {
      var root = HTMLDivElement();
      document.body!.appendChild(root);
      addTearDown(() => root.remove());

      root.appendHTML(
        '<div class="ui-loading-spinner" style="color: red">Wait</div>'
        '<div class="ui-loading-ripple"></div>',
      );

      UILoading.resolveLoadingElements(root);

      var spinner = root.querySelector('.ui-loading-spinner')!;
      var inner = spinner.querySelector('.ui-loading')!;
      expect(inner.children.length, equals(12));
      expect(inner.classList.contains('ui-loading-spinner-red'), isTrue);
      expect(spinner.querySelector('.ui-loading-text')!.textContent, 'Wait');

      var ripple = root.querySelector('.ui-loading-ripple')!;
      expect(ripple.querySelector('.ui-loading')!.children.length, equals(2));
    });
  });

  group('UIMenu', () {
    test('horizontal entries, separators, titles and actions', () async {
      var actions = <String>[];

      var menu = UIMenu(uiRoot.content, [
        MenuEntry('Home', action: () => actions.add('home')),
        MenuSeparator(content: '||', size: 10),
        MenuEntry(
          'Profile',
          title: 'Your profile',
          action: (MenuEntry e) => actions.add('entry:${e.nameText}'),
          payload: 42,
        ),
      ], itemSeparator: ' / ');
      await menu.callRenderAndWait();

      var text = menu.content!.textContent!;
      expect(text, contains('Home'));
      expect(text, contains('||'));
      expect(text, contains('Profile'));
      expect(text, contains('/'));
      expect(menu.vertical, isFalse);

      var titled = menu.content!.querySelector('[title="Your profile"]');
      expect(titled, isNotNull);
      expect(titled!.textContent, equals('Profile'));

      var entries = menu.content!.children
          .toList()
          .where((e) => e.textContent == 'Home' || e.textContent == 'Profile')
          .toList();
      expect(entries.length, equals(2));

      (entries[0] as HTMLElement).click();
      (entries[1] as HTMLElement).click();
      await _tick();
      expect(actions, equals(['home', 'entry:Profile']));
    });

    test('sub-menu popup', () async {
      var picked = <Object?>[];

      var menu = UIMenu(
        uiRoot.content,
        [
          MenuEntry(
            'File',
            subMenu: [
              MenuEntry(
                'Open',
                action: (MenuEntry e) => picked.add(e.payload),
                payload: 'open',
              ),
              MenuSeparator(size: 4),
              MenuEntry('Close', action: () => picked.add('close')),
            ],
          ),
        ],
        itemOverBgColor: 'rgb(1, 2, 3)',
        popupItemOverBgColor: 'rgb(4, 5, 6)',
        popupOffset: Point(3, 4),
        zIndex: '12',
      );
      await menu.callRenderAndWait();

      expect(menu.content!.style.zIndex, equals('12'));

      var fileEntry = menu.content!.children.toList().firstWhere(
        (e) => e.textContent!.contains('File'),
      ) as HTMLElement;
      // The drop-down icon:
      expect(fileEntry.querySelector('svg'), isNotNull);

      var popupContent =
          uiRoot.content!.querySelectorAll('.ui-popup-menu').toElements().last
              as HTMLElement;
      expect(popupContent.style.display, equals('none'));

      fileEntry.dispatchEvent(MouseEvent('mouseover'));
      await _tick();
      expect(fileEntry.style.backgroundColor, equals('rgb(1, 2, 3)'));
      fileEntry.dispatchEvent(MouseEvent('mouseout'));
      await _tick();
      expect(fileEntry.style.backgroundColor, isEmpty);

      fileEntry.click();
      await testUISleep(ms: 100);
      expect(popupContent.style.display, isNot(equals('none')));
      expect(popupContent.style.position, equals('fixed'));
      expect(fileEntry.style.fontWeight, equals('bold'));

      var popupText = popupContent.textContent!;
      expect(popupText, contains('Open'));
      expect(popupText, contains('Close'));

      var open = popupContent.children.toList().firstWhere(
        (e) => e.textContent == 'Open',
      ) as HTMLElement;
      open.dispatchEvent(MouseEvent('mouseover'));
      await _tick();
      expect(open.style.backgroundColor, equals('rgb(4, 5, 6)'));

      open.click();
      await testUISleep(ms: 50);
      expect(picked, equals(['open']));
      expect(popupContent.style.display, equals('none'));
      expect(fileEntry.style.fontWeight, isEmpty);

      // Toggle open/close:
      fileEntry.click();
      await testUISleep(ms: 50);
      expect(popupContent.style.display, isNot(equals('none')));
      fileEntry.click();
      await testUISleep(ms: 50);
      expect(popupContent.style.display, equals('none'));
    });

    test('vertical is not implemented', () async {
      var menu = UIMenu(uiRoot.content, [MenuEntry('A')], vertical: true);
      await menu.callRenderAndWait();
      expect(menu.content!.textContent, contains('?vertical?'));
    });

    test('MenuEntry', () {
      var entry = MenuEntry('Name', title: 'T', payload: 1);
      expect(entry.nameText, equals('Name'));
      expect(entry.titleText, equals('T'));
      expect(entry.hasAction, isFalse);
      expect(entry.hasSubMenu, isFalse);
      expect(entry.iconElement, isNull);
      expect(entry.toString(), contains('Name'));

      entry.subMenu = [];
      expect(entry.subMenu, isNull, reason: 'An empty sub-menu is null');
      entry.subMenu = [MenuEntry('Sub')];
      expect(entry.hasSubMenu, isTrue);

      expect(MenuEntry('x').titleText, isEmpty);
      expect(() => MenuEntry(null), throwsArgumentError);

      var icon = MenuEntry('I', icon: HTMLSpanElement()..textContent = '*');
      expect(icon.iconElement!.textContent, equals('*'));
    });

    test('UIPopupMenu positions', () async {
      UIPopupMenu popup(PopupPosition position) => UIPopupMenu(
        uiRoot.content,
        [MenuEntry('Item')],
        point: Point(10, 20),
        popupOffset: Point(1, 2),
        popupPosition: position,
      );

      var below = popup(PopupPosition.below);
      expect(below.switchShowing(), isTrue);
      await testUISleep(ms: 50);
      expect(below.content!.style.left, equals('11px'));
      expect(below.content!.style.top, equals('22px'));
      expect(below.content!.style.transform, isEmpty);
      expect(below.renderWidth, isNull, reason: 'point: no width');
      expect(below.switchShowing(), isFalse);

      var upward = popup(PopupPosition.upward)..switchShowing();
      await testUISleep(ms: 50);
      expect(upward.content!.style.transform, equals('translate(0%, -100%)'));

      var left = popup(PopupPosition.leftSide)..switchShowing();
      await testUISleep(ms: 50);
      expect(left.content!.style.transform, equals('translate(-100%, 0%)'));

      expect(
        () => UIPopupMenu(uiRoot.content, []).renderPoint,
        throwsStateError,
      );
    });

    test('UIPopupMenu with a target element and group', () async {
      var target = HTMLDivElement()
        ..style.width = '150px'
        ..style.height = '20px'
        ..style.zIndex = '5'
        ..style.position = 'relative';
      uiRoot.content!.appendChild(target);
      addTearDown(() => target.remove());

      var group = PopupGroup();
      var p1 = UIPopupMenu(
        uiRoot.content,
        [MenuEntry('A')],
        targetElement: target,
        group: group,
      );
      var p2 = UIPopupMenu(
        uiRoot.content,
        [MenuEntry('B')],
        targetElement: target,
        group: group,
        popupPosition: PopupPosition.rightSide,
      );

      expect(group.contains(p1), isTrue);
      expect(group.popups.length, equals(2));

      expect(p1.renderWidth, equals(150));
      expect(p2.renderWidth, isNull);
      expect(p1.renderZIndex, equals('4'));

      var r = target.getBoundingClientRect();
      expect(p1.renderPoint, equals(Point(r.left, r.top + r.height)));
      expect(p2.renderPoint, equals(Point(r.left + r.width, r.top)));

      p1.switchShowing();
      await testUISleep(ms: 50);
      expect(p1.content!.style.minWidth, equals('150px'));
      expect(p1.isShowing, isTrue);

      // Showing a popup hides the others of the group:
      p2.switchShowing();
      expect(p1.isShowing, isFalse);
      expect(p2.isShowing, isTrue);

      group.showAll(p2);
      expect(p1.isShowing, isTrue);
      group.hideAll();
      expect(p1.isShowing, isFalse);
      expect(p2.isShowing, isFalse);

      group.unregister(p2);
      expect(group.contains(p2), isFalse);
      group.clear();
      expect(group.popups, isEmpty);
    });
  });

  group('UISVG', () {
    test('svgContent: dimension, color and title', () async {
      var svg = UISVG(
        uiRoot.content,
        svgContent: _svgIcon,
        width: '24px',
        height: '2em',
        color: 'red',
        title: 'Icon',
      );
      await svg.callRenderAndWait();

      var element = svg.content!.querySelector('svg')!;
      var style = element.getAttribute('style')!;
      expect(style, contains('width: 24px'));
      expect(style, contains('height: 2em'));
      expect(style, contains('fill: red'));
      expect(element.getAttribute('title'), equals('Icon'));
      expect(element.getAttribute('data-toggle'), equals('tooltip'));
      expect(element.hasAttribute('width'), isFalse);

      expect(svg.widthAsCSSLength!.value, equals(24));
      expect(svg.widthAsCSSValue, equals('24px'));
      expect(svg.heightAsCSSValue, equals('2em'));
    });

    test('src not loaded yet renders an image', () async {
      var svg = UISVG(
        uiRoot.content,
        src: 'data:image/svg+xml;base64,${base64Encode(utf8.encode(_svgIcon))}',
        title: 'From src',
      );
      await svg.callRenderAndWait();

      // Not loaded yet: an `img` of the `src`:
      expect(svg.isRenderedAsImage, isTrue);
      var img = svg.content!.querySelector('img') as HTMLImageElement;
      expect(img.src, startsWith('data:image/svg+xml'));
      expect(img.title, equals('From src'));
      expect(img.style.width, equals('20px'));

      // Loaded: re-rendered as the `svg`:
      await testUISleep(ms: 300);
      expect(svg.isRenderedAsSVG, isTrue);
      expect(svg.content!.querySelector('svg'), isNotNull);
      expect(svg.content!.querySelector('img'), isNull);
    });

    test('no src and no svgContent renders nothing', () async {
      var svg = UISVG(uiRoot.content);
      await svg.callRenderAndWait();
      expect(svg.renderedElement, isNull);
      expect(svg.content!.children.length, equals(0));
    });

    test('buildSVGImg and buildRenderedImage', () async {
      var svg = UISVG(
        uiRoot.content,
        svgContent: _svgIcon,
        width: '10px',
        height: '10px',
      );

      var img = svg.buildSVGImg();
      expect(img.src, startsWith('data:image/svg+xml;base64,'));
      expect(img.style.width, equals('10px'));

      var rendered = await svg.buildRenderedImage();
      expect(rendered.src, startsWith('data:image/png'));
      expect(rendered.style.height, equals('10px'));
    });

    test('generator: `ui-svg` tag', () async {
      var holder = _Holder(
        uiRoot.content,
        () => $div(
          content: [
            $uiSVG(
              src:
                  'data:image/svg+xml;base64,${base64Encode(utf8.encode(_svgIcon))}',
              width: '16px',
              height: '16px',
              color: 'blue',
              title: 'Generated',
            ),
          ],
        ),
      );
      await holder.callRenderAndWait();
      await testUISleep(ms: 400);

      var uiSvg = holder.content!.querySelector('.ui-svg')!;
      var element = uiSvg.querySelector('svg')!;
      expect(element.getAttribute('style'), contains('width: 16px'));
      expect(element.getAttribute('style'), contains('fill: blue'));
      expect(element.getAttribute('title'), equals('Generated'));
    });
  });

  group('UIColorPicker / UIColorPickerInput', () {
    test('color setters and change events', () async {
      var picker = UIColorPicker(uiRoot.content, pointSize: 8);
      await picker.callRenderAndWait();
      expect(picker.color, equals(Color.BLUE));

      var changes = <Object?>[];
      picker.onChange.listen(changes.add);

      picker.color = Color.fromRGBO(0, 255, 0);
      expect(picker.hsvColor!.hue, closeTo(120, 0.5));
      await _tick();
      expect(changes.last, equals(Color.fromRGBO(0, 255, 0)));

      picker.hsvColor = HSVColor.fromAHSV(1, 0, 1, 1);
      expect(picker.color, equals(Color.fromRGBO(255, 0, 0)));

      picker.hslColor = HSLColor.fromAHSL(1, 240, 1, 0.5);
      expect(picker.color, equals(Color.BLUE));

      picker.color = null;
      expect(picker.color, equals(Color.black));
      picker.hsvColor = null;
      expect(picker.color, equals(Color.black));
      picker.hslColor = null;
      expect(picker.color, equals(Color.black));
      await _tick();
      expect(changes.length, equals(6));

      picker.color = Color.fromRGBO(255, 0, 0);
      await testUISleep(ms: 100);
      var parts = _PickerParts(picker.content!);
      expect(parts.viewColor.style.backgroundColor, equals('rgb(255, 0, 0)'));
      // The point is the inverse color:
      expect(parts.point.style.backgroundColor, equals('rgb(0, 255, 255)'));
    });

    test('clicking the color view emits onClickColor', () async {
      var picker = UIColorPicker(
        uiRoot.content,
        color: Color.fromRGBO(1, 2, 3),
      );
      await picker.callRenderAndWait();

      var clicked = <Color>[];
      picker.onClickColor.listen(clicked.add);

      _PickerParts(picker.content!).viewColor.click();
      await _tick();
      expect(clicked, equals([Color.fromRGBO(1, 2, 3)]));
    });

    test(
      'input: toggle, typed color, picked color and format switch',
      () async {
        var input = UIColorPickerInput(
          uiRoot.content,
          value: '#ff0000',
          fieldName: 'my-color',
          placeholder: 'Color',
        );
        await input.callRenderAndWait();

        var panel = _child(input.content!, 0);
        var field = _child(panel, 0) as HTMLInputElement;
        var colorButton = _child(panel, 1);
        var pickerContent =
            input.content!.querySelector('.ui-color-picker') as HTMLElement;

        expect(input.fieldName, equals('my-color'));
        expect(field.getAttribute('field'), equals('my-color'));
        expect(field.getAttribute('name'), equals('my-color'));
        expect(field.placeholder, equals('Color'));
        expect(colorButton.style.backgroundColor, equals('rgb(255, 0, 0)'));

        // The picker starts hidden and the color button toggles it:
        expect(pickerContent.style.display, equals('none'));
        colorButton.click();
        expect(pickerContent.style.display, equals('block'));
        colorButton.click();
        expect(pickerContent.style.display, equals('none'));
        colorButton.click();

        // Typing a color updates the picker:
        field.value = 'rgb(0, 0, 255)';
        field.dispatchEvent(Event('change'));
        await testUISleep(ms: 100);
        var parts = _PickerParts(pickerContent);
        expect(parts.viewColor.style.backgroundColor, equals('rgb(0, 0, 255)'));

        // Picking a color updates the input (keeping its RGB format):
        var changes = 0;
        input.onChange.listen((_) => changes++);
        var focused = 0;
        input.onFocus.listen((_) => focused++);

        // (Not at the current color: the input only changes on a new color.)
        parts.square.dispatchEvent(_mouse('mousedown', parts.square, 100, 100));
        parts.square.dispatchEvent(_mouse('mouseup', parts.square, 100, 100));
        await testUISleep(ms: 50);
        expect(focused, equals(1));
        expect(field.value, startsWith('rgb('));
        expect(field.value, isNot(equals('rgb(0, 0, 255)')));
        expect(changes, greaterThanOrEqualTo(1));

        // Double-click switches between RGB and HEX:
        field.value = 'rgb(255, 0, 0)';
        field.dispatchEvent(MouseEvent('dblclick'));
        expect(field.value.toLowerCase(), equals('#ff0000'));
        field.dispatchEvent(MouseEvent('dblclick'));
        expect(field.value, equals('rgb(255, 0, 0)'));

        input.setFieldValue('#00ff00');
        expect(input.getFieldValue(), equals('#00ff00'));
        input.setFieldValue(null);
        expect(input.getFieldValue(), isEmpty);
      },
    );
  });

  group('UICalendar', () {
    test('month mode', () async {
      var today = UICalendar.today();

      var calendar = UICalendar(
        uiRoot.content,
        mode: CalendarMode.month,
        currentDate: today,
        firstDayOfWeek: DateTimeWeekDay.monday,
        events: [
          CalendarEvent(
            'E1',
            today.add(Duration(hours: 10)),
            today.add(Duration(hours: 11)),
          ),
        ],
      );
      await calendar.callRenderAndWait();

      var content = calendar.content!;
      expect(content.querySelectorAll('.ui-calendar-week-cell').length, 7);
      expect(content.querySelectorAll('.ui-calendar-today-cell').length, 1);

      var withEvent = content
          .querySelectorAll('.ui-calendar-day-with-event')
          .toElements();
      expect(withEvent.length, equals(1));
      expect(withEvent.single.textContent, contains('•'));

      var days = <DateTime>[];
      calendar.onDayClick.listen(days.add);
      (withEvent.single as HTMLElement).click();
      await _tick();
      expect(days, equals([today]));

      var titles = 0;
      calendar.onTitleClick.listen((_) => titles++);
      var title = content.querySelector('.ui-calendar-title')! as HTMLElement;
      title.click();
      await _tick();
      expect(titles, equals(1));

      // Next/previous month arrows:
      var changes = 0;
      calendar.onChange.listen((_) => changes++);

      var arrows = _children(title);
      arrows.last.click();
      await testUISleep(ms: 100);
      expect(calendar.currentDate.month, equals(today.nextMonthNumber));
      expect(calendar.currentDate.day, equals(1));

      _children(calendar.content!.querySelector('.ui-calendar-title')!).first
          .click();
      await testUISleep(ms: 100);
      expect(calendar.currentDate.month, equals(today.month));
      expect(changes, equals(2));
    });

    test('month: typing a date in the title', () async {
      var calendar = UICalendar(
        uiRoot.content,
        mode: CalendarMode.month,
        currentDate: DateTime(2026, 3, 15),
      );
      await calendar.callRenderAndWait();

      var text = calendar.content!.querySelector(
        '#ui-calendar-day-date-text',
      ) as HTMLElement;
      var input = calendar.content!.querySelector(
        '#ui-calendar-day-input-date',
      ) as HTMLInputElement;

      expect(text.textContent, equals('2026/03'));
      expect(input.value, equals('2026-03-15'));
      expect(input.style.display, equals('none'));

      // Regression: the date text isn't mapped (no listeners), so updating or
      // hiding it through `elemText.runtime` did nothing.
      // Clicking the text shows the date input:
      text.click();
      await _tick();
      expect(input.style.display, equals('inline'));
      expect(text.style.display, equals('none'));

      input.value = '2026-05-20';
      input.dispatchEvent(Event('change'));
      await _tick();
      expect(text.textContent, equals('2026/05/20'));

      // Applied after the interaction delay:
      await testUISleep(ms: 1500);
      expect(calendar.currentDate, equals(DateTime(2026, 5, 20)));
    });

    test('day mode', () async {
      var date = DateTime(2026, 3, 15);
      var event = CalendarEvent(
        'Meet',
        date.add(Duration(hours: 10)),
        date.add(Duration(hours: 10, minutes: 30)),
        description: 'Room 1',
      );

      var calendar = UICalendar(
        uiRoot.content,
        mode: CalendarMode.day,
        currentDate: date,
        timeInterval: 30,
        events: [event],
        allowedModes: [CalendarMode.day, CalendarMode.month],
      );
      await calendar.callRenderAndWait();

      var content = calendar.content!;
      var hours = content
          .querySelectorAll('.ui-calendar-hour-cell')
          .toElements();
      expect(hours.length, equals(48));
      expect(hours[21].textContent!.trim(), equals('10:30'));

      var eventCell =
          content.querySelector('.ui-calendar-day-events-cell') as HTMLElement;
      expect(eventCell.textContent, contains('Meet'));
      expect(eventCell.textContent, contains('Room 1'));

      var clickedEvents = <CalendarEvent>[];
      calendar.onEventClick.listen(clickedEvents.add);
      var clickedHours = <DateTime>[];
      calendar.onHourClick.listen(clickedHours.add);

      eventCell.click();
      await _tick();
      expect(clickedEvents, equals([event]));
      expect(clickedHours, equals([date.add(Duration(hours: 10))]));

      // Day arrows (title: up, ←, date, →, hidden):
      var title = content.querySelector('.ui-calendar-title')!;
      var spans = _children(title);
      expect(spans.length, equals(5));

      spans[3].click();
      await testUISleep(ms: 100);
      expect(calendar.currentDate, equals(DateTime(2026, 3, 16)));

      _children(
        calendar.content!.querySelector('.ui-calendar-title')!,
      )[1].click();
      await testUISleep(ms: 100);
      expect(calendar.currentDate, equals(date));

      // Up: the previous allowed mode (week isn't allowed):
      _children(
        calendar.content!.querySelector('.ui-calendar-title')!,
      )[0].click();
      await testUISleep(ms: 100);
      expect(calendar.mode, equals(CalendarMode.month));
    });

    test(
      'day mode shows events spanning more than one time interval',
      () async {
        var date = DateTime(2026, 3, 15);
        var calendar = UICalendar(
          uiRoot.content,
          mode: CalendarMode.day,
          currentDate: date,
          events: [
            CalendarEvent(
              'Long',
              date.add(Duration(hours: 10)),
              date.add(Duration(hours: 12)),
            ),
          ],
        );
        await calendar.callRenderAndWait();
        expect(calendar.content!.textContent, contains('Long'));
      },
      skip:
          'BUG?: `CalendarEvent.isInTimeRange` requires the event to be fully '
          'inside the range, so an event longer than `timeInterval` (or '
          'spanning days in month mode) is never rendered',
    );

    test(
      'week mode (the default) renders a calendar panel',
      () async {
        var calendar = UICalendar(uiRoot.content);
        await calendar.callRenderAndWait();
        expect(
          calendar.content!.querySelector('.ui-calendar-panel'),
          isNotNull,
        );
      },
      skip:
          'BUG?: `CalendarMode.week` (the default mode) is not implemented: '
          '`_renderModeWeek` renders nothing',
    );

    test('events, modes and fields', () async {
      var calendar = UICalendar(uiRoot.content, fieldName: 'cal');
      expect(calendar.fieldName, equals('cal'));
      expect(UICalendar(uiRoot.content).fieldName, equals('calendar'));
      expect(calendar.timeInterval, equals(60));
      expect(calendar.currentDate, equals(UICalendar.today()));

      var changes = 0;
      calendar.onChange.listen((_) => changes++);

      var d = DateTime(2026, 1, 1);
      var late = CalendarEvent(
        'Late',
        d.add(Duration(hours: 5)),
        d.add(Duration(hours: 6)),
      );
      var early = CalendarEvent.byDuration('Early', d, Duration(hours: 1));

      calendar.addEvent(late);
      calendar.addEvent(early);
      expect(calendar.events, equals([early, late]), reason: 'Sorted');
      await _tick();
      expect(changes, equals(2));

      // `events` is a copy:
      calendar.events.clear();
      expect(calendar.events.length, equals(2));

      expect(calendar.removeEvent(late), isTrue);
      expect(calendar.removeEvent(late), isFalse);
      await _tick();
      expect(changes, equals(3));

      expect(calendar.selectEvents(d, d.add(Duration(hours: 1))), [early]);
      expect(calendar.selectEvents(d, d.add(Duration(minutes: 30))), isEmpty);

      calendar.events = [late];
      expect(calendar.getFieldValue(), equals([late]));
      await _tick();
      expect(changes, equals(4));

      calendar.setFieldValue([early, late]);
      expect(calendar.getFieldValue()!.length, equals(2));
      calendar.setFieldValue(null);
      expect(calendar.getFieldValue(), isEmpty);

      calendar.mode = CalendarMode.month;
      calendar.mode = CalendarMode.month;
      await _tick();
      expect(changes, equals(5));

      calendar.currentDate = d;
      calendar.currentDate = d;
      await _tick();
      expect(changes, equals(6));

      calendar.allowedModes = [CalendarMode.day];
      calendar.allowedModes = [CalendarMode.day];
      expect(calendar.allowedModes, equals({CalendarMode.day}));
      await _tick();
      expect(changes, equals(7));
      expect(
        () => calendar.allowedModes.add(CalendarMode.week),
        throwsUnsupportedError,
      );

      calendar.nextDay();
      expect(calendar.currentDate, equals(DateTime(2026, 1, 2)));
      calendar.previousDay();
      calendar.previousDay();
      expect(calendar.currentDate, equals(DateTime(2025, 12, 31)));
      calendar.nextMonth();
      expect(calendar.currentDate, equals(DateTime(2026, 1, 1)));
      calendar.previousMonth();
      expect(calendar.currentDate, equals(DateTime(2025, 12, 31)));

      calendar.currentDate = DateTime(2026, 2, 28);
      calendar.nextDay();
      expect(calendar.currentDate, equals(DateTime(2026, 3, 1)));
    });

    test('UICalendarPopup delegates to its calendar', () async {
      var popup = UICalendarPopup(
        uiRoot.content,
        fieldName: 'popup-cal',
        mode: CalendarMode.month,
        currentDate: DateTime(2026, 3, 15),
      );
      await popup.callRenderAndWait();

      expect(popup.fieldName, equals('popup-cal'));
      expect(popup.calendar.fieldName, equals('popup-cal'));
      expect(popup.mode, equals(CalendarMode.month));

      var changes = 0;
      popup.onChange.listen((_) => changes++);

      var e = CalendarEvent.byDuration(
        'E',
        DateTime(2026, 3, 15, 9),
        Duration(hours: 1),
      );
      popup.addEvent(e);
      expect(popup.events, equals([e]));
      expect(popup.getFieldValue(), equals([e]));
      expect(popup.removeEvent(e), isTrue);
      popup.events = [e];
      popup.setFieldValue(null);
      expect(popup.events, isEmpty);
      popup.mode = CalendarMode.day;
      expect(popup.calendar.mode, equals(CalendarMode.day));
      await _tick();
      expect(changes, greaterThanOrEqualTo(4));

      expect(popup.onTitleClick, same(popup.calendar.onTitleClick));
      expect(popup.onHourClick, same(popup.calendar.onHourClick));
      expect(popup.onDayClick, same(popup.calendar.onDayClick));
      expect(popup.onEventClick, same(popup.calendar.onEventClick));

      popup.mode = CalendarMode.month;

      // Clicking the button shows the calendar dialog:
      (popup.content!.querySelector('button')! as HTMLElement).click();
      await testUISleep(ms: 150);
      expect(isNodeInDOM(popup.calendar.content!), isTrue);
      expect(
        popup.calendar.content!.querySelector('.ui-calendar-panel'),
        isNotNull,
      );

      popup.hideCalendar();
      await testUISleep(ms: 50);
      expect(isNodeInDOM(popup.calendar.content!), isFalse);

      popup.showCalendar();
      await testUISleep(ms: 50);
      expect(isNodeInDOM(popup.calendar.content!), isTrue);
    });

    test('CalendarEvent', () {
      var d = DateTime(2026, 3, 15, 10);
      var e = CalendarEvent('Meet', d, d.add(Duration(minutes: 90)));

      expect(e.duration, equals(Duration(minutes: 90)));
      expect(e.description, isEmpty);
      expect(e.toString(), contains('Meet'));
      expect(
        () => CalendarEvent('Bad', d, d.subtract(Duration(minutes: 1))),
        throwsArgumentError,
      );

      expect(e.isInTimeRange(d, d.add(Duration(hours: 2))), isTrue);
      expect(e.isInTimeRange(d, d.add(Duration(hours: 1))), isFalse);

      var json = e.toJson();
      expect(
        json,
        equals({
          'title': 'Meet',
          'initTime': '2026/03/15 10:00',
          'endTime': '2026/03/15 11:30',
        }),
      );
      var back = CalendarEvent.fromJson(json);
      expect(back.initTime, equals(e.initTime));
      expect(back.endTime, equals(e.endTime));
      expect(back.compareTo(e), equals(0));

      var withDescription = CalendarEvent.fromJson({
        'title': 'X',
        'initTime': '2026-03-15 08:00:00',
        'endTime': '2026-03-15T09:00:00',
        'description': 'Desc',
      });
      expect(withDescription.initTime, equals(DateTime(2026, 3, 15, 8)));
      expect(withDescription.toJson()['description'], equals('Desc'));
      expect(withDescription.compareTo(e), lessThan(0));

      var sameStart = CalendarEvent('Y', d, d.add(Duration(minutes: 30)));
      expect(sameStart.compareTo(e), lessThan(0));

      var rendered = withDescription.render().buildHTML();
      expect(rendered, contains('X:<br>'));
      expect(rendered, contains('Desc'));
    });

    test('CalendarModeExtension', () {
      expect(CalendarMode.month.nextMode(), equals(CalendarMode.week));
      expect(CalendarMode.week.nextMode(), equals(CalendarMode.day));
      expect(CalendarMode.day.nextMode(), equals(CalendarMode.day));
      expect(CalendarMode.month.nextMode(week: false), CalendarMode.day);
      expect(
        CalendarMode.month.nextMode(week: false, day: false),
        CalendarMode.month,
      );

      expect(CalendarMode.day.previousMode(), equals(CalendarMode.week));
      expect(CalendarMode.day.previousMode(week: false), CalendarMode.month);
      expect(CalendarMode.week.previousMode(), equals(CalendarMode.month));
      expect(CalendarMode.month.previousMode(), equals(CalendarMode.month));
      expect(
        CalendarMode.day.previousMode(week: false, month: false),
        CalendarMode.day,
      );
    });
  });

  group('UIComponentAsync', () {
    test('validity helpers', () async {
      expect(UIComponentAsync.isValidComponentAsync(null), isFalse);
      expect(UIComponentAsync.isValidLocaleComponentAsync(null), isFalse);

      var component = _AsyncCounter(uiRoot.content);
      expect(UIComponentAsync.isValidComponentAsync(component), isFalse);

      await component.callRenderAndWait();
      await testUISleep(ms: 150);

      expect(
        UIComponentAsync.isValidComponentAsync(component, {'v': 1}),
        isTrue,
      );
      expect(
        UIComponentAsync.isValidComponentAsync(component, {'v': 2}),
        isFalse,
      );
      expect(UIComponentAsync.isValidLocaleComponentAsync(component), isTrue);
      expect(component.hasAutoRefresh, isFalse);
      expect(component.content!.textContent, contains('async 1 #1'));
    });

    test('`cacheRenderAsync: false` re-renders the async content', () async {
      var component = _AsyncCounter(uiRoot.content, cacheRenderAsync: false);
      await component.callRenderAndWait();
      await testUISleep(ms: 150);
      expect(component.renders, equals(1));

      component.refresh();
      await testUISleep(ms: 150);
      component.refresh();
      await testUISleep(ms: 150);

      expect(component.renders, greaterThan(1));
    });

    test('reset / refreshAsyncContent / auto refresh', () async {
      var component = _AsyncCounter(
        uiRoot.content,
        refreshInterval: Duration(milliseconds: 100),
      );
      expect(component.hasAutoRefresh, isTrue);

      await component.callRenderAndWait();
      await testUISleep(ms: 450);
      var auto = component.renders;
      expect(auto, greaterThan(1), reason: 'Auto refresh');

      component.stop();
      await testUISleep(ms: 50);
      var stopped = component.renders;
      await testUISleep(ms: 300);
      expect(component.renders, equals(stopped));

      component.refreshAsyncContent();
      await testUISleep(ms: 100);
      expect(component.renders, equals(stopped), reason: 'Stopped');

      component.reset();
      await testUISleep(ms: 150);
      expect(component.renders, greaterThan(stopped));
      expect(component.isOK, isTrue);
    });
  });

  group('UIDataSource / UIJsonRender', () {
    test('UIDataSource renders its JSON', () async {
      var ds = UIDataSource(uiRoot.content, _dataSource());
      await ds.callRenderAndWait();

      expect(ds.dataSource!.name, equals('items'));
      expect(ds.content!.isHidden, isTrue);
      var pre = ds.content!.querySelector('pre')!;
      expect(pre.textContent, contains('"domain": "test"'));
      expect(pre.textContent, contains('"name": "items"'));

      ds.dataSource = _dataSource(name: 'other');
      expect(ds.dataSource!.name, equals('other'));
      ds.refresh();
      await testUISleep(ms: 100);
      expect(
        ds.content!.querySelector('pre')!.textContent,
        contains('"name": "other"'),
      );
      ds.dataSource = null;
      expect(ds.dataSource, isNull);
    });

    test('UIDataSource generator', () {
      expect(UIDataSource.generator.tag, equals('ui-data-source'));
    });

    test('UIJsonRender values', () async {
      Future<String> render(Object? json) async {
        var r = UIJsonRender(uiRoot.content, json: json);
        await r.callRenderAndWait();
        expect(r.content!.classList.contains('ui-json-render'), isTrue);
        return r.content!.querySelector('pre')!.textContent!;
      }

      expect(await render(null), equals('null'));
      expect(await render(12.5), equals('12.5'));
      expect(await render('a "b" <c>'), equals('"a "b" <c>"'));
      expect(await render(true), equals('true'));
      expect(await render([1, 2]), equals('[\n  1,\n  2\n]'));
      expect(await render({'a': 1}), equals('{\n  "a": 1\n}'));
    });
  });
}

DataSourceHttp _dataSource({String name = 'items'}) => DataSourceHttp(
  'test',
  name,
  baseURL: 'http://localhost/api',
  opGet: DataSourceOperationHttp(DataSourceOperation.get, path: 'items'),
);

extension on DateTime {
  int get nextMonthNumber => month == 12 ? 1 : month + 1;
}
