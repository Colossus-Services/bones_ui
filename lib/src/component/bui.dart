import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bones_ui/bones_ui.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:dynamic_call/dynamic_call.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:yaml/yaml.dart';

class BUIElementGenerator extends ElementGeneratorBase {
  @override
  final String tag = 'bui';

  @override
  DivElement generate(
      DOMGenerator<Node> domGenerator,
      DOMTreeMap<Node> treeMap,
      String? tag,
      DOMElement? domParent,
      Node? parent,
      DOMNode domNode,
      Map<String, DOMAttribute> attributes,
      Node? contentHolder,
      List<DOMNode>? contentNodes,
      DOMContext<Node>? context) {
    var buiElement = DivElement();

    setElementAttributes(buiElement, attributes);

    buiElement.nodes.addAll(contentHolder!.nodes);

    return buiElement;
  }

  @override
  bool isGeneratedElement(Node element) {
    return element is DivElement && element.classes.contains(tag);
  }

  @override
  DOMElement? revert(DOMGenerator domGenerator, DOMTreeMap? treeMap,
      DOMElement? domParent, Node? parent, Node? node) {
    if (node is DivElement) {
      var bui =
          $tag(tag, classes: node.classes.join(' '), style: node.style.cssText);

      if (treeMap != null) {
        var mappedDOMNode = treeMap.getMappedDOMNode(node);
        if (mappedDOMNode != null) {
          bui.add(mappedDOMNode.content);
        }
      } else {
        bui.add(node.text);
      }

      return bui;
    } else {
      return null;
    }
  }
}

class BUIRender extends UINavigableComponent {
  final DOMGenerator<Node> renderDomGenerator;
  final DataAssets? _dataAssets;

  BUIRenderSource? _navbarSource;
  BUIRenderSource? _renderSource;

  final EventStream<BUIRender> onChangeSource = EventStream();

  BUIRender(Element? parent,
      {dynamic source,
      DOMGenerator<Node>? domGenerator,
      DataAssets? dataAssets,
      BUIViewProviderBase? viewProvider,
      dynamic classes,
      dynamic style,
      bool renderOnConstruction = true})
      : renderDomGenerator =
            domGenerator ?? DOMGeneratorDelegate(UIComponent.domGenerator),
        _dataAssets = dataAssets,
        _viewProvider = viewProvider,
        super(parent, ['*'],
            componentClass: 'ui-render',
            classes: classes,
            style: style,
            renderOnConstruction: false) {
    _navbarSource = BUIRenderSource(
        renderDomGenerator, () => renderContainer, notifySourceChange, refresh);
    _renderSource = BUIRenderSource(
        renderDomGenerator, () => renderContainer, notifySourceChange, refresh);

    _renderSource!.onIntlLoad.listen(_onIntlLoad);
    _navbarSource!.onIntlLoad.listen(_onIntlLoad);

    _renderSource!.source = source;

    renderDomGenerator.sourceResolver =
        _sourceResolver as String Function(String)?;

    renderDomGenerator.domContext ??= DOMContext(resolveCSSURL: true);

    var domContext = renderDomGenerator.domContext!;

    domContext.resolveCSSURL = true;
    domContext.cssURLResolver ??= _cssURLResolver as String Function(String?)?;
    domContext.namedElementProvider ??= _namedElementProvider;

    updateSourcesFromViewProvider();

    if (renderOnConstruction) {
      if (!hasIntlMessages) {
        callRender();
      } else {
        ensureIntlMessagesLoaded().then((value) {
          refreshInternal();
        });
      }
    }
  }

  void _onIntlLoad(BUIRenderSource renderSource) {
    if (isIntlLoaded) {
      if (isRendered) {
        refreshInternal();
      }
    }
  }

  bool get hasIntlMessages {
    var navIntl = _navbarSource?.hasIntlPath ?? false;
    var renderIntl = _renderSource!.hasIntlPath;
    return navIntl || renderIntl;
  }

  bool get isIntlLoaded {
    var navOk = _navbarSource == null ||
        !_navbarSource!.hasIntlPath ||
        _navbarSource!.isIntlLoaded;
    var renderOk = _renderSource == null ||
        !_renderSource!.hasIntlPath ||
        _renderSource!.isIntlLoaded;
    return navOk && renderOk;
  }

  Future<bool> ensureIntlMessagesLoaded() async {
    Future<bool>? navFuture;
    if (_navbarSource?.hasIntlPath ?? false) {
      navFuture = _navbarSource!.ensureIntlMessagesLoaded();
    }

    Future<bool?>? renderFuture;
    if (_renderSource?.hasIntlPath ?? false) {
      renderFuture = _renderSource!.ensureIntlMessagesLoaded();
    }

    var navLoaded = navFuture != null ? await navFuture : true;
    var renderLoaded = renderFuture != null ? await renderFuture : true;

    return navLoaded && renderLoaded!;
  }

