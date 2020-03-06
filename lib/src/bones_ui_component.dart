
import 'dart:html';
import 'dart:async';

import 'bones_ui_base.dart';

import 'package:swiss_knife/swiss_knife.dart';

///////////////////////

abstract class UIButton extends UIComponent {
  static final EVENT_CLICK = 'CLICK' ;

  UIButton(Element container, {String navigate, Map<String,String> navigateParameters, ParametersProvider navigateParametersProvider, dynamic classes, dynamic classes2}) : super(container, classes: classes, classes2: classes2) {
    registerClickListener(onClickEvent) ;

    if (navigate != null) {
      this.navigate(navigate, navigateParameters, navigateParametersProvider) ;
    }
  }

  bool _disabled = false ;

  bool get disabled => _disabled ;

  set disabled(bool disabled) {
    _disabled = disabled ;
    refreshInternal();
  }

  StreamSubscription _navigateOnClick_Subscription ;

  void cancelNavigate() {
    if (_navigateOnClick_Subscription != null) {
      _navigateOnClick_Subscription.cancel();
      _navigateOnClick_Subscription = null ;
    }
  }

  void navigate(String navigate, [Map<String,String> navigateParameters, ParametersProvider navigateParametersProvider]) {
    cancelNavigate() ;
    _navigateOnClick_Subscription = UINavigator.navigateOnClick(content, navigate, navigateParameters, navigateParametersProvider) ;
  }

  void registerClickListener(UIEventListener listener) {
    registerEventListener(EVENT_CLICK, listener);
  }

  Point _prevClickEvent_point ;
  num _prevClickEvent_time ;

  void fireClickEvent(MouseEvent event, [List params]) {
    if (disabled) return ;

    var p = event.page ;
    var time = event.timeStamp ;

    if ( _prevClickEvent_time == time && _prevClickEvent_point == p ) return ;

    _prevClickEvent_point = p ;
    _prevClickEvent_time = time ;

    fireEvent(EVENT_CLICK, event, params);

    onClick.add(event);
  }

  final EventStream<MouseEvent> onClick = EventStream() ;

  void onClickEvent(dynamic event, List params) {}

  @override
  List render() {
    var rendered = renderButton() ;

    var renderedElements = toContentElements(content, rendered);

    var clickSet = false ;

    for (var e in renderedElements) {
      if (e is Element) {
        e.onClick.listen((e) => fireClickEvent(e)) ;
        clickSet = true ;
      }
    }

    if (!clickSet) {
      content.onClick.listen((e) => fireClickEvent(e)) ;
    }

    var renderedHidden = renderHiddens() ;

    if (renderedHidden != null) {
      var renderedElementsHidden = toContentElements(content, renderedHidden, true);
      renderedElements.addAll(renderedElementsHidden) ;
    }

    return renderedElements ;
  }

  dynamic renderButton() ;

  dynamic renderHiddens() {
    return null;
  }

}

///////////////////////

class UIInfosTable extends UIComponent {

  final Map _infos ;

  UIInfosTable(Element parent, this._infos) : super(parent);

  @override
  List render() {

    var table = TableElement();
    table.setAttribute('border', '0') ;
    table.setAttribute('align', 'center') ;

    for (var k in _infos.keys) {
      var v = _infos[k];

      var row = table.addRow() ;

      var cell1 = row.addCell();
      cell1.setAttribute('align', 'right') ;
      cell1.innerHtml = '<b>$k:&nbsp;</b>' ;

      var cell2 = row.addCell();
      cell2.setAttribute('align', 'center') ;

      if (v is Element) {
        cell2.children.add(v) ;
      }
      else {
        cell2.innerHtml = v.toString() ;
      }
    }

    return [table];
  }

}

///////////////////////

class InputConfig {

  String _id ;
  String _label ;
  String _type ;
  String _value ;
  Map<String,String> _attributes ;
  Map<String,String> _options ;
  bool _optional ;

