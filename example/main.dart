import 'dart:html';

import 'package:bones_ui/bones_ui_kit.dart';

void main() async {
  // Create `bones_ui` root and initialize it:
  var root = MyRoot(querySelector('#output'));
  root.initialize();
}

// `Bones_UI` root.
class MyRoot extends UIRoot {
  MyRoot(super.rootContainer);

  MyMenu? _menu;
  MyFooter? _footer;
  MyNavigable? _navigable;

  @override
  void configure() {
    _menu = MyMenu(content);
    _footer = MyFooter(content);
    _navigable = MyNavigable(content);
  }

  // Returns the menu component.
  @override
  UIComponent? renderMenu() => _menu;

  // Returns the footer component.
  @override
  UIComponent? renderFooter() => _footer;

  // Returns the content component.
  @override
  UIComponent? renderContent() => _navigable;
}

// Top menu.
class MyMenu extends UIComponent {
  MyMenu(super.parent);

  // Renders a fixed top menu with sections 'home' and 'help'.
  @override
  dynamic render() {
    return $div(
        style:
            'position: fixed; top: 0; left: 0; width: 100%; background-color: black; color: white; padding: 10px',
        content: [
          $span(
              content:
                  '<span style="font-size: 120%; font-weight: bold" navigate="home">Bones_UI &nbsp; - &nbsp;</span>'),
          $span(attributes: {'navigate': 'home'}, content: 'Home'),
          '<span> &nbsp; | &nbsp; </span>',
          $span(attributes: {'navigate': 'components'}, content: 'Components'),
          '<span> &nbsp; | &nbsp; </span>',
          $span(attributes: {'navigate': 'help'}, content: 'Help')
        ]);
  }
}

// Footer
class MyFooter extends UIComponent {
  MyFooter(super.parent);

  // Renders a fixed top menu with sections 'home' and 'help'.
  @override
  dynamic render() {
    return $div(
        style:
            'position: absolute; position: fixed; bottom: 0; left: 0; width: 100%; background-color: rgba(0,0,0, 0.05); color: black; padding: 4px',
        content: [
          $span(
              content:
                  '<span style="font-size: 90%;" navigate="home">Built with <a href="https://colossus-services.github.io/bones_ui/" target="_blank">Bones_UI</a></span>'),
        ]);
  }
}

// Navigable content, that changes by current `route`.
class MyNavigable extends UINavigableComponent {
  MyNavigable(Element? parent) : super(parent, ['home', 'components', 'help']);

  @override
  dynamic renderRoute(String? route, Map<String, String>? parameters) {
    print('renderRoute> $route');
    switch (route) {
      case 'home':
        return MyHome(content);
      case 'components':
        return MyComponents(content);
      case 'help':
        return MyHelp(content);
      default:
        return '?';
    }
  }
}

// The `home` route.
class MyHome extends UIComponent {
  MyHome(super.parent);

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
  MyHelp(super.parent);

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

// The `components` route.
class MyComponents extends UIComponent {
  MyComponents(super.parent);

  @override
  dynamic render() {
    _buildCalendar();

    return [
      '<br><h1>Components</h1>',
      '<hr>',
      UIButton(content, 'UIButton')
        ..onClick.listen((event) => _showAlert('<b>UIButton Clicked:</b>',
            'x: ${event.client.x}<br> y: ${event.client.y}')),
      '<hr>',
      UIInputTable(content, [
        InputConfig('name', 'Name', type: 'text'),
        InputConfig('email', 'Email',
            type: 'email',
            valueNormalizer: (f, v) => v?.toString().trim() ?? ''),
        InputConfig('color', 'Color', type: 'color', optional: true),
        InputConfig('sel', 'Select',
            type: 'select', options: {'a': 'A Option', 'b': 'B Option'}),
      ]),
      '<hr>',
      _uiCalendarPopup,
      '<hr>',
    ];
  }

  UICalendarPopup? _uiCalendarPopup;

  void _buildCalendar() {
    _uiCalendarPopup ??= UICalendarPopup(content,
        backgroundBlur: 4,
        mode: CalendarMode.month,
        allowedModes: {CalendarMode.month, CalendarMode.day},
        currentDate: DateTime(2022, 3, 20),
        events: [
          CalendarEvent.fromJson({
            'title': 'Sleep',
            'initTime': '2022/03/20 01:00',
            'endTime': '2022/03/20 01:30',
          }),
          CalendarEvent('Meeting', DateTime(2022, 3, 20, 9, 0),
              DateTime(2022, 3, 20, 9, 30),
              description: 'Call'),
          CalendarEvent('Lunch', DateTime(2022, 3, 20, 13, 0),
              DateTime(2022, 3, 20, 14, 0),
              description: 'At X'),
          CalendarEvent('Dinner', DateTime(2022, 3, 20, 21, 0),
              DateTime(2022, 3, 20, 21, 40),
              description: 'At Y'),
          CalendarEvent.byDuration(
              'Wine', DateTime(2022, 3, 21, 21, 0), Duration(minutes: 40),
              description: 'Wine and cheese.'),
        ])
      ..onDayClick.listen((day) {
        _uiCalendarPopup!.currentDate = day;
        _uiCalendarPopup!.mode = CalendarMode.day;
      })
      ..onEventClick.listen((event) => window.alert('$event'));
  }

  UIDialogAlert _showAlert(String title, String text) => UIDialogAlert(
      '<div style="background-color: rgba(0,0,0, 0.80); width: 100%; padding: 4px 0;">$title</div><br>$text<br>',
      'OK',
      style:
          'width: 200px; overflow: hidden; border-radius: 8px; padding: 0px 0px 8px 0px; box-shadow: 0 6px 14px rgba(0,0,0, 0.60);')
    ..show();
}
