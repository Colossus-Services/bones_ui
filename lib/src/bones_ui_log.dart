import 'dart:async';

import 'package:dom_tools/dom_tools.dart';
import 'package:logging/logging.dart' as logging;
import 'package:web_utils/web_utils.dart';

import 'bones_ui_web.dart';

StreamSubscription<logging.LogRecord>? _loggingListenSubscription;

void _logToConsole() {
  _loggingListenSubscription ??=
      logging.Logger.root.onRecord.listen(_logConsole);
}

void _logConsole(logging.LogRecord msg) {
  var levelName = '[${msg.level.name}]'.padRight(9);

  var loggerName = msg.loggerName;
  var message = msg.message;

  var logMsg = StringBuffer('$levelName\t$loggerName\t> $message').toString();

  if (msg.error != null) {
    UIConsole.error(logMsg, msg.error, msg.stackTrace);
  } else {
    UIConsole.log(logMsg);
  }
}

// Temporary logger.
class _Logger {
  void log(Object? msg) {
    print('║ $msg');
  }

  void error(dynamic msg, [Object? error, StackTrace? stackTrace]) {
    msg = _format(msg, error);
    _printError(msg);

    if (stackTrace != null) {
      var s = _formatStackTrace(stackTrace);
      _printError('\n$s');
    }
  }

  void _printError(Object? msg) {
    if (msg == null) return;
    window.console.error(msg.jsify());
  }

  Object? _format(Object? msg, [Object? error]) {
    if (msg is List) {
      return [
        ...msg.map((e) => _format(msg)),
        if (error != null) error,
      ];
    } else if (msg is String) {
      var str = StringBuffer(error != null ? '\n' : '');

      str.write('╔═════════════════════════════════════════════════\n');

      var lines = msg.split('\n');

      for (var line in lines) {
        str.write('║ ');
        str.write(line);
        str.write('\n');
      }

      if (error != null) {
        str.write('║\n');
        str.write('╠═ ERROR ═════════════════════════════════════════\n');
        str.write('║\n');

        var errorLines = error.toString().split('\n');

        for (var line in errorLines) {
          str.write('║ ');
          str.write(line);
          str.write('\n');
        }

        str.write('║\n');
      }

      str.write('╚═════════════════════════════════════════════════\n');

      return str.toString();
    } else {
      return msg;
    }
  }

  String? _formatStackTrace(StackTrace stackTrace) {
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

// ignore: library_private_types_in_public_api
final _Logger logger = _Logger();

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
    _logToConsole();
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
    return _logs.toList();
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

  void _error(dynamic msg, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) {
      _checkLogsLimit();

      var now = _timeNow();

      _logs.add(now);
      _logs.add('╔═ ERROR ═════════════════════════════════════════');
      _logs.add('$msg');

      if (error != null) {
        _logs.add('\n$error');
      }

      if (stackTrace != null) {
        var s = logger._formatStackTrace(stackTrace);
        _logs.add('\n$s');
      }

      _logs.add('╚═════════════════════════════════════════════════');
    }

    if (error != null && stackTrace != null) {
      logger.error(msg, error, stackTrace);
    } else {
      logger.log(msg);
    }
  }

  String _timeNow() => DateTime.now().toString().padRight(23);

  void _checkLogsLimit() {
    while (_logs.length > _limit) {
      _logs.removeAt(0);
    }
  }

  static void log(dynamic msg) {
    return get()!._log(msg);
  }

  void _log(dynamic msg) {
    if (_enabled) {
      _checkLogsLimit();

      var now = _timeNow();
      var log = '$now  $msg';

      _logs.add(log);
    }

    logger.log(msg);
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
    return document.querySelector('#UIConsole') != null;
  }

  static void hide() {
    return get()!._hide();
  }

  void _hide() {
    var prevConsoleDiv = document.querySelector('#UIConsole');

    if (prevConsoleDiv != null) {
      prevConsoleDiv.remove();
    }
  }

  static void show() {
    return get()!._show();
  }

  HTMLDivElement? _contentClipboard;

  void _show() {
    _enable();

    _hide();

    var consoleDiv = HTMLDivElement();
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

    consoleDiv.appendChild(contentClipboard);

    var allLogs = _allLogs();

    var consoleButtons = HTMLDivElement();

    var buttonClose = HTMLSpanElement()..text = '[X]';
    buttonClose.style.cursor = 'pointer';
    buttonClose.onClick.listen((m) => hide());

    var buttonCopy = HTMLSpanElement()..text = '[Copy All]';
    buttonCopy.style.cursor = 'pointer';
    buttonCopy.onClick.listen((m) => copy());

    var buttonZoomIn = HTMLSpanElement()..text = '[ + ]';
    buttonZoomIn.style.cursor = 'zoom-in';

    var buttonZoomOut = HTMLSpanElement()..text = '[ - ]';
    buttonZoomOut.style.cursor = 'zoom-out';

    var buttonClear = HTMLSpanElement()..text = '[Clear]';
    buttonClear.style.cursor = 'pointer';

    consoleButtons.appendChild(buttonClose);
    consoleButtons.children
        .add(HTMLSpanElement()..innerHTML = '&nbsp;&nbsp;'.toJS);
    consoleButtons.appendChild(buttonCopy);
    consoleButtons.children
        .add(HTMLSpanElement()..innerHTML = '&nbsp;&nbsp;'.toJS);
    consoleButtons.appendChild(buttonZoomIn);
    consoleButtons.children
        .add(HTMLSpanElement()..innerHTML = '&nbsp;&nbsp;'.toJS);
    consoleButtons.appendChild(buttonZoomOut);
    consoleButtons.children
        .add(HTMLSpanElement()..innerHTML = '&nbsp;&nbsp;'.toJS);
    consoleButtons.appendChild(buttonClear);

    var consoleText = HTMLDivElement();
    consoleText.style.fontSize = '$_fontSize%';
    consoleText.style.overflow = 'scroll';

    var html = '<br><pre style="color: #999999;">\n'
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

    consoleDiv.appendChild(consoleButtons);
    consoleDiv.appendChild(consoleText);

    _contentClipboard = contentClipboard;

    document.documentElement!.appendChild(consoleDiv);
  }

  double _fontSize = 100.0;

  void _changeFontSize(HTMLDivElement consoleText, double change) {
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
      _contentClipboard!.innerHTML = '<pre>$allLogs</pre>'.toJS;
      _copyElementToClipboard(_contentClipboard!);
      _contentClipboard!.text = '';
    }
  }

  void _copyElementToClipboard(UIElement elem) {
    var selection = window.getSelection()!;
    var range = document.createRange();

    range.selectNodeContents(elem);
    selection.removeAllRanges();
    selection.addRange(range);

    document.execCommand('copy');

    window.getSelection()!.removeAllRanges();
  }

  static final String buttonId = 'UIConsole_button';

  static HTMLDivElement button([double opacity = 0.20]) {
    enable();

    var elem = createDivInline(html: '[>_]');

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
    var prevElem = document.querySelector('#$buttonId');
    if (prevElem != null) return;

    var elem = button(1.0);

    logger.log('Button: ${elem.clientHeight}');

    elem.style
      ..position = 'fixed'
      ..left = '0px'
      ..top = '100%'
      ..transform = 'translateY(-15px)'
      ..zIndex = '999999';

    document.body!.appendChild(elem);
  }
}
