import 'dart:async';
import 'dart:html';
import 'dart:svg' as dart_svg;

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Component to show a SVG.
class UISVG extends UIComponent {
  static final ResourceContentCache _resourceContentCache =
      ResourceContentCache();

  /// Source for the SVG.
  final String? src;

  /// SVG tag to render.
  final String? svgContent;

  /// Width of the SVG.
  final String width;

  /// Height of the SVG.
  final String height;

  /// Title of the SVG.
  final String? title;

  /// Color to render the SVG.
  final String? color;

  UISVG(Element? parent,
      {this.src,
      this.svgContent,
      this.width = '20px',
      this.height = '20px',
      this.title,
      this.color,
      String? classes,
      String? style})
      : super(parent, componentClass: 'ui-svg', classes: classes, style: style);

  CSSLength? get widthAsCSSLength => CSSLength.parse(width);

  CSSLength? get heightAsCSSLength => CSSLength.parse(height);

  String get widthAsCSSValue => (CSSLength.parse(width) ?? width).toString();

  String get heightAsCSSValue => (CSSLength.parse(height) ?? height).toString();

  Element? _renderedElement;

  /// Returns the [Element] rendered.
  Element? get renderedElement => _renderedElement;

  /// Returns [true] if it was rendered as an [ImageElement].
  bool get isRenderedAsImage => _renderedElement is ImageElement;

  /// Returns [true] if it was rendered as an [SvgElement].
  bool get isRenderedAsSVG => _renderedElement is dart_svg.SvgElement;

  @override
  dynamic render() {
    if (svgContent != null && svgContent!.isNotEmpty) {
      return _renderFromSVGContent();
    } else {
      return _renderFromSRC();
    }
  }

  Element _renderFromSVGContent() {
    return buildSVGElement(svgContent);
  }

  Element? _renderFromSRC() {
    if (src == null || src!.isEmpty) return null;

    var resourceContent = _resourceContentCache.get(src)!;

    Element element;

    if (resourceContent.isLoaded) {
      var content = resourceContent.getContentIfLoaded();
      var svg = buildSVGElement(content);
      element = svg;
    } else {
      resourceContent.onLoad.listen((_) => refresh());
      resourceContent.getContent();
      element = buildSVGImg();
    }

    _renderedElement = element;

    return element;
  }

  static final NodeValidatorBuilder _svgNodeValidator =
      createStandardNodeValidator(svg: true, allowSvgForeignObject: true);

  dart_svg.SvgElement buildSVGElement([String? content]) {
    content ??= svgContent;

    var svg = createHTML(content, _svgNodeValidator) as dart_svg.SvgElement;

    _applyDimension(svg);

    if (color != null && color!.isNotEmpty) {
      svg.style.cssText = (svg.style.cssText ?? '') + 'fill: $color';
    }

    if (title != null && title!.isNotEmpty) {
      svg.setAttribute('data-toggle', 'tooltip');
      svg.setAttribute('title', title!);
    }

    return svg;
  }

  ImageElement buildSVGImg() {
    ImageElement img;
    if (isEmptyObject(src) && isNotEmptyObject(svgContent)) {
      var svgDataURL =
          'data:image/svg+xml;base64,' + Base64.encode(svgContent!);
      img = ImageElement(src: svgDataURL);
    } else {
      img = ImageElement(src: src);
    }

    _applyDimension(img);

    if (title != null && title!.isNotEmpty) img.title = title;

    return img;
  }

  void _applyDimension(Element elem) {
    elem.removeAttribute('width');
    elem.removeAttribute('height');

    if (width.isNotEmpty) {
      var w = widthAsCSSValue;
      elem.style.width = w;
    }
    if (height.isNotEmpty) {
      var h = heightAsCSSValue;
      elem.style.height = h;
    }
  }

  Future<ImageElement> buildRenderedImage() {
    var svgIMG = buildSVGImg();

    var completer = Completer<ImageElement>();

    svgIMG.onLoad.listen((event) {
      var img = _drawImageToCanvas(svgIMG);
      completer.complete(img);
    });

    return completer.future;
  }

  ImageElement _drawImageToCanvas(ImageElement img) {
    var w = widthAsCSSLength!.value.toInt();
    var h = heightAsCSSLength!.value.toInt();

    var canvas = CanvasElement(width: w, height: h);

    var ctx = canvas.context2D;
    ctx.clearRect(0, 0, w, h);
    ctx.drawImage(img, 0, 0);

    var imgDataURL = canvas.toDataUrl('image/png', 1.0);

    var imgRendered = ImageElement(src: imgDataURL);
    _applyDimension(imgRendered);

    return imgRendered;
  }
}

String? htmlAsSvgContent(String html,
    {int? width, int? height, String? rootClass, String? style}) {
  print(style);
  var htmlRoot = $htmlRoot(html);
  if (htmlRoot == null) return null;

  if (isNotEmptyObject(rootClass)) {
    htmlRoot.addClass('ui-render');
  }

  htmlRoot
      .selectAllWhere((n) => true)
      .whereType<DOMElement>()
      .forEach((e) => e['xmlns'] = 'http://www.w3.org/1999/xhtml');

  html = htmlRoot.buildHTML(xhtml: true);

  var svg =
      '''<svg viewBox="0 0 $width $height" width="${width}px" height="${height}px" xmlns="http://www.w3.org/2000/svg">
<foreignObject x="0" y="0" width="$width" height="$height">
<html xmlns="http://www.w3.org/1999/xhtml">
<head xmlns="http://www.w3.org/1999/xhtml">
<style xmlns="http://www.w3.org/1999/xhtml">
$style
</style>
</head>
<body xmlns="http://www.w3.org/1999/xhtml">
$html
</body>
</html>
</foreignObject>
</svg>''';

  return svg;
}
