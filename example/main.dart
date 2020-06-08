import 'dart:html';

import 'package:bones_ui/bones_ui.dart';

void main() async {
  // Creates `bones_ui` root and initialize it:
  var root = MyRoot(querySelector('#output'));
  root.initialize();
}

// `Bones_UI` root.
class MyRoot extends UIRoot {
  MyRoot(Element container) : super(container);

  MyMenu _menu;
  MyNavigable _navigable;

  @override
  void configure() {
    _menu = MyMenu(content);
    _navigable = MyNavigable(content);
  }

  // Returns the menu component.
  @override
  UIComponent renderMenu() => _menu;

  // Returns the content component.
  @override
  UIComponent renderContent() => _navigable;
}

// Top menu.
class MyMenu extends UIComponent {
  MyMenu(Element parent) : super(parent);

  // Renders a fixed top menu with sections 'home' and 'help'.
  @override
  dynamic render() {
    return $div(
        style:
            'position: fixed; top: 0; left: 0; width: 100%; background-color: black; color: white; padding: 10px',
        content: [
          $span(
              content:
                  '<span style="fonte-size: 120%; font-weight: bold" navigate="home">Bones_UI &nbsp; - &nbsp;</span>'),
          $span(attributes: {'navigate': 'home'}, content: 'Home'),
          '<span> &nbsp; | &nbsp; </span>',
          $span(attributes: {'navigate': 'help'}, content: 'Help')
        ]);
  }
}

// Navigable content, that changes by current `route`.
class MyNavigable extends UINavigableComponent {
  MyNavigable(Element parent) : super(parent, ['home', 'help']);

  @override
  dynamic renderRoute(String route, Map<String, String> parameters) {
    print('renderRoute> $route');
    switch (route) {
      case 'home':
        return MyHome(content);
      case 'help':
        return MyHelp(content);
      default:
        return '?';
    }
  }
}

// The `home` route.
class MyHome extends UIComponent {
  MyHome(Element parent) : super(parent);

  @override
  dynamic render() {
    return markdownToDiv(('''
    <br>
    
    # Home
    
    Welcome to `Bones_UI` example
    
    This is a VERY simple example!
    
    See the [Help section](#help) for more
    
    '''));
  }
}

// The `help` route.
class MyHelp extends UIComponent {
  MyHelp(Element parent) : super(parent);

  @override
  dynamic render() {
    return $divInline(
        style: 'width: 300px ; max-width:80vw; text-align: left',
        content: [
          markdownToDiv('''
          <br>
    
          # Help
    
          See our FAQ for help:
    
          ## FAQ
    
          - Is `Bones_UI` FREE?
          
            YES, it is!
    
          - Where can I get `Bones_UI`?
          
            See the [project page](https://colossus-services.github.io/bones_ui/){:target="_blank"}.
    
          ''')
        ]);
  }
}