  InputConfig(String id, String label, { String type = 'text', String value = '', Map<String,String> attributes, Map<String,String> options, bool optional = false }) {
    if (type == null || type.isEmpty) type = 'text' ;
    if (value == null || value.isEmpty) value = null ;

    if (label == null || label.isEmpty) {
      if (value != null) {
        label = value ;
      }
      else {
        label = type ;
      }
    }

    id ??= label;

    if (id == null || id.isEmpty) throw ArgumentError('Invalid ID') ;
    if (label == null || label.isEmpty) throw ArgumentError('Invalid Label') ;

    _id = id ;
    _label = label ;
    _type = type ;
    _value = value ;

    _attributes = attributes ;
    _options = options ;

    _optional = optional ;
  }

  String get id => _id ;
  String get fieldName => _id ;

  String get label => _label ;
  String get type => _type ;
  String get value => _value ;
  Map<String,String> get attributes => _attributes ;
  Map<String,String> get options => _options ;
  bool get optional => _optional;

  bool get required => !_optional;

}

class UIInputTable extends UIComponent {

  final List<InputConfig> _inputs ;

  UIInputTable(Element parent, this._inputs, [ this._inputErrorClass ]) : super(parent);

  String _inputErrorClass ;

  String get inputErrorClass => _inputErrorClass ;
  set inputErrorClass(String value) => _inputErrorClass = value ;

  bool canHighlightInputs() => _inputErrorClass == null || _inputErrorClass.isEmpty ;

  int highlightEmptyInputs() {
    if ( canHighlightInputs() ) return -1 ;

    unhighlightErrorInputs() ;
    return forEachEmptyFieldElement( (fieldElement) => fieldElement.classes.add( 'ss-input-error' ) );
  }

  int unhighlightErrorInputs() {
    if ( canHighlightInputs() ) return -1 ;

    return forEachFieldElement( (fieldElement) => fieldElement.classes.remove( 'ss-input-error' ) );
  }

  bool highlightField(String fieldName) {
    if ( canHighlightInputs() ) return false ;

    var fieldElement = getFieldElement(fieldName) ;
    if (fieldElement == null) return false ;

    fieldElement.classes.add( _inputErrorClass ) ;
    return true ;
  }

  bool unhighlightField(String fieldName) {
    if ( canHighlightInputs() ) return false ;

    var fieldElement = getFieldElement(fieldName) ;
    if (fieldElement == null) return false ;

    fieldElement.classes.remove( _inputErrorClass ) ;
    return true ;
  }

  bool checkFields() {
    var ok = true ;

    unhighlightErrorInputs();

    for (var i in _inputs) {
      if ( i.required && isEmptyField(i.fieldName)  ) {
        highlightField( i.fieldName ) ;
        ok = false ;
      }
    }

    return ok ;
  }

  @override
  List render() {

    var html = """
    <table border='0' align="center">
    """;

    for (var i in _inputs) {

      var attrs = '' ;

      if (i.attributes != null && i.attributes.isNotEmpty) {
        for (var attrKey in i.attributes.keys) {
          var attrVal = i.attributes[attrKey] ;
          if (attrKey.isNotEmpty && attrVal.isNotEmpty) {
            attrs += '$attrKey=\"$attrVal\"';
          }
        }

      }

      String input ;

      if ( i.type == 'textarea') {
        input = '''
        <textarea field='${ i.id }' name='${ i.id }' $attrs>${ i.value != null ? "value=\" ${i.value}\"" : '' }</textarea>
        ''';
      }
      else if ( i.type == 'select') {
        input = """
        <select field='${ i.id }' name='${ i.id }' $attrs>
        """;

        if ( i.options != null && i.options.isNotEmpty ) {
          for (var optKey in i.options.keys) {
            var optVal = i.options[optKey];
            if (optVal == null || optVal.isEmpty) {
              optVal = optKey;
            }

            input += '''
            <option value="$optKey">$optVal</option>
            ''';
          }
        }
        else if ( i.value != null && i.value.isNotEmpty ) {
          input += '${ i.value }' ;
        }

        input += '''
        </select>
        ''';


      }
      else {
        input = '''
        <input field='${ i.id }' name='${ i.id }' type="${ i.type }" ${ i.value != null ? "value=\" ${i.value}\"" : '' } $attrs>
        ''';
      }

      html += '''
      <tr>
      <td style="vertical-align: top ; text-align: right"><b>${ i.label }:&nbsp;</b></td><td style="text-align: center">$input</td>
      </tr>
      ''';
    }

    html += '''
    </table>
    ''';

    return [html];
  }

}

