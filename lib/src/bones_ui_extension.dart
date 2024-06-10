import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';
import 'bones_ui_root.dart';
import 'bones_ui_web.dart';

extension ElementExtension on UIElement {
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
      bool allowTextAsValue = true}) {
    var self = this;

    if (self is InputElement ||
        self is TextAreaElement ||
        self is SelectElement) {
      return resolveInputElementValue();
    }

    uiComponent ??= resolveUIComponent(parentUIComponent: parentUIComponent);

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
      value = self.text;
    }
    return value;
  }

  String? resolveInputElementValue() {
    var self = this;

    if (self is TextAreaElement) {
      return self.value;
    } else if (self is SelectElement) {
      var selected = self.selectedOptionsSafe;
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

  bool dispatchChangeEvent() {
    var event = Event.eventType('Event', 'change');
    return dispatchEvent(event);
  }
}

extension IterableElementExtension<E extends UIElement> on Iterable<E> {
  /// Returns a [List] of [UIComponent] of this [Iterable] of [UIElement]s.
  List<UIComponent?> get uiComponents => map((e) => e.uiComponent).toList();

  /// Returns a [List] of values of this [Iterable] of [UIElement]s.
  List<String?> get elementsValues => map((e) => e.elementValue).toList();
}

extension SelectElementExtension on SelectElement {
  /// Selects an [index] and triggers the `change` event.
  /// See [dispatchChangeEvent] and [selectedIndex].
  bool selectIndex(int index) {
    selectedIndex = index;
    return dispatchChangeEvent();
  }

  List<OptionElement> get selectedOptionsSafe {
    try {
      return selectedOptions;
    } catch (_) {
      return [];
    }
  }
}
