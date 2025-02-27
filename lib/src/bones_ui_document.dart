import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_ui_component.dart';
import 'bones_ui_generator.dart';
import 'bones_ui_web.dart';
import 'component/component_async.dart';
import 'component/json_render.dart';

/// Represents an [url] link, with an optional [target].
class URLLink {
  final String url;

  final String? target;

  URLLink(this.url, [this.target]);

  @override
  String toString() {
    return 'URLLink{url: $url, target: $target}';
  }
}

typedef URLFilter = URLLink Function(String url);

/// Returns a document language by [extension].
String? getLanguageByExtension(String extension) {
  extension = extension.trim().toLowerCase();
  if (extension.isEmpty) return null;
  extension = extension.replaceAll(RegExp(r'\W+'), '');
  if (extension.isEmpty) return null;

  switch (extension) {
    case 'dart':
      return 'dart';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'cpp':
      return 'cpp';
    case 'diff':
      return 'diff';
    case 'awk':
      return 'awk';
    case 'bash':
      return 'bash';
    case 'sh':
    case 'shell':
      return 'shell';
    case 'swift':
      return 'swift';
    case 'yaml':
      return 'yaml';
    case 'xml':
      return 'xml';
    case 'sql':
      return 'sql';
    case 'json':
      return 'json';
    case 'java':
      return 'java';
    case 'rb':
    case 'ruby':
      return 'ruby';
    case 'r':
      return 'r';
    case 'php':
      return 'php';
    case 'css':
      return 'css';
    case 'htm':
    case 'html':
      return 'html';
    case 'txt':
    case 'text':
      return 'text';
    case 'pl':
    case 'perl':
      return 'perl';
    case 'py':
    case 'python':
      return 'python';
    default:
      return null;
  }
}

/// An [UIComponentAsync] to show rendered documents,
/// like `markdown`, `html`, `json` and `text`.
class UIDocument extends UIComponentAsync {
  static final UIComponentGenerator<UIDocument> generator =
      UIComponentGenerator<UIDocument>('ui-document', 'div', 'ui-document', '',
          (parent, attributes, contentHolder, contentNodes) {
    var src = attributes['src']?.toString();

    ResourceContent? resourceContent;
    if (isNotEmptyString(src)) {
      resourceContent = ResourceContent.from(src);
    } else {
      var type = attributes['type']?.toString() ?? '.md';
      resourceContent =
          ResourceContent.fromURI('file.$type', contentHolder?.textContent);
    }

    return UIDocument(parent, resourceContent);
  }, [
    UIComponentAttributeHandler<UIDocument, String>('src',
        parser: parseString,
        getter: (c) => c._resourceContent?.uri?.toString(),
        setter: (c, v) => c.resourceContent = v,
        appender: (c, v) => c.resourceContent = v,
        cleaner: (c) => c.resourceContent = null)
  ], hasChildrenElements: false, contentAsText: true);

  static void register() {
    UIComponent.registerGenerator(generator);
  }

  ResourceContent? _resourceContent;

  UIDocument(UIElement? parent, ResourceContent? resourceContent,
      {loadingContent,
      errorContent,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic style2,
      dynamic id})
      : _resourceContent = resourceContent,
        super(parent, null, null, loadingContent, errorContent,
            componentClass: 'ui-document',
            classes: classes,
            classes2: classes2,
            style: style,
            style2: style2,
            id: id,
            generator: generator);

  ResourceContent? get resourceContent => _resourceContent;

  set resourceContent(dynamic value) {
    var resourceContent = ResourceContent.from(value);
    if (resourceContent != _resourceContent) {
      _resourceContent = resourceContent;
      refreshInternal();
    }
  }

  @override
  Map<String, dynamic> renderPropertiesProvider() {
    return {'uri': resourceContent!.uri};
  }

  @override
  Future<dynamic> renderAsync(Map<String, dynamic> properties) async {
    await resourceContent!.load();

    var type = resourceContent!.uriMimeType!.subType;
    if (isEmptyString(type)) return null;

    var docContent = await resourceContent!.getContent();
    if (docContent == null) return null;

    var extension = resourceContent!.uriFileExtension!.toLowerCase().trim();

    if (isNotEmptyString(extension)) {
      var language = getLanguageByExtension(extension);

      if (language == 'html') {
        return docContent;
      } else if (language == 'text') {
        return '<pre>\n$docContent\n</pre>';
      } else if (language == 'markdown') {
        var div = markdownToDiv(docContent);
        div.style.overflowWrap = 'break-word';
        return div;
      } else if (language == 'json') {
        return UIJsonRender(null, json: docContent);
      }
    }

    return docContent;
  }
}