///////////////////////

abstract class UIDialog extends UIComponent {

  final bool hideUIRoot ;

  UIDialog({this.hideUIRoot = false, dynamic classes}) : super(document.documentElement, classes: classes) {
    _myConfigure() ;
  }

  void _myConfigure() {

    content.style
      ..position = 'fixed'
      ..width = '100%'
      ..height = '100%'
      ..left = '0px'
      ..top = '0px'
      ..float = 'top'
      ..clear = 'both'
      ..padding = '6px 6px 7px 6px'
      ..color = '#ffffff'
      ..backgroundColor = 'rgba(0,0,0, 0.70)'
      ..zIndex = '100'
    ;

    _callOnShow();
  }

  void _callOnShow() {
    if (hideUIRoot) {
      var ui = UIRoot.getInstance();
      if (ui != null) ui.hide() ;
    }

    onShow() ;
  }

  void _callOnHide() {
    if (hideUIRoot) {
      var ui = UIRoot.getInstance();
      if (ui != null) ui.show() ;
    }

    onHide() ;
  }

  void onShow() {

  }

  void onHide() {

  }

  bool get isShowing {
    return parent.contains(content) ;
  }

  @override
  void show() {
    if ( !isShowing )  {
      document.documentElement.children.add(content) ;
      _callOnShow() ;
    }
  }

  @override
  void hide() {
    var showing = isShowing ;

    content.remove() ;

    if (showing) {
      _callOnHide();
    }
  }

}

///////////////////////

class ImageClip {

  final Dimension viewDimension ;
  final Rectangle viewClip ;

  Dimension _imageDimension ;
  Dimension get imageDimension => _imageDimension ;

  Rectangle _clip ;
  Rectangle get clip => _clip ;

  ImageClip(this.viewDimension, this.viewClip, [this._imageDimension]) {

    if (_imageDimension != null) {

      var wR = viewDimension.width / _imageDimension.width ;
      var hR = viewDimension.height / _imageDimension.height ;

      var r = wR < hR ? wR : hR ;

      var w = (_imageDimension.width * r).toInt() ;
      var h = (_imageDimension.height * r).toInt() ;

      var imgViewRect = Rectangle( (viewDimension.width-w)/2 , (viewDimension.height-h)/2 , w,h) ;

      var imgViewClip = imgViewRect.intersection(viewClip) ;

      var rInv = 1/r ;

      var imgRect = Rectangle( imgViewRect.left*rInv , imgViewRect.top*rInv , imgViewRect.width*rInv , imgViewRect.height*rInv ) ;
      var imgClip = Rectangle( imgViewClip.left*rInv , imgViewClip.top*rInv , imgViewClip.width*rInv , imgViewClip.height*rInv ) ;

      imgClip = Rectangle( (imgClip.left-imgRect.left).toInt() , (imgClip.top-imgRect.top).toInt() , imgClip.width.toInt() , imgClip.height.toInt() ) ;

      _clip = imgClip ;
    }
    else {
      _imageDimension = viewDimension ;
      _clip = viewClip ;
    }

  }

}

class UIClipImage extends UIComponent {

  final ImageElement _img ;

  int imgWidth ;
  int imgHeight ;

  String color ;

  UIClipImage(Element container, this._img, {this.imgWidth = 0 , this.imgHeight = 0, this.color = '#00ff00', dynamic classes}) : super(container, classes: classes) ;

  @override
  void configure() {
    content.onTouchStart.listen( _startPoint ) ;
    content.onMouseDown.listen( _startPoint ) ;

    content.onTouchMove.listen( _movePoint ) ;
    content.onMouseMove.listen( _movePoint ) ;

    content.onTouchEnd.listen( _endPoint ) ;
    content.onMouseUp.listen( _endPoint ) ;

    content.draggable = false ;

    content.style.width = '100%';
    content.style.height = '100%';

    _img.draggable = false ;

    _img.style.width = '100%';
    _img.style.height = '100%';
    _img.style.objectFit = 'contain' ;
  }

