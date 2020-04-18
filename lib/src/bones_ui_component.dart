
import 'dart:html';
import 'dart:async';

import 'bones_ui_capture.dart';

import 'bones_ui_base.dart';

import 'package:swiss_knife/swiss_knife.dart';

import 'package:dom_tools/dom_tools.dart';


///////////////////////

abstract class UIButton extends UIComponent {
  static final EVENT_CLICK = 'CLICK' ;

  UIButton(Element container, {String navigate, Map<String,String> navigateParameters, ParametersProvider navigateParametersProvider, dynamic classes}) : super(container, classes: 'ui-button', classes2: classes) {
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
    onChange.add(this) ;
  }

  final EventStream<MouseEvent> onClick = EventStream() ;

  void onClickEvent(dynamic event, List params) {}

  @override
  dynamic render() {

    var rendered = renderButton() ;

    var renderAll = toContentElements(content, rendered, false, false) ;
    _onClickListen(renderAll) ;

    var renderedHidden = renderHidden() ;

    if (renderedHidden != null) {
      renderAll.add( renderedHidden ) ;
    }

    return renderAll ;
  }

  bool _content_onClick_listening = false ;

  void _onClickListen(List renderedElements) {
    var clickSet = false ;

    for (var elem in renderedElements) {
      if (elem is Element) {
        elem.onClick.listen((e) => fireClickEvent(e)) ;
        clickSet = true ;
      }
    }

    if (!clickSet && !_content_onClick_listening) {
      content.onClick.listen((e) => fireClickEvent(e)) ;
      _content_onClick_listening = true ;
    }
  }

  dynamic renderButton() ;

  dynamic renderHidden() {
    return null;
  }

}

class UISimpleButton extends UIButton {
  final String text ;
  final String fontSize ;

  UISimpleButton(Element parent, this.text, {String navigate, Map<String,String> navigateParameters, ParametersProvider navigateParametersProvider, dynamic classes, bool small = false, this.fontSize}) : super(parent, navigate: navigate, navigateParameters: navigateParameters, navigateParametersProvider: navigateParametersProvider, classes: classes) {
    configureClasses( classes , [ small ? 'ui-button-small' : 'ui-button' ] ) ;
  }

  @override
  String renderButton() {
    if (disabled) {
      content.style.opacity = '0.7' ;
    }
    else {
      content.style.opacity = null ;
    }

    if (fontSize != null) {
      return "<span style='font-size: $fontSize'>$text</span>" ;
    }
    else {
      return text ;
    }
  }

  void setWideButton() {
    content.style.width = '80%';
  }

  void setNormalButton() {
    content.style.width = null ;
  }

}


///////////////////////

class UIInfosTable extends UIComponent {

  final Map _infos ;

  UIInfosTable(Element parent, this._infos, { dynamic classes }) : super(parent, classes: 'ui-infos-table', classes2: classes );

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

typedef FieldValueProvider = dynamic Function(String field) ;

class InputConfig {

  static List<InputConfig> listFromMap( Map map ) {
    return map.map( (k,v) => MapEntry( k , InputConfig.from( v , '$k' ) ) ).values.toList() ;
  }

  String _id ;
  String _label ;
  String _type ;
  String _value ;
  Map<String,String> _attributes ;
  Map<String,String> _options ;
  bool _optional ;

  factory InputConfig.from(dynamic config, [String id]) {
    if ( config is List ) {
      config = config.join(' ; ') ;
    }

    if ( config is String ) {
      config = parseFromInlineMap(config, RegExp(r'\s*[,;]\s*') , RegExp(r'\s*[=:]\s*') , parseString, parseString) ;
    }

    if ( config is Map ) {
      id ??= parseString( findKeyValue(config, ['id'], true) ) ;

      var label = parseString( findKeyValue(config, ['label'], true) );
      var type = parseString( findKeyValue(config, ['type'], true) , 'text');
      var value = parseString( findKeyValue(config, ['value'], true) , '' );
      var attributes = findKeyValue(config, ['attributes'], true);
      var options = findKeyValue(config, ['options'], true);
      var optional = parseBool( findKeyValue(config, ['optional'], true) , false );

      if (attributes is Map) {
        attributes = asMapOfString(attributes) ;
      }
      
      if (options is Map) {
        options = asMapOfString(options) ;
      }

      return InputConfig(
        id ,
        label ,
        type: type,
        value: value,
        attributes: attributes ,
        options: options ,
        optional: optional ,
      ) ;
    }

    return null ;
  }

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
  set value(String value) => _value = value;

