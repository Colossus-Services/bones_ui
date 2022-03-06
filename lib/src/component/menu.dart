import 'dart:html';

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';
import 'svg.dart';

typedef MenuActionSimple = void Function();
typedef MenuAction = void Function(MenuEntry menuEntry);

class MenuItem {}

class MenuSeparator extends MenuItem {
  final int? size;
  final String? content;

  MenuSeparator({this.size, this.content});
}

class MenuEntry<P> extends MenuItem {
  ElementProvider? _icon;

  TextProvider? _name;

  TextProvider? _title;

  List<MenuItem>? _subMenu;

  Function? action;

  P? payload;

  MenuEntry(dynamic name,
      {dynamic icon,
      dynamic title,
      Iterable<MenuItem>? subMenu,
      this.action,
      this.payload}) {
    this.icon = icon;
    this.name = name;
    this.title = title;

    if (subMenu != null) {
      this.subMenu = subMenu.toList();
    }
  }

  TextProvider? get name => _name;

  set name(dynamic name) {
    _name = TextProvider.from(name);
    if (_name == null || _name!.text == null) {
      throw ArgumentError.notNull('name');
    }
  }

  String? get nameText => _name != null ? _name!.text : '';

  TextProvider? get title => _title;

  set title(dynamic title) {
    _title = TextProvider.from(title);
  }

  String? get titleText => _title != null ? _title!.text : '';

  ElementProvider? get icon => _icon;

  set icon(dynamic icon) {
    _icon = ElementProvider.from(icon);
  }

  Element? get iconElement => _icon != null ? _icon!.element : null;

  bool get hasSubMenu => _subMenu != null ? _subMenu!.isNotEmpty : false;

  List<MenuItem>? get subMenu => _subMenu;

  set subMenu(Iterable<MenuItem>? subMenu) {
    if (subMenu != null) {
      var list = List<MenuItem>.from(subMenu);

      if (list.isNotEmpty) {
        _subMenu = list;
        return;
      }
    }

    _subMenu = null;
  }

  bool get hasAction => action != null;

  @override
  String toString() {
    return 'MenuEntry{_name: $_name, _subMenu: $_subMenu, payload: $payload}';
  }
}

class UIMenu extends UIComponent {
  List<MenuItem>? entries;

  bool? _vertical;

  dynamic popupClasses;
  dynamic popupStyle;
  Point<num>? popupOffset;

  ElementProvider itemSeparator;

  final int? backgroundBlur;
  final int? popupBackgroundBlur;
  final String? itemOverBgColor;
  final String? popupItemOverBgColor;

  final List<String>? scrollbarColors;

  final PopupGroup _popupGroup = PopupGroup();

  final String? zIndex;

  UIMenu(Element parent, Iterable<MenuItem> entries,
      {bool? vertical,
      String? itemSeparator,
      this.backgroundBlur,
      this.popupBackgroundBlur,
      this.itemOverBgColor,
      this.popupItemOverBgColor,
      this.scrollbarColors,
      dynamic classes,
      dynamic style,
      this.popupOffset,
      this.popupClasses,
      this.popupStyle,
      this.zIndex})
      : itemSeparator = ElementProvider.from(itemSeparator ?? ' | ')!,
        super(parent,
            componentClass: 'ui-menu', classes: classes, style: style) {
    this.entries = List.from(entries);
    this.vertical = vertical;

    removeEmptyEntries(scrollbarColors);
  }

  @override
  void configure() {
    if (backgroundBlur != null && backgroundBlur! > 0) {
      setElementBackgroundBlur(content!, backgroundBlur);
    }

    if (isNotEmptyObject(zIndex)) {
      content!.style.zIndex = zIndex;
    }
  }

  bool? get vertical => _vertical;

  set vertical(bool? value) {
    _vertical = value ?? false;
  }

  @override
  dynamic render() {
    if (vertical!) {
      return _renderVertical();
    } else {
      return _renderHorizontal();
    }
  }

  static const String svgArrowDown = '''
  <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-arrow-down-short" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
    <path fill-rule="evenodd" d="M4.646 7.646a.5.5 0 0 1 .708 0L8 10.293l2.646-2.647a.5.5 0 0 1 .708.708l-3 3a.5.5 0 0 1-.708 0l-3-3a.5.5 0 0 1 0-.708z"/>
    <path fill-rule="evenodd" d="M8 4.5a.5.5 0 0 1 .5.5v5a.5.5 0 0 1-1 0V5a.5.5 0 0 1 .5-.5z"/>
  </svg>
  ''';

