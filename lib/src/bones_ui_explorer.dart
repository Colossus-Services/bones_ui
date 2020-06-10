import 'dart:convert' as dart_convert;
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:json_render/json_render.dart';
import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:yaml/yaml.dart';

final ResourceContentCache _resourceContentCache = ResourceContentCache();

abstract class ResourceConfig<D extends ConfigDocument> {
  ResourceContent _resourceContent;

  EventStream<String> _onLoad;

  ResourceConfig(ResourceContent resourceContent) {
    if (resourceContent != null) {
      _resourceContent = _resourceContentCache.get(resourceContent);
      _onLoad = _resourceContent.onLoad;
    } else {
      _onLoad = EventStream();
    }
  }

  ResourceContent get resourceContent {
    if (_resourceContent == null) return null;
    if (_resourceContent.uri == null) return _resourceContent;
    return _resourceContentCache.get(_resourceContent);
  }

  EventStream<String> get onLoad => _onLoad;

  D loadDocument(String content);

  D _document;

  bool _loaded = false;

  void setDocument(D doc) {
    _document = doc;
    _loaded = _document != null;

    if (_loaded) {
      onLoad.add(doc.asString());
    }
  }

  bool get isLoaded => _loaded;

  Future<D> load() async {
    if (!_loaded) {
      var resourceContent = this.resourceContent;
      if (resourceContent == null) return null;

      var content = await resourceContent.getContent();
      _document = content != null ? loadDocument(content) : null;
      _loaded = true;
    }
    return _document;
  }

  Future<D> getDocument() async {
    if (!_loaded) {
      await load();
    }
    return _document;
  }

  D getDocumentIfLoaded() {
    if (!_loaded) {
      var resourceContent = this.resourceContent;
      if (resourceContent == null) return null;

      if (resourceContent.isLoaded) {
        var content = resourceContent.getContentIfLoaded();
        _document = content != null ? loadDocument(content) : null;
        _loaded = true;
      }
    }
    return _document;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceConfig &&
          runtimeType == other.runtimeType &&
          _resourceContent == other._resourceContent;

  @override
  int get hashCode => _resourceContent != null ? _resourceContent.hashCode : 0;

  Uri get uri => _resourceContent != null ? _resourceContent.uri : null;

  Future<Uri> get uriResolved =>
      _resourceContent != null ? _resourceContent.uriResolved : null;

  Future<Uri> resolveURL(String url) =>
      ResourceContent.resolveURLFromReference(resourceContent, url);

  @override
  String toString() {
    return 'ResourceConfig{uri: $uri}';
  }
}

abstract class ConfigDocument {
  dynamic get(String key, [dynamic def]);

  Map getAsMap(String key, [Map def]) => get(key, def) as Map;

  List getAsList(String key, [List def]) => get(key, def) as List;

  List<String> getAsStringList(String key, [List<String> def]) =>
      getAsList(key, def).cast();

  List<int> getAsIntList(String key, [List<int> def]) =>
      getAsList(key, def).cast();

  List<num> getAsNumList(String key, [List<num> def]) =>
      getAsList(key, def).cast();

  List<double> getAsDoubleList(String key, [List<double> def]) =>
      getAsList(key, def).cast();

  List<bool> getAsBoolList(String key, [List<bool> def]) =>
      getAsList(key, def).cast();

  String getAsString(String key, [String def]) => parseString(get(key), def);

  int getAsInt(String key, [int def]) => parseInt(get(key), def);

  num getAsNum(String key, [num def]) => parseNum(get(key), def);

  double getAsDouble(String key, [double def]) => parseDouble(get(key), def);

  bool getAsBool(String key, [bool def]) => parseBool(get(key), def);

  dynamic getPath(List<String> keys, [dynamic def]) {
    if (keys == null || keys.isEmpty) return def;

    if (keys.length == 1) return get(keys[0]);

    var val = get(keys[0]);
    if (val == null) return def;

    for (var i = 1; i < keys.length; i++) {
      var k = keys[i];
      var v = val[k];
      if (v == null) return def;
      val = v;
    }

    return val;
  }

