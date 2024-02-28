import 'dart:html' as web;
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

typedef UIElement = web.Element;
typedef UINode = web.Node;

extension UIElementExtension on UIElement {
  List<UIElement> get uiChildren => children;

  bool get hasUIChildren => children.isNotEmpty;

  MapEntry<String, Object>? resolveFieldName<V>() {
    final element = this;

    var fieldName = getElementAttributeStr(element, 'field');
    if (fieldName != null) {
      fieldName = fieldName.trim();
      if (fieldName.isNotEmpty) {
        return MapEntry<String, Object>(fieldName, element);
      }
    }

    if (element is web.InputElement ||
        element is web.TextAreaElement ||
        element is web.ButtonElement ||
        element is web.SelectElement) {
      fieldName = getElementAttributeStr(element, 'name');

      if (fieldName != null) {
        fieldName = fieldName.trim();
        if (fieldName.isNotEmpty) {
          return MapEntry<String, Object>(fieldName, element);
        }
      }
    }

    return null;
  }

  void setValue(String? value) {
    final element = this;

    if (element is web.InputElement) {
      var type = element.type;
      if (type == 'checkbox') {
        var checked = parseBool(value) ?? false;
        element.checked = checked;
      } else {
        element.value = value;
      }
    } else {
      element.text = value;
    }
  }

  bool get isTextInput =>
      this is web.InputElement || this is web.TextAreaElement;
}

void navigationHistoryPush(String routeTitle, String locationUrl) {
  web.window.history.pushState({}, routeTitle, locationUrl);
}

String navigationURL() => web.window.location.href;

void navigationOnChangeRoute(
    void Function(String? oldURL, String? newURL) listener) {
  web.window.onHashChange.listen((e) {
    if (e is web.HashChangeEvent) {
      listener(e.oldUrl, e.newUrl);
    } else {
      listener(null, null);
    }
  });
}

bool navigationIsOnline() => web.window.navigator.onLine ?? false;

bool navigationIsSecureContext() => web.window.isSecureContext ?? false;

UIElement? documentQuerySelector(String selectors) =>
    web.document.querySelector(selectors);

List<UIElement> documentQuerySelectorAll(String selectors) =>
    web.document.querySelectorAll(selectors);
