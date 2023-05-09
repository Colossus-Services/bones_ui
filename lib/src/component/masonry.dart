import 'dart:html';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_component.dart';

class MasonryItem {
  final dynamic element;

  int? _width;

  int? _height;

  MasonryItem(this.element, this._width, this._height);

  factory MasonryItem.from(dynamic element) {
    if (element is Element) {
      return MasonryItem.fromElement(element);
    } else if (element is DOMElement) {
      return MasonryItem.fromDOMElement(element);
    } else if (element is UIComponent) {
      return MasonryItem.fromElement(element.content);
    } else {
      var w = _getElementHeight(element);
      var h = _getElementHeight(element);
      return MasonryItem(element, w, h);
    }
  }

  factory MasonryItem.fromDOMElement(DOMElement element) {
    var domElement = UIComponent.domGenerator.generate(element);
    return MasonryItem.fromElement(domElement as Element?);
  }

  factory MasonryItem.fromElement(Element? element) {
    return MasonryItem(
        element, _getElementWidth(element), _getElementHeight(element));
  }

  int? get width => _width;

  int? get height => _height;

  bool checkChangedDimension() {
    var w = _getElementWidth(element);
    var h = _getElementHeight(element);

    if (w != width || h != height) {
      return true;
    }
    return false;
  }

  void updateDimensions() {
    _width = _getElementWidth(element);
    _height = _getElementHeight(element);
  }
}

int? _getElementWidth(dynamic element) {
  if (element == null) return null;
  if (element is Element) {
    return getElementWidth(element);
  } else if (element is UIComponent) {
    return getElementWidth(element.content!);
  } else if (element is DOMElement) {
    return parseCSSLength(element['width'] ?? element.style.width as String,
        unit: 'px', allowPXWithoutSuffix: true) as int?;
  }
  return 0;
}

int? _getElementHeight(dynamic element) {
  if (element == null) return null;
  if (element is Element) {
    return getElementHeight(element);
  } else if (element is UIComponent) {
    return getElementHeight(element.content!);
  } else if (element is DOMElement) {
    return parseCSSLength(element['height'] ?? element.style.height as String,
        unit: 'px', allowPXWithoutSuffix: true) as int?;
  }
  return 0;
}

class UIMasonry extends UIComponent {
  List<MasonryItem> items;

  final NNField<String?> _width =
      NNField('100%', filter: (s) => isNotEmptyString(s) ? s : null);

  final NNField<String?> _height =
      NNField('100%', filter: (s) => isNotEmptyString(s) ? s : null);

  final NNField<int?> _itemsMargin =
      NNField(0, filter: (n) => n != null ? clipNumber(n, 0, 1000) : null);

  final NNField<double?> _dimensionTolerance =
      NNField(0, filter: (n) => n != null ? clipNumber(n, 0, 10) : null);

  final List<String>? scrollbarColors;

  late NNField<int?> _masonryWidthSize;
  late NNField<int?> _masonryHeightSize;

  late CachedComputation<int, Parameters2<List<int?>, double?>,
      Parameters2<List<int>, double>> _computeGCDCache;

  UIMasonry(Element? parent, Iterable<MasonryItem> items,
      {int? masonryWidthSize,
      int? masonryHeightSize,
      int? itemsMargin,
      double? dimensionTolerance,
      String? width,
      String? height,
      this.scrollbarColors,
      dynamic classes,
      dynamic style})
      : items = List<MasonryItem>.from(items),
        super(parent,
            componentClass: 'ui-masonry', classes: classes, style: style) {
    this.width = width;
    this.height = height;
    this.itemsMargin = itemsMargin;
    this.dimensionTolerance = dimensionTolerance;

    _masonryWidthSize = NNField<int?>(0,
        filter: (n) => n is int && n > 10 ? n : null,
        resolver: computeMasonryWidthSize);

    _masonryHeightSize = NNField<int?>(0,
        filter: (n) => n is int && n > 10 ? n : null,
        resolver: computeMasonryHeightSize);

    _masonryWidthSize.set(masonryWidthSize);
    _masonryHeightSize.set(masonryHeightSize);
    _computeGCDCache = CachedComputation(
        _computeGCDImpl as int Function(Parameters2<List<int?>, double?>));
  }

