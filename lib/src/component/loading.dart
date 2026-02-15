import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';

const Map<String, String> _cssLoading = {
  'ui-loading-ring': '''
.ui-loading-ring {
  display: block;
  position: relative;
  width: 80px;
  height: 80px;
}
.ui-loading-ring div {
  box-sizing: border-box;
  display: block;
  position: absolute;
  width: 64px;
  height: 64px;
  margin: 8px;
  border: 8px solid #fff;
  border-radius: 50%;
  animation: ui-loading-ring 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite;
  border-color: #fff transparent transparent transparent;
}
.ui-loading-ring div:nth-child(1) {
  animation-delay: -0.45s;
}
.ui-loading-ring div:nth-child(2) {
  animation-delay: -0.3s;
}
.ui-loading-ring div:nth-child(3) {
  animation-delay: -0.15s;
}
@keyframes ui-loading-ring {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}
''',
  'ui-loading-dual-ring': '''
.ui-loading-dual-ring {
  display: block;
  width: 80px;
  height: 66px;
}
.ui-loading-dual-ring:after {
  content: " ";
  display: block;
  width: 64px;
  height: 64px;
  margin: 8px;
  border-radius: 50%;
  border: 6px solid #fff;
  border-color: #fff transparent #fff transparent;
  animation: ui-loading-dual-ring 1.2s linear infinite;
}
@keyframes ui-loading-dual-ring {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}
''',
  'ui-loading-roller': '''
.ui-loading-roller {
  display: block;
  position: relative;
  width: 80px;
  height: 80px;
}
.ui-loading-roller div {
  animation: ui-loading-roller 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite;
  transform-origin: 40px 40px;
}
.ui-loading-roller div:after {
  content: " ";
  display: block;
  position: absolute;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #fff;
  margin: -4px 0 0 -4px;
}
.ui-loading-roller div:nth-child(1) {
  animation-delay: -0.036s;
}
.ui-loading-roller div:nth-child(1):after {
  top: 63px;
  left: 63px;
}
.ui-loading-roller div:nth-child(2) {
  animation-delay: -0.072s;
}
.ui-loading-roller div:nth-child(2):after {
  top: 68px;
  left: 56px;
}
.ui-loading-roller div:nth-child(3) {
  animation-delay: -0.108s;
}
.ui-loading-roller div:nth-child(3):after {
  top: 71px;
  left: 48px;
}
.ui-loading-roller div:nth-child(4) {
  animation-delay: -0.144s;
}
.ui-loading-roller div:nth-child(4):after {
  top: 72px;
  left: 40px;
}
.ui-loading-roller div:nth-child(5) {
  animation-delay: -0.18s;
}
.ui-loading-roller div:nth-child(5):after {
  top: 71px;
  left: 32px;
}
.ui-loading-roller div:nth-child(6) {
  animation-delay: -0.216s;
}
.ui-loading-roller div:nth-child(6):after {
  top: 68px;
  left: 24px;
}
.ui-loading-roller div:nth-child(7) {
  animation-delay: -0.252s;
}
.ui-loading-roller div:nth-child(7):after {
  top: 63px;
  left: 17px;
}
.ui-loading-roller div:nth-child(8) {
  animation-delay: -0.288s;
}
.ui-loading-roller div:nth-child(8):after {
  top: 56px;
  left: 12px;
}
@keyframes ui-loading-roller {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}
''',
  'ui-loading-spinner': '''
.ui-loading-spinner {
  color: official;
  display: block;
  position: relative;
  width: 80px;
  height: 80px;
}
.ui-loading-spinner div {
  transform-origin: 40px 40px;
  animation: ui-loading-spinner 1.2s linear infinite;
}
.ui-loading-spinner div:after {
  content: " ";
  display: block;
  position: absolute;
  top: 3px;
  left: 37px;
  width: 6px;
  height: 18px;
  border-radius: 20%;
  background: #fff;
}
.ui-loading-spinner div:nth-child(1) {
  transform: rotate(0deg);
  animation-delay: -1.1s;
}
.ui-loading-spinner div:nth-child(2) {
  transform: rotate(30deg);
  animation-delay: -1s;
}
.ui-loading-spinner div:nth-child(3) {
  transform: rotate(60deg);
  animation-delay: -0.9s;
}
.ui-loading-spinner div:nth-child(4) {
  transform: rotate(90deg);
  animation-delay: -0.8s;
}
.ui-loading-spinner div:nth-child(5) {
  transform: rotate(120deg);
  animation-delay: -0.7s;
}
.ui-loading-spinner div:nth-child(6) {
  transform: rotate(150deg);
  animation-delay: -0.6s;
}
.ui-loading-spinner div:nth-child(7) {
  transform: rotate(180deg);
  animation-delay: -0.5s;
}
.ui-loading-spinner div:nth-child(8) {
  transform: rotate(210deg);
  animation-delay: -0.4s;
}
.ui-loading-spinner div:nth-child(9) {
  transform: rotate(240deg);
  animation-delay: -0.3s;
}
.ui-loading-spinner div:nth-child(10) {
  transform: rotate(270deg);
  animation-delay: -0.2s;
}
.ui-loading-spinner div:nth-child(11) {
  transform: rotate(300deg);
  animation-delay: -0.1s;
}
.ui-loading-spinner div:nth-child(12) {
  transform: rotate(330deg);
  animation-delay: 0s;
}
@keyframes ui-loading-spinner {
  0% {
    opacity: 1;
  }
  100% {
    opacity: 0;
  }
}
''',
  'ui-loading-ripple': '''
.ui-loading-ripple {
  display: block;
  position: relative;
  width: 74px;
  height: 74px;
}
.ui-loading-ripple div {
  position: absolute;
  border: 4px solid #fff;
  opacity: 1;
  border-radius: 50%;
  animation: ui-loading-ripple 1s cubic-bezier(0, 0.2, 0.8, 1) infinite;
}
.ui-loading-ripple div:nth-child(2) {
  animation-delay: -0.5s;
}
@keyframes ui-loading-ripple {
  0% {
    border-width: 1px;
    top: 40px;
    left: 40px;
    width: 0px;
    height: 0px;
    opacity: 0.0;
  }
  5% {
    border-width: 1px;
    top: 39px;
    left: 39px;
    width: 2px;
    height: 2px;
    opacity: 0.0;
  }
  10% {
    border-width: 1px;
    top: 35px;
    left: 35px;
    width: 8px;
    height: 8px;
    opacity: 0.9;
  }
  100% {
    border-width: 4px;
    top: 4px;
    left: 4px;
    width: 70px;
    height: 70px;
    opacity: 0.0;
  }
}
''',
  'ui-loading-blocks': '''
.ui-loading-blocks {
  display: block;
  position: relative;
  width: 80px;
  height: 68px;
}
.ui-loading-blocks div {
  display: inline-block;
  position: absolute;
  left: 8px;
  width: 16px;
  background: #fff;
  animation: ui-loading-blocks 1.2s cubic-bezier(0, 0.5, 0.5, 1) infinite;
}
.ui-loading-blocks div:nth-child(1) {
  left: 8px;
  animation-delay: -0.24s;
}
.ui-loading-blocks div:nth-child(2) {
  left: 32px;
  animation-delay: -0.12s;
}
.ui-loading-blocks div:nth-child(3) {
  left: 56px;
  animation-delay: 0;
}
@keyframes ui-loading-blocks {
  0% {
    top: 2px;
    height: 64px;
  }
  50%, 100% {
    top: 18px;
    height: 32px;
  }
}
''',
  'ui-loading-ellipsis': '''
.ui-loading-ellipsis {
  display: block;
  position: relative;
  width: 80px;
  height: 40px;
}
.ui-loading-ellipsis div {
  position: absolute;
  top: 13px;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: #fff;
  animation-timing-function: cubic-bezier(0, 1, 1, 0);
}
.ui-loading-ellipsis div:nth-child(1) {
  left: 8px;
  animation: ui-loading-ellipsis1 0.6s infinite;
}
.ui-loading-ellipsis div:nth-child(2) {
  left: 8px;
  animation: ui-loading-ellipsis2 0.6s infinite;
}
.ui-loading-ellipsis div:nth-child(3) {
  left: 32px;
  animation: ui-loading-ellipsis2 0.6s infinite;
}
.ui-loading-ellipsis div:nth-child(4) {
  left: 56px;
  animation: ui-loading-ellipsis3 0.6s infinite;
}
@keyframes ui-loading-ellipsis1 {
  0% {
    transform: scale(0);
  }
  100% {
    transform: scale(1);
  }
}
@keyframes ui-loading-ellipsis3 {
  0% {
    transform: scale(1);
  }
  100% {
    transform: scale(0);
  }
}
@keyframes ui-loading-ellipsis2 {
  0% {
    transform: translate(0, 0);
  }
  100% {
    transform: translate(24px, 0);
  }
}
''',
};

