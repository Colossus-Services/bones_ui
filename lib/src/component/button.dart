import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Base class for button components.
abstract class UIButtonBase extends UIComponent {
  static final EVENT_CLICK = 'CLICK';

  UIButtonBase(Element parent,
      {String navigate,
      Map<String, String> navigateParameters,
      ParametersProvider navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic componentClass})
      : super(parent,
            classes: classes,
            classes2: classes2,
            componentClass: ['ui-button', componentClass]) {
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

  StreamSubscription _navigateOnClick_Subscription;

  void cancelNavigate() {
    if (_navigateOnClick_Subscription != null) {
      _navigateOnClick_Subscription.cancel();
      _navigateOnClick_Subscription = null;
    }
  }

  void navigate(String navigate,
      [Map<String, String> navigateParameters,
      ParametersProvider navigateParametersProvider]) {
    cancelNavigate();
    _navigateOnClick_Subscription = UINavigator.navigateOnClick(
        content, navigate, navigateParameters, navigateParametersProvider);
  }

  void registerClickListener(UIEventListener listener) {
    registerEventListener(EVENT_CLICK, listener);
  }

  Point _prevClickEvent_point;

  num _prevClickEvent_time;

  void fireClickEvent(MouseEvent event, [List params]) {
    if (disabled) return;

    var p = event.page;
    var time = event.timeStamp;

    if (_prevClickEvent_time == time && _prevClickEvent_point == p) return;

    _prevClickEvent_point = p;
    _prevClickEvent_time = time;

    fireEvent(EVENT_CLICK, event, params);

    onClick.add(event);
    onChange.add(this);
  }

  final EventStream<MouseEvent> onClick = EventStream();

  void onClickEvent(dynamic event, List params) {}

  @override
  dynamic render() {
    var rendered = renderButton();

    var renderAll = toContentElements(content, rendered, false, false);
    _onClickListen(renderAll);

    var renderedHidden = renderHidden();

    if (renderedHidden != null) {
      renderAll.add(renderedHidden);
    }

    return renderAll;
  }

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
      content.onClick.listen((e) => fireClickEvent(e));
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
  static void register() {
    UIComponent.registerElementGenerator('ui-button', generator);
  }

  static Element generator(DOMGenerator<Node> domGenerator, tag, Node parent,
      Map<String, DOMAttribute> attributes, Node contentHolder) {
    var component = UIButton(parent, contentHolder.text);
    component.appendComponentAttributes(attributes.values);
    component.ensureRendered();
    return component.content;
  }

  @override
  dynamic getComponentAttributeExtended(String name) {
    switch (name) {
      case 'text':
        return text;
      default:
        return null;
    }
  }

  @override
  bool setComponentAttributeExtended(String name, value) {
    switch (name) {
      case 'text':
        {
          _text = parseAttributeValueAsString(value);
          return true;
        }
      default:
        return null;
    }
  }

  @override
  bool appendComponentAttributeExtended(String name, value) {
    switch (name) {
      case 'text':
        {
          _text += parseAttributeValueAsString(value);
          return true;
        }
      default:
        return null;
    }
  }

  @override
  bool clearComponentAttributeExtended(String name) {
    switch (name) {
      case 'text':
        {
          _text = '';
          return true;
        }
      default:
        return null;
    }
  }

  /// Text/label of the button.
  String _text;

  /// Font size of the button.
  final String fontSize;

  UIButton(Element parent, String text,
      {String navigate,
      Map<String, String> navigateParameters,
      ParametersProvider navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic componentClass,
      bool small = false,
      this.fontSize})
      : _text = text,
        super(parent,
            navigate: navigate,
            navigateParameters: navigateParameters,
            navigateParametersProvider: navigateParametersProvider,
            classes: classes,
            classes2: classes2,
            componentClass: [
              small ? 'ui-button-small' : 'ui-button',
              componentClass
            ]);

  String get text => _text;

  set text(String value) {
    _text = value;
  }

  @override
  Element createContentElement(bool inline) {
    return ButtonElement();
  }

  @override
  String renderButton() {
    if (disabled) {
      content.style.opacity = '0.7';
    } else {
      content.style.opacity = null;
    }

    if (fontSize != null) {
      return "<span style='font-size: $fontSize'>$text</span>";
    } else {
      return text;
    }
  }

  void setWideButton() {
    content.style.width = '80%';
  }

  void setNormalButton() {
    content.style.width = null;
  }
}