  final EventStream<UIComponent> onRenderChildComponent = EventStream();

  @override
  void onChildRendered(UIComponent child) {
    onRenderChildComponent.add(child);
  }

  @override
  bool updateRoutes([List<String>? foundRoutes]) {
    if (viewProvider != null) {
      var routes = _viewProvider!.routes;
      setRoutes(routes);
      return true;
    }
    return false;
  }

  @override
  String? getRouteName(String route) {
    return viewProvider?.getView(route)?.name;
  }

  @override
  bool isRouteHiddenFromMenu(String route) {
    return viewProvider?.getView(route)?.isHideFromMenu ?? false;
  }

  @override
  String? get currentRoute =>
      super.currentRoute ??
      (_viewProvider != null
          ? (_viewProvider!.currentRoute ?? _viewProvider!.getMainView()!.route)
          : UINavigator.currentRoute);

  void setCurrentRoute(String? route) {
    if (_viewProvider != null) {
      if (isEmptyString(route)) {
        var mainView = _viewProvider!.getMainView();
        if (mainView != null) {
          route = mainView.route;
        }
      }

      _viewProvider!.currentRoute = route;
    }
  }

  DataAssets? get dataAssets => _dataAssets ?? viewProvider?.dataAssets;

  String? _sourceResolver(String url) => assetPathResolver(dataAssets, url);

  String? _cssURLResolver(String? url) => assetPathResolver(dataAssets, url);

  static String? assetPathResolver(DataAssets? dataAssets, String? url) {
    if (dataAssets == null) return url;
    if (isEmptyObject(url)) return url;

    if (url!.startsWith('assets/') ||
        url.startsWith('./assets/') ||
        url.startsWith('/assets/')) {
      var idx = url.indexOf('assets/');
      assert(idx >= 0);
      var fileName = url.substring(idx + 7);
      var assetURL = dataAssets.getURL(fileName);
      if (assetURL != null) {
        return assetURL;
      }
    }

    return url;
  }

  BUIRenderSource? get navbarSource => _navbarSource;

  BUIRenderSource? get renderSource => _renderSource;

  void updateSourceFromDOMTreeMap() {
    var root = renderedTreeMap?.rootDOMNode;
    if (root != null) {
      var html = root.buildHTML(withIndent: true);
      renderSource!.source = html;
    }
  }

  void notifySourceChange() {
    onChangeSource.add(this);
  }

  dynamic get navbar => _navbarSource!.source;

  set navbar(dynamic navbarSource) => _navbarSource!.source = navbarSource;

  dynamic get source => _renderSource!.source;

  set source(dynamic source) => _renderSource!.source = source;

  DOMTreeMap? _renderedTreeMap;

  DOMTreeMap? get renderedTreeMap => _renderedTreeMap;

  DOMNode? getMappedDOMNodeInTreeMap(dynamic element) {
    return _renderedTreeMap != null
        ? _renderedTreeMap!.getMappedDOMNode(element)
        : null;
  }

  bool rebuildSourceFromDOMTreeMap(
      {bool withIndent = false, String indent = '  '}) {
    if (_renderedTreeMap == null) return false;
    var rebuiltSource = _renderedTreeMap!.rootDOMNode!
        .buildHTML(withIndent: withIndent, indent: indent);
    source = rebuiltSource;
    return true;
  }

  Element? _renderedRoot;

  Element? get renderedRoot => _renderedRoot;

  Element? renderContainer;

  DivElement? get renderViewportElement => content as DivElement?;

  @override
  void preRenderClear() {}