  String getPathAsString(List<String> keys, [dynamic def]) =>
      (getPath(keys, def) ?? '').toString();

  String asString();
}

class YAMLConfigDocument extends ConfigDocument {
  dynamic _document;

  YAMLConfigDocument(YamlDocument document) {
    _document = deepCopy(document.contents.value);
  }

  YAMLConfigDocument.load(String yaml) : this(loadYamlDocument(yaml));

  @override
  dynamic get(String key, [dynamic def]) {
    return findKeyValue<dynamic, dynamic>(_document, [key], true) ?? def;
  }

  YamlNode asYamlNode() {
    if (_document is Map) return YamlMap.wrap(_document);
    if (_document is List) return YamlList.wrap(_document);
    return YamlScalar.wrap(_document);
  }

  @override
  String asString() {
    return asYamlNode().toString();
  }
}

class JSONConfigDocument extends ConfigDocument {
  dynamic _document;

  JSONConfigDocument(this._document);

  JSONConfigDocument.loadFromJSONString(String json)
      : this(dart_convert.json.decode(json));

  JSONConfigDocument.loadFromJSON(dynamic json) : this(json);

  @override
  dynamic get(String key, [dynamic def]) {
    return findKeyValue<dynamic, dynamic>(_document, [key], true) ?? def;
  }

  @override
  String asString() {
    return dart_convert.JsonEncoder.withIndent(' ').convert(_document);
  }
}

class YAMLConfig extends ResourceConfig<YAMLConfigDocument> {
  YAMLConfig(dynamic resourceContent)
      : super(ResourceContent.from(resourceContent));

  @override
  YAMLConfigDocument loadDocument(String content) =>
      YAMLConfigDocument.load(content);

  @override
  String toString() {
    return 'YAMLConfig{uri: $uri';
  }
}

class JSONConfig extends ResourceConfig<JSONConfigDocument> {
  JSONConfig(dynamic resourceContent)
      : super(ResourceContent.from(resourceContent));

  JSONConfig.withDocument(JSONConfigDocument doc) : super(null) {
    setDocument(doc);
  }

  factory JSONConfig.fromJSON(dynamic json) {
    if (json == null) return null;
    var doc = json is String
        ? JSONConfigDocument.loadFromJSONString(json)
        : JSONConfigDocument.loadFromJSON(json);
    return JSONConfig.withDocument(doc);
  }

  @override
  JSONConfigDocument loadDocument(String content) =>
      JSONConfigDocument.loadFromJSONString(content);

  @override
  String toString() {
    return 'JSONConfig{uri: $uri';
  }
}

class ExplorerModel {
  final ResourceConfig resourceConfig;

  ExplorerModel(this.resourceConfig);

  factory ExplorerModel.from(dynamic resourceConfigSource) {
    if (resourceConfigSource == null) return null;
    if (resourceConfigSource is ExplorerModel) return resourceConfigSource;
    if (resourceConfigSource is ResourceConfig) {
      return ExplorerModel(resourceConfigSource);
    }
    if (resourceConfigSource is Map) {
      return ExplorerModel.fromJSON(resourceConfigSource);
    }
    if (resourceConfigSource is String) {
      return ExplorerModel.fromURI(resourceConfigSource);
    }
    return ExplorerModel.fromURI(resourceConfigSource.toString());
  }

  factory ExplorerModel.fromJSON(dynamic json) {
    var config = JSONConfig.fromJSON(json);
    return config != null ? ExplorerModel(config) : null;
  }

