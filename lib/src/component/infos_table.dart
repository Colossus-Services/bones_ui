import 'dart:html';

import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_component.dart';
import '../bones_ui_web.dart';

/// Component that renders a table with information.
class UIInfosTable extends UIComponent {
  final Map _infos;
  final List<String>? headerColumnsNames;

  final String? headerColor;
  final String? rowsStyles;
  final String? cellsStyles;

  List<String>? rowsColors;

  UIInfosTable(super.parent, this._infos,
      {this.headerColumnsNames,
      this.headerColor,
      this.rowsStyles,
      this.cellsStyles,
      super.classes,
      super.style})
      : super(componentClass: 'ui-infos-table');

  @override
  List render() {
    var rowsColors = this.rowsColors ?? <String>[];
    rowsColors.removeWhere((e) => isEmptyObject(e));
    if (rowsColors.isEmpty) {
      rowsColors.add('');
    }

    var table = TableElement();
    table.setAttribute('border', '0');
    table.setAttribute('align', 'center');

    if (isNotEmptyObject(headerColumnsNames)) {
      var headerColor = this.headerColor;

      if (isEmptyObject(headerColor)) {
        headerColor = rowsColors[1 % rowsColors.length];
      }

      var tHead = table.createTHead();
      var headRow = tHead.addRow();

      if (isNotEmptyObject(rowsStyles)) {
        headRow.style.cssText = rowsStyles;
      }

      if (headerColor!.isNotEmpty) {
        headRow.style.backgroundColor = headerColor;
      }

      for (var columnName in headerColumnsNames!) {
        var cel = headRow.addCell();
        if (isNotEmptyObject(cellsStyles)) {
          cel.style.cssText = cellsStyles;
        }

        cel.text = columnName;
      }
    }

    var i = 0;
    for (var entry in _infos.entries) {
      var k = entry.key;
      var v = entry.value;

      var color = rowsColors[i++ % rowsColors.length];

      var row = table.addRow();

      if (isNotEmptyObject(rowsStyles)) {
        row.style.cssText = rowsStyles;
      }

      if (color.isNotEmpty) {
        row.style.backgroundColor = color;
      }

      var cell1 = row.addCell();
      if (isNotEmptyObject(cellsStyles)) {
        cell1.style.cssText = cellsStyles;
      }

      cell1.setAttribute('align', 'right');
      cell1.innerHtml = '<b>$k:&nbsp;</b>';

      var cell2 = row.addCell();
      if (isNotEmptyObject(cellsStyles)) {
        cell2.style.cssText = cellsStyles;
      }

      cell2.setAttribute('align', 'center');

      if (v is UIElement) {
        cell2.children.add(v);
      } else {
        cell2.innerHtml = v.toString();
      }
    }

    return [table];
  }
}
