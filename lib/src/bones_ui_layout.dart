import 'dart:html';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:expressions/expressions.dart';

import 'bones_ui_component.dart';

typedef ElementProvider = dynamic Function(String id, bool all);
typedef ElementPropertyResolver = dynamic Function(
    dynamic element, String property);

class ValueUnitExpression extends SimpleExpression {
  static String? getUnit(Expression? a, Expression? b) {
    if (a is ValueUnitExpression && b is ValueUnitExpression) {
      var unitA = a.unit;
      var unitB = b.unit;

      if (unitA != unitB) {
        throw UnsupportedError(
            'Different unit expressions not supported: $a != $b');
      }

      return unitA;
    }

    if (a is ValueUnitExpression) return a.unit;
    if (b is ValueUnitExpression) return b.unit;

    return null;
  }

  final dynamic value;

  final String? unit;

  ValueUnitExpression(this.value, this.unit);

  Literal get valueAsLiteral => Literal(value);

  @override
  String toString() {
    return '$value$unit';
  }

  dynamic operator +(o) => ValueUnitExpression(value + o, unit);

  dynamic operator -(o) => ValueUnitExpression(value - o, unit);

  dynamic operator *(o) => ValueUnitExpression(value * o, unit);

  dynamic operator /(o) => ValueUnitExpression(value / o, unit);

  dynamic operator ~/(o) => ValueUnitExpression(value ~/ o, unit);
}

class ElementExpression extends SimpleExpression {
  final dynamic element;

  final Identifier? property;

  ElementExpression(this.element, this.property);

  @override
  String toTokenString() => toString();

  @override
  String toString() {
    return property != null ? '$element.$property' : '$element';
  }
}

typedef ValueFromElement = String Function(Element elem);
typedef ElementCoordsValue = String Function(
    int parentWidth, int parentHeight, int width, int height);
typedef ElementPercentageValue = String Function(
    int parentWidth, int parentHeight, double percentage);

class UILayoutEvaluator extends ExpressionEvaluator {
  final ElementProvider elementProvider;

  final ElementPropertyResolver elementPropertyResolver;

  UILayoutEvaluator(this.elementProvider, this.elementPropertyResolver);

  void reset() {
    _providedElements = {};
  }

  Set<dynamic> _providedElements = {};

  bool isProvidedElement(dynamic elem) {
    if (elem == null) return false;
    return _providedElements.contains(elem);
  }

  dynamic _requestElement(String id, bool all) {
    var elem = elementProvider(id, all);
    if (elem == null) return null;

    if (elem is List) {
      _providedElements.addAll(elem);
    } else {
      _providedElements.add(elem);
    }

    return elem;
  }

  dynamic _requestElementProperty(dynamic element, String propery) {
    var resolved = elementPropertyResolver(element, propery);
    if (resolved == null) return null;
    _providedElements.add(resolved);
    return resolved;
  }

  Expression? _toExpression(dynamic o) {
    if (o == null) return null;
    if (o is Expression) return o;
    if (o is num) return Literal(o);

    if (o is String) {
      return Variable(Identifier(o));
    } else {
      return Variable(Identifier(o.toString()));
    }
  }

  String? _getIdentifierName(Identifier? o) => o?.name;

  @override
  dynamic evalBinaryExpression(
      BinaryExpression expression, Map<String, dynamic> context) {
    dynamic left = expression.left;
    dynamic right = expression.right;

    var changed = false;

    if (left is MemberExpression) {
      left = resolveMemberExpression(left, context);
      changed = true;
    }

    if (right is MemberExpression) {
      right = resolveMemberExpression(right, context);
      changed = true;
    }

    if (left is ThisExpression) {
      left = resolveThisExpression(left, context);
      changed = true;
    }

    if (right is ThisExpression) {
      right = resolveThisExpression(right, context);
      changed = true;
    }

    if (left is BinaryExpression) {
      left = evalBinaryExpression(left, context);
      changed = true;
    }

    if (right is BinaryExpression) {
      right = evalBinaryExpression(right, context);
      changed = true;
    }

    if (left is ValueUnitExpression || right is ValueUnitExpression) {
      // ignore: omit_local_variable_types
      Expression leftValue = left is ValueUnitExpression
          ? left.valueAsLiteral
          : _toExpression(left)!;
      // ignore: omit_local_variable_types
      Expression rightValue = right is ValueUnitExpression
          ? right.valueAsLiteral
          : _toExpression(right)!;

      var expression2 =
          BinaryExpression(expression.operator, leftValue, rightValue);

      var evaluated = super.evalBinaryExpression(expression2, context);
      var unit = ValueUnitExpression.getUnit(left, right);

      return ValueUnitExpression(evaluated, unit);
    } else if (changed) {
      var expression2 = BinaryExpression(
          expression.operator, _toExpression(left)!, _toExpression(right)!);
      return super.evalBinaryExpression(expression2, context);
    } else {
      return super.evalBinaryExpression(expression, context);
    }
  }