  int? computeMasonryWidthSize(int? masonrySize) =>
      _computeMasonryDimensionSize(
          masonrySize!, () => _getItemsDimension((item) => item.width));

  int? computeMasonryHeightSize(int? masonrySize) =>
      _computeMasonryDimensionSize(
          masonrySize!, () => _getItemsDimension((item) => item.height));

  int? _computeMasonryDimensionSize(
      int masonrySize, List<int?> Function() dimensionsGetter) {
    if (masonrySize <= 0) {
      var dimensions = dimensionsGetter();
      if (dimensions.isEmpty) {
        return 10;
      } else if (dimensions.length == 1) {
        return dimensions.first;
      }
      return _computeGCD(dimensions, dimensionTolerance);
    } else {
      return masonrySize >= 10 ? masonrySize : 10;
    }
  }

  int _computeGCD(List<int?> ns, double? tolerance) =>
      _computeGCDCache.compute(Parameters2(ns, tolerance));

  int _computeGCDImpl(Parameters2<List<int>, double> parameters) {
    var ns = parameters.a;
    var tolerance = parameters.b;

    if (ns.isEmpty) return 0;
    if (ns.length == 1) return ns[0];

    ns.sort();
    var min = ns[0];

    if (tolerance > 0) {
      min = Math.abs(min * (1 + tolerance)).toInt();
    }

    var ratios = <int, double>{};

    for (var i = min; i >= 10; i--) {
      ratios[i] = 0;

      var divides = true;

      for (var n in ns) {
        var rest = n % i;

        if (rest != 0) {
          var rest2 = i - rest;
          if (rest2 < rest) rest = rest2;

          var overRatio = rest / i;
          if (overRatio > ratios[i]!) {
            ratios[i] = overRatio;
          }

          if (tolerance > 0) {
            if (overRatio > tolerance) {
              divides = false;
            }
          } else {
            divides = false;
          }
        }
      }

      if (divides) {
        return i;
      }
    }

    var ratiosEntries = ratios.entries.toList();

    ratiosEntries.sort((a, b) => a.value.compareTo(b.value));

    var minRatioEntry = ratiosEntries[0];

    return minRatioEntry.key;
  }

  List<int?> _getItemsDimension(
      int? Function(MasonryItem item) dimensionGetter) {
    var dimension = <int?>{};
    for (var item in items) {
      var n = dimensionGetter(item);
      dimension.add(n);
    }
    var list = dimension.where((n) => n != null && n >= 10).toList();
    list.sort();
    return list;
  }

  String? get width => _width.value;

  set width(String? value) => _width.value = value;

  String? get height => _height.value;

  set height(String? value) => _height.value = value;

  int get masonryWidthSizeWithItemsMargin =>
      _masonryWidthSize.value! + (itemsMargin! * 1);

  int get masonryHeightSizeWithItemsMargin =>
      _masonryHeightSize.value! + (itemsMargin! * 1);

  int? get masonryWidthSize => _masonryWidthSize.value;

  set masonryWidthSize(int? value) => _masonryWidthSize.value = value;

  int? get masonryHeightSize => _masonryHeightSize.value;

  set masonryHeightSize(int? value) => _masonryHeightSize.value = value;

  int? get itemsMargin => _itemsMargin.value;

  set itemsMargin(int? value) => _itemsMargin.value = value;

  double? get dimensionTolerance => _dimensionTolerance.value;

  set dimensionTolerance(double? value) => _dimensionTolerance.value = value;

  static final TrackElementResize _resizeTracker = TrackElementResize();

  @override
  void configure() {
    _resizeTracker.track(content!, (_) => _onResize());
  }

