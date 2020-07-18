import 'dart:async';
import 'dart:html';

import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Component that renders a dialog.
abstract class UIDialogBase extends UIComponent {
  static final rootParent = document.documentElement;

  final bool hideUIRoot;

  UIDialogBase({this.hideUIRoot = false, bool show = false, dynamic classes})
      : super(show ?? false ? rootParent : null,
            classes: 'ui-dialog', classes2: classes) {
    _myConfigure();
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
      ..zIndex = '999999999';

    _callOnShow();
  }

  final String dialogButtonClass = 'ui-dialog-button';

  bool _onClickListenOnlyForDialogButtonClass = false;

  bool get onClickListenOnlyForDialogButtonClass =>
      _onClickListenOnlyForDialogButtonClass;

  set onClickListenOnlyForDialogButtonClass(bool value) {
    _onClickListenOnlyForDialogButtonClass = value ?? false;
  }

  @override
  void posRender() {
    var selectors = _onClickListenOnlyForDialogButtonClass
        ? '.$dialogButtonClass'
        : '.$dialogButtonClass, button';

    var buttons = content.querySelectorAll(selectors);

    if (buttons != null && buttons.isNotEmpty) {
      for (var button in buttons) {
        button.onClick.listen(_callOnDialogButtonClick);
      }
    }
  }

  bool _hideOnDialogButtonClick = true;

  bool get hideOnDialogButtonClick => _hideOnDialogButtonClick;

  set hideOnDialogButtonClick(bool value) {
    _hideOnDialogButtonClick = value ?? true;
  }

  void _callOnDialogButtonClick(MouseEvent event) {
    if (_hideOnDialogButtonClick) {
      var clickedElement = event.target;

      if (clickedElement != null && isCancelButton(clickedElement)) {
        cancel();
      } else {
        hide();
      }
    }

    onDialogButtonClick(event);
  }

  List<String> cancelButtonClasses = ['btn-cancel'];

  bool isCancelButton(Element clickedElement) {
    if (clickedElement == null) return false;

    if (isNotEmptyObject(cancelButtonClasses)) {
      for (var className in cancelButtonClasses) {
        if (clickedElement.classes.contains(className)) {
          return true;
        }

        var elementsWithClass = content.querySelectorAll('.$className');

        for (var elem in elementsWithClass) {
          if (elem == clickedElement || elem.contains(clickedElement)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  void onDialogButtonClick(MouseEvent event) {}

  final EventStream<UIDialog> onHide = EventStream();
  final EventStream<UIDialog> onShow = EventStream();

  void _callOnShow() {
    if (hideUIRoot) {
      var ui = UIRoot.getInstance();
      if (ui != null) ui.hide();
    }

    onShow.add(this);
    onChange.add(this);
  }

  void _callOnHide() {
    if (hideUIRoot) {
      var ui = UIRoot.getInstance();
      if (ui != null) ui.show();
    }

    onHide.add(this);
    onChange.add(this);
  }

  @override
  bool get isShowing {
    return rootParent.contains(content);
  }

  @override
  void show() {
    if (!isShowing) {
      rootParent.children.add(content);
      ensureRendered();
      _callOnShow();
    }
  }

  @override
  void hide() {
    var showing = isShowing;

    content.remove();

    if (showing) {
      _callOnHide();
    }
  }

  bool _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() {
    _canceled = true;
    hide();
  }

  final Map<Completer, StreamSubscription<UIDialog>> _showAndWaitHideListens =
      {};

  Future<bool> showAndWait() async {
    show();

    var completer = Completer<bool>();

    var listen = onHide.listen((event) {
      var listen = _showAndWaitHideListens.remove(completer);
      if (listen != null) {
        listen.cancel();
      }
      completer.complete(!isCanceled);
    });

    _showAndWaitHideListens[completer] = listen;

    return completer.future;
  }
}

class UIDialog extends UIDialogBase {
  dynamic renderContent;

  UIDialog(this.renderContent,
      {bool hideUIRoot = false, bool show = false, dynamic classes})
      : super(hideUIRoot: hideUIRoot, show: show, classes: classes);

  @override
  void configure() {
    super.configure();
    content.style.textAlign = 'center';
  }

  @override
  dynamic render() {
    return $div(
        style: 'text-align: center;'
            'position: absolute;'
            'top: 50%; left: 50%;'
            'transform: translate(-50%, -50%);',
        content: renderContent);
  }
}
