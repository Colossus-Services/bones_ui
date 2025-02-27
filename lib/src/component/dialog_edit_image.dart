import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:web_utils/web_utils.dart';

import 'dialog.dart';

/// An [UIDialog] that edits an [image].
class UIDialogEditImage extends UIDialog {
  /// The original image.
  final HTMLImageElement image;

  final int marginHorizontal;
  final int marginVertical;

  final String? btnClasses;

  final String? btnStyle;

  UIDialogEditImage(this.image,
      {this.btnClasses = 'btn btn-primary',
      this.btnStyle =
          'background-color: rgba(0,0,0, 0.50); color: #ffffff; border-color: #ffffff;',
      this.marginHorizontal = 8,
      this.marginVertical = 48,
      super.hideUIRoot = false})
      : super(null,
            showCloseButton: true,
            backgroundGrey: 16,
            backgroundAlpha: 0.80,
            backgroundBlur: 2) {
    onClickListenOnlyForDialogButtonClass = true;
  }

  _CanvasEditImage? _canvasEditImage;

  @override
  dynamic renderContent() {
    _canvasEditImage ??= _CanvasEditImage(image, image.naturalWidth,
        image.naturalHeight, marginHorizontal, marginVertical);

    return [
      _canvasEditImage!,
      $br(),
      $button(
          classes: btnClasses,
          style: btnStyle,
          content: $span(content: '&nbsp;+&nbsp;'))
        ..onClick.listen((event) => _canvasEditImage?.zoomIn()),
      $nbsp(),
      $button(
          classes: btnClasses,
          style: btnStyle,
          content: $span(content: '&nbsp;-&nbsp;'))
        ..onClick.listen((event) => _canvasEditImage?.zoomOut()),
      $nbsp(6),
      $button(classes: btnClasses, style: btnStyle, content: 'OK')
        ..onClick.listen((_) => hide()),
    ];
  }

  /// The [editedImage] data URL.
  String? get editedImageDataURL => _canvasEditImage?.imageDataURL;

  /// The edited image.
  /// See [editedImageDataURL].
  HTMLImageElement? get editedImage {
    var imageDataURL = editedImageDataURL;
    if (imageDataURL == null || !imageDataURL.startsWith('data:')) return null;

    //print(imageDataURL);
    //downloadDataURL(DataURLBase64.parse(imageDataURL)!, 'edited-image.jpeg');

    return HTMLImageElement()..src = imageDataURL;
  }
}

class _CanvasEditImage extends ExternalElementNode {
  final CanvasImageSource img;
  final int imgNaturalWidth;
  final int imgNaturalHeight;
  final int marginHorizontal;
  final int marginVertical;

  late final TrackElementResize _elementResize;

  _CanvasEditImage(this.img, this.imgNaturalWidth, this.imgNaturalHeight,
      this.marginHorizontal, this.marginVertical)
      : super(_buildCanvas(img, imgNaturalWidth, imgNaturalHeight,
            marginHorizontal, marginVertical)) {
    _elementResize = TrackElementResize();

    _resetZoom();
    render();

    var canvas = this.canvas;

    _elementResize.track(canvas, (_) => _onResize(false));
    window.onResize.listen((_) => _onResize(true));

    canvas.onMouseDown.listen((evt) => _onMouseDown1(evt.offsetPoint));
    canvas.onMouseMove.listen((evt) => _onMouseMove(evt.offsetPoint));
    canvas.onMouseUp.listen((evt) => _onMouseUp());
    canvas.onMouseLeave.listen((evt) => _onMouseUp());

    canvas.onTouchStart.listen((evt) => _pointHandler(evt, _onMouseDown1));
    canvas.onTouchMove.listen((evt) => _pointHandler(evt, _onMouseMove));
    canvas.onTouchEnd.listen((evt) => _onMouseUp());
    canvas.onTouchLeave.listen((evt) => _onMouseUp());
  }

  int innerWidth = math.max(1, window.innerWidth);

  int innerHeight = math.max(1, window.innerHeight);

  void _onResize(bool windowResize) {
    var innerWidth = window.innerWidth;
    var innerHeight = window.innerHeight;

    if (innerWidth < 1 || innerHeight < 1) return;

    var wR = innerWidth / this.innerWidth;
    var hR = innerHeight / this.innerHeight;

    var wRd = (1 - wR).abs();
    var hRd = (1 - hR).abs();

    var r = math.max(wRd, hRd);

    //print('!!! _onResize[$window]> $wR x $hR');

    _updateCanvasDimension();

    if (r > 0.15) {
      _resetZoom();
    }
  }

