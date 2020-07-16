import 'dart:html';
import 'package:bones_ui/src/bones_ui_base.dart';

/// Component that renders a table with information.
class UIInfosTable extends UIComponent {
  final Map _infos;

  UIInfosTable(Element parent, this._infos, {dynamic classes})
      : super(parent, classes: 'ui-infos-table', classes2: classes);

  @override
  List render() {
    var table = TableElement();
    table.setAttribute('border', '0');
    table.setAttribute('align', 'center');

    for (var k in _infos.keys) {
      var v = _infos[k];

      var row = table.addRow();

      var cell1 = row.addCell();
      cell1.setAttribute('align', 'right');
      cell1.innerHtml = '<b>$k:&nbsp;</b>';

      var cell2 = row.addCell();
      cell2.setAttribute('align', 'center');

      if (v is Element) {
        cell2.children.add(v);
      } else {
        cell2.innerHtml = v.toString();
      }
    }

    return [table];
  }
}