  Map<String,String> get attributes => _attributes ;
  Map<String,String> get options => _options ;
  bool get optional => _optional;

  bool get required => !_optional;

  dynamic renderInput( [ FieldValueProvider fieldValueProvider ] ) {
    var inputID = id ;
    var inputType = type;
    var inputValue = fieldValueProvider != null ? ( fieldValueProvider( fieldName ) ?? value ) : value ;

    Element inputElement ;
    UIComponent inputComponent ;

    if ( inputType == 'textarea') {
      inputElement = _render_textArea(inputValue) ;
    }
    else if ( inputType == 'select') {
      inputElement = _render_select(inputValue);
    }
    else if ( inputType == 'image') {
      var capture = UIButtonCapturePhoto(null, label, fieldName: inputID) ;
      inputComponent = capture ;
    }
    else {
      inputElement = _render_generic_input(inputType, inputValue) ;
    }

    if ( inputElement != null ) {
      inputElement.setAttribute('name', inputID);
      inputElement.setAttribute('field', inputID);

      if (attributes != null && attributes.isNotEmpty) {
        for (var attrKey in attributes.keys) {
          var attrVal = attributes[attrKey];
          if (attrKey.isNotEmpty && attrVal.isNotEmpty) {
            inputElement.setAttribute(attrKey, attrVal);
          }
        }
      }

      return inputElement ;
    }
    else if ( inputComponent != null ) {
      return inputComponent ;
    }

    return null ;
  }

  TextAreaElement _render_textArea(inputValue) {
    var textArea = TextAreaElement() ;
    textArea.value = inputValue ;
    return textArea;
  }

  Element _render_generic_input(String inputType, inputValue) {
    var inputHtml = '''
      <input type="$inputType" ${ inputValue != null ? 'value="$inputValue"' : '' }>
    ''';

    var input = createHTML( inputHtml ) ;
    return input;
  }

  SelectElement _render_select(inputValue) {
    var select = SelectElement() ;

    if ( options != null && options.isNotEmpty ) {
      for (var optKey in options.keys) {
        var optVal = options[optKey];
        var selected = false ;

        if (optKey.endsWith('*')) {
          optKey = optKey.substring(0, optKey.length-1) ;
          selected = true ;
        }

        if (optVal == null || optVal.isEmpty) {
          optVal = optKey;
        }

        var optionElement = OptionElement(data: optVal, value: optKey);

        if (selected) {
          optionElement.selected = selected;
        }

        select.add( optionElement , null ) ;
      }
    }
    else if ( inputValue != null && inputValue.isNotEmpty ) {
      select.innerHtml = '$inputValue' ;
    }
    return select;
  }



}

class UIInputTable extends UIComponent {

  final List<InputConfig> _inputs ;

  UIInputTable(Element parent, this._inputs, { String inputErrorClass , dynamic classes } ) :
        _inputErrorClass = inputErrorClass ,
        super(parent, classes: 'ui-infos-table', classes2: classes )
  ;

  String _inputErrorClass ;

  String get inputErrorClass => _inputErrorClass ;
  set inputErrorClass(String value) => _inputErrorClass = value ;

  bool canHighlightInputs() => _inputErrorClass == null || _inputErrorClass.isEmpty ;

  int highlightEmptyInputs() {
    if ( canHighlightInputs() ) return -1 ;

    unhighlightErrorInputs() ;
    return forEachEmptyFieldElement( (fieldElement) => fieldElement.classes.add( 'ui-input-error' ) );
  }

