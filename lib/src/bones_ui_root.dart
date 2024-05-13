import 'dart:async';
import 'dart:html';

import 'package:dom_builder/dom_builder_dart_html.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_component.dart';
import 'bones_ui_document.dart';
import 'bones_ui_log.dart';
import 'bones_ui_navigator.dart';
import 'bones_ui_web.dart';
import 'component/button.dart';
import 'component/data_source.dart';
import 'component/dialog.dart';
import 'component/loading.dart';
import 'component/multi_selection.dart';
import 'component/svg.dart';

/// Base class for [UIComponent]s serving as roots for other components.
/// - Implemented by [UIRoot] and [UIDialogBase].
/// - Handles registration of the tree of [UIComponent]s and sub-[UIComponent]s.
abstract class UIRootComponent extends UIComponent {
  UIRootComponent(super.parent,
      {super.componentClass,
      super.componentStyle,
      super.classes,
      super.classes2,
      super.style,
      super.style2,
      super.clearParent,
      super.inline,
      super.construct,
      super.renderOnConstruction,
      super.preserveRender,
      super.id,
      super.generator});

  late DOMTreeReferenceMap<UIComponent> _uiComponentsTree;

  void initializeUIComponentsTree() {
    _uiComponentsTree = DOMTreeReferenceMap(content!,
        keepPurgedKeys: true,
        maxPurgedEntries: 1000,
        purgedEntriesTimeout: Duration(minutes: 1));
  }

  @override
  void registerInUIRoot() {}

  @override
  UIRootComponent get uiRootComponent;

  bool get isAnyComponentRendering => _uiComponentsTree.validEntries
      .where((e) => e.value.isRendering)
      .isNotEmpty;

  UIComponent? getUIComponentByContent(UIElement? uiComponentContent,
      {bool includePurgedEntries = false}) {
    if (uiComponentContent == null) return null;
    if (includePurgedEntries) {
      return _uiComponentsTree.getAlsoFromPurgedEntries(uiComponentContent);
    } else {
      return _uiComponentsTree.get(uiComponentContent);
    }
  }

  UIComponent? getUIComponentByChild(UIElement? child,
      {bool includePurgedEntries = false}) {
    return _uiComponentsTree.getParentValue(child,
        includePurgedEntries: includePurgedEntries);
  }

  List<UIComponent>? getSubUIComponentsByElement(UIElement? element,
      {bool includePurgedEntries = false}) {
    if (element == null ||
        (!_uiComponentsTree.isInTree(element) && !(includePurgedEntries))) {
      return null;
    }
    return _uiComponentsTree.getSubValues(element,
        includePurgedEntries: includePurgedEntries);
  }

  void registerUIComponentInTree(UIComponent uiComponent) {
    _uiComponentsTree.put(uiComponent.content!, uiComponent);
    //print('_uiComponentsTree> $_uiComponentsTree');
  }

  void purgeUIComponentsTree() => _uiComponentsTree.purge();

  /// [EventStream] for when this [UIRoot] finishes to render UI.
  final EventStream<UIRootComponent> onFinishRender = EventStream();

  void notifyFinishRender() {
    onFinishRender.add(this);

    _uiComponentsTree.purge();
    //print('FINISH RENDER> _uiComponentsTree: $_uiComponentsTree');
  }
}

/// The root for `Bones_UI` component tree.
abstract class UIRoot extends UIRootComponent {
  static UIRoot? _rootInstance;

  /// Returns the current [UIRoot] instance.
  static UIRoot? getInstance() {
    return _rootInstance;
  }

  LocalesManager? _localesManager;

  Future<bool>? _futureInitializeLocale;

  Duration readyTimeout;

  final String? name;

