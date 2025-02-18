import 'dart:convert';

import 'package:bones_ui/bones_ui.dart';
import 'package:dom_builder/dom_builder.dart';

class UIJsonRender extends UIComponent {
  final Object? json;

  UIJsonRender(super.parent,
      {required this.json,
      super.classes,
      super.classes2,
      super.style,
      super.style2,
      super.inline = true,
      super.id})
      : super(componentClass: 'ui-json-render');

  @override
  Object? render() {
    final json = this.json;

    if (json == null) {
      return $tag('pre', content: 'null');
    } else if (json is String) {
      var s = HtmlEscape().convert(json);
      return $tag('pre', content: '"$s"');
    } else if (json is num) {
      return $tag('pre', content: '$json');
    } else {
      var j = JsonEncoder.withIndent('  ').convert(json);
      return $tag('pre', content: j);
    }
  }
}
