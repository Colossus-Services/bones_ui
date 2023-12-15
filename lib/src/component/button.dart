import 'dart:async';
import 'dart:html';

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';
import '../bones_ui_navigator.dart';
import '../bones_ui_utils.dart';
import 'loading.dart';

/// Base class for button components.
abstract class UIButtonBase extends UIComponent {
  static final eventClick = 'CLICK';

  UIButtonBase(super.parent,
      {String? navigate,
      Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider,
      super.classes,
      super.classes2,
      dynamic componentClass,
      super.style,
      super.style2,
      super.componentStyle,
      super.generator})
      : super(componentClass: ['ui-button', componentClass]) {
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

    var renderAll = toContentElements(rendered, parseAttributes: false);
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

/// [DOMElement] tag `ui-button` for [UIButton].
DOMElement $uiButton({
  id,
  String? field,
  classes,
  style,
  Map<String, String>? attributes,
  String? text,
  bool commented = false,
}) {
  return $tag('ui-button',
      id: id,
      classes: classes,
      style: style,
      attributes: {
        if (field != null && field.isNotEmpty) 'field': field,
        ...?attributes
      },
      content: text,
      commented: commented);
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
                getter: (c) => c.text,
                setter: (c, v) => c.text = v,
                appender: (c, v) => c.text = v,
                cleaner: (c) => c.text = null)
          ],
          hasChildrenElements: false,
          contentAsText: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  /// The content of the button.
  Object? _buttonContent;

  /// Font size of the button.
  String? _fontSize;

  UIButton(super.parent, Object? buttonContent,
      {super.navigate,
      super.navigateParameters,
      super.navigateParametersProvider,
      super.classes,
      super.classes2,
      dynamic componentClass,
      super.style,
      super.style2,
      bool small = false,
      String? fontSize})
      : _buttonContent = buttonContent,
        _fontSize = fontSize,
        super(componentClass: [
          small ? 'ui-button-small' : 'ui-button',
          componentClass
        ], generator: generator);

  /// The [buttonContent] as text.
  String? get text => resolveToText(_buttonContent);

  set text(String? value) => buttonContent = value;

  /// The content of the button.
  Object? get buttonContent => _buttonContent;

  set buttonContent(Object? value) {
    if (value != _buttonContent) {
      _buttonContent = value;
      requestRefresh();
    }
  }

  String? get fontSize => _fontSize;

  set fontSize(String? value) {
    if (isEmptyString(value)) {
      value = null;
    }

    if (_fontSize != value) {
      _fontSize = value;
      requestRefresh();
    }
  }

  @override
  Element createContentElement(bool inline) {
    return ButtonElement();
  }

  @override
  Object? renderButton() {
    if (disabled) {
      content!.style.opacity = '0.7';
    } else {
      content!.style.opacity = '';
    }

    if (fontSize != null && fontSize!.isNotEmpty) {
      return $span(style: 'font-size: $fontSize', content: _buttonContent);
    } else {
      return _buttonContent;
    }
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = null;
  }
}

/// [DOMElement] tag `ui-button-loader` for [UIButtonLoader].
DOMElement $uiButtonLoader(
    {id,
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
  return $tag(
    'ui-button-loader',
    id: id,
    classes: classes,
    style: style,
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
    commented: commented,
  );
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

    return UIButtonLoader(parent, contentNodes,
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
    UIComponentAttributeHandler<UIButtonLoader, String>(
      'text',
      parser: parseString,
      getter: (c) => c.text,
      setter: (c, v) => c.text = v,
      appender: (c, v) => c.text = v,
      cleaner: (c) => c.text = null,
    )
  ], usesContentHolder: false, hasChildrenElements: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  final UILoadingConfig? loadingConfig;

  /// Content of the button.
  Object? _buttonContent;

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
    super.parent,
    Object? buttonContent, {
    this.loadingConfig,
    dynamic loadedTextOK,
    dynamic loadedTextError,
    dynamic loadedTextStyle,
    dynamic loadedTextClass,
    dynamic loadedTextErrorStyle,
    dynamic loadedTextErrorClass,
    super.navigate,
    super.navigateParameters,
    super.navigateParametersProvider,
    super.classes,
    super.classes2,
    dynamic componentClass,
    dynamic buttonClasses,
    super.style,
    super.style2,
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
        _buttonContent = buttonContent,
        super(
            componentClass: ['ui-button-loader', componentClass],
            generator: generator);

  /// The [buttonContent] as text.
  String? get text => resolveToText(_buttonContent);

  set text(String? value) => buttonContent = value;

  /// The button content.
  Object? get buttonContent => _buttonContent;

  set buttonContent(Object? value) {
    value ??= '';
    if (value != _buttonContent) {
      _buttonContent = value;
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
        content: _buttonContent);
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

    var button = _button;

    var buttonElement =
        (button is DOMElement ? button.runtimeNode : button) as Element;
    buttonElement.style.display = 'none';

    _loadedMessage!.style.display = 'none';
  }

  void stopLoading(bool? loadOK, {String? okMessage, String? errorMessage}) {
    if (_loadingDiv == null) return;

    if (okMessage != null) {
      okMessage = resolveTextIntl(okMessage);
    }

    if (errorMessage != null) {
      errorMessage = resolveTextIntl(errorMessage);
    }

    var button = _button;

    var buttonElement =
        (button is DOMElement ? button.runtimeNode : button) as Element?;

    if (loadOK == null) {
      _setLoadedMessageStyle();

      _loadingDiv!.style.display = 'none';
      buttonElement!.style.display = '';
      _loadedMessage!.style.display = 'none';
    } else if (loadOK) {
      _setLoadedMessageStyle();

      _loadingDiv!.style.display = 'none';
      buttonElement!.style.display = 'none';

      var okMsg = okMessage ?? _loadedTextOK?.text ?? 'OK';
      setElementInnerHTML(_loadedMessage!, okMsg);
      _loadedMessage!.style.display = '';

      _disabled = true;
    } else {
      _setLoadedMessageStyle(error: true);

      _loadingDiv!.style.display = 'none';
      buttonElement!.style.display = '';

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