  int unhighlightErrorInputs() {
    if ( canHighlightInputs() ) return -1 ;

    return forEachFieldElement( (fieldElement) => fieldElement.classes.remove( 'ui-input-error' ) );
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
  dynamic render() {
    var table = TableElement() ;
    var tBody = table.createTBody() ;

    for (var input in _inputs) {
      var row = tBody.addRow() ;

      row.addCell()
        ..style.verticalAlign = 'top'
        ..style.textAlign = 'right'
        ..innerHtml = '<b>${ input.label }:&nbsp;</b>'
      ;

      var celInput = row.addCell()
        ..style.textAlign = 'center'
      ;

      var inputRendered = input.renderInput( getPreviousRenderedFieldValue ) ;

      if ( inputRendered is Element ) {
        celInput.children.add( inputRendered ) ;
      }
      else if ( inputRendered is UIComponent ) {
        var div = createDiv() ;
        celInput.children.add(div) ;

        inputRendered.setParent(div) ;
        inputRendered.render();
      }
    }

    return table ;
  }

  @override
  void posRender() {
    var fields = getFieldsElementsMap() ;

    if (fields != null && fields.isNotEmpty) {
      for ( var entry in fields.entries ) {
        //var fieldName = entry.key ;
        var elem = entry.value ;

        elem.onChange.listen( (e) {
          //updateRenderedFieldValue(fieldName) ;
          updateRenderedFieldElementValue(elem) ;
          onChange.add(elem);
        }) ;
      }
    }
  }

}

///////////////////////

abstract class UIDialog extends UIComponent {

  final bool hideUIRoot ;

  UIDialog( {this.hideUIRoot = false, dynamic classes} ) : super(document.documentElement, classes: 'ui-dialog', classes2: classes) {
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

    try {
      onShow() ;
    }
    catch(e,s) {
      print(e) ;
      print(s) ;
    }

    onChange.add(this) ;
  }

