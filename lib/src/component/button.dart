import 'dart:async';
import 'dart:html';

import 'package:bones_ui/bones_ui_kit.dart';
import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Base class for button components.
abstract class UIButtonBase extends UIComponent {
  static final eventClick = 'CLICK';

  UIButtonBase(Element? parent,
      {String? navigate,
      Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic componentClass,
      dynamic style,
      dynamic style2,
      dynamic componentStyle,
      UIComponentGenerator? generator})
      : super(parent,
            classes: classes,
            classes2: classes2,
            componentClass: ['ui-button', componentClass],
            style: style,
            style2: style2,
            componentStyle: componentStyle,
            generator: generator) {
    registerClickListener(onClickEvent);

    if (navigate != null) {
      this.navigate(navigate, navigateParameters, navigateParametersProvider);
    }
  }

  bool _disabled = false;

  bool get disabled => _disabled;

  set disabled(bool disabled) {
    _disabled = disabled;
    refreshInternal();
  }

  // ignore: non_constant_identifier_names
  StreamSubscription? _navigateOnClick_Subscription;

  void cancelNavigate() {
    if (_navigateOnClick_Subscription != null) {
      _navigateOnClick_Subscription!.cancel();
      _navigateOnClick_Subscription = null;
    }
  }

  void navigate(String navigate,
      [Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider]) {
    cancelNavigate();
    _navigateOnClick_Subscription = UINavigator.navigateOnClick(
        content!, navigate, navigateParameters, navigateParametersProvider);
  }

  void registerClickListener(UIEventListener listener) {
    registerEventListener(eventClick, listener);
  }

  // ignore: non_constant_identifier_names
  Point? _prevClickEvent_point;

  // ignore: non_constant_identifier_names
  num? _prevClickEvent_time;

  void fireClickEvent(MouseEvent event, [List? params]) {
    if (disabled) return;

    var p = event.page;
    var time = event.timeStamp;

    if (_prevClickEvent_time == time && _prevClickEvent_point == p) return;

    _prevClickEvent_point = p;
    _prevClickEvent_time = time;

    fireEvent(eventClick, event, params);

    onClick.add(event);
    onChange.add(this);
  }

  final EventStream<MouseEvent> onClick = EventStream();

  void onClickEvent(dynamic event, List? params) {}

  @override
  dynamic render() {
    var rendered = renderButton();

    var renderAll = toContentElements(rendered, false, false);
    _onClickListen(renderAll);

    var renderedHidden = renderHidden();

    if (renderedHidden != null) {
      renderAll.add(renderedHidden);
    }

    return renderAll;
  }

  // ignore: non_constant_identifier_names
  bool _content_onClick_listening = false;

  void _onClickListen(List renderedElements) {
    var clickSet = false;

    for (var elem in renderedElements) {
      if (elem is Element) {
        elem.onClick.listen((e) => fireClickEvent(e));
        clickSet = true;
      }
    }

    if (!clickSet && !_content_onClick_listening) {
      content!.onClick.listen((e) => fireClickEvent(e));
      _content_onClick_listening = true;
    }
  }

  dynamic renderButton();

  dynamic renderHidden() {
    return null;
  }
}

