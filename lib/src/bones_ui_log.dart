import 'dart:html';

import 'package:dom_tools/dom_tools.dart';

/*
final LoggerFactory _loggerFactory = LoggerFactory(name: 'Bones_UI') ;

final Logger logger = _loggerFactory.get();

final Logger loggerIgnoreBonesUI = _loggerFactory.get(
    printer: PrettyPrinter(printTime: true)
      ..ignorePackage('bones_ui')
      ..ignorePackage('bones_ui_bootstrap'));
*/

// Temporary logger. Will be replaced by `logger`.
class _Logger {
  void i(dynamic msg) {
    msg = _format(msg);
    print(msg);
  }

  void e(dynamic msg, dynamic e, StackTrace s) {
    msg = _format(msg, true);
    _error(msg);
    if (e != null) {
      _error(e.toString());
    }
    _error(formatStackTrace(s));
  }

  void _error(msg) {
    window.console.error(msg);
  }

  dynamic _format(dynamic msg, [bool error = false]) {
    if (msg is List) {
      return msg.map((e) => _format(msg));
    } else if (msg is String) {
      var str = StringBuffer(error ? '\n' : '');

      str.write('┌-------------------------------------------------\n');

      var lines = msg.split('\n');

      for (var line in lines) {
        str.write('| ');
        str.write(line);
        str.write('\n');
      }

      str.write('└-------------------------------------------------\n');

      return str.toString();
    } else {
      return msg;
    }
  }

  String? formatStackTrace(StackTrace stackTrace) {
    var lines = stackTrace.toString().split('\n');

    var formatted = <String>[];
    var count = 0;

    var length = lines.length;
    for (var i = 0; i < length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;
      formatted.add('#$count   ${line.replaceFirst(RegExp(r'#\d+\s+'), '')}');
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }
}

final _Logger logger = _Logger();
final _Logger loggerIgnoreBonesUI = _Logger();

/// A console output int the UI.
///
/// Useful for web development, allowing access to console output
/// directly in the UI.
class UIConsole {
  static UIConsole? _instance;

  static UIConsole? get() {
    _instance ??= UIConsole._internal();
    return _instance;
  }

  bool _enabled = false;

  final List<String> _logs = [];

  int _limit = 10000;

  UIConsole._internal() {
    mapJSUIConsole();
  }

  static bool _mapJSUIConsole = false;

  static void mapJSUIConsole() {
    if (_mapJSUIConsole) return;
    _mapJSUIConsole = true;

    try {
      mapJSFunction('UIConsole', (o) {
        UIConsole.log('JS> $o');
      });
    } catch (e) {
      UIConsole.error("Can't mapJSFunction: UIConsole", e);
    }
  }

  bool get enabled => _enabled;

  int get limit => _limit;

  set limit(int l) {
    if (l < 10) l = 10;
    _limit = l;
  }

  static void enable() {
    get()!._enable();
  }

  static final String sessionKeyUIConsoleEnabled = '__UIConsole__enabled';

  void _enable() {
    _enabled = true;

    window.sessionStorage[sessionKeyUIConsoleEnabled] = '1';
  }

  static void checkAutoEnable() {
    if (window.sessionStorage[sessionKeyUIConsoleEnabled] == '1') {
      displayButton();
    }
  }

  static void disable() {
    get()!._disable();
  }

  void _disable() {
    _enabled = false;

    window.sessionStorage[sessionKeyUIConsoleEnabled] = '0';
  }

  static List<String> logs() {
    return get()!._getLogs();
  }

  List<String> _getLogs() {
    return List.from(_logs).cast();
  }

  static List<String> tail([int tailSize = 100]) {
    return get()!._tail(tailSize);
  }

  List<String> _tail([int tailSize = 100]) {
    // ignore: omit_local_variable_types
    List<String> list = [];

    for (var i = _logs.length - tailSize; i < _logs.length; ++i) {
      list.add(_logs[i]);
    }

    return list;
  }

  static List<String> head([int headSize = 100]) {
    return get()!._head(headSize);
  }

  List<String> _head([int headSize = 100]) {
    // ignore: omit_local_variable_types
    List<String> list = [];

    if (headSize > _logs.length) headSize = _logs.length;

    for (var i = 0; i < headSize; ++i) {
      list.add(_logs[i]);
    }

    return list;
  }

  static void error(dynamic msg, [dynamic exception, StackTrace? trace]) {
    return get()!._error(msg, exception, trace);
  }

  void _error(dynamic msg, [dynamic exception, StackTrace? trace]) {
    if (!_enabled) {
      if (exception != null) {
        msg += ' >> $exception';
      }

      window.console.error(msg);

      if (trace != null) {
        window.console.error(trace.toString());
      }

      return;
    }

    var now = DateTime.now();
    var log = 'ERROR> $now>  $msg';

    if (exception != null) {
      log += ' >> $exception';
    }

    _logs.add(log);

    if (trace != null) {
      _logs.add(trace.toString());
    }

    while (_logs.length > _limit) {
      _logs.removeAt(0);
    }

    if (msg is String) {
      window.console.error(log);
    } else {
      window.console.error(msg);
    }

    if (trace != null) {
      window.console.error(trace.toString());
    }
  }

  static void log(dynamic msg) {
    return get()!._log(msg);
  }

  void _log(dynamic msg) {
    if (!_enabled) {
      loggerIgnoreBonesUI.i(msg);
      return;
    }

    var now = DateTime.now();
    var log = '$now>  $msg';

    _logs.add(log);

    while (_logs.length > _limit) {
      _logs.removeAt(0);
    }

    loggerIgnoreBonesUI.i(msg);
  }

  static String allLogs() {
    return get()!._allLogs();
  }

  String _allLogs() {
    var allLogs = _logs.join('\n');

    allLogs = allLogs.replaceAll('<', '&lt;');
    allLogs = allLogs.replaceAll('>', '&gt;');

    return allLogs;
  }

  static void clear() {
    return get()!._clear();
  }

  void _clear() {
    _logs.clear();
  }

  static bool isShowing() {
    return get()!._isShowing();
  }

  bool _isShowing() {
    return querySelector('#UIConsole') != null;
  }

  static void hide() {
    return get()!._hide();
  }

  void _hide() {
    var prevConsoleDiv = querySelector('#UIConsole');

    if (prevConsoleDiv != null) {
      prevConsoleDiv.remove();
    }
  }

  static void show() {
    return get()!._show();
  }

  DivElement? _contentClipboard;

  void _show() {
    _enable();

    _hide();

    var consoleDiv = DivElement();
    consoleDiv.id = 'UIConsole';

    consoleDiv.style
      ..position = 'absolute'
      ..width = '100%'
      ..height = '100%'
      ..left = '0px'
      ..top = '0px'
      ..padding = '6px 6px 7px 6px'
      ..color = '#ffffff'
      ..backgroundColor = 'rgba(0,0,0, 0.90)'
      ..zIndex = '9999999999';

    var contentClipboard = createDivInline();

    contentClipboard.style
      ..width = '0px'
      ..height = '0px'
      ..lineHeight = '0px';

    consoleDiv.children.add(contentClipboard);

    var allLogs = _allLogs();

    var consoleButtons = DivElement();

    var buttonClose = Element.span()..text = '[X]';
    buttonClose.style.cursor = 'pointer';
    buttonClose.onClick.listen((m) => hide());

    var buttonCopy = Element.span()..text = '[Copy All]';
    buttonCopy.style.cursor = 'pointer';
    buttonCopy.onClick.listen((m) => copy());

    var buttonZoomIn = Element.span()..text = '[ + ]';
    buttonZoomIn.style.cursor = 'zoom-in';

    var buttonZoomOut = Element.span()..text = '[ - ]';
    buttonZoomOut.style.cursor = 'zoom-out';

    var buttonClear = Element.span()..text = '[Clear]';
    buttonClear.style.cursor = 'pointer';

    consoleButtons.children.add(buttonClose);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonCopy);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonZoomIn);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonZoomOut);
    consoleButtons.children.add(Element.span()..innerHtml = '&nbsp;&nbsp;');
    consoleButtons.children.add(buttonClear);

