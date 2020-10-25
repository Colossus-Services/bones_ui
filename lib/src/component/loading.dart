import 'dart:html';

import 'package:bones_ui/bones_ui_kit.dart';

const Map<String, String> _CSS_LOADING = {
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
    top: 37px;
    left: 37px;
    width: 2px;
    height: 2px;
    opacity: 1;
  }
  100% {
    border-width: 4px;
    top: 2px;
    left: 2px;
    width: 72px;
    height: 72px;
    opacity: 0;
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

String _loadCSS(String loadingClass, String color) {
  if (loadingClass == null) return null;
  var cssCode = _CSS_LOADING[loadingClass];
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

UILoadingType getUILoadingType(dynamic type) {
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

String getUILoadingTypeClass(UILoadingType type) {
  if (type == null) return null;
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
    default:
      return null;
  }
}

int _getUILoadingTypeSubDivs(UILoadingType type) {
  if (type == null) return null;
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
    default:
      return 0;
  }
}

abstract class UILoading {
  static void resolveLoadingElements([Element root]) {
    root ??= document.documentElement;

    for (var type in UILoadingType.values) {
      resolveLoadingElementsOfType(type, root);
    }
  }

  static void resolveLoadingElementsOfType(UILoadingType type, [Element root]) {
    root ??= document.documentElement;

    var loadingClass = getUILoadingTypeClass(type);
    if (loadingClass == null) return;

    var sel = root.querySelectorAll('.$loadingClass');

    for (var elem in sel) {
      var color = ensureNotEmptyString(elem.style.color, trim: true);
      var text = ensureNotEmptyString(elem.text, trim: true);

      var loading = asDivElement(type, color: color, text: text);

      elem.nodes.clear();
      elem.append(loading);
    }
  }

  static DIVElement asDIVElement(UILoadingType type,
      {bool inline = true,
      String color,
      double zoom,
      String text,
      double textZoom,
      dynamic cssContext,
      UILoadingConfig config}) {
    if (config != null) {
      if (config.type != null) type = config.type;
      if (isNotEmptyString(config.color, trim: true)) color = config.color;
      if (config.zoom != null) zoom = config.zoom;
      if (config.text != null) text = config.text;
      if (config.textZoom != null) textZoom = config.textZoom;
    }

    var loadingClass = getUILoadingTypeClass(type);
    if (loadingClass == null) return null;

    if (isEmptyString(color, trim: true)) {
      color = null;

      var cssProvider = CSSProvider.from(cssContext);
      if (cssProvider != null) {
        color = cssProvider.css.color?.valueAsString;
      }

      color ??= '#fff';
    }

    loadingClass = _loadCSS(loadingClass, color);
    if (loadingClass == null) return null;

    var divLoading =
        $div(style: 'margin: auto', classes: ['ui-loading', loadingClass]);

    for (var i = 0; i < _getUILoadingTypeSubDivs(type); ++i) {
      divLoading.add(DIVElement());
    }

    var div = $div(content: [divLoading]);

    if (inline ?? true) {
      div.style.put('display', 'inline-block');
    }

    if (zoom != null && zoom > 0) {
      div.style.put('zoom', '$zoom');
    }

    if (isNotEmptyString(text)) {
      var fontSize = textZoom != null && textZoom > 0 && textZoom != 1
          ? '; font-size: ${textZoom * 100}%'
          : '';
      div.add('<div style="margin: auto; color: $color$fontSize">$text</div>');
    }

    return div;
  }

  static DivElement asDivElement(UILoadingType type,
      {bool inline = true,
      String color,
      double zoom,
      String text,
      double textZoom,
      dynamic cssContext,
      UILoadingConfig config}) {
    var div = asDIVElement(type,
        inline: inline,
        color: color,
        zoom: zoom,
        text: text,
        textZoom: textZoom,
        cssContext: cssContext,
        config: config);
    return div.buildDOM(generator: UIComponent.domGenerator) as DivElement;
  }
}

class UILoadingConfig {
  final UILoadingType type;
  final bool inline;
  final TextProvider _color;
  final double zoom;
  final TextProvider _text;
  final double textZoom;

  UILoadingConfig(
      {dynamic type,
      this.inline,
      dynamic color,
      this.zoom,
      dynamic text,
      this.textZoom})
      : type = getUILoadingType(type),
        _color = TextProvider.from(color),
        _text = TextProvider.from(text);

  String get text => _text?.text;

  String get color => _color?.text;
}