  void _onResize() {
    requestRefresh();
  }

  List<_MasonryLine>? _renderedLines;

  @override
  dynamic render() {
    content!
      ..style.textAlign = 'center'
      ..style.width = width
      ..style.height = height
      ..style.overflowY = 'auto';

    if (isNotEmptyObject(scrollbarColors)) {
      var buttonColor = scrollbarColors![0].trim();
      var bgColor =
          scrollbarColors!.length > 1 ? scrollbarColors![1].trim() : '';

      setElementScrollColors(content!, 8, buttonColor, bgColor);
    }

    var renderItems = <_MasonryRenderItem>[];

    for (var i = 0; i < items.length; ++i) {
      var item = items[i];
      var renderItem = _MasonryRenderItem(this, i + 1, item);
      renderItems.add(renderItem);
    }

    var renderBounds = content!.getBoundingClientRect();

    var lineMaxWidth = renderBounds.width ~/ masonryWidthSizeWithItemsMargin;

    var lines = _buildLines(renderItems, lineMaxWidth);

    var renderedLines = [];

    for (var line in lines) {
      var renderedLine = line.render();
      renderedLines.add(renderedLine);
    }

    _renderedLines = lines;

    return $div(
        style: 'display: table; width: 100%; height: 100%;',
        content: $div(
            style:
                'display: table-cell; text-align: center; vertical-align: middle;',
            content: renderedLines));
  }

  void _updateDimensionsAndRefresh() {
    updateDimensions();
    requestRefresh();
  }

  @override
  void posRender() {
    if (checkChangedDimension()) {
      Future.delayed(
          Duration(milliseconds: 100), () => _updateDimensionsAndRefresh());
    } else {
      Future.delayed(Duration(milliseconds: 100), () {
        if (checkChangedDimension()) {
          _updateDimensionsAndRefresh();
        }
      });
    }
  }

  bool checkChangedDimension() {
    return _renderedLines != null &&
        _renderedLines!.firstWhereOrNull((e) => e.checkChangedDimension()) !=
            null;
  }

  void updateDimensions() {
    if (_renderedLines != null) {
      for (var e in _renderedLines!) {
        e.updateDimensions();
      }
    }
  }

  int? _sortItems(_MasonryRenderable a, _MasonryRenderable b) {
    var h1 = a.masonryHeight;
    var h2 = b.masonryHeight;
    var cmp = h2.compareTo(h1);
    if (cmp == 0) {
      var w1 = a.masonryWidth;
      var w2 = b.masonryWidth;
      cmp = w2.compareTo(w1);
    }
    return cmp;
  }

  List<_MasonryLine> _buildLines(
      List<_MasonryRenderItem> renderItems, int lineMaxWidth) {
    renderItems.sort(
        _sortItems as int Function(_MasonryRenderItem, _MasonryRenderItem)?);

    var lines = <_MasonryLine>[];
    var line = _MasonryLine(this);

    while (renderItems.isNotEmpty) {
      _MasonryRenderable? item;

      if (line.isEmpty) {
        item = renderItems.removeAt(0);
        line.add(item);
      } else {
        var lineWidth = line.masonryWidth;
        var lineMaxHeight = line.maxMasonryHeight;

        var remainingWidth = lineMaxWidth - lineWidth;

        item = _findItemExactMatch(renderItems, remainingWidth, lineMaxHeight);
        item ??= _findItemNearWidth(renderItems, remainingWidth, lineMaxHeight);
        item ??= _buildGroup(renderItems, remainingWidth, lineMaxHeight);

        if (item != null) {
          line.add(item);
        } else {
          lines.add(line);
          line = _MasonryLine(this);
        }
      }

      if (line.masonryWidth >= lineMaxWidth) {
        lines.add(line);
        line = _MasonryLine(this);
      }
    }

    if (line.isNotEmpty) {
      lines.add(line);
    }

    lines.sort(_sortLines as int Function(_MasonryLine, _MasonryLine)?);

    return lines;
  }