    var consoleText = DivElement();
    consoleText.style.fontSize = '$_fontSize%';
    consoleText.style.overflow = 'scroll';

    var html = '<pre>\n'
        '$allLogs'
        '</pre>';

    setElementInnerHTML(consoleText, html);

    buttonClear.onClick.listen((m) {
      if (window.confirm('Clear UIConsole?')) {
        clear();
        consoleText.text = '';
      }
    });

    buttonZoomIn.onClick.listen((m) {
      _changeFontSize(consoleText, 1.05);
    });

    buttonZoomOut.onClick.listen((m) {
      _changeFontSize(consoleText, 0.95);
    });

    consoleDiv.children.add(consoleButtons);
    consoleDiv.children.add(consoleText);

    _contentClipboard = contentClipboard;

    document.documentElement!.children.add(consoleDiv);
  }

  double _fontSize = 100.0;

  void _changeFontSize(DivElement consoleText, double change) {
    var fontSizeProp = consoleText.style.fontSize;

    var fontSize = fontSizeProp.isEmpty
        ? 100
        : double.parse(fontSizeProp.replaceFirst('%', ''));
    var size = fontSize * change;

    size = size.toInt().toDouble();

    if (size >= 96 && size <= 104) size = 100.0;

    if (fontSize == size) {
      if (change > 1) {
        size++;
      } else {
        size--;
      }
    }

    if (size < 50) {
      size = 30.0;
    } else if (size > 300) {
      size = 300.0;
    }

    consoleText.style.fontSize = '$size%';

    _fontSize = size;
  }

  static void copy() {
    get()!._copy();
  }

  void _copy() {
    var allLogs = _allLogs();

    if (_contentClipboard != null) {
      _contentClipboard!.innerHtml = '<pre>$allLogs</pre>';
      _copyElementToClipboard(_contentClipboard!);
      _contentClipboard!.text = '';
    }
  }

  void _copyElementToClipboard(Element elem) {
    var selection = window.getSelection()!;
    var range = document.createRange();

    range.selectNodeContents(elem);
    selection.removeAllRanges();
    selection.addRange(range);

    document.execCommand('copy');

    window.getSelection()!.removeAllRanges();
  }

  static final String buttonId = 'UIConsole_button';

  static DivElement button([double opacity = 0.20]) {
    enable();

    var elem = createDivInline('[>_]');

    elem.id = buttonId;

    elem.style
      ..backgroundColor = 'rgba(0,0,0, 0.5)'
      ..color = 'rgba(0,255,0, 0.5)'
      ..fontSize = '14px'
      ..opacity = '$opacity';

    elem.onClick.listen((m) => isShowing() ? hide() : show());

    return elem;
  }

  static void displayButton() {
    var prevElem = querySelector('#$buttonId');
    if (prevElem != null) return;

    var elem = button(1.0);

    loggerIgnoreBonesUI.i('Button: ${elem.clientHeight}');

    elem.style
      ..position = 'fixed'
      ..left = '0px'
      ..top = '100%'
      ..transform = 'translateY(-15px)'
      ..zIndex = '999999';

    document.body!.children.add(elem);
  }
}
