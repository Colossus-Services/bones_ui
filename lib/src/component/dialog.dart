import 'dart:async';
import 'package:web_utils/web_utils.dart';

import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_component.dart';
import '../bones_ui_generator.dart';
import '../bones_ui_root.dart';
import 'loading.dart';

/// Component that renders a dialog.
abstract class UIDialogBase extends UIRootComponent {
  static final rootParent = document.body;

  final bool hideUIRoot;
  final int backgroundGrey;
  final double backgroundAlpha;
  final int? backgroundBlur;
  final bool fullScreen;
  final bool removeFromDomOnHide;

  final String padding;

  UIDialogBase(
      {super.id,
      super.classes,
      super.renderOnConstruction,
      this.hideUIRoot = false,
      bool show = false,
      bool? addToParent,
      dynamic style,
      this.padding = '6px',
      this.fullScreen = true,
      this.removeFromDomOnHide = true,
      this.onClickListenOnlyForDialogButtonClass = false,
      int backgroundGrey = 0,
      double backgroundAlpha = 0.80,
      this.backgroundBlur})
      : backgroundGrey = clipNumber(backgroundGrey, 0, 255)!,
        backgroundAlpha = clipNumber(backgroundAlpha, 0.0, 1.0)!,
        super(
          (addToParent ?? show) ? rootParent : null,
          componentClass: 'ui-dialog',
        ) {
    _myConfigure(style);

    initializeUIComponentsTree();
  }

  @override
  UIRoot? get uiRoot => null;

  @override
  UIRootComponent get uiRootComponent => this;

  void _myConfigure(dynamic style) {
    content!.style
      ..position = 'fixed'
      ..float = 'top'
      ..clear = 'both'
      ..padding = padding
      ..color = '#ffffff'
      ..backgroundColor =
          'rgba($backgroundGrey,$backgroundGrey,$backgroundGrey, $backgroundAlpha)'
      ..zIndex = '999999999';

    if (fullScreen) {
      content!.style
        ..width = '100%'
        ..height = '100%'
        ..left = '0px'
        ..top = '0px';
    } else {
      content!.style
        ..left = '50%'
        ..top = '50%'
        ..transform = 'translate(-50%, -50%)';
    }

    if (backgroundBlur != null && backgroundBlur! > 0) {
      setElementBackgroundBlur(content!, backgroundBlur);
    }

    configureStyle(style);

    _callOnShow();
  }

  static final String dialogButtonClass = 'ui-dialog-button';
  static final String dialogButtonCancelClass = 'ui-dialog-button-cancel';

  bool onClickListenOnlyForDialogButtonClass;

  @override
  void preRender() {
    _configuredButtons = {};
  }

  @override
  void posRender() {
    configureButtons();
  }

  @override
  void posAsyncRender() {
    configureButtons();
  }

  Set<Element> _configuredButtons = {};

  void configureButtons() {
    var buttons = selectDialogButtons();

    for (var button in buttons) {
      if (_configuredButtons.add(button)) {
        button.onClick.listen((event) {
          // Call it asynchronously to allow custom listeners to be called 1st.
          Future.delayed(Duration(milliseconds: 40),
              () => _callOnDialogButtonClick(event));
        });
      }
    }
  }

  List<Element> selectDialogButtons() {
    var selectors = onClickListenOnlyForDialogButtonClass
        ? '.$dialogButtonClass'
        : '.$dialogButtonClass, button';

    var sel = content!.querySelectorAll(selectors);
    var buttons = sel.whereElement().where(isDialogButton).toList();
    return buttons;
  }

  bool isDialogButton(Element element) => true;

  bool onlyHideOnCancelButton = false;

  bool hideOnDialogButtonClick = true;

  bool removeOnDialogButtonClick = false;

  void _callOnDialogButtonClick(MouseEvent event) {
    if (hideOnDialogButtonClick) {
      var clickedElement = event.target;
      if (clickedElement != null && isCancelButton(clickedElement as Element)) {
        cancel();
      } else {
        if (!onlyHideOnCancelButton) {
          hide();
        }
      }
    }

    if (removeOnDialogButtonClick) {
      content!.remove();
    }

    onDialogButtonClick(event);
  }

  final List<String> _cancelButtonClasses = ['btn-cancel'];

  List<String> get cancelButtonClasses => _cancelButtonClasses;

