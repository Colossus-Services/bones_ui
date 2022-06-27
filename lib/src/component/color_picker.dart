import 'dart:html';

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';

class UIColorPickerInput extends UIComponent implements UIField<String> {
  @override
  final String fieldName;
  final String _initialValue;

  final String? placeholder;

  final int _pickerWidth;

  final int _pickerHeight;

  UIColorPickerInput(Element? parent,
      {this.placeholder,
      String? fieldName,
      String? value = '',
      int pickerWidth = 200,
      int pickerHeight = 200})
      : fieldName = fieldName ?? 'color-picker',
        _initialValue = value ?? '',
        _pickerWidth = pickerWidth,
        _pickerHeight = pickerHeight,
        super(parent);

  @override
  String getFieldValue() => _input?.value ?? '';

  int get pickerWidth => _pickerWidth;

  int get pickerHeight => _pickerHeight;

  InputElement? _input;

  @override
  dynamic render() {
    content!.style.width = '100%';

    var input = _input = _renderGenericInput('text', _initialValue);
    input.setAttribute('id', fieldName);
    input.setAttribute('name', fieldName);
    input.setAttribute('field', fieldName);

    if (placeholder != null) {
      input.setAttribute('placeholder', placeholder!);
    }

    var cssColor = CSSColor.parse(_initialValue) ?? CSSColorName('grey');

    var color =
        isNotEmptyObject(_initialValue) ? Color.parse(cssColor.args) : null;

    var colorButton = createDivInline()
      ..style.width = '20px'
      ..style.height = '20px'
      ..style.marginLeft = '2px'
      ..style.backgroundColor = '$cssColor'
      ..style.border = '3px solid #000'
      ..style.verticalAlign = 'middle';

    var panel = createDivInline()
      ..style.width = '100%'
      ..style.whiteSpace = 'nowrap';

    panel.append(input);
    panel.append(colorButton);

    var picker = UIColorPicker(content,
        color: color, width: _pickerWidth, height: _pickerHeight)
      ..content!.style.display = 'none'
      ..content!.style.paddingRight = '22px';

    var inputInteractionCompleter = InteractionCompleter('UIColorPickerInput',
        triggerDelay: Duration(seconds: 2), functionToTrigger: () {
      _updateColorFromInput(input, picker);
    });

    input.onKeyUp.listen((_) {
      inputInteractionCompleter.interact();
    });

    input.onChange.listen((_) {
      _updateColorFromInput(input, picker);
    });

    input.onDoubleClick.listen((_) {
      _switchColorInputType(input, picker);
    });

    picker.onChange.listen((color) {
      _updateColorFromPicker(color, input, colorButton);
    });

    picker.onClickColor.listen((_) {
      _switchColorInputType(input, picker);
    });

    picker.onFocus.listen((_) {
      onFocus.add(this);
    });

    colorButton.onClick.listen((_) {
      if (picker.content!.style.display == 'none') {
        picker.content!.style.display = 'block';
      } else {
        picker.content!.style.display = 'none';
      }
    });

    return [panel, picker];
  }

  void _updateColorFromPicker(
      color, InputElement input, DivElement colorButton) {
    var pickerColor = CSSColor.from([color.red, color.green, color.blue]);

    var inputColor = CSSColor.from(input.value);

    if (inputColor != null) {
      if (inputColor is CSSColorHEX) {
        pickerColor = pickerColor!.asCSSColorHEX;
      } else {
        pickerColor = pickerColor!.asCSSColorRGB;
      }
    }

    var pickerColorStr = pickerColor.toString();

    if (pickerColorStr != input.value) {
      input.value = pickerColorStr;
      colorButton.style.backgroundColor = '$pickerColor';

      _dispatchInputChange(input);
      onChange.add(input);
    }
  }

  EventStream<UIColorPickerInput> onFocus = EventStream();

  void _dispatchInputChange(InputElement input) {
    input.dispatchEvent(Event('change'));
  }

  void _updateColorFromInput(InputElement input, UIColorPicker picker) {
    var inputColor = CSSColor.from(input.value);

    var color = picker.color!;
    var pickerColor = CSSColor.from([color.red, color.green, color.blue]);

    if (inputColor != null && inputColor != pickerColor) {
      picker.color = Color.parse(inputColor.args);
    }
  }

  void _switchColorInputType(InputElement input, UIColorPicker picker) {
    var inputColor = CSSColor.from(input.value);

    if (inputColor != null) {
      CSSColor setColor;
      if (inputColor is CSSColorHEX) {
        setColor = inputColor.asCSSColorRGB;
      } else {
        setColor = inputColor.asCSSColorHEX;
      }

      input.value = setColor.toString();

      _dispatchInputChange(input);
    }
  }