  @override
  bool canHandleNewRoute(String route) {
    if (_viewProvider != null) {
      if (isEmptyString(route)) {
        return _viewProvider!.getMainView() != null;
      } else {
        return _viewProvider!.containsView(route);
      }
    }
    return super.canHandleNewRoute(route);
  }

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    setCurrentRoute(route);
    return _render();
  }

  Element? _navbarElement;

  String? _navbarElementHTML;

  dynamic _render() {
    updateSourcesFromViewProvider();

    if (renderContainer == null) {
      renderContainer = createDivInlineBlock();
      renderContainer!.style.cssText = '';
      renderContainer!.style.width = '100%';
      renderContainer!.style.height = '100%';
    } else {
      var nodes = List<Node>.from(renderContainer!.nodes);

      for (var node in nodes) {
        if (node != _navbarElement) {
          node.remove();
        }
      }
    }

    if (!content!.contains(renderContainer)) {
      content!.append(renderContainer!);
    }

    _renderNavbar();

    if (_renderedRoot != null) {
      _renderedRoot!.remove();
    }

    var context = renderDomGenerator.domContext?.copy() ?? DOMContext();
    context.namedElementProvider = _namedElementProvider;

    var treeMap =
        _renderSource!.generateTree(appendToContainer: true, context: context);

    /*!!!*/
    /*
    if (treeMap != null) {
      _renderedTreeMap = treeMap;
      _renderedRoot = treeMap.rootElement as Element?;
    } else {
      _renderedTreeMap = null;
      _renderedRoot = _renderSource!.sourceAsElement;
    }
     */
    _renderedTreeMap = treeMap;
    _renderedRoot = treeMap.rootElement as Element?;

    _renderedRoot!.classes.add('bui-root');

    return renderContainer;
  }

  void _renderNavbar() {
    if (_navbarSource!.isNull) return;

    var navbarHTML = _navbarSource!.sourceAsHTML;

    if (_navbarElementHTML != navbarHTML) {
      if (_navbarElement != null) {
        _navbarElement!.remove();
      }

      var context = renderDomGenerator.domContext?.copy() ?? DOMContext();

      context.namedElementProvider = _namedElementProvider;

      context.onPreElementCreated = (treeMap, domElement, element, context) {
        if (element is Element && treeMap.rootDOMNode == domElement) {
          element.classes.add('ui-render-navbar');
        }
      };

      context.preFinalizeGeneratedTree = (treeMap) {
        var navbarRoot = treeMap.rootElement;
        if (navbarRoot is Element) {
          navbarRoot.classes.add('ui-render-navbar');
        }
      };

      var navbarTree = _navbarSource!
          .generateTree(appendToContainer: true, context: context);
      _navbarElement = navbarTree.rootElement as Element?;
      _navbarElementHTML = navbarHTML;
    }
  }

  BUIViewProviderBase? _viewProvider;

  BUIViewProviderBase? get viewProvider => _viewProvider;

  set viewProvider(BUIViewProviderBase? value) {
    _viewProvider = value;
    updateRoutes();
  }

  void updateSourcesFromViewProvider() {
    if (viewProvider == null) return;

    var navbar = viewProvider!.getNavbar();
    this.navbar = navbar;

    var route = currentRoute;
    var view = viewProvider!.getView(route) ?? viewProvider!.getMainView();

    if (view != null) {
      source = view.buiCode;
    }
  }

  Node? _namedElementProvider(
      String name,
      DOMGenerator<dynamic>? domGenerator,
      DOMTreeMap<dynamic> treeMap,
      DOMElement? domParent,
      dynamic parent,
      String? tag,
      Map<String, DOMAttribute> attributes) {
    if (viewProvider == null) return null;

    BUIView? view;
    if (tag == 'header') {
      view = viewProvider!.getHeader(name);
    } else if (tag == 'footer') {
      view = viewProvider!.getFooter(name);
    }

    if (view == null) return null;

    var domContext = DOMContext<Node?>(
        parent: domGenerator!.domContext as DOMContext<Node?>?);

    var buiCode = view.buiCode;

    var intlPath = view.intl;

    if (isNotEmptyString(intlPath, trim: true) &&
        buiCode!.contains('{{intl:')) {
      var messages = view.intlMessagesLoader?.intlMessages;
      if (messages != null) {
        buiCode = BUIRenderSource.resolveIntl(messages, buiCode);
      }
    }

    return domGenerator.generateFromHTML(buiCode!,
        parent: parent, context: domContext, finalizeTree: false);
  }

  Future<ImageElement?> renderThumbnail(
      {String? renderedHTML,
      bool includeDocumentStyles = true,
      String? styles,
      int? width = 800,
      int? height = 600}) async {
    renderedHTML ??= renderDomGenerator.generatedHTMLTrees.join('\n');
    if (isEmptyObject(renderedHTML)) return null;

    var svgStyles = '';
    if (includeDocumentStyles) {
      var rules = getAllCssStyleSheet()
          .map((e) => e.rules)
          .whereType<List<CssRule>>()
          .expand((e) => e)
          .toList();

      svgStyles = rules.map((e) => e.cssText).join('\n');
    }

    if (isNotEmptyObject(styles)) {
      svgStyles = '\n$styles';
    }

    var svg = htmlAsSvgContent(renderedHTML,
        width: width, height: height, style: svgStyles);

    var thumbnail = UISVG(parent,
        svgContent: svg, width: '${width}px', height: '${height}px');

    var renderedImage = await thumbnail.buildRenderedImage();

    return renderedImage;
  }
}

