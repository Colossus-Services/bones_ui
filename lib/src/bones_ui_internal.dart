import 'bones_ui_component.dart';
import 'bones_ui_web.dart';

class UIComponentInternals {
  final UIComponent component;

  final void Function(List list) _parseAttributes;

  final void Function(List elements) _ensureAllRendered;

  final void Function() _refreshInternal;

  final void Function(
    bool preserveRender,
    bool inline,
    dynamic classes,
    dynamic classes2,
    dynamic componentClass,
    dynamic style,
    dynamic style2,
    dynamic componentStyle,
    bool renderOnConstruction,
  ) _construct;

  final UIElement? Function() _getContent;

  final void Function(UIElement content) _setContent;

  UIComponentInternals(
    this.component,
    this._getContent,
    this._setContent,
    this._construct,
    this._parseAttributes,
    this._ensureAllRendered,
    this._refreshInternal,
  );

  void parseAttributes(List list) => _parseAttributes(list);

  void ensureAllRendered(List elements) => _ensureAllRendered(elements);

  void refreshInternal() => _refreshInternal();

  void construct(
    bool preserveRender,
    bool inline,
    dynamic classes,
    dynamic classes2,
    dynamic componentClass,
    dynamic style,
    dynamic style2,
    dynamic componentStyle,
    bool renderOnConstruction,
  ) =>
      _construct(preserveRender, inline, classes, classes2, componentClass,
          style, style2, componentStyle, renderOnConstruction);

  UIElement? getContent() => _getContent();

  void setContent(UIElement content) => _setContent(content);
}
