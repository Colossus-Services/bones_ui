import 'dart:html';

import 'package:dom_builder/dom_builder_dart_html.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl_messages/intl_messages.dart';

import 'bones_ui_async_content.dart';
import 'bones_ui_component.dart';
import 'bones_ui_log.dart';

typedef UIEventListener = void Function(dynamic event, List? params);

abstract class UIEventHandler extends EventHandlerPrivate {
  void registerEventListener(String type, UIEventListener listener) {
    _registerEventListener(type, listener);
  }

  void fireEvent(String type, dynamic event, [List? params]) {
    _fireEvent(type, event, params);
  }
}

abstract class EventHandlerPrivate {
  final Map<String, List<UIEventListener>> _eventListeners = {};

  void _registerEventListener(String type, UIEventListener listener) {
    var events = _eventListeners[type];
    if (events == null) _eventListeners[type] = events = [];
    events.add(listener);
  }

  void _fireEvent(String type, dynamic event, [List? params]) {
    var eventListeners = _eventListeners[type];

    if (eventListeners != null) {
      try {
        for (var listener in eventListeners) {
          listener(event, params);
        }
      } catch (exception, stackTrace) {
        UIConsole.error(
            'Error firing event: type: $type ; event: $event ; params: $params',
            exception,
            stackTrace);
      }
    }
  }
}

/// Tracks and fires events of device orientation changes.
class UIDeviceOrientation extends EventHandlerPrivate {
  static final eventChangeOrientation = 'CHANGE_ORIENTATION';

  static UIDeviceOrientation? _instance;

  static UIDeviceOrientation? get() {
    _instance ??= UIDeviceOrientation._internal();
    return _instance;
  }

  UIDeviceOrientation._internal() {
    window.onDeviceOrientation.listen(_onChangeOrientation);
  }

  /// Registers [listen] for device orientation changes.
  static void listen(UIEventListener listener) {
    get()!._listen(listener);
  }

  void _listen(UIEventListener listener) {
    _registerEventListener(eventChangeOrientation, listener);
  }

  int? _lastOrientation;

  void _onChangeOrientation(DeviceOrientationEvent event) {
    var orientation = window.orientation;

    if (_lastOrientation != orientation) {
      _fireEvent(eventChangeOrientation, event, [orientation]);
    }

    _lastOrientation = orientation;
  }

  /// Returns [true] if device is in landscape orientation.
  static bool isLandscape() {
    var orientation = window.orientation;
    if (orientation == null) return false;
    return orientation == -90 || orientation == 90;
  }
}

/// Returns [true] if a `Bones_UI` component is in DOM.
bool isComponentInDOM(dynamic element) {
  if (element == null) return false;

  if (element is Node) {
    return document.body!.contains(element);
  } else if (element is UIComponent) {
    return isComponentInDOM(element.renderedElements);
  } else if (element is UIAsyncContent) {
    return isComponentInDOM(element.content);
  } else if (element is List) {
    for (var elem in element) {
      var inDom = isComponentInDOM(elem);
      if (inDom) return true;
    }
    return false;
  }

  return false;
}

/// Returns [true] if [element] type is able to be in DOM.
bool canBeInDOM(dynamic element) {
  if (element == null) return false;

  if (element is Node) {
    return true;
  } else if (element is UIComponent) {
    return true;
  } else if (element is UIAsyncContent) {
    return true;
  } else if (element is List) {
    return true;
  }

  return false;
}

typedef FilterRendered = bool Function(dynamic elem);
typedef FilterElement = bool Function(Element elem);
typedef ForEachElement = void Function(Element elem);
typedef ParametersProvider = Map<String, String> Function();

/// For a [UIComponent] that is a field (has a value).
abstract class UIField<V> {
  V? getFieldValue();
}

/// For a [UIComponent] that is a field with a Map value.
abstract class UIFieldMap<V> {
  Map<String, V> getFieldMap();
}

class TextProvider {
  dynamic _object;

  String? _text;

  String Function()? _function;

  IntlKey? _intlKey;

  ElementProvider? _elementProvider;

  TextProvider.fromText(this._text);

  TextProvider.fromObject(this._object);

  TextProvider.fromFunction(this._function);

  TextProvider.fromElementProvider(this._elementProvider);

  TextProvider.fromIntlKey(this._intlKey);

  TextProvider.fromMessages(IntlMessages intlMessages, String key,
      {Map<String, dynamic>? variables,
      IntlVariablesProvider? variablesProvider})
      : this.fromIntlKey(IntlKey(intlMessages, key,
            variables: variables, variablesProvider: variablesProvider));

  static TextProvider? from(dynamic text) {
    if (text == null) return null;
    if (text is TextProvider) return text;

    if (text is String) return TextProvider.fromText(text);
    if (text is Function) {
      return TextProvider.fromFunction(text as String Function()?);
    }
    if (text is IntlKey) return TextProvider.fromIntlKey(text);

    if (text is ElementProvider) return TextProvider.fromElementProvider(text);

    if (ElementProvider.accepts(text)) {
      return TextProvider.fromElementProvider(ElementProvider.from(text));
    } else {
      return TextProvider.fromObject(text);
    }
  }

