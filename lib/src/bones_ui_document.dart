class URLLink {
  final String url;

  final String target;

  URLLink(this.url, [this.target]);

  @override
  String toString() {
    return 'URLLink{url: $url, target: $target}';
  }
}

typedef URLFilter = URLLink Function(String url);

String getLanguageByExtension(String extension) {
  if (extension == null) return null;
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
