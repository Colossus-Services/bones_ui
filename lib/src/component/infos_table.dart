import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import '../bones_ui_component.dart';

/// Component that renders a table with information.
class UIInfosTable extends UIComponent {
  final Map<Object, Object?> _infos;
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

    var table = HTMLTableElement();
    table.setAttribute('border', '0');
    table.setAttribute('align', 'center');

    if (isNotEmptyObject(headerColumnsNames)) {
      var headerColor = this.headerColor;

      if (isEmptyObject(headerColor)) {
        headerColor = rowsColors[1 % rowsColors.length];
      }

      var tHead = table.createTHead();
      var headRow = tHead.appendRow();

      final rowsStyles = this.rowsStyles;
      if (rowsStyles != null && rowsStyles.isNotEmpty) {
        headRow.style.cssText = rowsStyles;
      }

      if (headerColor!.isNotEmpty) {
        headRow.style.backgroundColor = headerColor;
      }

      for (var columnName in headerColumnsNames!) {
        var cel = headRow.appendCell();
        final cellsStyles = this.cellsStyles;
        if (cellsStyles != null && cellsStyles.isNotEmpty) {
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

      var row = table.appendRow();

      final rowsStyles = this.rowsStyles;
      if (rowsStyles != null && rowsStyles.isNotEmpty) {
        row.style.cssText = rowsStyles;
      }

      if (color.isNotEmpty) {
        row.style.backgroundColor = color;
      }

      var cell1 = row.appendCell();
      final cellsStyles = this.cellsStyles;
      if (cellsStyles != null && cellsStyles.isNotEmpty) {
        cell1.style.cssText = cellsStyles;
      }

      cell1.setAttribute('align', 'right');
      cell1.innerHTML = '<b>$k:&nbsp;</b>'.toJS;

      var cell2 = row.appendCell();
      if (cellsStyles != null && cellsStyles.isNotEmpty) {
        cell2.style.cssText = cellsStyles;
      }

      cell2.setAttribute('align', 'center');

      if (v.isElement) {
        cell2.appendChild(v as Element);
      } else {
        cell2.innerHTML = v.toString().toJS;
      }
    }

    return [table];
  }
}