  @override
  dynamic evalUnaryExpression(
      UnaryExpression expression, Map<String, dynamic> context) {
    dynamic arg = expression.argument;

    var changed = false;

    if (arg is MemberExpression) {
      arg = resolveMemberExpression(arg, context);
      changed = true;
    }

    if (arg is ThisExpression) {
      arg = resolveThisExpression(arg, context);
      changed = true;
    }

    if (arg is BinaryExpression) {
      arg = evalBinaryExpression(arg, context);
      changed = true;
    }

    if (arg is ValueUnitExpression) {
      Expression leftValue = arg.valueAsLiteral;
      var expression2 = UnaryExpression(expression.operator, leftValue,
          prefix: expression.prefix);

      var evaluated = super.evalUnaryExpression(expression2, context);
      var unit = arg.unit;

      return ValueUnitExpression(evaluated, unit);
    } else if (changed) {
      var expression2 = UnaryExpression(
          expression.operator, _toExpression(arg)!,
          prefix: expression.prefix);
      return super.evalUnaryExpression(expression2, context);
    } else {
      return super.evalUnaryExpression(expression, context);
    }
  }

  @override
  dynamic evalIndexExpression(
      IndexExpression expression, Map<String, dynamic> context) {
    var o = expression.object;

    dynamic list;
    if (o is MemberExpression) {
      list = _evalMemberExpressionImpl(o, context, null, true);
    } else {
      list = eval(o, context);
    }

    if (list == null) return null;

    var index = eval(expression.index, context);
    index ??= 0;

    if (list is List) {
      if (index >= list.length) return null;
      return list[index];
    } else {
      if (index == 0) return list;
      return list[index];
    }
  }

  @override
  dynamic evalVariable(Variable variable, Map<String, dynamic> context) {
    var name = variable.identifier.name;
    var val = context[name];

    val ??= context[name.toLowerCase()];

    return val;
  }

  Expression? resolveThisExpression(
      ThisExpression expression, Map<String, dynamic> context,
      [String? subProperty]) {
    var element = _requestElement('_', false);
    if (element == null) return null;
    var elemProperty = subProperty != null ? Identifier(subProperty) : null;
    return ElementExpression(element, elemProperty);
  }

  @override
  dynamic evalThis(ThisExpression expression, Map<String, dynamic> context) {
    return _evalThisImpl(expression, context);
  }

  dynamic _evalThisImpl(ThisExpression expression, Map<String, dynamic> context,
      [String? subProperty]) {
    var expressionResolved =
        resolveThisExpression(expression, context, subProperty);

    if (expressionResolved is ElementExpression) {
      return evalElementExpression(expressionResolved, context);
    } else {
      return eval(expressionResolved!, context);
    }
  }

  static final RegExp _patternNumberPlaceHolder =
      RegExp(r'^__(\d+)(?:D(\d+))?__$');

  Expression? resolveMemberExpression(
      MemberExpression expression, Map<String, dynamic> context,
      [String? subProperty, bool? fromIndexExpression = false]) {
    dynamic o = expression.object;

    if (o is Variable) {
      var varName = o.identifier.name;

      Iterable<Match> matches;

      if (varName == 'elements') {
        var elementID = expression.property.name;
        fromIndexExpression ??= false;
        var element = _requestElement(elementID, fromIndexExpression);
        if (element == null) return null;
        var elemProperty = subProperty != null ? Identifier(subProperty) : null;
        return ElementExpression(element, elemProperty);
      } else if ((matches = _patternNumberPlaceHolder.allMatches(varName))
          .isNotEmpty) {
        var number = matches.first.group(1);
        var decimal = matches.first.group(2);

        if (decimal == null) {
          decimal = '';
        } else if (decimal.isNotEmpty) {
          decimal = '.$decimal';
        }

        var unit = expression.property.name;
        dynamic n = decimal.isNotEmpty
            ? double.parse('$number$decimal')
            : int.parse(number!);
        return ValueUnitExpression(n, unit);
      }
    }

    return expression;
  }

  @override
  dynamic evalMemberExpression(
      MemberExpression expression, Map<String, dynamic> context) {
    return _evalMemberExpressionImpl(expression, context);
  }