  int? _sortLines(_MasonryLine l1, _MasonryLine l2) {
    var w1 = l1.masonryWidth;
    var w2 = l2.masonryWidth;

    var cmp = w2.compareTo(w1);

    if (cmp == 0) {
      var id1 = l1.lowestID;
      var id2 = l2.lowestID;
      if (id1 != null && id2 != null) {
        cmp = id1.compareTo(id2);
      }
    }

    return cmp;
  }

  _MasonryRenderItem? _findItemExactMatch(
      List<_MasonryRenderItem> renderItems, int width, int height) {
    for (var i = 0; i < renderItems.length; ++i) {
      var item = renderItems[i];

      if (item.masonryWidth == width && item.masonryHeight == height) {
        return renderItems.removeAt(i);
      }
    }
    return null;
  }

  _MasonryRenderItem? _findItemNearWidth(
      List<_MasonryRenderItem> renderItems, int width, int height) {
    for (var i = 0; i < renderItems.length; ++i) {
      var item = renderItems[i];

      if (item.masonryWidth <= width && item.masonryHeight == height) {
        return renderItems.removeAt(i);
      }
    }
    return null;
  }

  _MasonryRenderGroup? _buildGroup(
      List<_MasonryRenderItem> renderItems, int width, int height) {
    var group = _buildGroupImpl(renderItems, width, height, false);
    if (group == null) return null;
    _removeGroupItems(renderItems, group);
    group.sort();
    return group;
  }

  _MasonryRenderGroup? _buildGroupImpl(List<_MasonryRenderItem> renderItems,
      int width, int height, bool exactDimension) {
    if (renderItems.isEmpty) return null;
    if (width <= 0 || height <= 0) return null;

    var w = width;
    var h = height;

    var group = _MasonryRenderGroup.withDimension(this, renderItems, w, h);
    if (group != null) return group;

    h = w = Math.min(width, height);

    while (w > 0 && h > 0) {
      var group1 = _MasonryRenderGroup.withDimension(this, renderItems, w, h);
      if (group1 != null) {
        var renderItems2 = List<_MasonryRenderItem>.from(renderItems);
        _removeGroupItems(renderItems2, group1);

        var neededHeight = height - h;
        var group2 = _buildGroupImpl(renderItems2, w, neededHeight, true);

        if (group2 != null) {
          var item1 = group1.itemsLength == 1 ? group1.getItem(0) : group1;
          var item2 = group2.itemsLength == 1 ? group2.getItem(0) : group2;
          var group = _MasonryRenderGroup(this, [item1, item2], w);
          if (!exactDimension ||
              (group.masonryWidth == width && group.masonryHeight == height)) {
            return group;
          }
        }
      }
      w--;
      h--;
    }

    w = width - 1;
    h = height;

    while (w > 0 && h > 0) {
      if (!exactDimension || (w == width && h == height)) {
        var group = _MasonryRenderGroup.withDimension(this, renderItems, w, h);
        if (group != null) {
          if (!exactDimension ||
              (group.masonryWidth == width && group.masonryHeight == height)) {
            return group;
          }
        }
      }
      w--;
    }

    for (h = height; h > 0; h--) {
      for (w = width - 1; w > 0; w--) {
        if (!exactDimension || (w == width && h == height)) {
          var group = _buildGroupImpl(renderItems, w, h, true);
          if (group != null) {
            if (!exactDimension ||
                (group.masonryWidth == width &&
                    group.masonryHeight == height)) {
              return group;
            }
          }
        }
      }
    }

    for (w = width; w > 0; w--) {
      for (h = height - 1; h > 0; h--) {
        if (!exactDimension || (w == width && h == height)) {
          var group = _buildGroupImpl(renderItems, w, h, true);
          if (group != null) {
            if (!exactDimension ||
                (group.masonryWidth == width &&
                    group.masonryHeight == height)) {
              return group;
            }
          }
        }
      }
    }

    return null;
  }

