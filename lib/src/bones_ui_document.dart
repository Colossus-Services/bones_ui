
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:dom_tools/dom_tools.dart';

import 'bones_ui_base.dart';


class URLLink {
  final String url ;
  final String target ;

  URLLink(this.url, [this.target]);

  @override
  String toString() {
    return 'URLLink{url: $url, target: $target}';
  }
}

typedef URLFilter = URLLink Function(String url) ;

class UICodeHighlight extends UIComponent {

  final String code ;
  final String language ;
  final bool normalizeIdent ;
  final bool linkURLs ;
  final URLFilter urlFilter ;

  UICodeHighlight(Element parent, this.code, {this.language, this.normalizeIdent, this.linkURLs = true, this.urlFilter, dynamic classes, dynamic classes2, bool inline = true, bool renderOnConstruction}) : super(parent, classes: classes, classes2: classes2, inline: inline, renderOnConstruction: renderOnConstruction) ;

  String _html ;

  String get html {
    _html ??= _buildHTML();
    return _html ;
  }

  String _buildHTML() {
    var codeHTML = codeToHighlightHtml(code, language: language, normalize: normalizeIdent);

    if (linkURLs) {
      codeHTML = codeHTML.replaceAllMapped(RegExp(r'''(https?://[^\s"']+)'''), (m) {
        var urlEscaped = m.group(1);
        var url = HtmlUnescape().convert(urlEscaped);
        String target ;

        if (urlFilter != null) {
          var urlLink = urlFilter(url) ;

          if (urlLink != null) {
            url = urlLink.url ;
            target = urlLink.target ;
          }
        }

        if (target == null || target.trim().isEmpty) target = '_blank' ;

        return '<a href="$url" class="hljs-link" target="$target">$urlEscaped</a>';
      });
    }

    return '<div style="text-align: left"><pre>$codeHTML</pre></div>';
  }

  @override
  dynamic render() {
    return html ;
  }

}


String getLanguageByExtension(String extension) {
  if (extension == null) return null ;
  extension = extension.trim().toLowerCase() ;
  if (extension.isEmpty) return null ;
  extension = extension.replaceAll(RegExp(r'\W+'), '') ;
  if (extension.isEmpty) return null ;

  switch (extension) {
    case 'dart': return 'dart' ;
    case 'mk': case 'markdown': return 'markdown' ;
    case 'cpp': return 'cpp' ;
    case 'diff': return 'diff' ;
    case 'awk': return 'awk' ;
    case 'bash': return 'bash' ;
    case 'sh': case 'shell': return 'shell' ;
    case 'swift': return 'swift' ;
    case 'yaml': return 'yaml' ;
    case 'xml': return 'xml' ;
    case 'sql': return 'sql' ;
    case 'json': return 'json' ;
    case 'java': return 'java' ;
    case 'rb': case 'ruby': return 'ruby' ;
    case 'r': return 'r' ;
    case 'php': return 'php' ;
    case 'css': return 'css' ;
    case 'htm': case 'html': return 'html' ;
    case 'txt': case 'text': return 'text' ;
    case 'pl': case 'perl': return 'perl' ;
    case 'py':  case 'python': return 'python' ;
    default: return null ;
  }
}