  factory ExplorerModel.fromURI(String resourceConfigUri) {
    var extension = getPathExtension(resourceConfigUri);
    if (extension == null) {
      throw ArgumentError('URI without extension: $resourceConfigUri');
    }

    extension = extension.trim().toLowerCase();

    var resourceConfig;

    if (extension == 'yaml') {
      resourceConfig = YAMLConfig(resourceConfigUri);
    } else if (extension == 'json') {
      resourceConfig = JSONConfig(resourceConfigUri);
    } else {
      throw ArgumentError(
          'Unknown config extension[$extension]: $resourceConfigUri');
    }

    return ExplorerModel(resourceConfig);
  }

  Uri get uri => resourceConfig.uri;

  Future<Uri> get uriResolved => resourceConfig.uriResolved;

  Future<Uri> resolveURL(String url) => resourceConfig.resolveURL(url);

  Future<ConfigDocument> load() => resourceConfig.load();

  Future<ConfigDocument> getConfigDocument() => resourceConfig.getDocument();

  ConfigDocument get configDocument => resourceConfig.getDocumentIfLoaded();

  String get modelType {
    var doc = configDocument;
    if (doc == null) return '';
    return doc.getAsString('model', '').trim().toLowerCase();
  }
}

class UIExplorer extends UIComponentAsync {
  static final String CLASS = 'ui-explorer';

  final ExplorerModel model;

  UIExplorer(Element parent, dynamic model,
      {loadingContent, errorContent, dynamic classes})
      : model = ExplorerModel.from(model),
        super(parent, null, null, loadingContent, errorContent,
            classes: CLASS, classes2: classes);

  @override
  Map<String, dynamic> renderPropertiesProvider() {
    return {'model': model.toString()};
  }

  @override
  Future<dynamic> renderAsync(Map<String, dynamic> properties) async {
    await model.load();

    var modelType = model.modelType;
    if (modelType == null || modelType.isEmpty) return null;

    content.classes.add('$CLASS-$modelType');

    if (modelType == 'document') {
      return await render_document();
    } else if (modelType == 'query') {
      return await render_query();
    } else if (modelType == 'catalog') {
      return await render_catalog();
    }
  }

  Future<dynamic> render_document() async {
    var doc = model.configDocument;

    var content = doc.getAsString('content');
    if (content != null) {
      return content;
    }

    var markdown = doc.getAsString('markdown');
    if (markdown != null) {
      var div = markdownToDiv(markdown);
      div.style.overflowWrap = 'break-word';
      return div;
    }

    var url = doc.getAsString('url');
    if (url != null) {
      return _render_document_url(url, doc);
    }

    return null;
  }

  Future<dynamic> _render_document_url(String url, ConfigDocument doc) async {
    var uri = await model.resolveURL(url);

    var localeUrlPattern = doc.getAsString('locale_url_pattern');

    ResourceContent resourceContent;
    if (localeUrlPattern != null) {
      var intlResourceUri =
          IntlResourceUri(RegExp(localeUrlPattern), url, _resourceContentCache);
      resourceContent = await intlResourceUri.resolveResourceContent();
    } else {
      resourceContent = ResourceContent.fromURI(uri);
      resourceContent = _resourceContentCache.get(resourceContent);
    }

    var urlContent = await resourceContent.getContent();
    if (urlContent == null) return null;

    var extension = getPathExtension(url).toLowerCase().trim();

    if (extension != null) {
      var language = getLanguageByExtension(extension);

      if (language == 'html') {
        return urlContent;
      } else if (language == 'text') {
        return '<pre>\n$urlContent\n</pre>';
      } else if (language == 'markdown') {
        var div = markdownToDiv(urlContent);
        div.style.overflowWrap = 'break-word';
        return div;
      } else if (language == 'json') {
        var jsonRender = JSONRender.fromJSONAsString(urlContent);
        jsonRender.addAllKnownTypeRenders();
        var div = jsonRender.render();
        div.style.overflowWrap = 'break-word';
        return div;
      }
    }

    return urlContent;
  }

