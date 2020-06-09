# Bones_UI

[![pub package](https://img.shields.io/pub/v/bones_ui.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/bones_ui)
[![CI](https://img.shields.io/github/workflow/status/Colossus-Services/bones_ui/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/Colossus-Services/bones_ui/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/Colossus-Services/bones_ui?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/releases)
[![New Commits](https://img.shields.io/github/commits-since/Colossus-Services/bones_ui/latest?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/network)
[![Last Commits](https://img.shields.io/github/last-commit/Colossus-Services/bones_ui?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/Colossus-Services/bones_ui?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_ui/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/Colossus-Services/bones_ui?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_ui)
[![License](https://img.shields.io/github/license/Colossus-Services/bones_ui?logo=open-source-initiative&logoColor=green)](https://github.com/Colossus-Services/bones_ui/blob/master/LICENSE)


Bones_UI - A simple and easy Web User Interface framework for Dart

## Usage

A simple usage example:

```dart
import 'dart:html';

import 'package:bones_ui/bones_ui.dart';

void main() async {
  // Create `bones_ui` root and initialize it:
  var root = MyRoot(querySelector('#output'));
  root.initialize();
}

// `Bones_UI` root.
class MyRoot extends UIRoot {
  MyRoot(Element rootContainer) : super(rootContainer);

  MyMenu _menu;
  MyHome _home;

  @override
  void configure() {
    _menu = MyMenu(content);
    _home = MyHome(content);
  }

  // Returns the menu component.
  @override
  UIComponent renderMenu() => _menu;

  // Returns the content component.
  @override
  UIComponent renderContent() => _home;
}

// Top menu.
class MyMenu extends UIComponent {
  MyMenu(Element parent) : super(parent);

  // Renders a fixed top menu with a title.
  @override
  dynamic render() {
    return $div(
        style: 'position: fixed; top: 0; left: 0; width: 100%; background-color: black; color: white; padding: 10px',
        content: '<span style="font-size: 120%; font-weight: bold">Bones_UI</span>'
        );
  }
}

// The `home` component.
class MyHome extends UIComponent {
  MyHome(Element parent) : super(parent);

  @override
  dynamic render() {
    return markdownToDiv(('''
    <br>
    
    # Home
    
    Welcome!
    
    This is a VERY simple example!
    '''));
  }
}

```

## Example from Sources

Get the source
```
  $> git clone https://github.com/Colossus-Services/bones_ui.git
```

...and see the [Web Example][example] (just follow the README file for instructions).

[example]: https://github.com/Colossus-Services/bones_ui/tree/master/example

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Colossus-Services/bones_ui/issues

## Colossus.Services

This is an open-source project from [Colossus.Services][colossus]:
the gateway for smooth solutions.

## Author

Graciliano M. Passos: [gmpassos@GitHub][gmpassos_github].

## License

[Artistic License - Version 2.0][artistic_license]


[gmpassos_github]: https://github.com/gmpassos
[colossus]: https://colossus.services/
[artistic_license]: https://github.com/Colossus-Services/bones_ui/blob/master/LICENSE