String? _loadCSS(String loadingClass, String? color) {
  var cssCode = _cssLoading[loadingClass];
  if (cssCode == null) return null;

  color ??= '#fff';

  var colorID = color.trim().replaceAll(RegExp(r'\W+'), '_');

  var classWithColorID = '$loadingClass-$colorID';

  if (color != '#fff') {
    cssCode = cssCode.replaceAll('#fff', color);
  }

  cssCode = cssCode.replaceAll(loadingClass, classWithColorID);

  addCSSCode(cssCode);

  return classWithColorID;
}

enum UILoadingType { ring, dualRing, roller, spinner, ripple, blocks, ellipsis }

UILoadingType? getUILoadingType(Object? type) {
  if (type == null) return null;

  if (type is UILoadingType) return type;

  var typeStr = type.toString().trim().toLowerCase();

  switch (typeStr) {
    case 'ring':
      return UILoadingType.ring;
    case 'dualRing':
      return UILoadingType.dualRing;
    case 'roller':
      return UILoadingType.roller;
    case 'spinner':
      return UILoadingType.spinner;
    case 'ripple':
      return UILoadingType.ripple;
    case 'blocks':
      return UILoadingType.blocks;
    case 'ellipsis':
      return UILoadingType.ellipsis;
    default:
      return null;
  }
}

