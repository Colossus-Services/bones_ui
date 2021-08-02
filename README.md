# Bones_UI

[![pub package](https://img.shields.io/pub/v/bones_ui.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/bones_ui)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)

[![CI](https://img.shields.io/github/workflow/status/Colossus-Services/bones_ui/Dart%20CI/master?logo=github-actions&logoColor=white)](https://github.com/Colossus-Services/bones_ui/actions)
[![GitHub Tag](https://img.shields.io/github/v/tag/Colossus-Services/bones_ui?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/releases)
[![New Commits](https://img.shields.io/github/commits-since/Colossus-Services/bones_ui/latest?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/network)
[![Last Commits](https://img.shields.io/github/last-commit/Colossus-Services/bones_ui?logo=git&logoColor=white)](https://github.com/Colossus-Services/bones_ui/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/Colossus-Services/bones_ui?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_ui/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/Colossus-Services/bones_ui?logo=github&logoColor=white)](https://github.com/Colossus-Services/bones_ui)
[![License](https://img.shields.io/github/license/Colossus-Services/bones_ui?logo=open-source-initiative&logoColor=green)](https://github.com/Colossus-Services/bones_ui/blob/master/LICENSE)


Bones_UI - A simple and easy Web User Interface framework for Dart.

## CLI

You can use the *__command-line interface (CLI)__* `bones_ui` to create or serve a project:

To activate it globally:

```bash
  $> dart pub global activate bones_ui
```

Now you can use the CLI directly:

```bash
  $> bones_ui --help
```

To show the `Bones_UI` template information:

```bash
  $> bones_ui info
```

To create a `Bones_UI` project from the default template:

```bash
  $> bones_ui create -o /path/to/workspace -p project_name_dir=simple_project -p "project_name=Simple Project"
```

## Usage

A simple usage example:

```dart
import 'dart:html';

import 'package:bones_ui/bones_ui_kit.dart';

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

## Bones_UI App Example

Also see the [App example @ GitHub][app_example]:

[app_example]: https://github.com/Colossus-Services/bones_ui_app_example

## Bootstrap Integration

You can use the Dart package [Bones_UI_Bootstrap][bones_ui_bootstrap]
to activate [Bootstrap][bootstrap] integration with `Bones_UI`.

[Bones_UI_Bootstrap][bones_ui_bootstrap] automatically handles loading of JavaScript libraries and CSS.
With it you don't need to add any HTML or JavaScript code to have full integration of [Bootstrap][bootstrap] with `Bones_UI`.

[bones_ui_bootstrap]: https://pub.dev/packages/bones_ui_bootstrap
[bootstrap]: https://getbootstrap.com/ 
 
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