String? parseBUIAttribute(String? buiCode, String attributeName) {
  if (buiCode == null) return null;

  var idx1 = buiCode.indexOf('<');
  var idx2 = buiCode.indexOf('>');

  if (idx1 < 0 || idx2 < 0) return null;

  var tag = buiCode.substring(idx1, idx2 + 1);

  var node = $html(tag).first;

  if (node is DOMElement && node.tag == 'bui') {
    var attributeValue = node.getAttributeValue(attributeName);
    return attributeValue;
  }

  return null;
}

typedef BUIViewPropertyProvider = String Function(BUIView view);

class BUIView {
  static Map<String, BUIView> toViewsMap(Iterable<BUIView>? views) =>
      Map.fromEntries((views ?? []).map(((v) => MapEntry(v.route!, v))));

  TextProvider? _route;

  TextProvider? _name;

  TextProvider? _buiCode;

  TextProvider? _intl;

  BUIView({
    dynamic route,
    dynamic name,
    dynamic buiCode,
  })  : _route = TextProvider.from(route),
        _name = TextProvider.from(name),
        _buiCode = TextProvider.from(buiCode);

  String? get buiCode => _buiCode?.text;

  set buiCode(dynamic value) => _buiCode = TextProvider.from(value);

  String? get name => _nameImp ?? _routeImp;

  String? get _nameImp => _name?.text ?? parseBUIAttribute(buiCode, 'name');

  set name(dynamic value) => _name = TextProvider.from(value);

  String? get route => _routeImp ?? _nameImp;

  String? get _routeImp => _route?.text ?? parseBUIAttribute(buiCode, 'route');

  set route(dynamic value) => _route = TextProvider.from(value);

  String? get intl => _intlImp;

  String? get _intlImp => _intl?.text ?? parseBUIAttribute(buiCode, 'intl');

  set intl(dynamic value) => _intl = TextProvider.from(value);

  bool get isHideFromMenu =>
      parseBool(parseBUIAttribute(buiCode, 'hide-from-menu'), false)!;

  IntlMessagesLoader? _intlMessagesLoader;

  IntlMessagesLoader? get intlMessagesLoader {
    if (_intlMessagesLoader == null) {
      var intl = this.intl;
      if (isNotEmptyString(intl)) {
        _intlMessagesLoader = IntlMessagesLoader('/bui/', intl);
      }
    }
    return _intlMessagesLoader;
  }

  @override
  String toString() => buiCode ?? '';
}

abstract class BUIViewProviderBase {
  String? name;
  DataAssets? dataAssets;

  BUIViewProviderBase(this.name, {this.dataAssets});

  BUIView? getHeader(String? name);

  BUIView? getFooter(String? name);

  BUIView? getView(String? route);

  bool containsView(String? route);

  BUIView? getNavbar();

  BUIView? getMainView();

  String? getRouteName(String? route);

  String? currentRoute;

  List<String>? routes;

  List<String>? menuRoutes;

  Map<String, String> get routesAndNames => routes == null
      ? <String, String>{}
      : Map.fromEntries(routes!.map((r) {
          var routeName = getRouteName(r);
          return MapEntry(r, routeName ?? r);
        }));

  Map<String, String> get menuRoutesAndNames => menuRoutes == null
      ? <String, String>{}
      : Map.fromEntries(menuRoutes!.map((r) {
          var routeName = getRouteName(r);
          return MapEntry(r, routeName ?? r);
        }));
}

class BUIViewProvider extends BUIViewProviderBase {
  BUIView? navbar;
  final Map<String, BUIView> headers = {};
  final Map<String, BUIView> footers = {};
  final Map<String?, BUIView> views = {};

  BUIViewProvider(String? name,
      {DataAssets? dataAssets,
      this.navbar,
      Iterable<BUIView>? headers,
      Iterable<BUIView>? footers,
      Iterable<BUIView>? views})
      : super(name, dataAssets: dataAssets) {
    this.headers.addAll(BUIView.toViewsMap(headers));
    this.footers.addAll(BUIView.toViewsMap(footers));
    this.views.addAll(BUIView.toViewsMap(views));
  }

  static Future<BUIViewProvider?> fromManifestContent(
      String manifestContent) async {
    if (isEncodedJSONMap(manifestContent)) {
      var manifestTree = parseJSON(manifestContent);
      return BUIViewProvider.fromManifestTree(manifestTree);
    } else {
      try {
        var manifestTree = loadYaml(manifestContent) as Map?;
        print(encodeJSON(manifestTree));
        return BUIViewProvider.fromManifestTree(manifestTree);
      } catch (e) {
        print(e);
      }
    }
    return null;
  }

