import 'dart:html';

import 'package:dom_tools/dom_tools.dart';
import 'package:dynamic_call/dynamic_call.dart';

import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';

class UIDataSource extends UIComponent {
  static final UIComponentGenerator<UIDataSource> generator =
      UIComponentGenerator<UIDataSource>(
          'ui-data-source',
          'div',
          'ui-data-source',
          '',
          (parent, attributes, contentHolder, contentNodes) =>
              UIDataSource(parent, contentHolder?.text),
          [
            UIComponentAttributeHandler<UIDataSource, String>('data-source',
                getter: (c) => c._dataSource!.toJson(true),
                setter: (c, v) => c.dataSource = v,
                cleaner: (c) => c.dataSource = null)
          ],
          hasChildrenElements: false,
          contentAsText: false);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  UIDataSource(Element? parent, dynamic dataSource)
      : _dataSource = DataSourceHttp.from(dataSource),
        super(parent, componentClass: 'ui-data-source');

  @override
  Element createContentElement(bool inline) {
    var div = createDiv(inline);
    div.hidden = true;
    div.style.display = 'node';
    div.style.visibility = 'hidden';
    return div;
  }

  DataSourceHttp? _dataSource;

  @override
  DataSourceHttp? get dataSource => _dataSource;

  set dataSource(dynamic dataSource) {
    _dataSource = DataSourceHttp.from(dataSource);
  }

  @override
  void configure() {
    content!.hidden = true;
  }

  @override
  dynamic render() {
    var json = dataSource!.toJson(true);
    return PreElement().text = '\n$json\n';
  }
}