  Future<dynamic> render_query() async {
    var conf = model.configDocument;

    var inputs = conf.getAsMap('inputs');

    var inputConfigs = InputConfig.listFromMap(inputs);

    var executor = MapProperties.fromMap(conf.getAsMap('executor'));

    var viewer = MapProperties.fromMap(conf.getAsMap('viewer'));

    return _UIExplorerQuery(content, inputConfigs, executor, viewer,
        loadingContent: 'loading...', errorContent: 'error!');
  }

  Future<dynamic> render_catalog() async {
    var conf = model.configDocument;

    var documentInputConfigs =
        InputConfig.listFromMap(conf.getAsMap('document'));

    var documentViewer =
        MapProperties.fromMap(conf.getAsMap('document_viewer'));

    var documentPreview =
        MapProperties.fromMap(conf.getAsMap('document_preview'));
    var documentStorage =
        MapProperties.fromMap(conf.getAsMap('document_storage'));
    var documentListing =
        MapProperties.fromMap(conf.getAsMap('document_listing'));

    return _UIExplorerCatalog(content, documentInputConfigs, documentViewer,
        documentPreview, documentStorage, documentListing);
  }
}

class _UIExplorerCatalog extends UIComponent {
  final List<InputConfig> documentInputConfig;

  final MapProperties _documentViewer;

  final MapProperties _documentPreview;

  final MapProperties _documentStorage;

  final MapProperties _documentListing;

  _UIExplorerCatalog(
      Element parent,
      this.documentInputConfig,
      this._documentViewer,
      this._documentPreview,
      this._documentStorage,
      this._documentListing,
      {dynamic classes})
      : super(parent, classes: classes, renderOnConstruction: false);

  @override
  dynamic render() {
    var listingAsync = UIComponentAsync(
        content, _listingProperties, render_listing, 'Loading...', 'Error...');

    var newDoc = render_newDocument();

    return [listingAsync, '<hr>', newDoc, '<hr>'];
  }

  Map<String, dynamic> _listingProperties() {
    var navigation = UINavigator.currentNavigation;

    var page = navigation.parameterAsInt('page', 0);

    return {'page': page};
  }

  Future<dynamic> render_listing(Map<String, dynamic> properties) async {
    var httpRequester = HttpRequester(MapProperties.fromMap(_documentListing),
        MapProperties.fromMap(properties));

    var response = await httpRequester.doRequest();

    var viewerRender = _ViewerRender(_documentViewer ?? _documentPreview);

    var responseType =
        httpRequester.config.getPropertyAsStringTrimLC('response');

    return viewerRender.render(content, responseType, response);
  }

  dynamic render_newDocument() {
    var documentInputs = UIInputTable(content, documentInputConfig);
    var sendButton = UISimpleButton(content, 'Send');

    var error = $span(
        classes: 'ui-text-alert',
        attributes: {'hidden': 'true', 'field': 'send-error'},
        content: 'Error sending!');

    sendButton.onClick.listen((e) => _sendNewDocument(documentInputs));

    return ['New Document:<p>', documentInputs, '<br>', sendButton, error];
  }

  void _sendNewDocument(UIInputTable documentInputs) async {
    var fields = documentInputs.getFields();

    var inputFields =
        documentInputConfig.map((input) => input.fieldName).toList();
    fields.removeWhere((k, v) => !inputFields.contains(k));

    var document = dart_convert.json.encode(fields);

    fields['DOCUMENT'] = document;

    var httpRequester = HttpRequester(
        MapProperties.fromMap(_documentStorage), MapProperties.fromMap(fields));
    var response = await httpRequester.doRequest();

    if (response == null) {
      var elementError = getFieldElement('send-error');
      elementError.hidden = false;
    } else {
      refresh();
    }
  }
}

class _UIExplorerQuery extends UIControlledComponent {
  final List<InputConfig> inputConfig;

  final MapProperties _executor;

  final MapProperties _viewer;

  _UIExplorerQuery(
      Element parent, this.inputConfig, this._executor, this._viewer,
      {dynamic loadingContent, dynamic errorContent, dynamic classes})
      : super(parent, loadingContent, errorContent,
            controllersPropertiesType: ControllerPropertiesType.IMPLEMENTATION,
            classes: classes);

