import 'dart:async';
import 'dart:html';

import 'package:bones_ui/bones_ui_kit.dart';
import 'package:bones_ui/src/bones_ui_base.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Component that renders a dialog.
abstract class UIDialogBase extends UIComponent {
  static final rootParent = document.documentElement;

  final bool hideUIRoot;
  final int backgroundGrey;
  final double backgroundAlpha;
  final int backgroundBlur;
  final bool fullScreen;

  final String padding;

  UIDialogBase(
      {this.hideUIRoot = false,
      bool show = false,
      bool addToParent = false,
      dynamic classes,
      dynamic style,
      String padding,
      bool fullScreen,
      int backgroundGrey,
      double backgroundAlpha,
      this.backgroundBlur})
      : padding = padding ?? '6px',
        fullScreen = fullScreen ?? true,
        backgroundGrey = clipNumber(backgroundGrey, 0, 255) ?? 0,
        backgroundAlpha = clipNumber(backgroundAlpha, 0.0, 1.0) ?? 0.80,
        super(addToParent ?? show ?? false ? rootParent : null,
            componentClass: 'ui-dialog', classes: classes) {
    _myConfigure(style);
  }

  void _myConfigure(dynamic style) {
    content.style
      ..position = 'fixed'
      ..float = 'top'
      ..clear = 'both'
      ..padding = padding
      ..color = '#ffffff'
      ..backgroundColor =
          'rgba($backgroundGrey,$backgroundGrey,$backgroundGrey, $backgroundAlpha)'
      ..zIndex = '999999999';

    if (fullScreen) {
      content.style
        ..width = '100%'
        ..height = '100%'
        ..left = '0px'
        ..top = '0px';
    } else {
      content.style
        ..left = '50%'
        ..top = '50%'
        ..transform = 'translate(-50%, -50%)';
    }

    if (backgroundBlur != null && backgroundBlur > 0) {
      setElementBackgroundBlur(content, backgroundBlur);
    }

    configureStyle(style);

    _callOnShow();
  }

  static final String dialogButtonClass = 'ui-dialog-button';
  static final String dialogButtonCancelClass = 'ui-dialog-button-cancel';

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

  bool _onlyHideOnCancelButton = false;

  bool get onlyHideOnCancelButton => _onlyHideOnCancelButton;