  dynamic _evalMemberExpressionImpl(
      MemberExpression expression, Map<String, dynamic> context,
      [String? subProperty, bool? fromIndexExpression]) {
    var expressionResolved = resolveMemberExpression(
        expression, context, subProperty, fromIndexExpression);

    if (expressionResolved is ElementExpression) {
      return evalElementExpression(expressionResolved, context);
    } else if (expressionResolved is ValueUnitExpression) {
      return evalValueUnitExpression(expressionResolved, context);
    } else if (expressionResolved is MemberExpression) {
      var o = expressionResolved.object;

      if (o is MemberExpression) {
        var property = _getIdentifierName(expressionResolved.property);
        var evaluated = _evalMemberExpressionImpl(o, context, property);
        return evalValue(evaluated, subProperty);
      } else {
        var property = _getIdentifierName(expressionResolved.property);
        var evaluated = eval(o, context);
        evaluated = evalValue(evaluated, property);
        if (subProperty != null) {
          evaluated = evalValue(evaluated, subProperty);
        }
        return evaluated;
      }
    } else {
      return eval(expressionResolved!, context);
    }
  }

  dynamic evalElementExpression(
      ElementExpression expression, Map<String, dynamic> context) {
    var elem = expression.element;

    if (expression.property != null) {
      return _requestElementProperty(elem, expression.property!.name);
    } else {
      return elem;
    }
  }

  dynamic evalValueUnitExpression(
      ValueUnitExpression expression, Map<String, dynamic> context) {
    return expression.toString();
  }

  bool _evalValueCalling = false;

  dynamic evalValue(dynamic value, String? property) {
    if (property == null) return value;

    if (!_evalValueCalling && isProvidedElement(value)) {
      try {
        _evalValueCalling = true;

        return _requestElementProperty(value, property);
      } finally {
        _evalValueCalling = false;
      }
    }

    if (value is Map) {
      dynamic val = value[property];
      return val;
    } else if (value is List) {
      var idx = int.parse(property);
      dynamic val = value[idx];
      return val;
    } else {
      return value;
    }
  }

  static final RegExp _patternNumber = RegExp(r'^(\d+(?:\.\d+)?)$');

  dynamic processLayout(String expressionStr, Map<String, dynamic> context,
      [String? unit, dynamic defaultValue]) {
    reset();

    var expression = _parse(expressionStr);
    var evaluated = eval(expression, context);

    if (evaluated is Expression) {
      evaluated = evaluated.toString();
    }

    //print("evaluated<<$evaluated>>") ;

    if (evaluated == null) return defaultValue;

    if (!isPrimitiveValue(evaluated)) {
      return evaluated;
    }

    if (evaluated is! String) {
      evaluated = '$evaluated';
    }

    if (unit != null && _patternNumber.hasMatch(evaluated)) {
      var evaluatedUnit = '$evaluated$unit';
      //print("evaluatedUnit<<$evaluatedUnit>>") ;
      return evaluatedUnit;
    }

    return evaluated;
  }

  static final Map<String, Expression> _parseCache = {};

  Expression _parse(String expressionStr) {
    var expression = _parseCache[expressionStr];
    if (expression != null) {
      //print("PARSE CACHE> $expressionStr > $expression") ;
      return expression;
    }

    var expressionStrOrig = expressionStr;

    //print("1<<$expressionStr>>") ;

    expressionStr = expressionStr.replaceAll('#', 'elements.');
    expressionStr = expressionStr
        .replaceAllMapped(RegExp(r'(\d+)(?:\.(\d+))?([a-zA-Z_]+)'), (m) {
      var gDecimal = m.group(2);
      if (gDecimal != null && gDecimal.isNotEmpty) {
        return '__' + m.group(1)! + 'D' + gDecimal + '__.' + m.group(3)!;
      } else {
        return '__' + m.group(1)! + '__.' + m.group(3)!;
      }
    });

    //print("2<<$expressionStr>>") ;

    expression = Expression.parse(expressionStr);
    _parseCache[expressionStrOrig] = expression;

    //print("PARSE!> $expressionStrOrig > $expression") ;

    return expression;
  }

  bool isPrimitiveValue(dynamic o) {
    if (o == null) return false;

    if (o is String) return true;
    if (o is num) return true;
    if (o is bool) return true;

    return false;
  }
}

class UILayout {
  final UIComponent parent;

  final Element element;

  final String layout;

  late UILayoutEvaluator _uiLayoutEvaluator;

  UILayout(this.parent, this.element, this.layout) {
    _uiLayoutEvaluator =
        UILayoutEvaluator(_getElementByID, _getElementProperty);

    _registerWindowResize();
    _configure();
  }