  void _callOnHide() {
    if (hideUIRoot) {
      var ui = UIRoot.getInstance();
      if (ui != null) ui.show() ;
    }

    try {
      onHide() ;
    }
    catch(e,s) {
      print(e) ;
      print(s) ;
    }

    onChange.add(this) ;
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

  UIClipImage(Element container, this._img, {this.imgWidth = 0 , this.imgHeight = 0, this.color = '#00ff00', dynamic classes}) : super(container, classes: 'ui-dialog', classes2: classes) ;

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
    onChange.add(this) ;
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


class UIMultiSelection extends UIComponent {

  final Map _options ;
  final bool multiSelection ;
  final String width ;
  final int optionsPanelMargin ;
  final String separator ;

  final Duration selectionMaxDelay ;

  final EventStream<UIMultiSelection> onSelect = EventStream() ;

  UIMultiSelection(Element parent, this._options, { this.multiSelection, this.width , this.optionsPanelMargin = 20 , this.separator = ' ; ' , Duration selectionMaxDelay , dynamic classes } ) :
        selectionMaxDelay = selectionMaxDelay ?? Duration( seconds: 10 ) ,
        super(parent, classes: 'ui-multi-selection', classes2: classes)
  ;

  InputElement _element ;
  DivElement _divOptions ;

  List<InputElementBase> _checkElements = [] ;

  bool isCheckedByID(dynamic id) {
    if (id == null) return null ;
    var checkElem = _getCheckElement('$id') ;
    return _isChecked(checkElem) ;
  }

  bool isCheckedByLabel(dynamic label) {
    var id = getLabelID(label);
    return isCheckedByID(id) ;
  }

  bool _needToNotifySelection = false ;

  void _notifySelection(bool delayed) {
    if ( !_needToNotifySelection ) return ;

    if ( delayed ) {
      var moveElapsed = DateTime.now().millisecondsSinceEpoch - _onDivOptionsLastMouseMove ;
      var maxDelay = selectionMaxDelay != null ? selectionMaxDelay.inMilliseconds : 200 ;
      if ( moveElapsed < maxDelay ) {
        _notifySelectionDelayed() ;
        return ;
      }
    }

    _needToNotifySelection = false ;

    onSelect.add( this ) ;

    onChange.add( this ) ;
  }

  void _notifySelectionDelayed() {
    if ( !_needToNotifySelection ) return ;

    var maxDelay = selectionMaxDelay != null ? selectionMaxDelay.inMilliseconds : 200 ;
    if (maxDelay < 200) maxDelay = 200 ;

    var moveElapsed = DateTime.now().millisecondsSinceEpoch - _onDivOptionsLastMouseMove ;
    var timeUntilMaxDelay = maxDelay - moveElapsed ;

    var delay = timeUntilMaxDelay < 100 ? 100 : Math.min( timeUntilMaxDelay , maxDelay ) ;

    Future.delayed( Duration(milliseconds: delay) , () => _notifySelection(true) ) ;
  }

  void checkByID(dynamic id, bool check) {
    _checkByIDImpl(id, check, false, true) ;
  }

  void _checkByIDImpl(dynamic id, bool check, bool fromCheckElement, bool notify) {
    if (id == null) return ;

    if (!fromCheckElement) {
      _setCheck( _getCheckElement('$id') , check) ;
    }

    if (notify) {
      _needToNotifySelection = true;
      _notifySelectionDelayed();
    }
  }

  void uncheckAll() {
    uncheckAllImpl(true);
  }

  void uncheckAllImpl(bool notify) {
    //if ( _selections.isEmpty ) return ;
    if ( _getSelectedElements().isEmpty ) return ;

    //_selections.clear();
    _checkAllElements(false);
    _updateElementText();

    if (notify) {
      _needToNotifySelection = true ;
      _notifySelectionDelayed();
    }
  }

  void setCheckedElements(List ids) {
    uncheckAllImpl(false);
    checkAllByID(ids, true) ;
  }

  void checkAllByID(List ids, bool check) {
    if (ids == null || ids.isEmpty) return ;

    for (var id in ids) {
      _checkByIDImpl(id, check, false, false) ;
    }

    _updateElementText();
    _needToNotifySelection = true ;
    _notifySelectionDelayed() ;
  }

  void checkByLabel(dynamic label, bool check) {
    checkByID( getLabelID(label) , check) ;
  }

  dynamic getIDLabel(dynamic id) {
    return _options[id] ;
  }

  dynamic getLabelID(dynamic label) {
    var entry = _options.entries.firstWhere( (e) => e.value == label , orElse: () => null );
    return entry != null ? entry.key : null ;
  }

  List< MapEntry > getOptionsEntriesFiltered(dynamic pattern) {
    if ( pattern == null || pattern.isEmpty ) return _options.entries ;

    if ( pattern is String ) {
      return _options.entries.where((e) => '${e.value}'.toLowerCase().contains(pattern)).toList();
    }
    else if ( pattern is RegExp ) {
      return _options.entries.where((e) =>  pattern.hasMatch('${e.value}') ).toList();
    }
    else {
      return [] ;
    }
  }

  List<InputElementBase> _getSelectedElements() {
    return _checkElements.where( (e) => (e is CheckboxInputElement && e.checked) || (e is RadioButtonInputElement && e.checked) ).toList() ;
  }

  InputElementBase _getCheckElement(String id) {
    return _checkElements.firstWhere( (e) => e.value == id , orElse: () => null ) ;
  }

  void _checkAllElements(bool check) {
    _getSelectedElements().forEach( (e) => _setCheck(e,check) ) ;
  }

  List<String> getSelectedIDs() {
    return _getSelectedElements().map( (e) => e.value ).toList() ;
  }

  List<String> getSelectedLabels() {
    return _getSelectedElements().map( (e) => e.getAttribute('opt_label') ).toList() ;
  }

  void _updateElementText() {
    var sep = separator ?? ' ; ' ;
    var value = getSelectedLabels().join(sep);
    _element.value = value ;
  }

  @override
  dynamic render() {
    if ( _element == null ) {
      _element = InputElement()
        ..type = 'text'
      ;

      if (width != null) {
        _element.style.width = width ;
      }

      _divOptions = DivElement()
        ..style.display = 'none'
        ..style.backgroundColor = 'rgba(255,255,255, 0.90)'
        ..style.position = 'absolute'
        ..style.left = '0px'
        ..style.top = '0px'
        ..style.textAlign = 'left'
        ..style.padding = '4px'
        ..style.borderRadius = '0 0 10px 10px'
      ;

      _divOptions.classes.add('ui-multiselection-options-menu') ;

      window.onResize.listen( (e) => _updateDivOptionsPosition() ) ;

      _element.onKeyUp.listen( (e) {
        _updateDivOptions() ;
        _toggleDivOptions(false) ;
      } );

      _element.onClick.listen( (e) {
        _element.value = '' ;
        _toggleDivOptions(false) ;
      } ) ;

      _element.onMouseEnter.listen( (e) => _mouseEnter(_element) ) ;
      _element.onMouseLeave.listen( (e) => _mouseLeave(_element) ) ;

      _divOptions.onMouseEnter.listen( (e) => _mouseEnter(_divOptions) ) ;
      _divOptions.onMouseLeave.listen( (e) => _mouseLeave(_divOptions) ) ;

      _divOptions.onMouseMove.listen( (e) => _onDivOptionsMouseMove(e) ) ;

      _divOptions.onTouchEnter.listen( (e) => _mouseEnter(_element) ) ;
      _divOptions.onTouchLeave.listen( (e) => _mouseLeave(_element) ) ;

      window.onTouchStart.listen( (e) {
        if (_divOptions == null) return ;

        var overDivOptions = nodeTreeContainsAny( _divOptions , e.targetTouches.map( (t) => t.target ) ) ;
        if ( !overDivOptions && _isShowing() ) {
          _toggleDivOptions( true ) ;
        }
      });
    }

    var checksList = _renderDivOptions(_element, _divOptions) ;
    _checkElements = checksList ;

    return [ _element , _divOptions ] ;
  }

  bool _overElement = false ;
  bool _overDivOptions = false ;

  void _mouseEnter(Element elem) {
    if ( elem == _element ) {
      _overElement = true ;
    }
    else {
      _overDivOptions = true ;
    }

    _updateDivOptionsView();
  }

  void _mouseLeave(Element elem) {
    if ( elem == _element ) {
      _overElement = false ;
    }
    else {
      _overDivOptions = false ;
    }

    _updateDivOptionsView();
  }

  void _updateDivOptionsView() {
    if ( _overElement || _overDivOptions ) {
      _toggleDivOptions( false ) ;
    }
    else {
      _toggleDivOptions( true ) ;
    }
  }

  void _updateDivOptionsPosition() {
    var elemMargin = optionsPanelMargin ?? 20 ;
    var elemW = _element.contentEdge.width ;
    var w = Math.max( elemW - elemMargin , Math.min(elemW, 10) ) ;

    var x = _element.offset.left ;
    var xPadding = (elemW-w) / 2 ;
    x += xPadding ;

    var y = _element.offset.top + _element.offset.height ;

    _divOptions
      ..style.position = 'absolute'
      ..style.left = '${x}px'
      ..style.top = '${y}px'
      ..style.width = '${w}px'
    ;
  }

  dynamic _toggleDivOptions( bool requestedHide ) {
    _updateDivOptionsPosition() ;

    var hide ;

    if (requestedHide != null) {
      hide = requestedHide ;
    }
    else {
      var showing = _isShowing() ;
      hide = showing ;
    }


    if ( hide ) {
      _divOptions.style.display = 'none' ;
      _updateElementText();
      _notifySelection(false);
    }
    else {
      _divOptions.style.display = null ;
    }

  }

  bool _isShowing() => _divOptions.style.display == null || _divOptions.style.display == '';

  bool _setCheck(InputElementBase elem, bool check) {
    if ( elem is CheckboxInputElement ) {
      return elem.checked = check ;
    }
    else if ( elem is RadioButtonInputElement ) {
      return elem.checked = check ;
    }
    else {
      return null ;
    }
  }

  bool _isChecked(InputElementBase elem) {
    if ( elem is CheckboxInputElement ) {
      return elem.checked ;
    }
    else if ( elem is RadioButtonInputElement ) {
      return elem.checked ;
    }
    else {
      return null ;
    }
  }

  dynamic _updateDivOptions() {
    var checksList = _renderDivOptions(_element, _divOptions) ;
    _checkElements = checksList ;
  }

  dynamic _renderDivOptions(InputElement element, DivElement divOptions) {
    divOptions.children.clear();

    // ignore: omit_local_variable_types
    List<InputElementBase> checksList = [] ;

    // ignore: omit_local_variable_types
    List<MapEntry<dynamic, dynamic>> entries = List.from(_options.entries).cast() ;
    // ignore: omit_local_variable_types
    List<MapEntry<dynamic, dynamic>>  entriesFiltered = [] ;

    var elementValue = element.value;
    if (elementValue.isNotEmpty) {
      entriesFiltered = getOptionsEntriesFiltered( elementValue ) ;

      if (entriesFiltered.isEmpty && elementValue.length > 1) {
        var elementValue2 = elementValue.substring(0, elementValue.length-1) ;
        entriesFiltered = getOptionsEntriesFiltered( elementValue2 ) ;
      }

      entriesFiltered.forEach((e1) => entries.removeWhere( (e2) => e2.key == e1.key ) ) ;
    }

    for (var optEntry in entriesFiltered) {
      _renderDivOptionsEntry(divOptions, checksList, optEntry);
    }

    for (var optEntry in entries) {
      _renderDivOptionsEntry(divOptions, checksList, optEntry);
    }

    return checksList ;
  }

  void _renderDivOptionsEntry( DivElement divOptions, List<InputElementBase> checksList, MapEntry optEntry ) {
    var optKey = '${ optEntry.key }' ;
    var optValue = '${ optEntry.value }' ;

    var check = isCheckedByID( optKey ) ?? false ;

    InputElementBase checkElem ;

    if (multiSelection) {
      var input = CheckboxInputElement() ;
      input.checked = check ;
      checkElem = input ;
    }
    else {
      var input = RadioButtonInputElement()..name = '__MultiSelection__' ;
      input.checked = check ;
      checkElem = input ;
    }

    checkElem.value = optKey ;
    checkElem.setAttribute('opt_label', optValue) ;

    divOptions.children.add(checkElem) ;

    checksList.add(checkElem) ;

    var label = LabelElement()
      ..text = optValue ;
    ;

    checkElem.onClick.listen( (e) {
      _updateElementText();
      _checkByIDImpl( optKey , _isChecked(checkElem) , true, true );
    } ) ;

    label.onClick.listen( (e) {
      checkElem.click();
      _updateElementText();
      _checkByIDImpl( optKey , _isChecked(checkElem) , true, true );
    } ) ;

    divOptions.children.add( label ) ;
    divOptions.children.add( BRElement() ) ;
  }

  int _onDivOptionsLastMouseMove = 0 ;

  void _onDivOptionsMouseMove(MouseEvent e) {
    _onDivOptionsLastMouseMove = DateTime.now().millisecondsSinceEpoch ;
  }

}


typedef RenderPropertiesProvider = Map<String,dynamic> Function() ;
typedef RenderAsync = Future<dynamic> Function( Map<String,dynamic> properties ) ;


class UIComponentAsync extends UIComponent {

  RenderPropertiesProvider _renderPropertiesProvider ;
  RenderAsync _renderAsync ;
  final dynamic loadingContent ;
  final dynamic errorContent ;
  final Duration refreshInterval ;

  UIComponentAsync(Element parent, this._renderPropertiesProvider, this._renderAsync, this.loadingContent, this.errorContent, { this.refreshInterval, dynamic classes, dynamic classes2 , dynamic id } ) : super(parent, classes: classes, classes2: classes2, id: id, renderOnConstruction: false) {
    _renderPropertiesProvider ??= renderPropertiesProvider ;
    _renderAsync ??= renderAsync ;

    callRender();
  }

  Map<String,dynamic> renderPropertiesProvider() => {};
  Future<dynamic> renderAsync( Map<String,dynamic> properties ) => null;

  final EventStream<dynamic> onLoadAsyncContent = EventStream() ;
  UIAsyncContent _asyncContent ;

  @override
  dynamic render() {
    var properties = renderProperties() ;

    if ( !UIAsyncContent.isValid(_asyncContent, properties) ) {
      _asyncContent = UIAsyncContent.provider( () => _renderAsync( renderProperties() ) , loadingContent, errorContent , refreshInterval , properties ) ;
      _asyncContent.onLoadContent.listen( (content) {
        onLoadAsyncContent.add(content);
        onChange.add(content);
      } ) ;
    }

    return _asyncContent ;
  }

  bool isValid() {
    return UIAsyncContent.isValid( _asyncContent , renderProperties() ) ;
  }

  bool isNotValid() => !isValid() ;

  void stop() {
    if ( _asyncContent != null ) _asyncContent.stop() ;
  }

  void refreshAsyncContent() {
    if ( _asyncContent != null && !_asyncContent.stopped ) _asyncContent.refresh() ;
  }

  void reset([bool refresh = true]) {
    if ( _asyncContent != null ) _asyncContent.reset(refresh) ;
  }

  bool get hasAutoRefresh => refreshInterval != null ;

  bool get stopped => _asyncContent != null ? _asyncContent.stopped : false ;
  bool get isLoaded => _asyncContent != null ? _asyncContent.isLoaded : false ;
  bool get isOK => _asyncContent != null ? _asyncContent.isOK : false ;
  bool get isWithError => _asyncContent != null ? _asyncContent.isWithError : false ;

  DateTime get loadTime => _asyncContent != null ? _asyncContent.loadTime : null ;
  int get loadCount => _asyncContent != null ? _asyncContent.loadCount : 0 ;

  Map<String, dynamic> get asyncContentProperties => _asyncContent != null ? _asyncContent.properties : null ;

  bool asyncContentEqualsProperties(Map<String, dynamic> properties) => _asyncContent != null ? _asyncContent.equalsProperties(properties) : false ;

  Map<String,dynamic> renderProperties() {
    var properties = _renderPropertiesProvider != null ? _renderPropertiesProvider() : null ;
    properties ??= {} ;
    return properties ;
  }

}


abstract class UIControlledComponent extends UIComponent {

  final dynamic loadingContent ;
  final dynamic errorContent ;

  final dynamic resultLoadingContent ;
  final dynamic resultErrorContent ;

  UIControlledComponent(Element parent, this.loadingContent, this.errorContent, { this.resultLoadingContent, this.resultErrorContent, dynamic classes, dynamic classes2 }) : super(parent, classes: classes, classes2: classes2, renderOnConstruction: false);

  UIComponentAsync _componentAsync ;

  @override
  dynamic render() {
    _componentAsync ??= UIComponentAsync( content , getControllersProperties , (props) => renderAsync(props as MapProperties) , loadingContent, errorContent, id: '$id/_componentAsync') ;
    return _componentAsync ;
  }

  void refreshComponentAsync() {
    if (_componentAsync != null) {
      _componentAsync.refreshAsyncContent();
    }
  }

  MapProperties getControllersProperties() ;

  Map<String,dynamic> _controllers ;

  Map<String, dynamic> get controllers => _controllers != null ? Map.from(_controllers).cast() : null ;

  dynamic getController(String key) {
    return _controllers != null ? _controllers[key] : null ;
  }

  UIComponentAsync _componentAsyncResult ;

  Future<dynamic> renderAsync( MapProperties properties ) async {
    if (_controllers == null) {
      _controllers = await renderControllers(properties);
      await listenControllers(_controllers) ;
    }

    await setupControllers(properties, _controllers) ;

    var validSetup = isValidControllersSetup(properties, _controllers) ;

    if ( !validSetup ) {
      return renderOnlyControllers(properties, _controllers) ;
    }

    var resultLoadingContent = this.resultLoadingContent ?? UIComponent.copyRenderable(loadingContent) ;
    var resultErrorContent = this.resultErrorContent ?? UIComponent.copyRenderable(errorContent) ;

    _componentAsyncResult ??= UIComponentAsync( content , getControllersProperties , (props) => renderResult(props as MapProperties) , resultLoadingContent, resultErrorContent, id: '$id/_componentAsyncResult') ;

    return renderControllersAndResult( properties, _controllers , _componentAsyncResult ) ;
  }

  Future< Map<String,dynamic> > renderControllers( MapProperties properties ) ;

  Future<bool> setupControllers( MapProperties properties , Map<String,dynamic> controllers ) ;

  Future<bool> listenControllers( Map<String,dynamic> controllers ) async {
    for ( var control in controllers.values ) {

      if ( control is Element ) {
        control.onChange.listen( (e) => callOnChangeControllers(control)) ;
      }
      else if ( control is UIComponent ) {
        control.onChange.listen( (e) => callOnChangeControllers(control)) ;
      }
      else if ( control is UIAsyncContent ) {
        control.onLoadContent.listen( (e) => callOnChangeControllers(control)) ;
      }

    }

    return true ;
  }

  void callOnChangeControllers(dynamic control) {
    var propertiesNow = getControllersProperties();

    try {
      var valid = isValidControllersSetup(propertiesNow, _controllers);
      onChangeController(_controllers, valid, control);
    }
    catch (e,s) {
      print(e);
      print(s);
    }

    onChange.add(this) ;
  }

  void onChangeController( Map<String,dynamic> controllers , bool validControllersSetup , dynamic changedController ) { }

  bool isValidControllersSetup( MapProperties properties , Map<String,dynamic> controllers ) {
    return true ;
  }

  Future<dynamic> renderOnlyControllers( MapProperties properties , Map<String,dynamic> controllers ) async {
    return controllers != null ? List.from(controllers.values) : null ;
  }

  Future<dynamic> renderResult( MapProperties properties ) ;

  Future<dynamic> renderControllersAndResult( MapProperties properties , Map<String,dynamic> controllers , dynamic result ) async {
    return [ List.from(_controllers.values) , '<p>', result] ;
  }

}