  @override
  MapProperties getControllersProperties() {
    var mapValues = inputConfig.asMap().map((k, v) => MapEntry(v.id, v.value));

    var inputTable = getController('table') as UIInputTable;

    if (inputTable != null) {
      var controllersValues = inputTable.getFields();
      controllersValues.removeWhere((k, v) => v == null || v.isEmpty);
      controllersValues.forEach((k, v) => mapValues[k] ??= v);
    }

    return MapProperties.fromStringProperties(mapValues);
  }

  @override
  Future<Map<String, dynamic>> renderControllers(
      MapProperties properties) async {
    return {'table': UIInputTable(parent, inputConfig)};
  }

  @override
  bool isValidControllersSetup(
      MapProperties properties, Map<String, dynamic> controllers) {
    var inputTable = controllers['table'] as UIInputTable;
    return inputTable.checkFields();
  }

  @override
  Future<bool> setupControllers(
      MapProperties properties, Map<String, dynamic> controllers) async {
    var inputTable = controllers['table'] as UIInputTable;

    properties.forEach((k, v) {
      inputTable.setField(k, v);
    });

    return true;
  }

  @override
  Future<bool> listenControllers(Map<String, dynamic> controllers) async {
    var inputTable = controllers['table'] as UIInputTable;

    inputTable.onChange.listen((elem) => callOnChangeControllers(elem));

    return true;
  }

  @override
  void onChangeController(Map<String, dynamic> controllers,
      bool validControllersSetup, dynamic changedController) {
    if (!validControllersSetup) return;

    refreshComponentAsync();
  }

  @override
  Future<dynamic> renderResult(MapProperties properties) async {
    var queryResponse = await executeQuery(properties, _executor);

    var responseType = _executor.getPropertyAsStringTrimLC('response');
    var viewerRender = _ViewerRender(_viewer);

    return viewerRender.render(content, responseType, queryResponse);
  }

  Future<dynamic> executeQuery(
      MapProperties properties, MapProperties executor) async {
    var type = executor.getPropertyAsStringTrimLC('type', 'http');

    if (type == 'http' || type == 'https') {
      return executeQuery_http(executor, type, properties, null);
    } else {
      return null;
    }
  }

  Future<dynamic> executeQuery_http(MapProperties executor, String type,
      MapProperties properties, int page) async {
    var httpRequester = HttpRequester(executor, properties);
    return httpRequester.doRequest();
  }
}

class _ViewerRender {
  final MapProperties config;

  _ViewerRender(this.config);

  Future<dynamic> render(
      Element output, String contentType, dynamic content) async {
    var type = config.getPropertyAsStringTrimLC('type', 'html');

    if (type == 'html') {
      if (content is Node) {
        return content;
      } else if (content is DOMElement) {
        return content;
      } else {
        return createHTML('$content');
      }
    } else if (type == 'json') {
      return render_json(output, contentType, content);
    }

    return null;
  }

  DivElement render_json(Element output, String contentType, dynamic content) {
    var jsonRender = content is String
        ? JSONRender.fromJSONAsString(content)
        : JSONRender.fromJSON(content);

    var mode = config.getPropertyAsStringTrimLC('mode');

    if (mode == 'input') {
      jsonRender.renderMode = JSONRenderMode.INPUT;
    } else if (mode == 'view') {
      jsonRender.renderMode = JSONRenderMode.VIEW;
    }

    jsonRender.addAllKnownTypeRenders();

    var showNodeArrow = config.getPropertyAsBool('show_node_arrow', true);
    var showNodeOpenerAndCloser =
        config.getPropertyAsBool('show_node_opener_and_closer', true);

    jsonRender.showNodeArrow = showNodeArrow;
    jsonRender.showNodeOpenerAndCloser = showNodeOpenerAndCloser;

    return jsonRender.render();
  }
}
