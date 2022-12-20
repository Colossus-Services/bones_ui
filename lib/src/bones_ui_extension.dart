import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_root.dart';

extension ElementExtension on Element {
  /// Resolves the [UIComponent] of this [Element].
  UIComponent? resolveUIComponent({UIComponent? parentUIComponent}) {
    if (parentUIComponent != null) {
      return parentUIComponent.findUIComponentByChild(this);
    } else {
      return UIRoot.getInstance()!.findUIComponentByChild(this);
    }
  }

  /// Resolves the value of this [Element].
  String? resolveElementValue(
      {UIComponent? parentUIComponent, bool allowTextAsValue = true}) {
    var uiComponent = resolveUIComponent(parentUIComponent: parentUIComponent);

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

    var self = this;

    if (self is TextAreaElement) {
      return self.value;
    } else if (self is SelectElement) {
      var selected = self.selectedOptions;
      if (selected.isEmpty) return '';
      return MapProperties.toStringValue(selected.map((opt) => opt.value));
    } else if (self is InputElement) {
      var type = self.type;
      switch (type) {
        case 'checkbox':
        case 'radio':
          return parseBool(self.checked, false)! ? self.value : null;
        case 'file':
          return MapProperties.toStringValue(self.files!.map((f) => f.name));
        default:
          return self.value;
      }
    } else {
      var value = self.getAttribute('field_value');
      if (isEmptyObject(value) && allowTextAsValue) {
        value = self.text;
      }
      return value;
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

extension IterableElementExtension<E extends Element> on Iterable<E> {
  /// Returns a [List] of [UIComponent] of this [Iterable] of [Element]s.
  List<UIComponent?> get uiComponents => map((e) => e.uiComponent).toList();

  /// Returns a [List] of values of this [Iterable] of [Element]s.
  List<String?> get elementsValues => map((e) => e.elementValue).toList();
}
