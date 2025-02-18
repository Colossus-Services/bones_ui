import 'package:web_utils/web_utils.dart';

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
              UIDataSource(parent, contentHolder?.textContent),
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

  UIDataSource(super.parent, dynamic dataSource)
      : _dataSource = DataSourceHttp.from(dataSource),
        super(componentClass: 'ui-data-source');

  @override
  HTMLElement createContentElement(bool inline) {
    var div = createDiv(inline: inline);
    div.hidden = true.toJS;
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
    content!.hidden = true.toJS;
  }

  @override
  dynamic render() {
    var json = dataSource!.toJson(true);
    return HTMLPreElement.pre()..text = '\n$json\n';
  }
}