  dynamic _renderHorizontal() {
    content!.style.width = '100%';

    var entries = this.entries ?? [];
    if (entries.isEmpty) return;

    var nodes = [];

    for (var menuEntry in entries) {
      if (menuEntry is MenuSeparator) {
        var menuEntryDiv = $divInline(content: menuEntry.content);
        if (menuEntry.size != null) {
          menuEntryDiv.style.put('width', '${menuEntry.size}px');
        }
        nodes.add(menuEntryDiv);
      } else if (menuEntry is MenuEntry) {
        if (nodes.isNotEmpty) {
          nodes.add($span(content: itemSeparator.elementAsHTML));
        }

        dynamic nameText = menuEntry.nameText;
        var titleText = menuEntry.titleText;

        var iconElement = menuEntry.iconElement;
        var iconSeparator = iconElement != null ? ' ' : null;

        UISVG? dropDownIcon;
        if (menuEntry.hasSubMenu) {
          dropDownIcon = UISVG(null,
              width: 'auto', height: '1.2em', svgContent: svgArrowDown);
        }

        if (isNotEmptyObject(titleText)) {
          if (iconElement != null) {
            iconElement.title = titleText;
          }

          nameText =
              $span(attributes: {'title': titleText!}, content: nameText);
        }

        var menuEntryDiv = $divInline(
            style: 'cursor: pointer;',
            content: [iconElement, iconSeparator, nameText, dropDownIcon]);
        nodes.add(menuEntryDiv);

        if (menuEntry.hasSubMenu) {
          var popupMenu = UIPopupMenu(parent, menuEntry.subMenu,
              group: _popupGroup,
              popupOffset: popupOffset,
              backgroundBlur: popupBackgroundBlur,
              itemOverBgColor: popupItemOverBgColor,
              scrollbarColors: scrollbarColors,
              targetElement: menuEntryDiv,
              classes: popupClasses,
              style: popupStyle);

          menuEntryDiv.onClick.listen((_) {
            popupMenu.switchShowing();
          });

          if (isNotEmptyObject(itemOverBgColor)) {
            menuEntryDiv.onMouseOver.listen((_) {
              menuEntryDiv.runtime
                  .setStyleProperty('background-color', itemOverBgColor!);
            });

            menuEntryDiv.onMouseOut.listen((_) {
              menuEntryDiv.runtime.removeStyleEntry('background-color');
            });
          }

          popupMenu.onShow.listen((event) {
            menuEntryDiv.runtime.setStyleProperties({'font-weight': 'bold'});
          });

          popupMenu.onHide.listen((event) {
            menuEntryDiv.runtime.removeStyleProperties(['font-weight']);
          });
        }

        if (menuEntry.hasAction) {
          menuEntryDiv.onClick.listen((_) {
            if (!menuEntry.hasSubMenu) {
              _popupGroup.hideAll();
            }

            _callMenuAction(menuEntry, menuEntry.action);
          });
        }
      }
    }

    //print('MENU H>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    //print( $div(content: nodes).buildHTML(withIndent: true));

    return nodes;
  }

  dynamic _renderVertical() {
    return '?vertical?';
  }
}

void _callMenuAction(MenuEntry menuEntry, Function? action) {
  if (action is MenuActionSimple) {
    action();
  } else if (action is MenuAction) {
    action(menuEntry);
  } else {
    action!();
  }
}

enum PopupPosition {
  leftSide,
  below,
  rightSide,
  upward,
}

class PopupGroup {
  final Set<UIPopupMenu> _popups = {};

  void clear() {
    _popups.clear();
  }

  void register(UIPopupMenu popup) {
    _popups.add(popup);
  }

  void unregister(UIPopupMenu popup) {
    _popups.remove(popup);
  }

  bool contains(UIPopupMenu popup) {
    return _popups.contains(popup);
  }

  List<UIPopupMenu> get popups => List.from(_popups);

  void hideAll([UIPopupMenu? ignorePopup]) {
    for (var p in _popups) {
      if (p != ignorePopup) {
        p.hide();
      }
    }
  }

  void showAll([UIPopupMenu? ignorePopup]) {
    for (var p in _popups) {
      if (p != ignorePopup) {
        p.show();
      }
    }
  }
}

class UIPopupMenu extends UIComponent {
  final PopupGroup? group;
  final Point<num>? point;

  final ElementProvider? targetElement;
  final PopupPosition popupPosition;
  final Point<num>? popupOffset;

  List<MenuItem>? entries;

  final int? backgroundBlur;

  final String? itemOverBgColor;

  final List<String>? scrollbarColors;

  UIPopupMenu(Element? parent, Iterable<MenuItem>? entries,
      {this.group,
      this.point,
      PopupPosition? popupPosition,
      this.popupOffset,
      dynamic targetElement,
      this.backgroundBlur,
      this.itemOverBgColor,
      this.scrollbarColors,
      dynamic classes,
      dynamic style})
      : popupPosition = popupPosition ?? PopupPosition.below,
        targetElement = ElementProvider.from(targetElement),
        super(parent,
            componentClass: 'ui-popup-menu',
            componentStyle:
                'max-height: 80vh; max-width: 80vw; overflow: auto; scrollbar-color: auto;',
            classes: classes,
            style: style) {
    this.entries = List.from(entries ?? <MenuItem>[]);

    removeEmptyEntries(scrollbarColors);

    hide();

    if (group != null) {
      group!.register(this);
    }
  }

