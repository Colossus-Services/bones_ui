import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';

/// [DOMElement] tag `ui-svg` for [UISVG].
DOMElement $uiSVG({
  id,
  String? field,
  classes,
  style,
  String? src,
  width,
  height,
  color,
  title,
  Map<String, String>? attributes,
  content,
  bool commented = false,
}) {
  return $tag(
    'ui-svg',
    id: id,
    classes: classes,
    style: style,
    attributes: {
      if (field != null && field.isNotEmpty) 'field': field,
      if (src != null) 'src': src,
      if (width != null) 'width': '$width',
      if (height != null) 'height': '$height',
      if (color != null) 'color': '$color',
      if (title != null) 'title': '$title',
      ...?attributes
    },
    content: content,
    commented: commented,
  );
}

/// Component to show a SVG.
class UISVG extends UIComponent {
  static final UIComponentGenerator<UISVG> generator =
      UIComponentGenerator<UISVG>(
          'ui-svg',
          'div',
          'ui-svg',
          '',
          (parent, attributes, contentHolder, contentNodes) => UISVG(
                parent,
                src: attributes['src']?.value,
                svgContent: contentHolder?.textContent,
                width: attributes['width']?.value ?? '20px',
                height: attributes['height']?.value ?? '20px',
                color: attributes['color']?.value,
                title: attributes['title']?.value,
              ),
          [
            UIComponentAttributeHandler<UISVG, String>('src',
                parser: parseString,
                getter: (c) => c.src,
                setter: (c, v) => c.src = v,
                appender: (c, v) => c.src = (c.src ?? '') + (v ?? ''),
                cleaner: (c) => c.src = null),
            UIComponentAttributeHandler<UISVG, String>('svg-content',
                parser: parseString,
                getter: (c) => c.svgContent,
                setter: (c, v) => c.svgContent = v,
                appender: (c, v) =>
                    c.svgContent = (c.svgContent ?? '') + (v ?? ''),
                cleaner: (c) => c.svgContent = null),
            UIComponentAttributeHandler<UISVG, String>('color',
                parser: parseString,
                getter: (c) => c.color,
                setter: (c, v) => c.color = v,
                appender: (c, v) => c.color = (c.color ?? '') + (v ?? ''),
                cleaner: (c) => c.color = null),
            UIComponentAttributeHandler<UISVG, String>('title',
                parser: parseString,
                getter: (c) => c.title,
                setter: (c, v) => c.title = v,
                appender: (c, v) => c.title = (c.title ?? '') + (v ?? ''),
                cleaner: (c) => c.title = null),
            UIComponentAttributeHandler<UISVG, String>('width',
                parser: parseString,
                getter: (c) => c.width,
                setter: (c, v) => c.width = v ?? '20px',
                appender: (c, v) => c.width = v ?? '20px',
                cleaner: (c) => c.width = '20px'),
            UIComponentAttributeHandler<UISVG, String>('height',
                parser: parseString,
                getter: (c) => c.height,
                setter: (c, v) => c.height = v ?? '20px',
                appender: (c, v) => c.height = v ?? '20px',
                cleaner: (c) => c.height = '20px'),
          ],
          hasChildrenElements: false,
          contentAsText: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  static final ResourceContentCache _resourceContentCache =
      ResourceContentCache();

  /// Source for the SVG.
  String? src;

  /// SVG tag to render.
  String? svgContent;

  /// Width of the SVG.
  String width;

  /// Height of the SVG.
  String height;

  /// Title of the SVG.
  String? title;

  /// Color to render the SVG.
  String? color;

  UISVG(super.parent,
      {this.src,
      this.svgContent,
      this.width = '20px',
      this.height = '20px',
      this.title,
      this.color,
      String? super.classes,
      String? super.style})
      : super(componentClass: 'ui-svg');

  CSSLength? get widthAsCSSLength => CSSLength.parse(width);

  CSSLength? get heightAsCSSLength => CSSLength.parse(height);

  String get widthAsCSSValue => (CSSLength.parse(width) ?? width).toString();

  String get heightAsCSSValue => (CSSLength.parse(height) ?? height).toString();

  Element? _renderedElement;

  /// Returns the [Element] rendered.
  Element? get renderedElement => _renderedElement;

  /// Returns [true] if it was rendered as an [HTMLImageElement].
  bool get isRenderedAsImage => _renderedElement.isA<HTMLImageElement>();

  /// Returns [true] if it was rendered as an [SvgElement].
  bool get isRenderedAsSVG => _renderedElement.isA<SVGElement>();

  @override
  dynamic render() {
    if (svgContent != null && svgContent!.isNotEmpty) {
      return _renderFromSVGContent();
    } else {
      return _renderFromSRC();
    }
  }

  Element? _renderFromSVGContent() {
    return buildSVGElement(svgContent);
  }

  Element? _renderFromSRC() {
    if (src == null || src!.isEmpty) return null;

    var resourceContent = _resourceContentCache.get(src)!;

    Element? element;

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

  SVGElement? buildSVGElement([String? content]) {
    content ??= svgContent;

    if (content == null || content.isEmpty) {
      return null;
    }

    var svg = createHTML(html: content) as SVGElement;

    _applyDimension(svg);

    if (color != null && color!.isNotEmpty) {
      svg.style.cssText = '${svg.style.cssText}fill: $color';
    }

    if (title != null && title!.isNotEmpty) {
      svg.setAttribute('data-toggle', 'tooltip');
      svg.setAttribute('title', title!);
    }

    return svg;
  }

  HTMLImageElement buildSVGImg() {
    HTMLImageElement img;
    if (isEmptyObject(src) && isNotEmptyObject(svgContent)) {
      var svgDataURL =
          'data:image/svg+xml;base64,${Base64.encode(svgContent!)}';
      img = HTMLImageElement()..src = svgDataURL;
    } else {
      img = HTMLImageElement()..src = src ?? '';
    }

    _applyDimension(img);

    final title = this.title;
    if (title != null && title.isNotEmpty) img.title = title;

    return img;
  }

  void _applyDimension(Element elem) {
    elem.removeAttribute('width');
    elem.removeAttribute('height');

    if (width.isNotEmpty) {
      var w = widthAsCSSValue;
      elem.style?.width = w;
    }
    if (height.isNotEmpty) {
      var h = heightAsCSSValue;
      elem.style?.height = h;
    }
  }

  Future<HTMLImageElement> buildRenderedImage() {
    var svgIMG = buildSVGImg();

    var completer = Completer<HTMLImageElement>();

    svgIMG.onLoad.listen((event) {
      var img = _drawImageToCanvas(svgIMG);
      completer.complete(img);
    });

    return completer.future;
  }

  HTMLImageElement _drawImageToCanvas(HTMLImageElement img) {
    var w = widthAsCSSLength!.value.toInt();
    var h = heightAsCSSLength!.value.toInt();

    var canvas = HTMLCanvasElement()
      ..width = w
      ..height = h;

    var ctx = canvas.context2D;
    ctx.clearRect(0, 0, w, h);
    ctx.drawImage(img, 0, 0);

    var imgDataURL = canvas.toDataUrl('image/png', 1.0);

    var imgRendered = HTMLImageElement()..src = imgDataURL;
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

  var titleNode =
      htmlRoot.selectAllWhere((e) => e is DOMElement && e.tag == 'title');

  var titleText = titleNode.firstOrNull ?? 'HTML as SVG';

  htmlRoot
      .selectAllWhere((n) => true)
      .whereType<DOMElement>()
      .forEach((e) => e['xmlns'] = 'http://www.w3.org/1999/xhtml');

  html = htmlRoot.buildHTML(xhtml: true);

  var svg =
      '''<svg viewBox="0 0 $width $height" width="${width}px" height="${height}px" xmlns="http://www.w3.org/2000/svg">
<foreignObject x="0" y="0" width="$width" height="$height">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head xmlns="http://www.w3.org/1999/xhtml">
<title>$titleText</title>
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
