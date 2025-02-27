import 'package:collection/collection.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web/web.dart' as web;
import 'package:web_utils/web_utils.dart';

typedef UIElement = web.Element;
typedef UINode = web.Node;

extension UIElementExtension on UIElement {
  List<UIElement> get uiChildren => children.toList();

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

    if (element.isA<web.HTMLInputElement>() ||
        element.isA<web.HTMLTextAreaElement>() ||
        element.isA<web.HTMLButtonElement>() ||
        element.isA<web.HTMLSelectElement>()) {
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

    if (element.isA<web.HTMLInputElement>()) {
      final inputElement = element as web.HTMLInputElement;
      var type = inputElement.type;
      if (type == 'checkbox') {
        var checked = parseBool(value) ?? false;
        inputElement.checked = checked;
      } else {
        inputElement.value = value ?? '';
      }
    } else if (element.isA<web.HTMLSelectElement>()) {
      final selectElement = element as web.HTMLSelectElement;
      if (value == null) {
        selectElement.selectedIndex = -1;
      } else {
        var options = selectElement.options.toList();

        var opt = options.firstWhereOrNull((op) => op.value == value);

        opt ??= options.firstWhereOrNull(
            (op) => equalsIgnoreAsciiCase(op.value.trim(), value.trim()));

        opt ??= options.firstWhereOrNull((op) {
          var label = op.label;
          return equalsIgnoreAsciiCase(label.trim(), value.trim());
        });

        selectElement.selectedIndex = opt?.index ?? -1;
      }
    } else {
      element.text = value;
    }
  }

  bool get isTextInput {
    return isA<web.HTMLInputElement>() || isA<web.HTMLTextAreaElement>();
  }
}

void navigationHistoryPush(String routeTitle, String locationUrl) {
  web.window.history.pushState(JSObject(), routeTitle, locationUrl);
}

String navigationURL() => web.window.location.href;

void navigationOnChangeRoute(
    void Function(String? oldURL, String? newURL) listener) {
  web.window.onHashChange.listen((e) {
    if (e.isA<web.HashChangeEvent>()) {
      var hashEvent = e as web.HashChangeEvent;
      listener(hashEvent.oldURL, hashEvent.newURL);
    } else {
      listener(null, null);
    }
  });
}

bool navigationIsOnline() => web.window.navigator.onLine;

bool navigationIsSecureContext() => web.window.isSecureContext;

UIElement? documentQuerySelector(String selectors) =>
    web.document.querySelector(selectors);

List<UIElement> documentQuerySelectorAll(String selectors) =>
    web.document.querySelectorAll(selectors).toElements();