/// A simple button implementation.
class UIButton extends UIButtonBase {
  static final UIComponentGenerator<UIButton> generator =
      UIComponentGenerator<UIButton>(
          'ui-button',
          'button',
          'ui-button',
          '',
          (parent, attributes, contentHolder, contentNodes) =>
              UIButton(parent, contentHolder?.text),
          [
            UIComponentAttributeHandler<UIButton, String>('text',
                parser: parseString,
                getter: (c) => c._text,
                setter: (c, v) => c._text = v ?? '',
                appender: (c, v) => c._text = (c._text ?? '') + (v ?? ''),
                cleaner: (c) => c._text = '')
          ],
          hasChildrenElements: false,
          contentAsText: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  /// Text/label of the button.
  String? _text;

  /// Font size of the button.
  String? _fontSize;

  UIButton(Element? parent, String? text,
      {String? navigate,
      Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic componentClass,
      dynamic style,
      dynamic style2,
      bool small = false,
      String? fontSize})
      : super(parent,
            navigate: navigate,
            navigateParameters: navigateParameters,
            navigateParametersProvider: navigateParametersProvider,
            classes: classes,
            classes2: classes2,
            componentClass: [
              small ? 'ui-button-small' : 'ui-button',
              componentClass
            ],
            style: style,
            style2: style2,
            generator: generator) {
    this.text = text;
    this.fontSize = fontSize;
  }

  String? get text => _text;

  set text(String? value) {
    value ??= '';
    if (value != _text) {
      _text = value;
      refresh();
    }
  }

  String? get fontSize => _fontSize;

  set fontSize(String? value) {
    if (isEmptyString(value)) {
      value = null;
    }

    if (_fontSize != value) {
      _fontSize = value;
      refresh();
    }
  }

  @override
  Element createContentElement(bool inline) {
    return ButtonElement();
  }

  @override
  String? renderButton() {
    if (disabled) {
      content!.style.opacity = '0.7';
    } else {
      content!.style.opacity = '';
    }

    if (fontSize != null && fontSize!.isNotEmpty) {
      return "<span style='font-size: $fontSize'>$text</span>";
    } else {
      return text;
    }
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = null;
  }
}

DOMElement $uiButtonLoader(
    {DOMNodeValidator? validate,
    id,
    String? field,
    classes,
    style,
    buttonClasses,
    buttonStyle,
    Map<String, String>? attributes,
    content,
    bool commented = false,
    bool? withProgress,
    dynamic loadingConfig}) {
  return $tag('ui-button-loader',
      id: id,
      attributes: {
        if (field != null && field.isNotEmpty) 'field': field,
        if (buttonClasses != null)
          'button-classes':
              parseStringFromInlineList(buttonClasses)?.join(',') ?? '',
        if (buttonClasses != null) 'button-style': CSS(buttonStyle).style,
        if (withProgress != null) 'with-progress': '$withProgress',
        if (loadingConfig != null)
          'loading-config': (loadingConfig is UILoadingConfig
              ? loadingConfig.toInlineProperties()
              : '$loadingConfig'),
        ...?attributes
      },
      content: content,
      commented: commented);
}

class UIButtonLoader extends UIButtonBase {
  static final UIComponentGenerator<UIButtonLoader> generator =
      UIComponentGenerator<UIButtonLoader>(
          'ui-button-loader', 'div', 'ui-button-loader', '',
          (parent, attributes, contentHolder, contentNodes) {
    var loadedTextStyle = attributes['loaded-text-style'];
    var loadedTextClass = attributes['loaded-text-class'];
    var loadedTextErrorStyle = attributes['loaded-text-error-style'];
    var loadedTextErrorClass = attributes['loaded-text-error-class'] ??
        attributes['loaded-text-error-classes'];
    var loadedTextOK = attributes['loaded-text-ok'];
    var loadedTextError = attributes['loaded-text-error'];
    var buttonClasses =
        attributes['button-class'] ?? attributes['button-classes'];
    var buttonStyle = attributes['button-style'];
    var withProgress = parseBool(attributes['with-progress']);
    var loadingConfig =
        UILoadingConfig.parse(attributes['loading-config']?.value);

    return UIButtonLoader(parent, contentHolder?.text,
        loadedTextStyle: loadedTextStyle,
        loadedTextClass: loadedTextClass,
        loadedTextErrorStyle: loadedTextErrorStyle,
        loadedTextErrorClass: loadedTextErrorClass,
        loadedTextOK: loadedTextOK,
        loadedTextError: loadedTextError,
        withProgress: withProgress,
        loadingConfig: loadingConfig,
        buttonClasses: buttonClasses,
        buttonStyle: buttonStyle);
  }, [
    UIComponentAttributeHandler<UIButtonLoader, String>('text',
        parser: parseString,
        getter: (c) => c._text,
        setter: (c, v) => c._text = v ?? '',
        appender: (c, v) => c._text = (c._text ?? '') + (v ?? ''),
        cleaner: (c) => c._text = '')
  ], hasChildrenElements: false, contentAsText: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  final UILoadingConfig? loadingConfig;

  /// Text/label of the button.
  String? _text;

  final TextProvider? _loadedTextOK;

  final TextProvider? _loadedTextError;

  final TextProvider? _loadedTextStyle;
  final TextProvider? _loadedTextClass;

  final TextProvider? _loadedTextErrorStyle;
  final TextProvider? _loadedTextErrorClass;

  final TextProvider? _buttonClasses;
  final TextProvider? _buttonStyle;

  final bool withProgress;

  UIButtonLoader(
    Element? parent,
    String? text, {
    this.loadingConfig,
    dynamic loadedTextOK,
    dynamic loadedTextError,
    dynamic loadedTextStyle,
    dynamic loadedTextClass,
    dynamic loadedTextErrorStyle,
    dynamic loadedTextErrorClass,
    String? navigate,
    Map<String, String>? navigateParameters,
    ParametersProvider? navigateParametersProvider,
    dynamic classes,
    dynamic classes2,
    dynamic componentClass,
    dynamic buttonClasses,
    dynamic style,
    dynamic style2,
    dynamic buttonStyle,
    bool? withProgress,
  })  : _loadedTextOK = TextProvider.from(loadedTextOK),
        _loadedTextError = TextProvider.from(loadedTextError),
        _loadedTextStyle = TextProvider.from(loadedTextStyle),
        _loadedTextClass = TextProvider.from(loadedTextClass),
        _loadedTextErrorStyle = TextProvider.from(loadedTextErrorStyle),
        _loadedTextErrorClass = TextProvider.from(loadedTextErrorClass),
        _buttonClasses = TextProvider.from(buttonClasses),
        _buttonStyle = TextProvider.from(buttonStyle),
        withProgress = withProgress ?? false,
        super(parent,
            navigate: navigate,
            navigateParameters: navigateParameters,
            navigateParametersProvider: navigateParametersProvider,
            classes: classes,
            classes2: classes2,
            componentClass: ['ui-button-loader', componentClass],
            style: style,
            style2: style2,
            generator: generator) {
    this.text = text;
  }

  String? get text => _text;

  set text(String? value) {
    value ??= '';
    if (value != _text) {
      _text = value;
      refreshInternal();
    }
  }

  dynamic _button;

  DivElement? _loadingDiv;

  DivElement? _loadedMessage;

  @override
  dynamic renderButton() {
    if (disabled) {
      content!.style.opacity = '0.7';
    } else {
      content!.style.opacity = '';
    }

    _loadingDiv ??= UILoading.asDivElement(UILoadingType.ring,
        zoom: 0.50,
        textZoom: 1.5,
        cssContext: content,
        withProgress: withProgress,
        config: loadingConfig)
      ..style.display = 'none';

    _button ??= renderButtonElement();

    _loadedMessage ??= DivElement()..style.display = 'none';

    _setLoadedMessageStyle();

    return [_button, _loadingDiv, _loadedMessage];
  }

  dynamic renderButtonElement() {
    return $button(
        classes: _buttonClasses?.text,
        style: _buttonStyle?.text,
        content: text);
  }

  void _setLoadedMessageStyle({bool error = false}) {
    var loadedMessage = _loadedMessage!;

    var style = error ? _loadedTextErrorStyle?.text : _loadedTextStyle?.text;
    if (isEmptyString(style, trim: true)) {
      style = _loadedTextStyle?.text;
    }

    if (isNotEmptyString(style, trim: true)) {
      loadedMessage.style.cssText = style;
    }

    var classesError = (_loadedTextErrorClass?.text ?? '')
        .trim()
        .split(RegExp(r'\s+'))
      ..removeWhere((e) => e.isEmpty);

    var classesOk = (_loadedTextClass?.text ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((e) => e.isEmpty);

    if (error) {
      loadedMessage.classes.removeAll(classesOk);
      loadedMessage.classes.addAll(classesError);
    } else {
      loadedMessage.classes.removeAll(classesError);
      loadedMessage.classes.addAll(classesOk);
    }
  }

  @override
  void fireClickEvent(MouseEvent event, [List? params]) {
    if (!disabled) {
      startLoading();
    }

    super.fireClickEvent(event, params);
  }

  void startLoading() {
    if (_loadingDiv == null) return;

    _loadingDiv!.style.display = 'inline-block';
    var button =
        (_button is DOMElement ? _button.runtimeNode : _button) as Element;
    button.style.display = 'none';

    _loadedMessage!.style.display = 'none';
  }

  void stopLoading(bool? loadOK, {String? okMessage, String? errorMessage}) {
    if (_loadingDiv == null) return;

    var button =
        (_button is DOMElement ? _button.runtimeNode : _button) as Element?;

    if (loadOK == null) {
      _setLoadedMessageStyle();

      _loadingDiv!.style.display = 'none';
      button!.style.display = '';
      _loadedMessage!.style.display = 'none';
    } else if (loadOK) {
      _setLoadedMessageStyle();

      _loadingDiv!.style.display = 'none';
      button!.style.display = 'none';

      var okMsg = okMessage ?? _loadedTextOK?.text ?? 'OK';
      setElementInnerHTML(_loadedMessage!, okMsg);
      _loadedMessage!.style.display = '';

      _disabled = true;
    } else {
      _setLoadedMessageStyle(error: true);

      _loadingDiv!.style.display = 'none';
      button!.style.display = '';

      var errorMsg = errorMessage ?? _loadedTextError?.text;

      if (isNotEmptyString(errorMsg)) {
        setElementInnerHTML(_loadedMessage!, errorMsg!);
        _loadedMessage!.style.display = '';
      } else {
        _loadedMessage!.style.display = 'none';
      }
    }
  }

  /// Sets the progress of loading.
  void setProgress(double? ratio) {
    var progressDiv = _loadingDiv!.querySelector('.ui-loading-progress');
    if (progressDiv == null) {
      progressDiv = DivElement()..classes.add('ui-loading-progress');
      var loadingDiv = _loadingDiv!.querySelector('.ui-loading')!;
      loadingDiv.append(progressDiv);
      return;
    }

    if (ratio == null) {
      progressDiv.text = '';
    } else {
      var percent = formatPercent(ratio, precision: 0, isRatio: true);
      progressDiv.text = percent;
    }
  }
}