  InputElement _renderGenericInput(String inputType, inputValue) {
    var inputHtml = '''
      <input style='width: calc(100% - 20px)' type="$inputType" ${inputValue != null ? 'value="$inputValue"' : ''}>
    ''';

    var input = createHTML(inputHtml);
    return input as InputElement;
  }
}

class UIColorPicker extends UIComponent {
  int width;

  int height;

  int pointSize;

  UIColorPicker(Element? parent,
      {Color? color, this.width = 200, this.height = 200, this.pointSize = 6})
      : super(parent, componentClass: 'ui-color-picker') {
    this.color = color ?? Color.BLUE;
  }

  EventStream<UIColorPicker> onFocus = EventStream();

  EventStream<Color> onClickColor = EventStream();

  @override
  void configure() {
    var content = this.content!;
    content.style.textAlign = 'center';
    _disableTransitions(content);
  }

  Color? _color;

  HSVColor? _hsvColor;

  HSLColor? _hslColor;

  Color? _baseColor;

  set color(Color? color) {
    color ??= Color.black;

    _color = color;
    _hsvColor = HSVColor.fromColor(color);
    _hslColor = HSLColor.fromColor(color);
    _baseColor = HSLColor.fromAHSL(1, _hsvColor!.hue, 1, 0.50).toColor();

    _notifyColorChange();

    refresh();
  }

  set hsvColor(HSVColor? hsvColor) {
    hsvColor ??= HSVColor.fromColor(Color.black);

    _color = hsvColor.toColor();
    _hsvColor = hsvColor;
    _hslColor = HSLColor.fromColor(_color!);
    _baseColor = HSLColor.fromAHSL(1, hsvColor.hue, 1, 0.50).toColor();

    _notifyColorChange();

    refresh();
  }

  set hslColor(HSLColor? hsvColor) {
    hsvColor ??= HSLColor.fromColor(Color.black);

    _color = hsvColor.toColor();
    _hsvColor = HSVColor.fromColor(_color!);
    _hslColor = hsvColor;
    _baseColor = HSLColor.fromAHSL(1, hsvColor.hue, 1, 0.50).toColor();

    _notifyColorChange();

    refresh();
  }

  void _notifyColorChange() {
    onChange.add(color);
  }

  Color? get color => _color;

  HSVColor? get hsvColor => _hsvColor;

  HSLColor? get hslColor => _hslColor;

  // ignore: non_constant_identifier_names
  DivElement? _panel_all;

  // ignore: non_constant_identifier_names
  DivElement? _panel_ViewColor_Saturation;

  // ignore: non_constant_identifier_names
  DivElement? _panel_Saturation_Luma_Square;

  DivElement? _viewColor;

  DivElement? _saturation;

  DivElement? _luma;

  DivElement? _square;

  DivElement? _hue;

  DivElement? _point;

  DivElement? _saturationBar;

  DivElement? _lumaBar;

  DivElement? _hueBar;

  bool _squarePressed = false;

  bool _lumaPressed = false;

  bool _saturationPressed = false;

  bool _huePressed = false;

  int get _barSize => Math.max(width, height) ~/ 8;

  int get _pointSizeHalf => pointSize ~/ 2;