  void _removeGroupItems(
      List<_MasonryRenderItem> renderItems, _MasonryRenderGroup group) {
    for (var item in group.items) {
      if (item is _MasonryRenderGroup) {
        _removeGroupItems(renderItems, item);
      } else {
        renderItems.remove(item);
      }
    }
  }
}

class _MasonryLine {
  static int _idCounter = 0;
  final int id = ++_idCounter;

  final UIMasonry masonry;

  final List<_MasonryRenderable> _elements = [];

  _MasonryLine(this.masonry);

  int? get itemsMargin => masonry.itemsMargin;

  int get masonryWidthSizeWithItemsMargin =>
      masonry.masonryWidthSizeWithItemsMargin;

  int get masonryHeightSizeWithItemsMargin =>
      masonry.masonryHeightSizeWithItemsMargin;

  int? get masonryWidthSize => masonry.masonryWidthSize;

  int? get masonryHeightSize => masonry.masonryHeightSize;

  bool get isEmpty => _elements.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int _maxMasonryWidth = 0;
  int _maxMasonryHeight = 0;

  int _masonryWidth = 0;

  int get maxMasonryWidth => _maxMasonryWidth;

  int get maxMasonryHeight => _maxMasonryHeight;

  int get masonryWidth => _masonryWidth;

  bool add(_MasonryRenderable elem) {
    var masonryWidth = elem.masonryWidth;

    _masonryWidth += masonryWidth;

    var changedMax = false;

    if (masonryWidth > _maxMasonryWidth) {
      _maxMasonryWidth = masonryWidth;
      changedMax = true;
    }

    var height = elem.masonryHeight;

    if (height > _maxMasonryHeight) {
      _maxMasonryHeight = height;
      changedMax = true;
    }

    _elements.add(elem);

    return changedMax;
  }

  int? get lowestID => minInIterable(_elements.map((e) => e.id)) as int?;

  void sort() {
    _elements.sort();
  }

  Element render() {
    _elements.sort();

    var w = masonryWidth * masonryWidthSizeWithItemsMargin;
    var h = maxMasonryHeight * masonryHeightSizeWithItemsMargin;

    var div = DivElement()
      ..classes.add('ui-masonry-line')
      ..style.textAlign = 'center'
      ..style.margin = '0 auto'
      ..style.width = '${w}px'
      ..style.height = '${h}px'
      ..style.overflow = 'hidden';

    for (var elem in _elements) {
      var rendered = elem.render();
      div.append(rendered);
    }

    return div;
  }

  bool checkChangedDimension() {
    return _elements.firstWhereOrNull((e) => e.checkChangedDimension()) != null;
  }

  void updateDimensions() {
    for (var e in _elements) {
      e.updateDimensions();
    }
  }
}

abstract class _MasonryRenderable implements Comparable<_MasonryRenderable> {
  final UIMasonry masonry;

  _MasonryRenderable(this.masonry);

  int calcMasonryWidth(int? elemSize) =>
      calcMasonryDimension(elemSize, masonryWidthSizeWithItemsMargin);

  int calcMasonryHeight(int? elemSize) =>
      calcMasonryDimension(elemSize, masonryHeightSizeWithItemsMargin);

  int calcMasonryDimension(int? elemSize, int masonrySize) {
    elemSize ??= 0;
    elemSize += itemsMargin! * 2;

    var size = elemSize ~/ masonrySize;

    if (size <= 0) return 1;

    var tolerance = masonry.dimensionTolerance!;
    if (tolerance > 0) {
      var rest = elemSize - (size * masonrySize);
      var overRatio = rest / masonrySize;
      if (overRatio > tolerance) size++;
      return size;
    } else {
      if (elemSize % masonrySize != 0) size++;
      return size;
    }
  }

  int? get itemsMargin => masonry.itemsMargin;

  int get masonryWidthSizeWithItemsMargin =>
      masonry.masonryWidthSizeWithItemsMargin;