  static Future<BUIViewProvider?> fromManifestTree(Map? manifestTree,
      {String? baseURL}) async {
    if (manifestTree == null || manifestTree.isEmpty) return null;

    var name = manifestTree['name'] as String?;

    var viewProvider = BUIViewProvider(name);

    var viewsTree = _resolveViews(manifestTree, baseURL, ['views'],
        ['headers', 'footers', 'views/headers', 'views/footers']);
    var headersTree =
        _resolveViews(manifestTree, baseURL, ['headers', 'views/headers']);
    var footersTree =
        _resolveViews(manifestTree, baseURL, ['footers', 'views/footers']);

    for (var entry in viewsTree.entries) {
      var content = await _resolveContent(entry.value);
      viewProvider.addFileViewContent(null, entry.key, content);
    }

    for (var entry in headersTree.entries) {
      var content = await _resolveContent(entry.value);
      viewProvider.addFileViewContent('headers', entry.key, content);
    }

    for (var entry in footersTree.entries) {
      var content = await _resolveContent(entry.value);
      viewProvider.addFileViewContent('footers', entry.key, content);
    }

    return viewProvider;
  }

  static Future<String?> _resolveContent(dynamic o) async {
    if (o == null) return '';
    if (o is ResourceContent) {
      return await o.getContent();
    } else {
      return o.toString();
    }
  }

  static Map<String, dynamic> _resolveViews(
      Map manifestTree, String? baseURL, List<String> keys,
      [List<String>? ignore]) {
    baseURL ??= './';
    ignore ??= [];

    var map = {};
    var list = [];

    for (var key in keys) {
      var val = findKeyPathValue(manifestTree, key);

      if (val is Map) {
        map.addAll(val);
      } else if (val is List) {
        list.addAll(val.where((e) =>
            e is String &&
            !listMatchesAny(ignore, (dynamic p) => e.startsWith('$p/'))));
      } else if (key.contains('/')) {
        var parts = key.split('/');
        var keyRoot = parts.removeAt(0);
        var restPath = parts.join('/');

        val = manifestTree[keyRoot];

        if (val is List) {
          list.addAll(val.where((e) =>
              e is String &&
              (e.startsWith('$key/') ||
                  e.startsWith('$restPath/') &&
                      !listMatchesAny(
                          ignore, (dynamic p) => e.startsWith('$p/')))));
        }
      }
    }

    var viewsTree = <String, dynamic>{};

    for (var entry in map.entries) {
      var key = entry.key;
      var val = entry.value;
      if (val is String) {
        viewsTree[key] = _asResourceContent(val, baseURL);
      }
    }

    for (var entry in list) {
      if (entry is String) {
        viewsTree[entry] = _asResourceContent(entry, baseURL);
      }
    }

    return viewsTree;
  }

  static ResourceContent _asResourceContent(String val, String baseURL) {
    if (RegExp(r'[\r\n<>]').hasMatch(val)) {
      return ResourceContent(null, val);
    } else {
      var resourceContent =
          ResourceContent.fromResolvedUrl(val, baseURL: baseURL)!;
      resourceContent.load();
      return resourceContent;
    }
  }

  factory BUIViewProvider.fromZipBytes(String name, Uint8List bytes) {
    return _loadBUIZipIntoViewProvider(name, bytes);
  }

  void addFileViewContent(String? type, String filePath, String? content) {
    var fileName = getPathFileName(filePath)!;
    var fileRoute = fileName.replaceFirst(RegExp(r'\.bui$'), '');

    if (isEmptyString(type, trim: true)) {
      if (fileRoute == 'navbar') {
        navbar = BUIView(name: 'navbar', buiCode: content);
      } else {
        var view = BUIView(buiCode: content);
        var viewRoute = view.route ?? fileRoute;
        views[viewRoute] = view;
      }
    } else {
      var view = BUIView(buiCode: content);
      var viewRoute = view.route ?? fileRoute;

      if (type == 'headers') {
        headers[viewRoute] = view;
      } else if (type == 'footers') {
        footers[viewRoute] = view;
      } else {
        views[viewRoute] = view;
      }
    }
  }

  @override
  BUIView? getNavbar() => navbar;

  @override
  BUIView? getHeader(String? name) => headers[name];

  @override
  BUIView? getFooter(String? name) => footers[name];

  @override
  BUIView? getView(String? route) => views[route];

  @override
  bool containsView(String? route) => views.containsKey(route);

  void addView(BUIView view) {
    views[view.route] = view;
  }

  @override
  BUIView? getMainView() {
    if (views.isEmpty) return null;

    var view = views['main'];
    if (view != null) return view;

    view = views['home'];
    if (view != null) return view;

    view = views['root'];
    if (view != null) return view;

    view = views.values.first;
    return view;
  }

  @override
  List<String> get routes =>
      views.values.map((e) => e.route).toList() as List<String>;

  @override
  List<String> get menuRoutes =>
      views.values.where((e) => !e.isHideFromMenu).map((e) => e.route).toList()
          as List<String>;

