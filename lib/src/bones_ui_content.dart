import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_component.dart';

/// Base class for content components.
abstract class UIContent extends UIComponent {
  /// Optional top margin (in px) for the content.
  int topMargin;

  UIContent(Element? parent,
      {this.topMargin = 0,
      dynamic classes,
      dynamic classes2,
      bool inline = true,
      bool renderOnConstruction = false})
      : super(parent,
            classes: classes,
            classes2: classes2,
            inline: inline,
            renderOnConstruction: renderOnConstruction);

  @override
  List render() {
    // ignore: omit_local_variable_types
    List allRendered = [];

    if (topMargin > 0) {
      var divTopMargin = Element.div();
      divTopMargin.style.width = '100%';
      divTopMargin.style.height = '${topMargin}px';

      allRendered.add(divTopMargin);
    }

    var headRendered = renderHead();
    var contentRendered = renderContent();
    var footRendered = renderFoot();

    addAllToList(allRendered, headRendered);
    addAllToList(allRendered, contentRendered);
    addAllToList(allRendered, footRendered);

    return allRendered;
  }

  /// Called to render the head of the content.
  dynamic renderHead() {
    return null;
  }

  /// Called to render the content.
  dynamic renderContent();

  /// Called to render the footer of the content.
  dynamic renderFoot() {
    return null;
  }
}