  UIRoot(super.rootContainer,
      {this.name,
      dynamic style,
      dynamic classes,
      super.id,
      UIComponentClearParent super.clearParent =
          UIComponentClearParent.onInitialRender,
      this.readyTimeout = const Duration(seconds: 15)})
      : super(
            style: style,
            classes: classes,
            componentClass: 'ui-root',
            construct: false) {
    _initializeAll();

    final componentInternals = this.componentInternals;

    if (componentInternals.getContent() == null) {
      componentInternals.setContent(createContentElement(true));
    }

    initializeUIComponentsTree();

    _rootInstance = this;

    componentInternals.construct(
        false, true, classes, null, 'ui-root', style, null, null, false);

    _localesManager =
        createLocalesManager(_callInitializeLocale, _onDefineLocale);
    _localesManager!.onPreDefineLocale.add(onPreDefineLocale);

    _futureInitializeLocale = _localesManager!.initialize(getPreferredLocale);

    window.onResize.listen(_onResize);

    UIConsole.checkAutoEnable();
  }

  /// Returns `true` if this instance is running from `bones_ui test` CLI.
  bool get isTest => content?.classes.contains('__bones_ui_test__') ?? false;

  /// Returns this [UIRoot] instance.
  @override
  UIRoot get uiRoot => this;

  /// Returns this [UIRoot] instance.
  @override
  UIRootComponent get uiRootComponent => this;

  /// The default loading to render for all [UIComponent] that do not implement [UIComponent.renderLoading].
  @override
  dynamic renderLoading() => null;

  IntlMessageResolver? _intlMessageResolver;

  IntlMessageResolver? get intlMessageResolver => _intlMessageResolver;

  set intlMessageResolver(dynamic resolver) {
    if (resolver is IntlMessages) {
      _intlMessageResolver = resolver.buildMsg;
    } else {
      _intlMessageResolver = toIntlMessageResolver(resolver);
    }
  }

  @override
  void onPreConstruct() {
    UILoading.resolveLoadingElements();
  }

  void _onResize(Event e) {
    try {
      onResize(e);
    } catch (e, s) {
      logger.error('Error calling onResize() for instance: $this', e, s);
    }
  }

  void onResize(Event e) {}

  LocalesManager? getLocalesManager() {
    return _localesManager;
  }

  // ignore: use_function_type_syntax_for_parameters
  SelectElement? buildLanguageSelector(refreshOnChange()) {
    return _localesManager!.buildLanguageSelector(refreshOnChange)
        as SelectElement?;
  }

  Future<bool> _callInitializeLocale(String locale) {
    initializeDateFormatting(locale, null);
    return initializeLocale(locale);
  }

  Future<bool> initializeLocale(String locale) {
    return Future.value(false);
  }

  String? getPreferredLocale() {
    return _localesManager!.getPreferredLocale();
  }

  static String? getCurrentLocale() {
    return Intl.defaultLocale;
  }

  /// [EventStream] for when [setPreferredLocale] is successfully called.
  final EventStream<UIRoot> onChangeLocale = EventStream();

  Future<bool> setPreferredLocale(String locale) {
    return _localesManager!.setPreferredLocale(locale).then((ok) {
      onChangeLocale.add(this);
      return ok;
    });
  }

  Future<bool> initializeAllLocales() {
    return _localesManager!.initializeAllLocales();
  }

  List<String> getInitializedLocales() {
    return _localesManager!.getInitializedLocales();
  }

  Future<bool> onPreDefineLocale(String locale) => Future.value(false);

  void _onDefineLocale(String locale) {
    UIConsole.log('UIRoot> Locale defined: $locale');
    refreshIfLocaleChanged();
  }

  @override
  List render() {
    if (isClosed) {
      return [renderClosed()];
    }

    var menu = renderMenu();
    var content = renderContent();
    var footer = renderFooter();

    return [
      if (menu != null) menu,
      if (content != null) content,
      if (footer != null) footer,
    ];
  }

  Future<bool>? isReady() {
    return null;
  }