  @override
  String? getRouteName(String? route) => getView(route)?.name;
}

BUIViewProvider _loadBUIZipIntoViewProvider(String fileName, Uint8List bytes,
    [BUIViewProvider? viewProvider]) {
  final archive = ZipDecoder().decodeBytes(bytes);

  DataAssets? dataAssets;
  if (viewProvider == null) {
    dataAssets = DataAssets();
    viewProvider = BUIViewProvider(fileName, dataAssets: dataAssets);
  } else {
    dataAssets = viewProvider.dataAssets;
    if (dataAssets == null) {
      viewProvider.dataAssets = dataAssets = DataAssets();
    }
  }

  for (final file in archive) {
    if (file.isFile) {
      var filePath = file.name;
      filePath = filePath.substring(filePath.indexOf('/') + 1);

      var idx = filePath.lastIndexOf('/');
      var filename = idx >= 0 ? filePath.substring(idx + 1) : filePath;

      if (filename.startsWith('.')) {
        continue;
      }

      if (filePath.startsWith('assets/')) {
        var fileID = filePath.substring(filePath.indexOf('/') + 1);
        var data = file.content as List<int>;
        var mimeType = MimeType.byExtension(fileID)!;
        dataAssets.putData(fileID, data, mimeType);
      } else if (filePath.startsWith('views/') && filePath.endsWith('.bui')) {
        var data = file.content as List<int>;
        var content = _decodeBytesToString(data);

        var route = filename.replaceFirst(RegExp(r'\.bui$'), '');
        var idx = route.lastIndexOf('/');
        if (idx >= 0) {
          route = route.substring(idx + 1);
        }

        if (filePath == 'views/navbar.bui') {
          viewProvider.navbar = BUIView(name: 'navbar', buiCode: content);
        } else {
          var view = BUIView(buiCode: content);
          var viewRoute = view.route ?? route;

          if (filePath.startsWith('views/headers')) {
            viewProvider.headers[viewRoute] = view;
          } else if (filePath.startsWith('views/footers')) {
            viewProvider.footers[viewRoute] = view;
          } else {
            viewProvider.views[viewRoute] = view;
          }
        }
      }
    }
  }

  return viewProvider;
}

String _decodeBytesToString(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (e) {
    return latin1.decode(bytes);
  }
}

class BUIRenderSource {
  final DOMGenerator<Node> domGenerator;

  final Element? Function() renderContainer;

  final void Function() notifySourceChange;

  final void Function() refresh;

  BUIRenderSource(this.domGenerator, this.renderContainer,
      this.notifySourceChange, this.refresh);

  dynamic _source;

  bool get isNull => _source == null;

  bool get isNotNull => !isNull;

  dynamic get source => _source;

  set source(dynamic value) {
    var prevSource = _source;
    _source = value;

    if (prevSource != value) {
      notifySourceChange();
    }
  }

  String? _resolveBUICode(dynamic o) {
    if (o == null) return null;
    String? code;
    if (o is BUIView) {
      code = parseString(o.buiCode);
    } else {
      code = parseString(o);
    }

    var intlPath = this.intlPath;

    if (isNotEmptyString(intlPath, trim: true) && code!.contains('{{intl:')) {
      code = _resolveIntl(code);
    }

    return code;
  }

  String? get intlPath {
    if (_source is BUIView) {
      BUIView view = _source;
      return view.intl;
    } else if (_source is String) {
      return parseBUIAttribute(_source, 'intl');
    } else {
      return null;
    }
  }

  bool get hasIntlPath => isNotEmptyString(intlPath, trim: true);

  final EventStream<BUIRenderSource> onIntlLoad = EventStream();

  String? _resolveIntl(String? code) {
    var messages = getIntlMessages();
    return resolveIntl(messages, code);
  }

  static final RegExp intlMarkPattern =
      RegExp(r'\{\{(intl:(\w+))\}\}', multiLine: false, caseSensitive: true);

  static String? resolveIntl(IntlMessages? messages, String? code) {
    code = replaceStringMarks(code, intlMarkPattern, (key) {
      key = key.substring(5);
      if (isEmptyString(key)) return '';
      var val = messages?.msg(key).build();
      return val ?? '';
    });

    return code;
  }

  IntlMessagesLoader? _intlMessagesLoader;

  bool get isIntlLoaded {
    return _intlMessagesLoader?.isLoaded ?? false;
  }

  bool get hasIntlLoadedAny {
    return _intlMessagesLoader?.hasLoadedAnyMessage ?? false;
  }

  Future<bool> ensureIntlMessagesLoaded() async {
    var messagesLoader = getIntlMessagesLoader();
    if (messagesLoader == null) return false;
    return messagesLoader.ensureLoaded();
  }