String? getUILoadingTypeClass(UILoadingType type) {
  switch (type) {
    case UILoadingType.ring:
      return 'ui-loading-ring';
    case UILoadingType.dualRing:
      return 'ui-loading-dual-ring';
    case UILoadingType.roller:
      return 'ui-loading-roller';
    case UILoadingType.spinner:
      return 'ui-loading-spinner';
    case UILoadingType.blocks:
      return 'ui-loading-blocks';
    case UILoadingType.ripple:
      return 'ui-loading-ripple';
    case UILoadingType.ellipsis:
      return 'ui-loading-ellipsis';
  }
}

int _getUILoadingTypeSubDivs(UILoadingType type) {
  switch (type) {
    case UILoadingType.ring:
      return 4;
    case UILoadingType.dualRing:
      return 0;
    case UILoadingType.roller:
      return 8;
    case UILoadingType.spinner:
      return 12;
    case UILoadingType.blocks:
      return 3;
    case UILoadingType.ripple:
      return 2;
    case UILoadingType.ellipsis:
      return 4;
  }
}

abstract class UILoading {
  static void resolveLoadingElements([Element? root]) {
    root ??= document.documentElement;

    for (var type in UILoadingType.values) {
      resolveLoadingElementsOfType(type, root);
    }
  }

  static void resolveLoadingElementsOfType(UILoadingType type,
      [Element? root]) {
    root ??= document.documentElement;

    var loadingClass = getUILoadingTypeClass(type);
    if (loadingClass == null) return;

    var sel = root!.querySelectorAll('.$loadingClass').toHTMLElements();

    for (var elem in sel) {
      var color = ensureNotEmptyString(elem.style.color, trim: true);
      var text = ensureNotEmptyString(elem.text, trim: true);

      var loading = asHTMLDivElement(type, color: color, text: text);

      elem.clear();
      elem.append(loading);
    }
  }

  static DIVElement asDIVElement(UILoadingType? type,
      {bool inline = true,
      String? color,
      double? zoom,
      String? text,
      double? textZoom,
      dynamic cssContext,
      bool? withProgress,
      UILoadingConfig? config}) {
    if (config != null) {
      type = config.type;
      if (isNotEmptyString(config.color, trim: true)) color = config.color;
      if (config.zoom != null) zoom = config.zoom;
      if (config.text != null) text = config.text;
      if (config.textZoom != null) textZoom = config.textZoom;
      if (config.withProgress != null) withProgress = config.withProgress;
    }

    type ??= UILoadingType.ring;

    var loadingClass = getUILoadingTypeClass(type)!;

    if (isEmptyString(color, trim: true)) {
      color = null;

      var cssProvider = CSSProvider.from(cssContext);
      if (cssProvider != null) {
        color = cssProvider.css.color?.valueAsString;
      }

      color ??= '#fff';
    }

    loadingClass = _loadCSS(loadingClass, color) ?? loadingClass;

    var divLoading =
        $div(style: 'margin: auto', classes: ['ui-loading', loadingClass]);

    for (var i = 0; i < _getUILoadingTypeSubDivs(type); ++i) {
      divLoading.add(DIVElement());
    }

    var div = $div(content: divLoading);

    if (inline) {
      div.style.put('display', 'inline-block');
    }

    if (zoom != null && zoom > 0) {
      div.style.put('zoom', '$zoom');
    }

    var fontSize = textZoom != null && textZoom > 0 && textZoom != 1
        ? '; font-size: ${textZoom * 100}%'
        : '';

    if (isNotEmptyString(text)) {
      div.add(
        $div(
            classes: 'ui-loading-text',
            style: 'margin: auto; color: $color$fontSize',
            content: text),
      );
    }

    if (withProgress ?? false) {
      div.add(
        $div(
            classes: 'ui-loading-progress',
            style: 'margin: auto; color: $color$fontSize',
            content: '0%'),
      );
    }

    return div;
  }