  set onlyHideOnCancelButton(bool value) {
    _onlyHideOnCancelButton = value ?? false;
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
        if (!_onlyHideOnCancelButton) {
          hide();
        }
      }
    }

    onDialogButtonClick(event);
  }

  final List<String> _cancelButtonClasses = ['btn-cancel'];

  List<String> get cancelButtonClasses => _cancelButtonClasses;

  bool isCancelButton(Element clickedElement) {
    if (clickedElement == null) return false;

    if (_isElementOfClass(clickedElement, dialogButtonCancelClass)) {
      return true;
    }

    if (isNotEmptyObject(cancelButtonClasses)) {
      for (var className in cancelButtonClasses) {
        if (_isElementOfClass(clickedElement, className)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isElementOfClass(Element element, String className) {
    if (element.classes.contains(className)) {
      return true;
    }

    var elementsWithClass = content.querySelectorAll('.$className');

    for (var elem in elementsWithClass) {
      if (elem == element || elem.contains(element)) {
        return true;
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
    return rootParent.contains(content) &&
        !content.hidden &&
        content.style.display != 'none' &&
        content.style.visibility != 'hidden';
  }

  String _styleDisplayPrevValue;

  String _styleVisibilityPrevValue;

  @override
  void show() {
    if (!isShowing) {
      var parent = this.parent ?? rootParent;

      if (!isInDOM(parent)) {
        rootParent.append(parent);
      }

      if (!parent.contains(content)) {
        parent.append(content);
      }

      if (content.hidden) {
        content.hidden = false;
      }

      if (content.style.display == 'none') {
        content.style.display = _styleDisplayPrevValue ?? '';
      }

      if (content.style.visibility == 'hidden') {
        content.style.visibility = _styleVisibilityPrevValue ?? '';
      }

      ensureRendered();
      _callOnShow();
    }
  }

  @override
  void hide() {
    var showing = isShowing;

    content.hidden = true;

    if (content.style.display != 'none') {
      _styleDisplayPrevValue = content.style.display;
      content.style.display = 'none';
    }

    if (content.style.visibility != 'hidden') {
      _styleVisibilityPrevValue = content.style.visibility;
      content.style.visibility = 'hidden';
    }

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

  final Map<Completer, StreamSubscription<UIDialog>> _showAndWaitHideListeners =
      {};

  Future<bool> showAndWait() async {
    show();

    var completer = Completer<bool>();

    var listen = onHide.listen((event) {
      var listen = _showAndWaitHideListeners.remove(completer);
      if (listen != null) {
        listen.cancel();
      }
      completer.complete(!isCanceled);
    });

    _showAndWaitHideListeners[completer] = listen;

    return completer.future;
  }
}

class UIDialog extends UIDialogBase {
  static final UIComponentGenerator<UIDialog> GENERATOR =
      UIComponentGenerator<UIDialog>('ui-dialog', 'div', 'ui-dialog', '',
          (parent, attributes, contentHolder, contentNodes) {
    var show = parseBool(attributes['show'], false);
    var showCloseButton = parseBool(attributes['show-close-button'], true);

    return UIDialog(contentNodes,
        show: show, showCloseButton: showCloseButton, addToParent: true);
  }, [], hasChildrenElements: false);

  static void register() {
    UIComponent.registerGenerator(GENERATOR);
  }

  dynamic renderContent;

  UIDialog(this.renderContent,
      {bool hideUIRoot = false,
      bool show = false,
      bool addToParent = false,
      bool showCloseButton = false,
      dynamic classes,
      dynamic style,
      String padding,
      bool fullScreen,
      int backgroundGrey,
      double backgroundAlpha,
      int backgroundBlur})
      : super(
            hideUIRoot: hideUIRoot,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur) {
    this.showCloseButton = showCloseButton;
    if (show ?? false) {
      this.show();
    } else {
      hide();
    }
  }

  @override
  void configure() {
    super.configure();

    content.style.display = 'none';
    content.style.textAlign = 'center';
  }

  bool _showCloseButton = false;

  bool get showCloseButton => _showCloseButton;

  set showCloseButton(bool value) {
    _showCloseButton = value ?? false;
  }

  @override
  dynamic render() {
    var closeButton = showCloseButton ? renderCloseButton() : null;

    if (fullScreen) {
      return $div(
          style:
              'text-align: center; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);',
          content: [closeButton, renderContent]);
    } else {
      return $div(
          style: 'text-align: center;', content: [closeButton, renderContent]);
    }
  }

  dynamic renderCloseButton() {
    var color = content.style.color;

    if (isEmptyString(color, trim: true)) {
      color = content.getComputedStyle().color;
    }

    if (isEmptyString(color, trim: true)) {
      color = '#000';
    }

    var shadowColor = CSSColor.from(color).inverse.toString();

    return $button(
        classes: [
          UIDialogBase.dialogButtonClass,
          UIDialogBase.dialogButtonCancelClass
        ],
        style:
            'background-color: transparent; border: none; padding: 4px; float: right; font-size: 1.5rem; font-weight: 700; line-height: 1; color: $color; text-shadow: 0 1px 0 $shadowColor; opacity: 0.7;',
        content: '<span>&times;</span>');
  }
}

class UIDialogInput extends UIDialog {
  static final String DIALOG_INPUT_FIELD = 'dialog-input';

  static DIVElement _buildContent(
      String label,
      String buttonLabel,
      String buttonClasses,
      String buttonCancelLabel,
      String buttonCancelClasses,
      String inputType,
      String inputPlaceholder,
      String inputClasses,
      String inputStyle,
      String value) {
    inputType ??= 'text';

    var div = $div(content: [
      $label(content: '$label: &nbsp;'),
      $input(
          type: inputType,
          placeholder: inputPlaceholder,
          classes: inputClasses,
          style: inputStyle,
          attributes: {'field': DIALOG_INPUT_FIELD},
          value: value),
      $nbsp(2),
      $button(
          classes: [UIDialogBase.dialogButtonClass, buttonClasses],
          content: buttonLabel),
      if (isNotEmptyString(buttonCancelLabel)) $nbsp(),
      if (isNotEmptyString(buttonCancelLabel))
        $button(classes: [
          UIDialogBase.dialogButtonClass,
          UIDialogBase.dialogButtonCancelClass,
          buttonCancelClasses
        ], content: buttonCancelLabel)
    ]);

    return div;
  }

  UIDialogInput(String label, String buttonLabel,
      {String buttonClasses,
      String buttonCancelLabel,
      String buttonCancelClasses,
      String inputType,
      String inputPlaceholder,
      String inputClasses,
      String inputStyle,
      String value,
      bool hideUIRoot = false,
      bool showCloseButton = false,
      dynamic classes,
      dynamic style,
      String padding,
      bool fullScreen = false,
      int backgroundGrey,
      double backgroundAlpha,
      int backgroundBlur})
      : super(
            _buildContent(
                label,
                buttonLabel,
                buttonClasses,
                buttonCancelLabel,
                buttonCancelClasses,
                inputType,
                inputPlaceholder,
                inputClasses,
                inputStyle,
                value),
            hideUIRoot: hideUIRoot,
            showCloseButton: showCloseButton,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen ?? false,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur);

  Future<String> ask() async {
    var ok = await showAndWait();
    if (!ok) return null;
    var value = getField(DIALOG_INPUT_FIELD);
    return value;
  }
}

class UIDialogAlert extends UIDialog {
  static DIVElement _buildContent(
      String text, String buttonLabel, String buttonClasses) {
    var div = $div(content: [
      $label(content: text),
      $br(),
      $button(classes: buttonClasses, content: buttonLabel)
    ]);

    return div;
  }

  UIDialogAlert(String text, String buttonLabel,
      {String buttonClasses,
      bool hideUIRoot = false,
      bool showCloseButton = false,
      dynamic classes,
      dynamic style,
      String padding,
      bool fullScreen = false,
      int backgroundGrey,
      double backgroundAlpha,
      int backgroundBlur})
      : super(_buildContent(text, buttonLabel, buttonClasses),
            hideUIRoot: hideUIRoot,
            showCloseButton: showCloseButton,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen ?? false,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur);
}

class UIDialogLoading extends UIDialog {
  static DIVElement _buildContent(UILoadingType loadingType, String text) {
    var div = $div(content: [
      $span(content: text),
      $br(),
      UILoading.asDIVElement(loadingType)
    ]);

    return div;
  }

  UIDialogLoading(String text, UILoadingType loadingType,
      {bool hideUIRoot = false,
      bool showCloseButton = false,
      bool show = false,
      dynamic classes,
      dynamic style,
      String padding,
      bool fullScreen = false,
      int backgroundGrey,
      double backgroundAlpha,
      int backgroundBlur})
      : super(_buildContent(loadingType, text),
            hideUIRoot: hideUIRoot,
            showCloseButton: showCloseButton,
            show: show,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen ?? false,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur);
}