  dynamic _getElementByID(String id, bool all) {
    if (id == '_') return element;

    var content = parent.content;
    if (all) {
      return content!.querySelectorAll('#$id');
    } else {
      return content!.querySelector('#$id');
    }
  }

  dynamic _getElementProperty(dynamic elem, String? property) {
    if (property == null) return null;

    if (elem is Element) {
      property = property.toLowerCase();

      if (property == 'x') {
        return elem.offsetLeft;
      } else if (property == 'y') {
        return elem.offsetTop;
      } else if (property == 'width') {
        return elem.offsetWidth;
      } else if (property == 'height') {
        return elem.offsetHeight;
      }
      if (property == 'center') {
        return _getElementCenter(elem);
      } else if (property == 'index') {
        return _getElementIndex(elem);
      } else if (property == 'indexbyid') {
        return _getElementIndexByID(elem);
      }
    } else {
      return _uiLayoutEvaluator.evalValue(elem, property);
    }
  }

  int _getElementIndex(Element elem) {
    var idx = elem.parent!.children.indexOf(elem);
    return idx;
  }

  int _getElementIndexByID(Element elem) {
    var elemID = elem.id;
    List<Element> elemsSameID = elem.parent!.querySelectorAll('#$elemID');
    if (elemsSameID.isEmpty) return -1;
    var idx = elemsSameID.indexOf(elem);
    return idx;
  }

  Map<String, int> _getElementCenter(Element elem) {
    var x = elem.offsetLeft;
    var y = elem.offsetTop;
    var w = elem.offsetWidth;
    var h = elem.offsetHeight;

    var x2 = x + (w ~/ 2);
    var y2 = y + (h ~/ 2);

    return {'x': x2, 'y': y2};
  }

  Window? _registeredWindow;

  void _registerWindowResize() {
    if (_registeredWindow != window) {
      _registeredWindow = window;
      window.onResize.listen(_onWindowResize);
    }
  }

  static void _onWindowResize(dynamic evt) {
    refreshAll();
  }

  static final Map<Element, UILayout> _instances = {};

  static void refreshAll() {
    //UIConsole.log("UILayout.refreshAll()") ;
    var list = List.from(_instances.values);
    for (var u in list) {
      u.refresh();
    }
  }

  static void checkInstances() {
    var list = List.from(_instances.values);
    for (var u in list) {
      u._checkRegistration();
    }
  }

  static bool someInstanceNeedsRefresh() {
    // ignore: omit_local_variable_types
    UILayout? uiLayout =
        _instances.values.firstWhereOrNull((u) => u.needsRefresh);
    return uiLayout != null;
  }

  bool _checkRegistration() {
    if (element.isConnected!) {
      _register();
      return true;
    } else {
      _unregister();
      return false;
    }
  }

  bool _registered = false;

  bool get isRegistered => _registered;

  void _register() {
    if (isRegistered) return;

    _instances[element] = this;
    _registered = true;
  }

  void _unregister() {
    if (!isRegistered) return;

    _instances.remove(element);
    _registered = false;
  }

  bool _needRefresh = false;

  bool get needsRefresh => _needRefresh;

  void refresh() {
    _needRefresh = false;
    _configure();
  }

  void _configure() {
    if (!_checkRegistration()) {
      return;
    }

    var layout = this.layout.trim();

    if (layout.isEmpty || layout == 'container') {
      element.style.position = 'relative';
      return;
    }

    element.style.position = 'absolute';

    var commands = this.layout.split('\\s*;\\s*');
    commands.forEach(_commandsParser);
  }

  void _commandsParser(String cmds) {
    var parts = cmds.split(';');
    parts.forEach(_command);
  }

  void _command(String? cmd) {
    if (cmd == null) return;
    cmd = cmd.trim();
    if (cmd.isEmpty) return;

    var idx1 = cmd.indexOf('(');

    if (idx1 < 0) {
      _commandSingle(cmd);
      return;
    }

    var idx2 = cmd.lastIndexOf(')');

    if (idx2 < 0) {
      return;
    }

    var name = cmd.substring(0, idx1).trim();
    var value = cmd.substring(idx1 + 1, idx2).trim();

    _commandFunction(name, value);
  }

  void _commandSingle(String cmd) {}

  void _commandFunction(String name, String value) {
    name = name.toLowerCase();

    if (name == 'x') {
      _commandFunctionX(value);
    } else if (name == 'y') {
      _commandFunctionY(value);
    } else if (name == 'centerx') {
      _commandFunctionCenterX(value);
    } else if (name == 'centery') {
      _commandFunctionCenterY(value);
    } else if (name == 'width') {
      _commandFunctionWidth(value);
    } else if (name == 'height') {
      _commandFunctionHeight(value);
    }
  }