  static void _pointHandler(
      TouchEvent event, void Function(Point<num> p1, [Point<num>? p2]) f) {
    var canvasTouches = event.touches
        .toIterable()
        .where((t) => t.target.isA<HTMLCanvasElement>())
        .toList();

    if (canvasTouches.isEmpty) {
      return;
    } else if (canvasTouches.length == 1) {
      event.preventDefault();

      var point1 = canvasTouches[0].clientPoint;
      //print('!!! touch> $event > $point1 >> ${event.touches} > ${event.touches?.map((e) => e.target)} ');

      f(point1);
    } else if (canvasTouches.length == 2) {
      event.preventDefault();

      var point1 = canvasTouches[0].clientPoint;
      var point2 = canvasTouches[1].clientPoint;
      //print('!!! touch> $event > $point1 & $point2 >> ${event.touches} > ${event.touches?.map((e) => e.target)} ');

      f(point1, point2);
    }
  }

  Point<num>? _translateStart;
  double? _zoomStart;
  Point<num>? _moveStart1;
  Point<num>? _moveStart2;
  bool _moveScaling = false;

  void _onMouseDown1(Point<num> point1, [Point<num>? point2]) {
    _translateStart = translate ?? Point<num>(0, 0);
    _zoomStart = zoom;
    _moveStart1 = point1;
    _moveStart2 = point2;
    _moveScaling = point2 != null;
    _showGrid = true;
  }

  void _onMouseMove(Point<num> point1, [Point<num>? point2]) {
    //print('!!! _onMouseMove> $point1');

    var translateStart = _translateStart;
    var zoomStart = _zoomStart;
    var moveStart1 = _moveStart1;
    var moveStart2 = _moveStart2;
    var moveScaling = _moveScaling;

    if (moveStart1 == null || translateStart == null || zoomStart == null) {
      return;
    }

    if (moveScaling) {
      if (moveStart2 == null) {
        throw StateError("`moveScaling`: null `moveStart2`");
      }
      if (point2 == null) return;

      var startDistance = moveStart1.distanceTo(moveStart2);
      var pointDistance = point1.distanceTo(point2);

      var zoomRatio = pointDistance / startDistance;
      var zoom2 = zoomStart * zoomRatio;
      //print('!!! zoomRatio> $zoomStart * $zoomRatio = $zoom2');

      zoom = zoom2;
    } else {
      var tx = point1.x - moveStart1.x;
      var ty = point1.y - moveStart1.y;

      var x = translateStart.x + tx;
      var y = translateStart.y + ty;

      translate = Point<num>(x, y);
    }
  }

  void _onMouseUp() {
    _translateStart = null;
    _zoomStart = null;
    _moveStart1 = null;
    _moveStart2 = null;
    _moveScaling = false;
    _showGrid = false;
    requestRender();
  }

  static HTMLCanvasElement _buildCanvas(
      CanvasImageSource img,
      int imgNaturalWidth,
      int imgNaturalHeight,
      int marginHorizontal,
      int marginVertical) {
    var d = _calcCanvasDimension(
        imgNaturalWidth, imgNaturalHeight, marginHorizontal, marginVertical);
    var w = d[0];
    var h = d[1];

    return HTMLCanvasElement()
      ..width = w
      ..height = h
      ..style.boxShadow = '0px 1px 18px 5px rgba(0, 0, 0, 0.65)'
      ..style.borderRadius = '12px';
  }

  static double _calcZoom(int imgNaturalWidth, int imgNaturalHeight,
      int canvasWidth, int canvasHeight) {
    var zoomW =
        imgNaturalWidth <= canvasWidth ? 1.0 : canvasWidth / imgNaturalWidth;
    var zoomH = imgNaturalHeight <= canvasHeight
        ? 1.0
        : canvasHeight / imgNaturalHeight;
    var zoom = math.min(zoomW, zoomH);
    return zoom;
  }

  static List<int> _calcCanvasDimension(int imgNaturalWidth,
      int imgNaturalHeight, int marginHorizontal, int marginVertical) {
    var innerWidth = window.innerWidth - (marginHorizontal * 2);
    var innerHeight = window.innerHeight - (marginVertical * 2);

    var zoom =
        _calcZoom(imgNaturalWidth, imgNaturalHeight, innerWidth, innerHeight);

    var imgW = (imgNaturalWidth * zoom).toInt();
    var imgH = (imgNaturalHeight * zoom).toInt();

    var w = math.min(imgW, innerWidth);
    var h = math.min(imgH, innerHeight);

    return [w, h];
  }

  void _updateCanvasDimension() {
    var d = _calcCanvasDimension(
        imgNaturalWidth, imgNaturalHeight, marginHorizontal, marginVertical);
    var w = d[0];
    var h = d[1];

    canvas
      ..width = w
      ..height = h;

    //print('!!! canvas dimension> $w x $h');

    requestRender();
  }

  double _fitZoom = 1.0;

  double _zoom = 1.0;

  void _resetZoom() {
    _fitZoom = _zoom =
        _calcZoom(imgNaturalWidth, imgNaturalHeight, canvasWidth, canvasHeight);

    var t = _translate;
    if (t != null) {
      translate = Point(t.x + 1, t.y);
    }

    requestRender();
  }