  IntlMessagesLoader? getIntlMessagesLoader() {
    var intlPath = this.intlPath;

    if (_intlMessagesLoader == null ||
        !_intlMessagesLoader!.matchesPathPrefix(intlPath!)) {
      if (isEmptyString(intlPath)) {
        _intlMessagesLoader = null;
        return null;
      }

      IntlMessagesLoader? messagesLoader;

      if (_source is BUIView) {
        BUIView view = _source;
        messagesLoader = view.intlMessagesLoader;
      } else {
        messagesLoader = IntlMessagesLoader('/bui/', intlPath);
      }

      _intlMessagesLoader = messagesLoader;

      messagesLoader!.onLoad.listen(notifyOnIntlLoad,
          singletonIdentifier: this, singletonIdentifyByInstance: true);
    }

    return _intlMessagesLoader;
  }

  IntlMessages? getIntlMessages() {
    return getIntlMessagesLoader()?.intlMessages;
  }

  void notifyOnIntlLoad(bool loaded) {
    onIntlLoad.add(this);
  }

  String get sourceAsHTML {
    if (_source == null) {
      return '';
    } else if (_source is String || _source is BUIView) {
      return _resolveBUICode(_source)!;
    } else if (_source is num || _source is bool) {
      return '$_source';
    } else if (_source is DOMElement) {
      var dom = _source as DOMElement;
      return dom.buildHTML(withIndent: true);
    } else if (_source is Element) {
      var elem = _source as Element;
      return elem.outerHtml!;
    } else {
      throw StateError("Can't convert source to HTML: $_source");
    }
  }

  Element? get sourceAsElement {
    if (_source == null) {
      return null;
    } else if (_source is String || _source is BUIView) {
      return createHTML(_resolveBUICode(_source));
    } else if (_source is num || _source is bool) {
      return createHTML('$_source');
    } else if (_source is DOMElement) {
      var dom = _source as DOMElement;
      return domGenerator.generate(dom) as Element?;
    } else if (_source is Element) {
      var elem = _source as Element?;
      return elem;
    } else {
      throw StateError("Can't convert source to Element: $_source");
    }
  }

  DOMElement? get sourceAsDOMElement {
    if (_source == null) {
      return null;
    } else if (_source is String || _source is BUIView) {
      return $htmlRoot(_resolveBUICode(_source));
    } else if (_source is num || _source is bool) {
      return $htmlRoot('$_source');
    } else if (_source is DOMElement) {
      return _source as DOMElement?;
    } else if (_source is Element) {
      var elem = _source as Element;
      return $htmlRoot(elem.outerHtml);
    } else {
      throw StateError("Can't convert source to Element: $_source");
    }
  }

  DOMTreeMap<Node> get sourceAsDOMTreeMap => generateTree();

  DOMTreeMap<Node> generateTree(
      {bool appendToContainer = false, DOMContext<Node>? context}) {
    var rootNode = sourceAsDOMElement ?? DIVElement();
    return domGenerator.generateMapped(rootNode,
        parent: appendToContainer ? renderContainer() : null, context: context);
  }

  bool isSameSource(BUIRenderSource other) {
    if (identical(this, other)) return true;
    if (identical(_source, other._source)) return true;
    if (_source == other._source) return true;

    var s1 = toString();
    var s2 = other.toString();
    var eq = s1 == s2;

    return eq;
  }

  @override
  String toString() {
    return sourceAsHTML;
  }
}

class BUIManifest {
  final ResourceContent? _resource;

  BUIManifest(this._resource) {
    _resource!.onLoad.listen((_) => _onLoad());
    _resource!.load();
  }

  static BUIManifest? from(dynamic manifest) {
    if (manifest == null) return null;
    if (manifest is BUIManifest) return manifest;

    if (manifest is ResourceContent) {
      return BUIManifest(manifest);
    }

    if (manifest is Uri) {
      return BUIManifest(ResourceContent.fromURI(manifest));
    }

    if (manifest is String) {
      if (manifest.isEmpty) return null;

      if (RegExp(r'''[\r\n\{\}\[\]'"]''', multiLine: false)
          .hasMatch(manifest)) {
        return BUIManifest(ResourceContent(null, manifest));
      } else {
        return BUIManifest(ResourceContent.fromURI(manifest));
      }
    }

    return null;
  }

  void _onLoad() async {
    await _loadDataSources();
  }

  Map<String, DataSource>? _dataSources;