  bool isCancelButton(Element clickedElement) {
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
    if (element.classList.contains(className)) {
      return true;
    }

    var elementsWithClass = content!.querySelectorAll('.$className');

    for (var elem in elementsWithClass.toIterable()) {
      if (elem == element || elem.contains(element)) {
        return true;
      }
    }

    return false;
  }

  void onDialogButtonClick(MouseEvent event) {}

  final EventStream<UIDialogBase> onHide = EventStream();
  final EventStream<UIDialogBase> onShow = EventStream();

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

    if (removeFromDomOnHide) {
      content?.remove();
    }
  }

  @override
  bool get isShowing {
    final rootParent = UIDialogBase.rootParent;
    final content = this.content;
    return rootParent != null &&
        content != null &&
        rootParent.contains(content) &&
        !content.isHidden &&
        content.style.display != 'none' &&
        content.style.visibility != 'hidden';
  }

  String? _styleDisplayPrevValue;

  String? _styleVisibilityPrevValue;

  @override
  void show() {
    if (!isShowing) {
      var parent = this.parent ?? rootParent!;

      if (!isInDOM(parent)) {
        rootParent!.append(parent);
      }

      final content = this.content;
      if (!parent.contains(content)) {
        parent.append(content!);
      }

      if (content!.isHidden) {
        content.hidden = null;
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

    content!.hidden = true.toJS;

    if (content!.style.display != 'none') {
      _styleDisplayPrevValue = content!.style.display;
      content!.style.display = 'none';
    }

    if (content!.style.visibility != 'hidden') {
      _styleVisibilityPrevValue = content!.style.visibility;
      content!.style.visibility = 'hidden';
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

  final Map<Completer, StreamSubscription<UIDialogBase>>
      _showAndWaitHideListeners = {};

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

/// [DOMElement] tag `ui-dialog` for [UIDialog].
DOMElement $uiDialog({
  id,
  String? field,
  classes,
  style,
  bool? show,
  bool? showCloseButton,
  Map<String, String>? attributes,
  content,
  bool commented = false,
}) {
  return $tag(
    'ui-button-loader',
    id: id,
    classes: classes,
    style: style,
    attributes: {
      if (field != null && field.isNotEmpty) 'field': field,
      if (show != null) 'show': '$show',
      if (showCloseButton != null) 'show-close-button': '$showCloseButton',
      ...?attributes
    },
    content: content,
    commented: commented,
  );
}

class UIDialog extends UIDialogBase {
  /// Returns all the `.ui-dialog` as [UIDialogBase].
  static List<UIDialogBase> getAllDialogs() {
    var dialogs = window.document.querySelectorAll('.ui-dialog');

    return dialogs
        .whereElement()
        .map(UIComponent.getContentUIComponent)
        .whereType<UIDialogBase>()
        .toList();
  }

  /// Removes and clears all the `.ui-dialog` [Element]s.
  static void removeAllDialogs() {
    var dialogs = window.document.querySelectorAll('.ui-dialog');

    for (var d in dialogs.whereElement()) {
      var component = UIComponent.getContentUIComponent(d);
      if (component is UIDialogBase) {
        component.hide();
      }

      component?.clear();

      d.remove();
    }
  }

  static final UIComponentGenerator<UIDialog> generator =
      UIComponentGenerator<UIDialog>('ui-dialog', 'div', 'ui-dialog', '',
          (parent, attributes, contentHolder, contentNodes) {
    var show = parseBool(attributes['show'], false)!;
    var showCloseButton = parseBool(attributes['show-close-button'], true)!;
    var removeOnHide = parseBool(attributes['remove-on-hide'], true)!;
    var onClickListenOnlyForDialogButtonClass = parseBool(
        attributes['on-click-listen-only-for-dialog-button-class'], true)!;

    return UIDialog(contentNodes,
        show: show,
        showCloseButton: showCloseButton,
        addToParent: true,
        removeFromDomOnHide: removeOnHide,
        onClickListenOnlyForDialogButtonClass:
            onClickListenOnlyForDialogButtonClass);
  }, [], hasChildrenElements: false);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  final bool autoScrollY;
  final bool autoScrollX;

  final bool blockScrollTraversing;

  dynamic dialogContent;

  UIDialog(this.dialogContent,
      {super.id,
      super.hideUIRoot,
      bool show = false,
      bool addToParent = false,
      this.showCloseButton = false,
      super.classes,
      super.style,
      super.padding,
      super.fullScreen,
      super.removeFromDomOnHide,
      super.onClickListenOnlyForDialogButtonClass,
      super.backgroundGrey,
      super.backgroundAlpha,
      super.backgroundBlur,
      this.autoScrollY = true,
      this.autoScrollX = true,
      this.blockScrollTraversing = false})
      : super() {
    if (show) {
      this.show();
    } else {
      hide();
    }
  }

  @override
  void configure() {
    super.configure();

    var content = this.content!;

    content.style.display = 'none';
    content.style.textAlign = 'center';

    if (blockScrollTraversing) {
      blockScrollTraverse(content);
    }
  }

  bool showCloseButton = false;

  @override
  dynamic render() {
    var closeButton = showCloseButton ? renderCloseButton() : null;

    var cssAutoScrollY = autoScrollY ? ' overflow-y: auto;' : '';
    var cssAutoScrollX = autoScrollX ? ' overflow-x: auto;' : '';
    var cssAutoScroll = '$cssAutoScrollY$cssAutoScrollX';

    if (fullScreen) {
      return $div(
          style:
              'text-align: center; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); max-height: calc(100vh - 8px); max-width: calc(100vw - 8px);$cssAutoScroll',
          content: [closeButton, renderContent()]);
    } else {
      return $div(
          style: 'text-align: center;$cssAutoScroll',
          content: [closeButton, renderContent()]);
    }
  }

  dynamic renderContent() {
    var dialogContent = this.dialogContent;
    if (dialogContent == null) return;

    if (dialogContent is Function()) {
      return dialogContent();
    } else {
      return dialogContent;
    }
  }

  dynamic renderCloseButton() {
    var color = content!.style.color;

    if (isEmptyString(color, trim: true)) {
      color = content!.getComputedStyle().color;
    }

    if (isEmptyString(color, trim: true)) {
      color = '#000';
    }

    var shadowColor = CSSColor.from(color)!.inverse.toString();

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
  static final String dialogInputField = 'dialog-input';

  static DIVElement _buildContent(
      String label,
      String buttonLabel,
      String? buttonClasses,
      String? buttonCancelLabel,
      String? buttonCancelClasses,
      String? inputType,
      String? inputPlaceholder,
      String? inputClasses,
      String? inputStyle,
      String? value) {
    inputType ??= 'text';

    var div = $div(content: [
      $label(content: '$label: &nbsp;'),
      $input(
          type: inputType,
          placeholder: inputPlaceholder,
          classes: inputClasses,
          style: inputStyle,
          attributes: {'field': dialogInputField},
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
      {String? buttonClasses,
      String? buttonCancelLabel,
      String? buttonCancelClasses,
      String? inputType,
      String? inputPlaceholder,
      String? inputClasses,
      String? inputStyle,
      String? value,
      bool hideUIRoot = false,
      bool showCloseButton = false,
      dynamic classes,
      dynamic style,
      String padding = '6px',
      bool fullScreen = false,
      int backgroundGrey = 0,
      double backgroundAlpha = 0.80,
      int? backgroundBlur})
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
            fullScreen: fullScreen,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur);

  Future<String?> ask() async {
    var ok = await showAndWait();
    if (!ok) return null;
    var value = getField(dialogInputField);
    return value;
  }
}

class UIDialogAlert extends UIDialog {
  static DIVElement _buildContent(
      String text, String buttonLabel, String? buttonClasses) {
    var div = $div(content: [
      $label(content: text),
      $br(),
      $button(classes: buttonClasses, content: buttonLabel)
    ]);

    return div;
  }

  UIDialogAlert(String text, String buttonLabel,
      {String? buttonClasses,
      bool hideUIRoot = false,
      bool showCloseButton = false,
      dynamic classes,
      dynamic style,
      String padding = '6px',
      bool fullScreen = false,
      int backgroundGrey = 0,
      double backgroundAlpha = 0.80,
      int? backgroundBlur})
      : super(_buildContent(text, buttonLabel, buttonClasses),
            hideUIRoot: hideUIRoot,
            showCloseButton: showCloseButton,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen,
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
      String padding = '6px',
      bool fullScreen = false,
      int backgroundGrey = 0,
      double backgroundAlpha = 0.80,
      int? backgroundBlur})
      : super(_buildContent(loadingType, text),
            hideUIRoot: hideUIRoot,
            showCloseButton: showCloseButton,
            show: show,
            classes: classes,
            style: style,
            padding: padding,
            fullScreen: fullScreen,
            backgroundGrey: backgroundGrey,
            backgroundAlpha: backgroundAlpha,
            backgroundBlur: backgroundBlur);
}