  double get zoom => _zoom;

  set zoom(double zoom) {
    if (zoom > 0.99 && zoom < 1.01) {
      zoom = 1.0;
    } else if (zoom <= 0.01) {
      zoom = 0.1;
    }
    if (_zoom == zoom) return;

    var prevZoom = _zoom;
    var prevTranslate = _translate;

    if (zoom < _fitZoom) {
      zoom = _fitZoom;
    }

    _zoom = zoom;

    if (prevTranslate != null) {
      var r = zoom / prevZoom;
      translate = Point<num>(prevTranslate.x * r, prevTranslate.y * r);
    }

    requestRender();
  }

  void zoomIn([double amount = 0.02]) => zoom += amount;

  void zoomOut([double amount = 0.02]) => zoom -= amount;

  Point<num>? _translate;

  Point<num>? get translate => _translate;

  set translate(Point<num>? translate) {
    if (_translate == translate) return;

    if (translate == null) {
      _translate = null;
      return;
    }

    var marginW = (renderWidth - canvasWidth) ~/ 2;
    var marginH = (renderHeight - canvasHeight) ~/ 2;

    if (translate.x > marginW) {
      translate = Point<num>(marginW, translate.y);
    } else if (translate.x < -marginW) {
      translate = Point<num>(-marginW, translate.y);
    }

    if (translate.y > marginH) {
      translate = Point<num>(translate.x, marginH);
    } else if (translate.y < -marginH) {
      translate = Point<num>(translate.x, -marginH);
    }

    _translate = translate;
    requestRender();
  }

  HTMLCanvasElement get canvas => externalElement as HTMLCanvasElement;

  int get renderWidth => (imgNaturalWidth * _zoom).toInt();

  int get renderHeight => (imgNaturalHeight * _zoom).toInt();

  int get renderX {
    var x = (canvasWidth - renderWidth) ~/ 2;
    var t = _translate;
    return t != null ? x + t.x.toInt() : x;
  }

  int get renderY {
    var y = (canvasHeight - renderHeight) ~/ 2;
    var t = _translate;
    return t != null ? y + t.y.toInt() : y;
  }

  int get canvasWidth => canvas.width;

  int get canvasHeight => canvas.height;

  Future? _rendering;

  void requestRender() {
    if (_rendering != null) return;
    _rendering = Future.microtask(render);
  }

  bool _showGrid = false;

  void render() {
    var canvas = this.canvas;
    var context2d = canvas.context2D;

    context2d.clearRect(0, 0, canvasWidth, canvasHeight);
    context2d.drawImage(
      img,
      renderX.toDouble(),
      renderY.toDouble(),
      renderWidth.toDouble(),
      renderHeight.toDouble(),
    );

    if (_showGrid) {
      var wDiv4 = canvasWidth ~/ 3;
      var hDiv4 = canvasHeight ~/ 3;

      context2d.fillStyle = 'rgba(0,0,0, 0.20)'.toJS;

      context2d.fillRect(wDiv4, 0, 2, canvasHeight);
      context2d.fillRect(canvasWidth - wDiv4, 0, 2, canvasHeight);

      context2d.fillRect(0, hDiv4, canvasWidth, 2);
      context2d.fillRect(0, canvasHeight - hDiv4, canvasWidth, 2);
    }

    //print('!!! render[zoom: $zoom${translate != null ? ' ; translate: $translate' : ''}]> $imgX , $imgY ; $imgW x $imgH');

    _rendering = null;
  }

  String get imageDataURL {
    var t = _translate;
    var zoom = _zoom;

    final zoomFitReverse = 1 / _fitZoom;

    zoom = zoom * zoomFitReverse;
    if (t != null) {
      t = Point((t.x * zoomFitReverse).toInt(), (t.y * zoomFitReverse).toInt());
    }

    var canvasWidth = imgNaturalWidth;
    var canvasHeight = imgNaturalHeight;

    var canvas = HTMLCanvasElement()
      ..width = canvasWidth
      ..height = canvasHeight;

    var imgW = (imgNaturalWidth * zoom).toInt();
    var imgH = (imgNaturalHeight * zoom).toInt();

    var x = (canvasWidth - imgW) ~/ 2;
    var y = (canvasHeight - imgH) ~/ 2;

    if (t != null) {
      x = x + t.x.toInt();
      y = y + t.y.toInt();
    }

    var context2d = canvas.context2D;
    context2d.imageSmoothingEnabled = true;
    context2d.imageSmoothingQuality = 'high';

    context2d.drawImage(
      img,
      x.toDouble(),
      y.toDouble(),
      imgW.toDouble(),
      imgH.toDouble(),
    );

    return canvas.toDataUrl('image/jpeg', 0.98);
  }
}