  @override
  dynamic render() {
    var barSize = _barSize;
    var pointSizeHalf = _pointSizeHalf;

    if (_panel_all == null) {
      _panel_all = createDivInlineBlock();

      _disableTransitions(_panel_all!);

      _panel_Saturation_Luma_Square = createDiv()
        ..style.width = '${width + barSize}px'
        ..style.height = '${height + barSize}px';

      _disableTransitions(_panel_Saturation_Luma_Square!);

      _panel_ViewColor_Saturation = createDiv()
        ..style.width = '${width + barSize}px'
        ..style.height = '${barSize}px';

      _disableTransitions(_panel_ViewColor_Saturation!);

      _viewColor = createDivInline()
        ..style.width = '${barSize}px'
        ..style.height = '${barSize}px';

      _disableTransitions(_viewColor!);

      _saturation = createDivInline()
        ..style.width = '${width}px'
        ..style.height = '${barSize}px';

      _disableTransitions(_saturation!);

      _panel_ViewColor_Saturation!.children.add(_viewColor!);
      _panel_ViewColor_Saturation!.children.add(_saturation!);

      _luma = createDivInline()
        ..style.width = '${barSize}px'
        ..style.height = '${height}px';

      _disableTransitions(_luma!);

      _square = createDivInline()
        ..style.width = '${width}px'
        ..style.height = '${height}px';

      _disableTransitions(_square!);

      _point = createDiv()
        ..style.width = '${pointSize}px'
        ..style.height = '${pointSize}px'
        ..style.borderRadius = '${pointSizeHalf}px'
        ..style.position = 'relative';

      _disableTransitions(_point!);

      _square!.children.add(_point!);

      _lumaBar = createDiv()
        ..style.width = '${barSize}px'
        ..style.height = '1px'
        ..style.position = 'relative';

      _disableTransitions(_lumaBar!);

      _luma!.children.add(_lumaBar!);

      _saturationBar = createDiv()
        ..style.width = '1px'
        ..style.height = '${barSize}px'
        ..style.backgroundColor = 'rgb(0,0,0)'
        ..style.position = 'relative';

      _disableTransitions(_saturationBar!);

      _saturation!.children.add(_saturationBar!);

      _panel_Saturation_Luma_Square!.children.add(_panel_ViewColor_Saturation!);
      _panel_Saturation_Luma_Square!.children.add(_luma!);
      _panel_Saturation_Luma_Square!.children.add(_square!);

      _hue = createDiv()
        ..style.backgroundColor = 'red'
        ..style.width = '${width + barSize}px'
        ..style.height = '${barSize}px'
        ..style.background =
            'linear-gradient(to right, #ff0000 0%, #ffff00 17%, #00ff00 33%, #00ffff 50%, #0000ff 67%, #ff00ff 83%, #ff0000 100%)';

      _disableTransitions(_hue!);

      _hueBar = createDiv()
        ..style.width = '1px'
        ..style.height = '${barSize}px'
        ..style.position = 'relative';

      _disableTransitions(_hueBar!);

      _hue!.children.add(_hueBar!);

      _panel_all!.children.add(_panel_Saturation_Luma_Square!);
      _panel_all!.children.add(_hue!);

      //

      _viewColor!.onClick.listen((_) {
        onClickColor.add(color!);
      });

      //

      _square!.onMouseDown.listen((event) {
        _squareDown(event);
        _squareDrag(event);
      });
      _square!.onMouseUp.listen(_squareUp);
      _square!.onMouseMove.listen(_squareDrag);

      redirectOnTouchStartToMouseEvent(_square!);
      _square!.onTouchEnd.listen(_squareUp);
      redirectOnTouchMoveToMouseEvent(_square!);

      _square!.onClick.listen(_squareClick);

      //

      _luma!.onMouseDown.listen(_lumaDown);
      _luma!.onMouseUp.listen(_lumaUp);
      _luma!.onMouseMove.listen(_lumaDrag);

      _luma!.onTouchStart.listen(_lumaDown);
      _luma!.onTouchEnd.listen(_lumaUp);
      redirectOnTouchMoveToMouseEvent(_luma!);

      _luma!.onClick.listen(_lumaClick);

      //

      _saturation!.onMouseDown.listen(_saturationDown);
      _saturation!.onMouseUp.listen(_saturationUp);
      _saturation!.onMouseMove.listen(_saturationDrag);

      _saturation!.onTouchStart.listen(_saturationDown);
      _saturation!.onTouchEnd.listen(_saturationUp);
      redirectOnTouchMoveToMouseEvent(_saturation!);

      _saturation!.onClick.listen(_saturationClick);

      //

      _hue!.onMouseDown.listen(_hueDown);
      _hue!.onMouseUp.listen(_hueUp);
      //_hue.onMouseLeave.listen(_hueUp);
      _hue!.onTouchStart.listen(_hueDown);
      //_hue.onTouchEnd.listen(_hueUp);
      _hue!.onClick.listen(_hueClick);
      _hue!.onMouseMove.listen(_hueDrag);

      //

      content!.onMouseLeave.listen(_allUp);
      content!.onTouchEnd.listen(_allUp);
    }

    var saturationX = _clip((_hsvColor!.saturation * width), 0, width);
    var lumaY = _clip(((1 - _hsvColor!.value) * height), 0, height);
    var hueX =
        _clip(((_hsvColor!.hue / 360) * (width + barSize)), 0, width + barSize);

    _point!.style.left = '${saturationX - pointSizeHalf}px';
    _point!.style.top = '${lumaY - pointSizeHalf}px';

    var c = Color.fromARGB(
        255, 255 - _color!.red, 255 - _color!.green, 255 - _color!.blue);
    _point!.style.background = 'rgb(${c.red},${c.green},${c.blue})';

    _saturationBar!.style.left = '${saturationX}px';
    _lumaBar!.style.top = '${lumaY}px';
    _hueBar!.style.left = '${hueX}px';

    _lumaBar!.style.backgroundColor =
        'rgb(${_baseColor!.red},${_baseColor!.green},${_baseColor!.blue}';

    _hueBar!.style.backgroundColor =
        'rgb(${255 - _baseColor!.red},${255 - _baseColor!.green},${255 - _baseColor!.blue}';

    _viewColor!.style.backgroundColor =
        'rgb(${_color!.red},${_color!.green},${_color!.blue})';

    _saturation!.style.background =
        'linear-gradient(90deg, rgba(0,0,0,0), rgba(${_baseColor!.red},${_baseColor!.green},${_baseColor!.blue},1))';

    _luma!.style.background =
        'linear-gradient(0deg, rgba(0,0,0,1), rgba(0,0,0,0) )';
    _square!.style.background =
        'linear-gradient(0deg, rgba(0,0,0,1), rgba(0,0,0,0) ), linear-gradient(270deg, rgb(${_baseColor!.red},${_baseColor!.green},${_baseColor!.blue}), rgb(255,255,255))';

    return _panel_all;
  }

