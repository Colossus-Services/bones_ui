import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_root.dart';
import 'bones_ui_web.dart';

extension UIElementExtension on UIElement {
  /// Resolves the [UIComponent] of this [UIElement].
  UIComponent? resolveUIComponent({UIComponent? parentUIComponent}) {
    if (parentUIComponent != null) {
      return parentUIComponent.findUIComponentByChild(this);
    } else {
      return UIRoot.getInstance()!.findUIComponentByChild(this);
    }
  }

  /// Resolves the value of this [UIElement].
  String? resolveElementValue(
      {UIComponent? parentUIComponent,
      UIComponent? uiComponent,
      bool allowTextAsValue = true,
      bool resolveUIComponents = true}) {
    var self = this;

    if (self.isA<HTMLInputElement>() ||
        self.isA<HTMLTextAreaElement>() ||
        self.isA<HTMLSelectElement>()) {
      return resolveInputElementValue();
    }

    if (uiComponent == null && resolveUIComponents) {
      uiComponent = resolveUIComponent(parentUIComponent: parentUIComponent);
    }

    if (uiComponent != null) {
      if (uiComponent is UIField) {
        var uiField = uiComponent as UIField;
        var fieldValue = uiField.getFieldValue();
        return MapProperties.toStringValue(fieldValue);
      } else if (uiComponent is UIFieldMap) {
        var uiFieldMap = uiComponent as UIFieldMap;
        var fieldValue = uiFieldMap.getFieldMap();
        return MapProperties.toStringValue(fieldValue);
      }
    }

    var value = self.getAttribute('field_value');
    if (isEmptyObject(value) && allowTextAsValue) {
      value = self.textContent;
    }
    return value;
  }

  String? resolveInputElementValue() {
    var self = this;

    if (self.isA<HTMLTextAreaElement>()) {
      return (self as HTMLTextAreaElement).value;
    } else if (self.isA<HTMLSelectElement>()) {
      var selected = (self as HTMLSelectElement).selectedOptionsSafe;
      if (selected.isEmpty) return '';
      return MapProperties.toStringValue(selected.map((opt) => opt.value));
    } else if (self.isA<HTMLInputElement>()) {
      var type = (self as HTMLInputElement).type;
      switch (type) {
        case 'checkbox':
        case 'radio':
          return parseBool(self.checked, false)! ? self.value : null;
        case 'file':
          return MapProperties.toStringValue(
              self.files!.toList().map((f) => f.name));
        default:
          return self.value;
      }
    } else {
      return null;
    }
  }

  /// Alias to [resolveUIComponent].
  UIComponent? get uiComponent => resolveUIComponent();

  /// Alias to [resolveElementValue].
  String? get elementValue => resolveElementValue();

  /// Returns `true` if [elementValue] is `null` or empty.
  bool get isElementValueEmpty {
    var value = elementValue;
    return value == null || value.isEmpty;
  }

  /// Returns `true` if [elementValue] is `null` or empty after `trim`.
  bool get isElementValueEmptyTrimmed {
    var value = elementValue;
    return value == null || value.trim().isEmpty;
  }
}

extension UIIterableElementExtension<E extends UIElement> on Iterable<E> {
  /// Returns a [List] of [UIComponent] of this [Iterable] of [UIElement]s.
  List<UIComponent?> get uiComponents => map((e) => e.uiComponent).toList();

  /// Returns a [List] of values of this [Iterable] of [UIElement]s.
  List<String?> get elementsValues => map((e) => e.elementValue).toList();
}

extension KeyboardEventExtension on KeyboardEvent {
  int? get keyCodeSafe {
    try {
      return keyCode;
    } catch (_) {
      return null;
    }
  }
}