  Future<void> _loadDataSources() async {
    var manifestTree = await getManifestTree() ?? {};

    var dataSourcesJSON = manifestTree['data-sources'] ?? [];

    if (dataSourcesJSON is String) {
      var resourceContent =
          ResourceContent.fromResolvedUrl(dataSourcesJSON, baseURL: './')!;
      var content = await resourceContent.getContent();
      dataSourcesJSON = parseTree(content);
    }

    if (dataSourcesJSON is Map) {
      dataSourcesJSON = dataSourcesJSON.values.toList();
    }

    if (dataSourcesJSON is List) {
      dataSourcesJSON =
          dataSourcesJSON.expand((e) => e is List ? e : [e]).toList();
    }

    if (dataSourcesJSON is List) {
      var dataSources = <String, DataSource>{};

      for (var src in dataSourcesJSON) {
        var dataSource = DataSourceHttp.from(src)!;
        dataSources[dataSource.id] = dataSource;
      }

      _dataSources = _dataSources;
    }
  }

  String? _manifestContent;

  Future<String?> getManifestContent() async {
    _manifestContent ??= await _resource!.getContent();
    return _manifestContent;
  }

  Map? _manifestTree;

  Future<Map?> getManifestTree() async {
    if (_manifestTree == null) {
      var manifestContent = await getManifestContent();
      _manifestTree = parseTree<Map>(manifestContent);
    }
    return _manifestTree;
  }

  static T? parseTree<T>(String? manifestContent) {
    if (isEncodedJSONMap(manifestContent)) {
      return parseJSON(manifestContent) as T?;
    } else {
      try {
        return loadYaml(manifestContent!) as T?;
      } catch (e) {
        print(e);
      }
    }
    return null;
  }

  BUIViewProvider? _viewProvider;

  Future<BUIViewProvider?> getViewProvider() async {
    if (_viewProvider == null) {
      var tree = await getManifestTree();
      _viewProvider = await BUIViewProvider.fromManifestTree(tree);
    }
    return _viewProvider;
  }
}

class BUIManifestRender extends UIComponentAsync {
  final BUIManifest _manifest;

  static dynamic _buildLoading(
      UILoadingType? loadingType,
      String? loadingColor,
      double? loadingZoom,
      String? loadingText,
      double? loadingTextZoom,
      dynamic loadingContent) {
    var demandsLoading = loadingType != null || isNotEmptyString(loadingColor);
    var hasContent = loadingContent != null;

    loadingType ??= UILoadingType.ring;
    var style = 'text-align: center; width: 100%';

    if (hasContent) {
      if (demandsLoading) {
        return $div(style: style, content: [
          loadingContent,
          UILoading.asDIVElement(loadingType,
              color: loadingColor,
              zoom: loadingZoom,
              text: loadingText,
              textZoom: loadingTextZoom)
        ]);
      } else {
        return loadingContent;
      }
    } else {
      return $div(
          style: style,
          content: UILoading.asDIVElement(loadingType,
              color: loadingColor,
              zoom: loadingZoom,
              text: loadingText,
              textZoom: loadingTextZoom));
    }
  }

  EventStreamDelegator<String>? _onChangeRoute;

  BUIManifestRender(Element parent, dynamic manifest,
      {UILoadingType? loadingType,
      dynamic loadingContent,
      String? loadingColor,
      double? loadingZoom,
      String? loadingText,
      double? loadingTextZoom,
      String? errorMessage})
      : _manifest = BUIManifest.from(manifest)!,
        super(
            parent,
            null,
            null,
            _buildLoading(loadingType, loadingColor, loadingZoom, loadingText,
                loadingTextZoom, loadingContent),
            errorMessage ?? 'Error!') {
    _onChangeRoute =
        EventStreamDelegator.provider(() => buiRender?.onChangeRoute);
  }

  BUIManifest get manifest => _manifest;

  @override
  void configure() {
    content!.style.width = '100%';
  }

  @override
  Map<String, dynamic> renderPropertiesProvider() {
    return {};
  }

  BUIRender? _buiRender;

  BUIRender? get buiRender => _buiRender;

  EventStream<String>? get onChangeRoute => _onChangeRoute;

  final EventStream<UIComponent> onRenderChildComponent = EventStream();

  @override
  void onChildRendered(UIComponent child) {
    onRenderChildComponent.add(child);
  }

  BUIViewProviderBase? get viewProviderBase => _buiRender?.viewProvider;

  String? get currentRoute => _buiRender?.viewProvider?.currentRoute;

  @override
  Future<dynamic> renderAsync(Map<String, dynamic> properties) async {
    var viewProvider = await _manifest.getViewProvider();

    if (_buiRender == null) {
      _buiRender = BUIRender(content,
          viewProvider: viewProvider, style: 'width: 100%; height: 100%;')
        ..onRenderChildComponent
            .listen((event) => onRenderChildComponent.add(event));

      _onChangeRoute!.flush();

      await _buiRender!.renderSource!.ensureIntlMessagesLoaded();
    }

    return _buiRender;
  }
}