  int get masonryHeightSizeWithItemsMargin =>
      masonry.masonryHeightSizeWithItemsMargin;

  int? get masonryWidthSize => masonry.masonryWidthSize;

  int? get masonryHeightSize => masonry.masonryHeightSize;

  int get id;

  int get masonryWidth;

  int get masonryHeight;

  @override
  int compareTo(_MasonryRenderable other) {
    var h1 = masonryHeight;
    var h2 = other.masonryHeight;

    var cmp = h2.compareTo(h1);

    if (cmp == 0) {
      cmp = id.compareTo(other.id);
    }

    return cmp;
  }

  Element render();

  bool checkChangedDimension();

  void updateDimensions();
}

class _MasonryRenderGroup extends _MasonryRenderable {
  final List<_MasonryRenderable> _items;
  final int maxWidth;

  _MasonryRenderGroup(
      UIMasonry masonry, List<_MasonryRenderable> items, this.maxWidth)
      : _items = items,
        super(masonry);

  List<_MasonryRenderable> get items => _items.toList();

  int get itemsLength => _items.length;

  _MasonryRenderable getItem(int idx) => _items[idx];

  void sort() {
    _items.sort();
    for (var item in _items) {
      if (item is _MasonryRenderGroup) {
        item.sort();
      }
    }
  }

  static _MasonryRenderGroup? withDimension(UIMasonry masonry,
      List<_MasonryRenderItem> items, int width, int height) {
    for (var init = 0; init < items.length; ++init) {
      var groupItems = <_MasonryRenderItem>[];

      for (var i = init; i < items.length; ++i) {
        var item = items[i];

        if (item.masonryWidth <= width && item.masonryHeight <= height) {
          groupItems.add(item);

          var g = _MasonryRenderGroup(masonry, groupItems, width);
          if (g.allWidth >= width) {
            var groupWidth = g.masonryWidth;
            var groupHeight = g.masonryHeight;

            if (groupWidth == width && groupHeight == height && !g.hasGap) {
              return g;
            } else if (groupWidth <= width &&
                groupHeight < height &&
                !g.hasGap) {
              continue;
            } else {
              groupItems.removeLast();
            }
          } else {
            continue;
          }
        }
      }
    }

    return null;
  }

  int get allWidth =>
      sumIterable(_items.map((_MasonryRenderable e) => e.masonryWidth)).toInt();

  @override
  int get masonryWidth {
    int lineWidth = 0;
    int lineMaxWidth = 0;

    for (var i = 0; i < _items.length; ++i) {
      var item = _items[i];

      if (lineWidth >= maxWidth) {
        if (lineWidth > lineMaxWidth) {
          lineMaxWidth = lineWidth;
        }

        lineWidth = item.masonryWidth;
      } else {
        lineWidth += item.masonryWidth;
      }
    }

    if (lineWidth > lineMaxWidth) {
      lineMaxWidth = lineWidth;
    }

    return lineMaxWidth;
  }

  @override
  int get masonryHeight {
    int? lineWidth = 0;
    var lineHeight = 0;

    int? lineMaxHeight = 0;

    for (var i = 0; i < _items.length; ++i) {
      var item = _items[i];

      if (lineWidth! >= maxWidth) {
        lineHeight += lineMaxHeight!;

        lineMaxHeight = item.masonryHeight;
        lineWidth = item.masonryWidth;
      } else {
        lineWidth += item.masonryWidth;
        if (item.masonryHeight > lineMaxHeight!) {
          lineMaxHeight = item.masonryHeight;
        }
      }
    }

    lineHeight += lineMaxHeight!;

    return lineHeight;
  }