  @override
  dynamic render() {
    _img.remove();

    return [_img] ;
  }

  Point parsePoint(Event e) {
    if ( e is TouchEvent ) {
      var p = e.changedTouches.first.client;
      return Point( p.x - _img.offset.left , p.y - _img.offset.top ) ;
    }
    else if ( e is MouseEvent ) {
      var p = e.page;
      return Point( p.x - _img.offset.left , p.y - _img.offset.top ) ;
    }
    return null ;
  }

  Point _start ;

  void _startPoint(Event e) {
    _start = parsePoint(e) ;
    _clearRects();
  }

  Element _divRectDrag ;

  void _movePoint(Event e) {
    if (_start == null) return ;

    var p = parsePoint(e) ;

    _clearRects();

    var rect = _createRect(_start, p) ;
    _divRectDrag = _createRectDiv(rect) ;

    content.children.add(_divRectDrag) ;
  }

  void _clearRects() {
    if (_divRectDrag != null) _divRectDrag.remove();
    if (_divRect != null) _divRect.remove();
  }

  Element _divRect ;

  ImageClip _imageClip ;

  void _endPoint(Event e) {
    var start = _start ;
    var end = parsePoint(e) ;

    _start = null ;

    _clearRects();

    _imageViewDimension = Rectangle(0, 0, _img.offsetWidth, _img.offsetHeight) ;

    var clipRect = _createRect(start, end) ;

    _clipRect = Rectangle(clipRect.left - _img.offsetLeft, clipRect.top - _img.offsetTop, clipRect.width, clipRect.height) ;

    if ( _clipRect.width > 1 && _clipRect.height > 1 ) {
      _imageClip = ImageClip( Dimension(_img.offsetWidth, _img.offsetHeight), _clipRect , imageDimension ) ;
    }
    else {
      _imageClip = null ;
    }

    _divRect = _createRectDiv(clipRect) ;

    content.children.add(_divRect) ;

    onChangeClip.add(_clipRect) ;
  }

  bool get hasImageDimension => imgWidth != null && imgHeight != null && imgWidth > 0 && imgHeight > 0 ;
  Dimension get imageDimension => hasImageDimension ? Dimension(imgWidth, imgHeight) : null ;

  final EventStream<Rectangle> onChangeClip = EventStream() ;

  Rectangle _imageViewDimension ;
  Rectangle get imageViewDimension => _imageViewDimension ;

  Rectangle _clipRect ;

  Rectangle get clipRectangle => _clipRect ;
  bool get hasClipRectangle => _clipRect != null && _clipRect.width > 0 && _clipRect.height > 0 ;

  ImageClip get imageClip => _imageClip ;

  DivElement _createRectDiv(Rectangle rect) {
    var div = DivElement();
    div.style
      ..width = '${rect.width}px'
      ..height = '${rect.height}px'
      ..backgroundColor = color
      ..opacity = '0.5'
      ..position = 'absolute'
      ..left = '${rect.left}px'
      ..top = '${rect.top}px'
    ;

    return div ;
  }

  Rectangle _createRect(Point p1, Point p2) {
    if (p1 == null || p2 == null) return null ;

    var x1 = Math.min(p1.x , p2.x) ;
    var y1 = Math.min(p1.y , p2.y) ;

    var x2 = Math.max(p1.x , p2.x) ;
    var y2 = Math.max(p1.y , p2.y) ;

    if (x1 < 0) x1 = 0;
    if (y1 < 0) y1 = 0;

    var imgViewWidth = _img.offsetWidth ;
    var imgViewHeight = _img.offsetHeight ;

    if (imgViewWidth != null && imgViewWidth > 0 && x2 > imgViewWidth) x2 = imgViewWidth ;
    if (imgViewHeight != null && imgViewHeight > 0 && y2 > imgViewHeight) y2 = imgViewHeight ;

    int x = x1 ;
    int y = y1 ;
    int w = x2-x1 ;
    int h = y2-y1 ;

    int left = _img.offset.left + x ;
    int top = _img.offset.top + y ;

    return Rectangle(left, top, w, h) ;
  }

}

///////////////////////
