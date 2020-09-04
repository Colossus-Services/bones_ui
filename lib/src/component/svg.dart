import 'dart:html';
import 'dart:svg' as dart_svg;

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Component to show a SVG.
class UISVG extends UIComponent {
  static final ResourceContentCache _resourceContentCache =
      ResourceContentCache();

  /// Source for the SVG.
  final String src;

  /// SVG tag to render.
  final String svgContent;

  /// Width of the SVG.
  final String width;

  /// Height of the SVG.
  final String height;

  /// Title of the SVG.
  final String title;

  /// Color to render the SVG.
  final String color;

  UISVG(Element parent,
      {this.src,
      this.svgContent,
      this.width = '20px',
      this.height = '20px',
      this.title,
      this.color,
      String classes,
      String style})
      : super(parent, componentClass: 'ui-svg', classes: classes, style: style);

  Element _renderedElement;

  /// Returns the [Element] rendered.
  Element get renderedElement => _renderedElement;

  /// Returns [true] if it was rendered as an [ImageElement].
  bool get isRenderedAsImage => _renderedElement is ImageElement;

  /// Returns [true] if it was rendered as an [SvgElement].
  bool get isRenderedAsSVG => _renderedElement is dart_svg.SvgElement;

  @override
  dynamic render() {
    if (svgContent != null && svgContent.isNotEmpty) {
      return _renderFromSVGContent();
    } else {
      return _renderFromSRC();
    }
  }

  Element _renderFromSVGContent() {
    return _buildSVG(svgContent);
  }

  Element _renderFromSRC() {
    if (src == null || src.isEmpty) return null;

    var resourceContent = _resourceContentCache.get(src);

    Element element;

    if (resourceContent.isLoaded) {
      var content = resourceContent.getContentIfLoaded();
      var svg = _buildSVG(content);
      element = svg;
    } else {
      resourceContent.onLoad.listen((_) => refresh());
      resourceContent.getContent();
      element = _buildImg();
    }

    _renderedElement = element;

    return element;
  }

  dart_svg.SvgElement _buildSVG(String content) {
    var svg = createHTML(content) as dart_svg.SvgElement;

    _applyDimension(svg);

    if (color != null && color.isNotEmpty) {
      svg.style.cssText += 'fill: $color';
    }

    if (title != null && title.isNotEmpty) {
      svg.setAttribute('data-toggle', 'tooltip');
      svg.setAttribute('title', title);
    }

    return svg;
  }

  ImageElement _buildImg() {
    var img = ImageElement(src: src);

    _applyDimension(img);

    if (title != null && title.isNotEmpty) img.title = title;

    return img;
  }

  void _applyDimension(Element elem) {
    elem.removeAttribute('width');
    elem.removeAttribute('height');

    if (width != null && width.isNotEmpty) {
      elem.style.width = _parseDimension(width);
    }
    if (height != null && height.isNotEmpty) {
      elem.style.height = _parseDimension(height);
    }
  }

  String _parseDimension(String s) {
    if (isNum(s)) return '${parseInt(s)}px';
    return s;
  }
}