  static HTMLDivElement asHTMLDivElement(UILoadingType? type,
      {bool inline = true,
      String? color,
      double? zoom,
      String? text,
      double? textZoom,
      dynamic cssContext,
      bool? withProgress,
      UILoadingConfig? config}) {
    var div = asDIVElement(type,
        inline: inline,
        color: color,
        zoom: zoom,
        text: text,
        textZoom: textZoom,
        cssContext: cssContext,
        withProgress: withProgress,
        config: config);
    return div.buildDOM(
        generator: UIComponent.domGenerator,
        treeMap: UIComponent.domTreeMapDummy,
        setTreeMapRoot: false) as HTMLDivElement;
  }
}

class UILoadingConfig implements AsDOMElement {
  final UILoadingType type;
  final bool? inline;
  final TextProvider? _color;
  final double? zoom;
  final TextProvider? _text;
  final double? textZoom;
  final bool? withProgress;

  UILoadingConfig(
      {UILoadingType? type,
      dynamic inline,
      dynamic color,
      dynamic zoom,
      dynamic text,
      dynamic textZoom,
      this.withProgress})
      : type = getUILoadingType(type) ?? UILoadingType.ring,
        inline = parseBool(inline),
        _color = TextProvider.from(color),
        zoom = parseDouble(zoom),
        _text = TextProvider.from(text),
        textZoom = parseDouble(textZoom);

  static UILoadingConfig? from(dynamic o, [String? prefix]) {
    if (o == null) return null;
    if (o is UILoadingConfig) return o;
    if (o is Map) return UILoadingConfig.fromMap(o, prefix);
    return UILoadingConfig.parse(o.toString(), prefix);
  }

  static UILoadingConfig? fromMap(Map attributes, [String? prefix]) {
    prefix ??= '';

    var type = parseString(attributes['${prefix}type']);
    var inline = parseString(attributes['${prefix}inline']);
    var color = parseString(attributes['${prefix}color']);
    var zoom = parseString(attributes['${prefix}zoom']);
    var text = parseString(attributes['${prefix}text']);
    var textZoom = parseString(attributes['${prefix}text-zoom']);
    var withProgress = parseBool(attributes['${prefix}with-progress']);

    if (isNotEmptyString(type, trim: true) ||
        isNotEmptyString(color, trim: true) ||
        isNotEmptyString(text, trim: true) ||
        isNotEmptyString(zoom, trim: true)) {
      return UILoadingConfig(
          type: getUILoadingType(type),
          inline: parseBool(inline),
          color: color,
          zoom: parseDouble(zoom),
          text: text,
          textZoom: parseDouble(textZoom),
          withProgress: withProgress);
    }

    return null;
  }

  static UILoadingConfig? parse(String? config, [String? prefix]) {
    if (isEmptyString(config)) return null;
    var map = parseFromInlineProperties(config!)!;
    return UILoadingConfig.fromMap(map, prefix);
  }

  String? get text => _text?.text;

  String? get color => _color?.text;

  DIVElement asDIVElement() => UILoading.asDIVElement(type, config: this);

  HTMLDivElement asDivElement() =>
      UILoading.asHTMLDivElement(type, config: this);

  @override
  DOMElement get asDOMElement => asDIVElement();

  String toInlineProperties() {
    var color = _color?.text;
    var text = _text?.text;

    return [
      'type: ${type.name}',
      if (inline != null) 'inline: $inline',
      if (isNotEmptyString(color, trim: true)) 'color: $color',
      if (zoom != null) 'zoom: $zoom',
      if (textZoom != null) 'textZoom: $textZoom',
      if (isNotEmptyString(text, trim: true)) 'text: $text',
    ].join('; ');
  }

  @override
  String toString() {
    return 'UILoadingConfig{${toInlineProperties()}}';
  }
}

DIVElement $uiLoading(
        {UILoadingType? type,
        dynamic inline,
        dynamic color,
        dynamic zoom,
        dynamic text,
        dynamic textZoom,
        bool? withProgress}) =>
    UILoadingConfig(
            type: type,
            inline: inline,
            color: color,
            zoom: zoom,
            text: text,
            textZoom: textZoom,
            withProgress: withProgress)
        .asDIVElement();