  @override
  void configure() {
    if (backgroundBlur != null && backgroundBlur! > 0) {
      setElementBackgroundBlur(content!, backgroundBlur);
    }

    if (isNotEmptyObject(scrollbarColors)) {
      var buttonColor = scrollbarColors![0].trim();
      var bgColor =
          scrollbarColors!.length > 1 ? scrollbarColors![1].trim() : '';

      setElementScrollColors(content!, 8, buttonColor, bgColor);
    }
  }

  String get renderZIndex {
    var zIndex = getElementZIndex(targetElement?.element);
    if (isNotEmptyObject(zIndex)) {
      try {
        var z = parseInt(zIndex)! - 1;
        return '$z';
      } catch (e, s) {
        print(e);
        print(s);
      }
    }

    return '$CSS_MAX_Z_INDEX';
  }

  Point? get renderPoint {
    if (point != null) {
      return point;
    } else if (targetElement != null) {
      var element = targetElement!.element!;
      var r = element.getBoundingClientRect();

      if (popupPosition == PopupPosition.below) {
        return Point(r.left, r.top + r.height);
      } else if (popupPosition == PopupPosition.rightSide) {
        return Point(r.left + r.width, r.top);
      } else {
        return Point(r.left, r.top);
      }
    } else {
      throw StateError('No point or targetElement');
    }
  }

  Point? get renderPointWithOffset {
    var p = renderPoint;
    if (popupOffset != null) {
      p = Point(p!.x + popupOffset!.x, p.y + popupOffset!.y);
    }
    return p;
  }

  int? get renderWidth {
    if (point != null) {
      return null;
    } else if (targetElement != null) {
      if (popupPosition == PopupPosition.below ||
          popupPosition == PopupPosition.upward) {
        var element = targetElement!.element!;
        var r = element.getBoundingClientRect();
        return r.width.toInt();
      }
    }
    return null;
  }

  @override
  dynamic render() {
    var point = renderPointWithOffset!;
    var zIndex = renderZIndex;

    content!.style
      ..position = 'fixed'
      ..left = '${point.x.toInt()}px'
      ..top = '${point.y.toInt()}px'
      ..padding = '1px 0px 5px 0px'
      ..zIndex = zIndex;

    if (popupPosition == PopupPosition.upward) {
      content!.style.transform = 'translate(0%, -100%)';
    } else if (popupPosition == PopupPosition.leftSide) {
      content!.style.transform = 'translate(-100%, 0%)';
    }

    var renderWidth = this.renderWidth;

    if (renderWidth != null) {
      content!.style.minWidth = '${renderWidth}px';
    }

    var entries = this.entries ?? [];
    if (entries.isEmpty) return;

    var nodes = [];

    nodes.add($hr(style: 'margin: 0px 0px 5px 0px'));

    for (var i = 0; i < entries.length; ++i) {
      var menuEntry = entries[i];

      if (menuEntry is MenuSeparator) {
        var menuEntryDiv =
            $div(style: 'width: 100%;', content: menuEntry.content);
        if (menuEntry.size != null) {
          menuEntryDiv.style.put('height', '${menuEntry.size}px');
        }
        nodes.add(menuEntryDiv);
      } else if (menuEntry is MenuEntry) {
        var iconElement = menuEntry.iconElement;
        var iconSeparator = iconElement != null ? ' ' : null;

        var nameText = menuEntry.nameText;
        if (nameText != null && nameText.isEmpty) {
          nameText = null;
        }

        var menuEntryDiv = $div(
            style: 'cursor: pointer; width: 100%; padding: 1px 6px 1px 6px',
            content: [iconElement, iconSeparator, nameText]);

        if (nameText == null || iconElement == null) {
          menuEntryDiv.style.put('text-align', 'center');
        }

        if (menuEntry.hasAction) {
          menuEntryDiv.onClick.listen((_) {
            hide();
            _callMenuAction(menuEntry, menuEntry.action);
          });
        }

        if (isNotEmptyObject(itemOverBgColor)) {
          menuEntryDiv.onMouseOver.listen((_) {
            menuEntryDiv.runtime
                .setStyleProperty('background-color', itemOverBgColor!);
          });

          menuEntryDiv.onMouseOut.listen((_) {
            menuEntryDiv.runtime.removeStyleEntry('background-color');
          });
        }

        nodes.add(menuEntryDiv);
      }
    }

    return nodes;
  }

  bool switchShowing() {
    if (!isShowing) {
      show();
      ensureRendered();
      return true;
    } else {
      hide();
      return false;
    }
  }

  final EventStream<UIPopupMenu> onShow = EventStream();

  @override
  void show() {
    if (group != null && group!.contains(this)) {
      group!.hideAll(this);
    }
    super.show();
    onShow.add(this);
  }

  final EventStream<UIPopupMenu> onHide = EventStream();

  @override
  void hide() {
    super.hide();
    onHide.add(this);
  }
}