  void _commandFunctionX(String value) {
    var x = _commandFunctionXValue(value);
    element.style.left = x;
  }

  String _commandFunctionXValue(String value) {
    return _valueXY(
        value,
        (pw, ph, w, h) => ((pw / 2) - (w / 2)).toStringAsFixed(0) + 'px',
        (e) => e.style.left);
  }

  void _commandFunctionY(String value) {
    var y = _commandFunctionYValue(value);
    element.style.top = y;
  }

  String _commandFunctionYValue(String value) {
    return _valueXY(
        value,
        (pw, ph, w, h) => ((ph / 2) - (h / 2)).toStringAsFixed(0) + 'px',
        (e) => e.style.top);
  }

  void _commandFunctionCenterX(String value) {
    var x = _commandFunctionXValue(value);

    var xInt = _parseValuePx(x);

    if (xInt != null) {
      var w = element.offsetWidth;
      element.style.left = '${xInt - (w / 2)}px';
    } else {
      element.style.left = x;
    }
  }

  void _commandFunctionCenterY(String value) {
    var y = _commandFunctionYValue(value);

    var yInt = _parseValuePx(y);

    if (yInt != null) {
      var h = element.offsetHeight;
      element.style.top = '${yInt - (h / 2)}px';
    } else {
      element.style.top = y;
    }
  }

  String _valueXY(String value, ElementCoordsValue valueCenter,
      ValueFromElement valueFromElement) {
    if (_patternElementID.hasMatch(value)) {
      var sel = element.parent!.querySelector(value);
      if (sel == null) return '0px';
      return valueFromElement(sel);
    } else if (value == '*') {
      var w = element.offsetWidth;
      var h = element.offsetHeight;

      var parent = element.offsetParent!;
      var pw = parent.offsetWidth;
      var ph = parent.offsetHeight;

      if (pw == 0 || ph == 0) {
        _needRefresh = true;
        return '0 px';
      }

      return valueCenter(pw, ph, w, h);
    } else {
      return _evaluateValue(value, valueFromElement);
    }
  }

  void _commandFunctionWidth(String value) {
    var width = _valueWH(
        value,
        (pw, ph, w, h) => '${pw}px',
        (pw, ph, p) => (pw * p).toStringAsFixed(0) + 'px',
        (e) => e.style.width);
    element.style.width = width;
  }

  void _commandFunctionHeight(String value) {
    var height = _valueWH(
        value,
        (pw, ph, w, h) => '${ph}px',
        (pw, ph, p) => (ph * p).toStringAsFixed(0) + 'px',
        (e) => e.style.height);
    element.style.height = height;
  }

  static final RegExp _patternElementID = RegExp(r'^#\w+$');

  String _valueWH(
      String value,
      ElementCoordsValue valueFull,
      ElementPercentageValue valuePercentage,
      ValueFromElement valueFromElement) {
    var w = element.offsetWidth;
    var h = element.offsetHeight;

    var parent = element.offsetParent!;
    var pw = parent.offsetWidth;
    var ph = parent.offsetHeight;

    if (_patternElementID.hasMatch(value)) {
      var sel = element.parent!.querySelector(value);
      if (sel == null) return '0px';
      return valueFromElement(sel);
    } else if (value == '*') {
      if (pw == 0 || ph == 0) {
        _needRefresh = true;
        return '0px';
      }

      return valueFull(pw, ph, w, h);
    } else if (value.endsWith('%')) {
      if (pw == 0 || ph == 0) {
        _needRefresh = true;
        return '0px';
      }

      var valPerc = int.parse(value.substring(0, value.length - 1));
      return valuePercentage(pw, ph, valPerc / 100);
    } else {
      return _evaluateValue(value, valueFromElement);
    }
  }

  String _evaluateValue(String value, ValueFromElement valueFromElement) {
    var context = _buildEvaluationContext();
    var evaluated =
        _uiLayoutEvaluator.processLayout(value, context, 'px', '0px');
    if (evaluated is Element) {
      return valueFromElement(evaluated);
    }
    return '$evaluated';
  }

  Map<String, int> _buildEvaluationContext() {
    var context = {
      'index': _getElementIndex(element),
      'indexbyid': _getElementIndexByID(element),
    };
    return context;
  }

  int? _parseValuePx(String val) {
    if (val.endsWith('px')) {
      var n = int.parse(val.substring(0, val.length - 2));
      return n;
    }
    return null;
  }
}