  void initialize() {
    var ready = isReady();

    if (_futureInitializeLocale != null) {
      if (ready == null) {
        ready = _futureInitializeLocale;
      } else {
        ready = ready.then((ok) {
          return _futureInitializeLocale!;
        });
      }
    }

    _initializeImpl(ready);
  }

  void _initializeImpl([Future<bool>? ready]) {
    if (ready == null) {
      _onReadyToInitialize();
    } else {
      ready.then((_) {
        _onReadyToInitialize();
      }, onError: (e) {
        _onReadyToInitialize();
      }).timeout(readyTimeout, onTimeout: () {
        _onReadyToInitialize();
      });
    }
  }

  /// [EventStream] for when this [UIRoot] is initialized.
  final EventStream<UIRoot> onInitialize = EventStream();

  void _onReadyToInitialize() {
    UIConsole.log('UIRoot> ready to initialize!');

    onInitialized();

    _initialRender();
    callRender();

    try {
      onInitialize.add(this);
    } catch (e) {
      UIConsole.error('Error calling UIRoot.onInitialize()', e);
    }

    UINavigator.get().refreshNavigationAsync();
  }

  @override
  void callRender([bool clear = false]) {
    UIConsole.log('UIRoot> rendering...');
    super.callRender(clear);
  }

  void onInitialized() {}

  void _initialRender() {
    buildAppStatusBar();
  }

  /// Called to render App status bar.
  void buildAppStatusBar() {}

  /// Called to render the UI menu.
  UIComponent? renderMenu() => null;

  /// Called to render the UI content.
  UIComponent? renderContent();

  /// Called to render the UI footer.
  UIComponent? renderFooter() => null;

  static void alert(dynamic dialogContent) {
    getInstance()!.renderAlert(dialogContent);
  }

  void renderAlert(dynamic dialogContent) {
    var div = $div(
        classes: 'ui-root-alert bg-blur',
        style:
            'color: #fff; background-color: rgba(255,255,255,0.20); margin: 12px 24px; padding: 14px; border-radius: 8px;',
        content: dialogContent);
    UIDialog($div(content: [$br(), div]), showCloseButton: true, show: true);
  }

  /// Called to render the UI when it's closed.
  /// - See [isClosed] and [close].
  /// - If you implement this method do not remove [content] from parent when closing this [UIRoot].
  UIElement? renderClosed() => null;

  /// [EventStream] for when this [UIRoot] is closed.
  final EventStream<UIRoot> onClose = EventStream();

  bool _closed = false;

  /// Returns `true` if this [UIRoot] is closed.
  ///
  /// - See [close] and [closeOperations].
  bool get isClosed => _closed;

  FutureOr<bool> close({bool refreshAfterClose = true}) {
    if (_closed) return false;
    _closed = true;

    var ret = closeOperations();

    if (ret is Future<bool>) {
      return ret.then((value) {
        if (refreshAfterClose) {
          refresh(forceRender: true);
        }
        UIConsole.log('UIRoot> closed!');
        onClose.add(this);
        return true;
      });
    } else {
      if (refreshAfterClose) {
        refresh(forceRender: true);
      }
      UIConsole.log('UIRoot> closed!');
      onClose.add(this);
      return true;
    }
  }

  /// Customizable close operations.
  ///
  /// - By default it calls [clear]: `clear(force: true)`.
  /// - Do not remove [content] from parent if you implement [renderClosed].
  FutureOr<bool> closeOperations() {
    clear(force: true);
    return true;
  }
}

bool _initializedAll = false;

void _initializeAll() {
  if (_initializedAll) return;
  _initializedAll = true;

  _configure();

  _registerAllComponents();
}

void _configure() {
  Dimension.parsers.add((v) {
    return v is Screen ? Dimension(v.width!, v.height!) : null;
  });
}

void _registerAllComponents() {
  UIConsole.get();
  UIButton.register();
  UIButtonLoader.register();
  UIMultiSelection.register();
  UIDataSource.register();
  UIDocument.register();
  UIDialog.register();
  UISVG.register();
}
