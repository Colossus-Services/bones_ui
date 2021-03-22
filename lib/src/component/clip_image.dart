import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Represents an image clip parameters.
class ImageClip {
  /// [Dimension] of viewed image.
  final Dimension viewDimension;

  /// Clip [Rectangle].
  final Rectangle? viewClip;

  Dimension? _imageDimension;

  Dimension? get imageDimension => _imageDimension;

  Rectangle? _clip;

  Rectangle? get clip => _clip;

  ImageClip(this.viewDimension, this.viewClip, [this._imageDimension]) {
    if (_imageDimension != null) {
      var wR = viewDimension.width / _imageDimension!.width;
      var hR = viewDimension.height / _imageDimension!.height;

      var r = wR < hR ? wR : hR;

      var w = (_imageDimension!.width * r).toInt();
      var h = (_imageDimension!.height * r).toInt();

      var imgViewRect = Rectangle(
          (viewDimension.width - w) / 2, (viewDimension.height - h) / 2, w, h);

      var imgViewClip = imgViewRect.intersection(viewClip!)!;

      var rInv = 1 / r;

      var imgRect = Rectangle(imgViewRect.left * rInv, imgViewRect.top * rInv,
          imgViewRect.width * rInv, imgViewRect.height * rInv);
      var imgClip = Rectangle(
        (imgViewClip.left * rInv).toInt(),
        (imgViewClip.top * rInv).toInt(),
        (imgViewClip.width * rInv).toInt(),
        (imgViewClip.height * rInv).toInt(),
      );

      imgClip = Rectangle(
          (imgClip.left - imgRect.left).toInt(),
          (imgClip.top - imgRect.top).toInt(),
          imgClip.width.toInt(),
          imgClip.height.toInt());

      _clip = imgClip;
    } else {
      _imageDimension = viewDimension;
      _clip = viewClip;
    }
  }
}

/// Component to clip an image.
class UIClipImage extends UIComponent {
  final ImageElement _img;

  int imgWidth;

  int imgHeight;

  String color;

  UIClipImage(Element container, this._img,
      {this.imgWidth = 0,
      this.imgHeight = 0,
      this.color = '#00ff00',
      dynamic classes})
      : super(container, classes: 'ui-dialog', classes2: classes);

  @override
  void configure() {
    content!.onTouchStart.listen(_startPoint);
    content!.onMouseDown.listen(_startPoint);

    content!.onTouchMove.listen(_movePoint);
    content!.onMouseMove.listen(_movePoint);

    content!.onTouchEnd.listen(_endPoint);
    content!.onMouseUp.listen(_endPoint);

    content!.draggable = false;

    content!.style.width = '100%';
    content!.style.height = '100%';

    _img.draggable = false;

    _img.style.width = '100%';
    _img.style.height = '100%';
    _img.style.objectFit = 'contain';
  }

  @override
  dynamic render() {
    _img.remove();

    return [_img];
  }

  Point? parsePoint(Event e) {
    if (e is TouchEvent) {
      var p = e.changedTouches!.first.client;
      return Point(p.x - _img.offset.left, p.y - _img.offset.top);
    } else if (e is MouseEvent) {
      var p = e.page;
      return Point(p.x - _img.offset.left, p.y - _img.offset.top);
    }
    return null;
  }

  Point? _start;

  void _startPoint(Event e) {
    _start = parsePoint(e);
    _clearRects();
  }

  Element? _divRectDrag;

  void _movePoint(Event e) {
    if (_start == null) return;

    var p = parsePoint(e);

    _clearRects();

    var rect = _createRect(_start, p)!;
    _divRectDrag = _createRectDiv(rect);

    content!.children.add(_divRectDrag!);
  }

  void _clearRects() {
    if (_divRectDrag != null) _divRectDrag!.remove();
    if (_divRect != null) _divRect!.remove();
  }

  Element? _divRect;

  ImageClip? _imageClip;

  void _endPoint(Event e) {
    var start = _start;
    var end = parsePoint(e);

    _start = null;

    _clearRects();

    _imageViewDimension = Rectangle(0, 0, _img.offsetWidth, _img.offsetHeight);

    var clipRect = _createRect(start, end)!;

    _clipRect = Rectangle(clipRect.left - _img.offsetLeft,
        clipRect.top - _img.offsetTop, clipRect.width, clipRect.height);

    if (_clipRect!.width > 1 && _clipRect!.height > 1) {
      _imageClip = ImageClip(Dimension(_img.offsetWidth, _img.offsetHeight),
          _clipRect, imageDimension);
    } else {
      _imageClip = null;
    }

    _divRect = _createRectDiv(clipRect);

    content!.children.add(_divRect!);

    onChangeClip.add(_clipRect);
    onChange.add(this);
  }

  bool get hasImageDimension => imgWidth > 0 && imgHeight > 0;

  Dimension? get imageDimension =>
      hasImageDimension ? Dimension(imgWidth, imgHeight) : null;

  final EventStream<Rectangle?> onChangeClip = EventStream();

  Rectangle? _imageViewDimension;

  Rectangle? get imageViewDimension => _imageViewDimension;

  Rectangle? _clipRect;

  Rectangle? get clipRectangle => _clipRect;

  bool get hasClipRectangle =>
      _clipRect != null && _clipRect!.width > 0 && _clipRect!.height > 0;

  ImageClip? get imageClip => _imageClip;

  DivElement _createRectDiv(Rectangle rect) {
    var div = DivElement();
    div.style
      ..width = '${rect.width}px'
      ..height = '${rect.height}px'
      ..backgroundColor = color
      ..opacity = '0.5'
      ..position = 'absolute'
      ..left = '${rect.left}px'
      ..top = '${rect.top}px';

    return div;
  }

  Rectangle? _createRect(Point? p1, Point? p2) {
    if (p1 == null || p2 == null) return null;

    var x1 = Math.min(p1.x, p2.x);
    var y1 = Math.min(p1.y, p2.y);

    var x2 = Math.max(p1.x, p2.x);
    var y2 = Math.max(p1.y, p2.y);

    if (x1 < 0) x1 = 0;
    if (y1 < 0) y1 = 0;

    var imgViewWidth = _img.offsetWidth;
    var imgViewHeight = _img.offsetHeight;

    if (imgViewWidth > 0 && x2 > imgViewWidth) {
      x2 = imgViewWidth;
    }
    if (imgViewHeight > 0 && y2 > imgViewHeight) {
      y2 = imgViewHeight;
    }

    var x = x1.toInt();
    var y = y1.toInt();
    var w = (x2 - x1).toInt();
    var h = (y2 - y1).toInt();

    var left = (_img.offset.left + x).toInt();
    var top = (_img.offset.top + y).toInt();

    return Rectangle(left, top, w, h);
  }
}
