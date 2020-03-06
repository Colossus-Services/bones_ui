
import 'dart:html';

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