  bool get hasGap {
    int? lineWidth = 0;
    int? lineMaxWidth = 0;
    int? lineMaxHeight = 0;

    for (var i = 0; i < _items.length; ++i) {
      var item = _items[i];

      if (item is _MasonryRenderGroup) {
        if (item.hasGap) {
          return true;
        }
      }

      if (lineWidth! >= maxWidth) {
        if (lineMaxWidth == 0) {
          lineMaxWidth = lineWidth;
        } else if (lineWidth != lineMaxWidth) {
          return true;
        }

        lineMaxHeight = item.masonryHeight;
        lineWidth = item.masonryWidth;
      } else {
        lineWidth += item.masonryWidth;

        if (lineMaxHeight == 0) {
          lineMaxHeight = item.masonryHeight;
        } else if (item.masonryHeight != lineMaxHeight) {
          return true;
        }
      }
    }

    if (lineMaxWidth! > 0 && lineWidth != lineMaxWidth) {
      return true;
    }

    return false;
  }

  @override
  int get id {
    var id = _items[0].id;
    for (var item in _items) {
      var itemID = item.id;
      if (itemID < id) {
        id = itemID;
      }
    }
    return id;
  }

  @override
  Element render() {
    var div = DivElement()
      ..classes.add('ui-masonry-group')
      ..style.display = 'inline-block'
      ..style.overflow = 'hidden'
      ..style.verticalAlign = 'top';

    var lineWidth = 0;
    for (var i = 0; i < _items.length; ++i) {
      var item = _items[i];

      if (lineWidth >= maxWidth) {
        div.append(BRElement());
        lineWidth = 0;
      }

      var elem = item.render();
      div.append(elem);

      lineWidth += item.masonryWidth;
    }

    return div;
  }

  @override
  bool checkChangedDimension() {
    return _items.firstWhereOrNull((e) => e.checkChangedDimension()) != null;
  }

  @override
  void updateDimensions() {
    for (var e in _items) {
      e.updateDimensions();
    }
  }
}

class _MasonryRenderItem extends _MasonryRenderable {
  @override
  final int id;
  final MasonryItem item;

  _MasonryRenderItem(UIMasonry masonry, this.id, this.item) : super(masonry);

  int? _masonryWidth;

  int? _masonryWidthInput;

  @override
  int get masonryWidth {
    var masonryWidth = _masonryWidth;
    if (masonryWidth == null || _masonryWidthInput != item.width) {
      _masonryWidthInput = item.width;
      _masonryWidth = masonryWidth = calcMasonryWidth(_masonryWidthInput);
    }
    return masonryWidth;
  }

  int? _masonryHeight;

  int? _masonryHeightInput;

  @override
  int get masonryHeight {
    var masonryHeight = _masonryHeight;
    if (masonryHeight == null || _masonryHeightInput != item.height) {
      _masonryHeightInput = item.height;
      _masonryHeight = masonryHeight = calcMasonryHeight(_masonryHeightInput);
    }
    return masonryHeight;
  }

  @override
  Element render() {
    var w2 = masonryWidth * masonryWidthSizeWithItemsMargin;
    var h2 = masonryHeight * masonryHeightSizeWithItemsMargin;

    var w = w2 - (itemsMargin! * 1);
    var h = h2 - (itemsMargin! * 1);

    var div1 = DivElement()
      ..classes.add('ui-masonry-block')
      ..style.cssText =
          'display: inline-block; vertical-align: top; text-align: center; overflow: hidden; width: ${w2}px; height: ${h2}px; margin: 0px;';

    var div2 = DivElement()
      ..style.cssText = 'display: table; width: 100%; height: 100%;';

    var div3 = DivElement()
      ..style.cssText =
          'display: table-cell; text-align: center; vertical-align: middle;';

    var div4 = DivElement()
      ..classes.add('ui-masonry-item')
      ..style.cssText =
          'display: inline-block; max-width: ${w}px; max-height: ${h}px';

    div1.append(div2);
    div2.append(div3);
    div3.append(div4);
    div4.append(item.element);

    return div1;
  }

  @override
  bool checkChangedDimension() => item.checkChangedDimension();

  @override
  void updateDimensions() => item.updateDimensions();
}