  void _squareClick(MouseEvent event) {
    var target = event.target;
    if (target == _square) {
      var x = event.offset.x.toInt();
      var y = event.offset.y.toInt();
      _adjustPoint(x, y);
    }
  }

  void _squareDrag(MouseEvent event) {
    if (_squarePressed) {
      _squareClick(event);
    } else if (_saturationPressed) {
      _saturationDrag(event);
    } else if (_lumaPressed) {
      _lumaDrag(event);
    } else if (_huePressed) {
      _hueDrag(event);
    }
  }

  void _lumaClick(MouseEvent event) {
    var target = event.target;
    if (target == _luma || target == _square) {
      var y = event.offset.y.toInt();
      _adjustLumaBar(y);
    }
  }

  void _lumaDrag(event) {
    if (_lumaPressed) {
      _lumaClick(event);
    } else if (_huePressed) {
      _hueDrag(event);
    }
  }

  void _saturationClick(MouseEvent event) {
    var target = event.target;
    if (target == _saturation || target == _square) {
      var x = event.offset.x.toInt();
      _adjustSaturationBar(x);
    }
  }

  void _saturationDrag(event) {
    if (_saturationPressed) {
      _saturationClick(event);
    }
  }

  void _hueClick(MouseEvent event) {
    var target = event.target;
    if (target == _hue || target == _square || target == _luma) {
      var x = event.offset.x.toInt();
      if (target == _square) {
        x += _barSize;
      }
      _adjustHueBar(x);
    }
  }

  void _hueDrag(event) {
    if (_huePressed) {
      _hueClick(event);
    }
  }

  void _allUp(_) {
    _squareUp(_);
    _lumaUp(_);
    _saturationUp(_);
    _hueUp(_);
  }

  bool get isPressed =>
      _squarePressed || _lumaPressed || _huePressed || _saturationPressed;

  void _notifyPressed() {
    if (!isPressed) {
      onFocus.add(this);
    }
  }

  void _squareDown(_) {
    _notifyPressed();

    _squarePressed = true;
    _lumaPressed = true;
    _saturationPressed = true;
  }

  void _squareUp(_) {
    _squarePressed = false;
    _lumaPressed = false;
    _saturationPressed = false;
    _huePressed = false;
  }

  void _lumaDown(_) {
    _notifyPressed();

    _lumaPressed = true;
  }

  void _lumaUp(_) => _lumaPressed = false;

  void _saturationDown(_) {
    _notifyPressed();

    _saturationPressed = true;
  }

  void _saturationUp(_) => _saturationPressed = false;

  void _hueDown(_) {
    _notifyPressed();

    _huePressed = true;
  }

  void _hueUp(_) => _huePressed = false;

  void _adjustPoint(int x, int y) {
    var hsvColor = _pickColorFromSquare(x, y);
    this.hsvColor = hsvColor;
  }

  void _adjustLumaBar(int y) {
    y = _clip(y, 0, height);

    var value = (height - y) / height;
    var hsvColor =
        HSVColor.fromAHSV(1, _hsvColor!.hue, _hsvColor!.saturation, value);

    this.hsvColor = hsvColor;
  }

  void _adjustSaturationBar(int x) {
    x = _clip(x, 0, width);

    var saturation = x / width;
    var hsvColor =
        HSVColor.fromAHSV(1, _hsvColor!.hue, saturation, _hsvColor!.value);

    this.hsvColor = hsvColor;
  }

  void _adjustHueBar(int x) {
    var barSize = _barSize;

    var hueWidth = width + barSize;
    x = _clip(x, 0, hueWidth);

    var hue = x / hueWidth;
    var hsvColor = HSVColor.fromAHSV(
        1, hue * 360, _hsvColor!.saturation, _hsvColor!.value);

    this.hsvColor = hsvColor;
  }

  N _clip<N extends num>(N n, N min, N max) {
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  HSVColor _pickColorFromSquare(int x, int y) {
    x = _clip(x, 0, width);
    y = _clip(y, 0, height);

    var hue = _hsvColor!.hue;
    var saturation = x / width;
    var value = (height - y) / height;

    return HSVColor.fromAHSV(1, hue, saturation, value);
  }
}

void _disableTransitions(Element element) {
  element.style
    ..transition = 'none'
    ..animation = 'none';
}