  static bool accepts(dynamic text) {
    if (text == null) return false;
    if (text is TextProvider) return true;

    if (text is String) return true;
    if (text is Function) return true;
    if (ElementProvider.accepts(text)) return true;

    return false;
  }

  bool singleCall = false;

  String? get text {
    if (_text != null) {
      return _text;
    }

    dynamic value;

    if (_object != null) {
      value = _object.toString();
    } else if (_function != null) {
      value = _function!();
    } else if (_elementProvider != null) {
      value = _elementProvider!.element!.text;
    } else if (_intlKey != null) {
      value = _intlKey!.message;
    } else {
      throw StateError("Can't provide a text: $this");
    }

    var text = value != null ? value.toString() : '';

    if (singleCall) {
      _text = text;
    }

    return text;
  }

  @override
  String toString() {
    return text!;
  }
}

class ElementProvider {
  Element? _element;

  String? _html;

  UIComponent? _uiComponent;

  DOMNode? _domNode;

  ElementProvider.fromElement(this._element);

  ElementProvider.fromHTML(this._html);

  ElementProvider.fromUIComponent(this._uiComponent);

  ElementProvider.fromDOMNode(this._domNode);

  static ElementProvider? from(dynamic element) {
    if (element == null) return null;
    if (element is ElementProvider) return element;
    if (element is String) return ElementProvider.fromHTML(element);
    if (element is Element) return ElementProvider.fromElement(element);
    if (element is UIComponent) return ElementProvider.fromUIComponent(element);
    if (element is DOMNode) return ElementProvider.fromDOMNode(element);
    return null;
  }

  static bool accepts(dynamic element) {
    if (element == null) return false;
    if (element is ElementProvider) return true;
    if (element is String) return true;
    if (element is Element) return true;
    if (element is UIComponent) return true;
    if (element is DOMNode) return true;
    return false;
  }

  String? get elementAsHTML {
    var elem = element;
    return elem != null ? element!.outerHtml : null;
  }

  Element? get element {
    if (_element != null) {
      return _element;
    }

    if (_html != null) {
      _element = createHTML(_html);
      return _element;
    }

    if (_uiComponent != null) {
      _uiComponent!.ensureRendered();
      _element = _uiComponent!.content;
      return _element;
    }

    if (_domNode != null) {
      var runtime = _domNode!.runtime;
      if (runtime.exists) {
        return runtime.node as Element?;
      } else {
        return _domNode!.buildDOM(generator: UIComponent.domGenerator)
            as Element?;
      }
    }

    throw StateError("Can't provide an Element: $this");
  }

  @override
  String toString() {
    return 'ElementProvider{_element: $_element, _html: $_html, _uiComponent: $_uiComponent, _domNode: $_domNode}';
  }
}

class CSSProvider {
  Element? _element;

  String? _html;

  UIComponent? _uiComponent;

  DOMNode? _domNode;

  CSSProvider.fromElement(this._element);

  CSSProvider.fromHTML(this._html);

  CSSProvider.fromUIComponent(this._uiComponent);

  CSSProvider.fromDOMNode(this._domNode);

  static CSSProvider? from(dynamic provider) {
    if (provider == null) return null;
    if (provider is CSSProvider) return provider;
    if (provider is String) return CSSProvider.fromHTML(provider);
    if (provider is Element) return CSSProvider.fromElement(provider);
    if (provider is UIComponent) return CSSProvider.fromUIComponent(provider);
    if (provider is DOMNode) return CSSProvider.fromDOMNode(provider);
    return null;
  }

  static bool accepts(dynamic element) {
    if (element == null) return false;
    if (element is CSSProvider) return true;
    if (element is String) return true;
    if (element is Element) return true;
    if (element is UIComponent) return true;
    if (element is DOMNode) return true;
    return false;
  }

  String get cssAsString => css.style;

  CSS get css {
    if (_element != null) {
      return cssFromElement(_element!);
    }

    if (_html != null) {
      _element = createHTML(_html);
      return cssFromElement(_element!);
    }

    if (_uiComponent != null) {
      _uiComponent!.ensureRendered();
      _element = _uiComponent!.content;
      return cssFromElement(_element!);
    }

    if (_domNode != null) {
      var runtime = _domNode!.runtime;
      if (runtime.exists) {
        return cssFromElement(runtime.node as Element);
      } else {
        var element =
            _domNode!.buildDOM(generator: UIComponent.domGenerator) as Element;
        return cssFromElement(element);
      }
    }

    throw StateError("Can't provide CSS from: $this");
  }

  static CSS cssFromElement(Element element) {
    if (isNodeInDOM(element)) {
      return CSS(element.getComputedStyle().cssText);
    } else {
      return CSS(element.style.cssText);
    }
  }

  @override
  String toString() {
    return 'CSSProvider{_element: $_element, _html: $_html, _uiComponent: $_uiComponent, _domNode: $_domNode}';
  }
}
