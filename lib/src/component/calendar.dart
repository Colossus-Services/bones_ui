import 'dart:html';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:dom_builder/dom_builder.dart';
import 'package:dom_tools/dom_tools.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl_messages/intl_messages.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_component.dart';
import 'button.dart';
import 'dialog.dart';

enum CalendarMode { day, week, month }

extension CalendarModeExtension on CalendarMode {
  CalendarMode nextMode(
      {bool day = true, bool week = true, bool month = true}) {
    for (var i = index - 1; i >= 0; --i) {
      var v = CalendarMode.values[i];
      if (v == CalendarMode.day) {
        if (day) return v;
      } else if (v == CalendarMode.week) {
        if (week) return v;
      } else if (v == CalendarMode.month) {
        if (month) return v;
      }
    }

    return this;
  }

  CalendarMode previousMode(
      {bool day = true, bool week = true, bool month = true}) {
    for (var i = index + 1; i < CalendarMode.values.length; ++i) {
      var v = CalendarMode.values[i];
      if (v == CalendarMode.day) {
        if (day) return v;
      } else if (v == CalendarMode.week) {
        if (week) return v;
      } else if (v == CalendarMode.month) {
        if (month) return v;
      }
    }

    return this;
  }
}

/// A button component that shows an [UICalendar] dialog when clicked.
class UICalendarPopup extends UIComponent
    implements UIField<List<CalendarEvent>> {
  final String? _buttonText;

  @override
  final String fieldName;

  late final UIDialog _dialog;
  late final UICalendar _calendar;
  late final UIButton _button;

  UICalendarPopup(Element? parent,
      {String? buttonText,
      String? fieldName,
      DateTime? currentDate,
      List<CalendarEvent>? events,
      CalendarMode mode = CalendarMode.week,
      Iterable<CalendarMode>? allowedModes,
      int backgroundGrey = 0,
      double backgroundAlpha = 0.80,
      int? backgroundBlur})
      : fieldName = fieldName ?? 'calendar',
        _buttonText = buttonText,
        super(parent) {
    _calendar = UICalendar(
      null,
      fieldName: fieldName,
      currentDate: currentDate,
      events: events?.toList() ?? <CalendarEvent>[],
      mode: mode,
      allowedModes: allowedModes,
    );

    _dialog = UIDialog(
      _calendar,
      showCloseButton: true,
      backgroundGrey: backgroundGrey,
      backgroundAlpha: backgroundAlpha,
      backgroundBlur: backgroundBlur,
    );

    _button = UIButton(content, this.buttonText)
      ..onClick.listen((_) => showCalendar());

    _calendar.onChange.listen((_) => _updateButtonText());
  }

  void _updateButtonText() {
    _button.text = buttonText;
  }

  String get buttonText {
    if (_buttonText != null) return _buttonText!;

    var currentDate = _calendar.currentDate;
    return '${currentDate.year}/${currentDate.month}/${currentDate.day}';
  }

  @override
  dynamic render() {
    var text = buttonText;
    _button.text = text;
    return _button;
  }

  UICalendar get calendar => _calendar;

  void showCalendar() => _dialog.show();

  void hideCalendar() => _dialog.hide();

  DateTime get currentDate => _calendar.currentDate;

  set currentDate(DateTime date) => _calendar.currentDate = date;

  CalendarMode get mode => _calendar.mode;

  set mode(CalendarMode mode) => _calendar.mode = mode;

  List<CalendarEvent> get events => _calendar.events;

  set events(List<CalendarEvent> events) => _calendar.events = events;

  void addEvent(CalendarEvent event) => _calendar.addEvent(event);

  bool removeEvent(CalendarEvent event) => _calendar.removeEvent(event);

  @override
  List<CalendarEvent> getFieldValue() => _calendar.events;

  @override
  void setFieldValue(List<CalendarEvent>? value) =>
      _calendar.events = value ?? <CalendarEvent>[];

  @override
  EventStream<dynamic> get onChange => _calendar.onChange;

  EventStream<DateTime> get onTitleClick => _calendar.onTitleClick;

  EventStream<DateTime> get onHourClick => _calendar.onHourClick;

  EventStream<DateTime> get onDayClick => _calendar.onDayClick;

  EventStream<CalendarEvent> get onEventClick => _calendar.onEventClick;
}

/// A calendar component.
class UICalendar extends UIComponent implements UIField<List<CalendarEvent>> {
  static DateTime today() {
    var now = DateTime.now();
    return now.withTime();
  }

  @override
  final String fieldName;

  CalendarMode _mode;
  List<CalendarEvent> _events;

  int timeInterval;

  DateTime _currentDate;

  final DateTimeWeekDay firstDayOfWeek;

  Set<CalendarMode> _allowedModes;

  UICalendar(Element? parent,
      {String? fieldName,
      List<CalendarEvent>? events,
      CalendarMode mode = CalendarMode.week,
      int? timeInterval,
      DateTime? currentDate,
      DateTimeWeekDay? firstDayOfWeek,
      Iterable<CalendarMode>? allowedModes})
      : fieldName = fieldName ?? 'calendar',
        _mode = mode,
        _events = events?.toList() ?? <CalendarEvent>[],
        timeInterval = timeInterval ?? 60,
        _currentDate = currentDate ?? today(),
        firstDayOfWeek = firstDayOfWeek ?? _getFirstDayOfWeek(),
        _allowedModes = (allowedModes ?? CalendarMode.values).toSet(),
        super(parent);

  Set<CalendarMode> get allowedModes =>
      UnmodifiableSetView<CalendarMode>(_allowedModes);

  set allowedModes(Iterable<CalendarMode> modes) {
    var modesSet = modes.toSet();
    if (!SetEquality<CalendarMode>().equals(_allowedModes, modesSet)) {
      _allowedModes = modesSet;
      _notifyChange();
    }
  }

  DateTime get currentDate => _currentDate;

  set currentDate(DateTime date) {
    if (_currentDate != date) {
      _currentDate = date;
      _notifyChange();
    }
  }

  CalendarMode get mode => _mode;

  set mode(CalendarMode value) {
    if (value != _mode) {
      _mode = value;
      _notifyChange();
    }
  }

  List<CalendarEvent> get events => _events.toList();

  set events(List<CalendarEvent> events) {
    _events = events.toList();
    _notifyChange();
  }

  void addEvent(CalendarEvent event) {
    _events.add(event);
    _notifyChange();
  }

  bool removeEvent(CalendarEvent event) {
    if (_events.remove(event)) {
      _notifyChange();
      return true;
    }
    return false;
  }

  void _notifyChange() {
    _events.sort();
    _inputDateInteractionCompleter.cancel();
    onChange.add(this);
    refresh();
  }

  @override
  List<CalendarEvent>? getFieldValue() => _events.toList();

  @override
  void setFieldValue(List<CalendarEvent>? value) {
    _events.clear();
    if (value != null) _events.addAll(value);
  }

  List<CalendarEvent> selectEvents(DateTime init, DateTime end) =>
      _events.where((e) => e.isInTimeRange(init, end)).toList();

  @override
  dynamic render() {
    switch (_mode) {
      case CalendarMode.day:
        return _renderModeDay();
      case CalendarMode.week:
        return _renderModeWeek();
      case CalendarMode.month:
        return _renderModeMonth();
    }
  }

  final EventStream<DateTime> onTitleClick = EventStream<DateTime>();

  final EventStream<DateTime> onHourClick = EventStream<DateTime>();

  final EventStream<CalendarEvent> onEventClick = EventStream<CalendarEvent>();

  final InteractionCompleter _inputDateInteractionCompleter =
      InteractionCompleter('ui-calendar-input-date',
          triggerDelay: Duration(milliseconds: 1200));

  dynamic _renderModeDay() {
    var allowPrevMode = _allowedModes.contains(CalendarMode.month) ||
        _allowedModes.contains(CalendarMode.week);

    return $div(
        classes: 'ui-calendar-panel',
        style: 'min-width: 28ch',
        content: [
          $div(
              classes: 'ui-calendar-title',
              style: 'background-color: rgba(0,0,0, 0.50); padding: 2px',
              content: [
                if (allowPrevMode)
                  $span(
                      style: 'cursor: pointer; float: left;',
                      content: '&nbsp;&nbsp;&#8673;&nbsp;')
                    ..onClick.listen((evt) {
                      evt.cancel(stopImmediatePropagation: true);
                      mode = mode.previousMode(
                          week: _allowedModes.contains(CalendarMode.week),
                          month: _allowedModes.contains(CalendarMode.month));
                    }),
                $span(style: 'cursor: pointer;', content: '&larr;&nbsp;&nbsp;')
                  ..onClick.listen((evt) {
                    evt.cancel(stopImmediatePropagation: true);
                    previousDay();
                  }),
                _renderInputDate(textWithDay: true),
                $span(style: 'cursor: pointer;', content: '&nbsp;&nbsp;&rarr;')
                  ..onClick.listen((evt) {
                    evt.cancel(stopImmediatePropagation: true);
                    nextDay();
                  }),
                if (allowPrevMode)
                  $span(
                      style: 'visibility: hidden; float: right;',
                      content: '&nbsp;&uarr;&nbsp;&nbsp;'),
              ])
            ..onClick.listen((_) => onTitleClick.add(_currentDate)),
          $div(
              style:
                  'overflow-y: scroll; max-height: calc(100vh - 120px); max-width: calc(100vw - 12px)',
              content: [
                $table(
                    classes: 'ui-calendar-grid',
                    style:
                        'border-collapse: collapse; border-top: 1px solid #000; width: 100%;',
                    trsStyle:
                        'border-left: 1px solid #000; border-right: 1px solid #000; border-bottom: 1px solid #000;',
                    tdsStyle:
                        'text-align: left; vertical-align: top; padding: 2px',
                    body: [
                      for (var t in _dayHours(timeInterval))
                        [
                          $td(
                              classes: 'ui-calendar-hour-cell',
                              style:
                                  'background-color: rgba(0,0,0, 0.50); width: 6ch; word-wrap: break-word; text-align: center;',
                              content:
                                  '${t.a.toString().padLeft(2, '0')}:${t.b.toString().padLeft(2, '0')}&nbsp;'),
                          $td(
                              content: selectEvents(
                                      _currentDate.withTime(t.a, t.b),
                                      _currentDate
                                          .withTime(t.a, t.b)
                                          .add(Duration(minutes: timeInterval)))
                                  .map((e) => e.render()
                                    ..onClick
                                        .listen((_) => onEventClick.add(e)))
                                  .toList())
                            ..onClick.listen((event) => onHourClick
                                .add(_currentDate.withTime(t.a, t.b))),
                        ]
                    ])
              ])
            ..onGenerate.listen((element) {
              if (element is Element) {
                blockVerticalScrollTraverse(element);
              }
            })
        ]);
  }

  DIVElement _renderInputDate({required bool textWithDay}) {
    var dateStr =
        _currentDate.toStringParts(year: true, month: true, day: true);

    var elemText = $span(
        id: 'ui-calendar-day-date-text',
        style: 'display: inline',
        content: (textWithDay ? dateStr : dateStr.sublist(0, 2)).join('/'));

    var elemInput = $input(
        classes: 'ui-calendar-input-date',
        id: 'ui-calendar-day-input-date',
        style: 'display: none',
        type: 'date',
        value: dateStr.join('-'));

    elemInput.onChange.listen((_) {
      var date = parseDateTime(elemInput.runtime.value);

      if (date != null) {
        elemText.runtime.text =
            date.toStringParts(year: true, month: true, day: true).join('/');

        _inputDateInteractionCompleter.interact();
      }
    });

    var div =
        $div(style: 'display: inline-block;', content: [elemText, elemInput]);

    bool isShowingInput() =>
        elemInput.runtime.getStyleProperty('display') == 'inline';

    bool swap() {
      _inputDateInteractionCompleter.cancel();

      if (isShowingInput()) {
        elemInput.runtime.setStyleProperty('display', 'none');
        elemText.runtime.setStyleProperty('display', 'inline');

        return false;
      } else {
        elemText.runtime.setStyleProperty('display', 'none');
        elemInput.runtime.setStyleProperty('display', 'inline');

        return true;
      }
    }

    _inputDateInteractionCompleter.cancel();

    _inputDateInteractionCompleter.functionToTrigger = () {
      if (!swap()) {
        var date = parseDateTime(elemInput.runtime.value);

        if (date != null) {
          currentDate = date;
        }
      }
    };

    div.onClick.listen((evt) {
      if (!isShowingInput()) {
        swap();
        evt.cancel(stopImmediatePropagation: true);
      } else {
        _inputDateInteractionCompleter.cancel();
        _inputDateInteractionCompleter.interact(noTriggering: true);
      }
    });

    return div;
  }

  dynamic _renderModeWeek() {}

  dynamic _renderModeMonth() {
    var today = UICalendar.today();

    return $div(
        classes: 'ui-calendar-panel',
        style: 'min-width: 18ch',
        content: [
          $div(
              classes: 'ui-calendar-title',
              style: 'background-color: rgba(0,0,0, 0.50); padding: 2px',
              content: [
                $span(style: 'cursor: pointer;', content: '&larr;&nbsp;&nbsp;')
                  ..onClick.listen((_) => previousMonth()),
                _renderInputDate(textWithDay: false),
                $span(style: 'cursor: pointer;', content: '&nbsp;&nbsp;&rarr;')
                  ..onClick.listen((_) => nextMonth()),
              ])
            ..onClick.listen((_) => onTitleClick.add(_currentDate)),
          $div(
              style:
                  'overflow-y: scroll; max-height: calc(100vh - 40px); max-width: calc(100vw - 12px)',
              content: [
                $table(
                    classes: 'ui-calendar-grid',
                    style:
                        'border-collapse: collapse; border-top: 1px solid #000; width: 100%;',
                    trsStyle:
                        'border-left: 1px solid #000; border-right: 1px solid #000; border-bottom: 1px solid #000;',
                    tdsStyle:
                        'text-align: left; vertical-align: top; padding: 2px',
                    body: [
                      _weekDays(firstDayOfWeek)
                          .map((w) => $td(
                              classes: 'ui-calendar-week-cell',
                              style: 'text-align: center; min-width: 3ch',
                              content:
                                  '${IntlBasicDictionary.msg('week_day_$w')?.truncate(3)}'))
                          .toList(),
                      for (var week in _monthDaysPerWeek(_currentDate.year,
                          _currentDate.month, firstDayOfWeek))
                        week
                            .map((day) =>
                                _renderMonthDay(day, _currentDate, today))
                            .toList()
                    ])
              ])
        ]);
  }

  final EventStream<DateTime> onDayClick = EventStream<DateTime>();

  DOMElement _renderMonthDay(
      DateTime day, DateTime currentDate, DateTime today) {
    var dayEvents = selectEvents(day, day.endOfDayTime);

    var div = $div(content: [
      $div(
          style: 'width: 100%; text-align: center; cursor: pointer;',
          content: day.day),
      if (dayEvents.isNotEmpty)
        $div(
            style: 'line-height: 26%; width: 100%; text-align: center;',
            content:
                List.generate(math.min(dayEvents.length, 4), (_) => '&bull;')
                    .join()),
    ]);

    div.appendToAttribute('class', 'ui-calendar-day-cell');

    if (day == today) {
      div.appendToAttribute('class', 'ui-calendar-today-cell');
      div.style['font-weight'] = 'bold';
    }

    if (day.month != currentDate.month) {
      div.appendToAttribute('class', 'ui-calendar-out-of-month-cell');
      div.style.opacity = '0.3';
    }

    if (dayEvents.isNotEmpty) {
      div.style['cursor'] = 'pointer';
      div.appendToAttribute('class', 'ui-calendar-day-with-event');
    }

    div.onClick.listen((_) => onDayClick.add(day));

    return div;
  }

  void nextDay() {
    currentDate = _currentDate.nextDay;
  }

  void previousDay() {
    currentDate = _currentDate.previousDay;
  }

  void nextMonth() {
    currentDate = _currentDate.nextMonth;
  }

  void previousMonth() {
    currentDate = _currentDate.previousMonth;
  }
}

class CalendarEvent implements Comparable<CalendarEvent> {
  String title;

  DateTime initTime;
  DateTime endTime;
  String description;

  CalendarEvent(this.title, this.initTime, this.endTime, {String? description})
      : description = description ?? '' {
    if (endTime.compareTo(initTime) < 0) {
      throw ArgumentError(
          'endTime <  initTime: initTime:$initTime .. endTime:$endTime');
    }
  }

  CalendarEvent.byDuration(String title, DateTime initTime, Duration duration,
      {String? description})
      : this(title, initTime, initTime.add(duration), description: description);

  bool isInTimeRange(DateTime init, DateTime end) {
    var a = init.compareTo(initTime) <= 0;
    var b = end.compareTo(endTime) >= 0;
    var c = a && b;
    return c;
  }

  @override
  int compareTo(CalendarEvent other) {
    var cmp = initTime.compareTo(other.initTime);
    if (cmp == 0) {
      cmp = endTime.compareTo(other.endTime);
    }
    return cmp;
  }

  Duration get duration => endTime.difference(initTime);

  DIVElement render() => $div(
          classes: 'ui-calendar-day-events-cell',
          style: 'cursor: pointer;',
          content: [
            $span(
                style: 'font-size: 90%',
                content: description.isNotEmpty ? '$title:<br>' : title),
            if (description.isNotEmpty)
              $span(style: 'font-size: 70%', content: description)
          ]);

  @override
  String toString() {
    return 'CalendarEvent{title: $title, initTime: $initTime, endTime: $endTime}';
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        json['title'],
        _parseDateTime(json['initTime'])!,
        _parseDateTime(json['endTime'])!,
        description: json['description'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'initTime': initTime.formatYYYY_MM_DD_HH_mm,
        'endTime': endTime.formatYYYY_MM_DD_HH_mm,
        if (description.isNotEmpty) 'description': description,
      };
}

extension _StringExtension on String {
  String truncate(int maxLength) {
    return length > maxLength ? substring(0, maxLength) : this;
  }
}

void _initializeDateFormatting() {
  var locale = Intl.defaultLocale;
  if (locale == null || locale.isEmpty) locale = 'en';
  initializeDateFormatting(locale, null);
}

final _dateFormat1 = DateFormat('yyyy/MM/dd HH:mm');
final _dateFormat2 = DateFormat('yyyy/MM/dd HH:mm:ss');
final _dateFormat3 = DateFormat('yyyy-MM-dd HH:mm');
final _dateFormat4 = DateFormat('yyyy-MM-dd HH:mm:ss');

DateTime? _parseDateTime(String? s) {
  if (s == null) return null;
  s = s.trim();
  if (s.isEmpty) return null;

  return DateTime.tryParse(s) ??
      _tryParseDateTime(_dateFormat1, s) ??
      _tryParseDateTime(_dateFormat2, s) ??
      _tryParseDateTime(_dateFormat3, s) ??
      _tryParseDateTime(_dateFormat4, s);
}

DateTime? _tryParseDateTime(DateFormat format, String s) {
  try {
    return format.parseLoose(s);
  } catch (_) {
    return null;
  }
}

extension _DateTimeExtension on DateTime {
  // ignore: non_constant_identifier_names
  String get formatYYYY_MM_DD_HH_mm {
    _initializeDateFormatting();
    return _dateFormat1.format(this);
  }

  List<String> toStringParts({
    bool year = false,
    bool month = false,
    bool day = false,
    bool hour = false,
    bool minute = false,
    bool second = false,
    bool millisecond = false,
    bool microsecond = false,
  }) =>
      <String>[
        if (year) this.year.toString().padLeft(4, '0'),
        if (month) this.month.toString().padLeft(2, '0'),
        if (day) this.day.toString().padLeft(2, '0'),
        if (hour) this.hour.toString().padLeft(2, '0'),
        if (minute) this.minute.toString().padLeft(2, '0'),
        if (second) this.second.toString().padLeft(2, '0'),
        if (millisecond) this.millisecond.toString().padLeft(3, '0'),
        if (microsecond) this.microsecond.toString().padLeft(3, '0'),
      ];

  DateTime withTime([int hour = 0, int min = 0, int sec = 0]) =>
      DateTime(year, month, day, hour, min, sec, 0, 0);

  DateTime get endOfDayTime => DateTime(year, month, day, 23, 59, 59, 999, 999);

  DateTime withDay(int day) => DateTime(
      year, month, day, hour, minute, second, millisecond, microsecond);

  // ignore: unused_element
  DateTime withMonth(int month, {int? year, int? day}) {
    year ??= this.year;
    day ??= this.day;

    month = _clipMonth(month);
    day = _clipDay(year, month, day);

    return DateTime(
        year, month, day, hour, minute, second, millisecond, microsecond);
  }

  // ignore: unused_element
  int clipDay(int day) => _clipDay(year, month, day);

  int get lastDayOfMonth {
    var cursor = DateTime(year, month, 28);
    var lastDay = cursor;

    while (cursor.month == month) {
      lastDay = cursor;
      cursor = cursor.add(Duration(days: 1));
    }

    return lastDay.day;
  }

  bool get isFirstMonthOfYear => month == 1;

  bool get isLastMonthOfYear => month == 12;

  bool get isFirstDayOfMonth => day == 1;

  bool get isLastDayOfMonth => day >= 28 && day == lastDayOfMonth;

  DateTime get withLastDayOfMonth => withDay(lastDayOfMonth);

  DateTime get previousMonth => isFirstMonthOfYear
      ? DateTime(year - 1, 12).withLastDayOfMonth
      : DateTime(year, month - 1).withLastDayOfMonth;

  DateTime get nextMonth => isLastMonthOfYear
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);

  DateTime get previousDay =>
      isFirstDayOfMonth ? previousMonth : withDay(day - 1);

  DateTime get nextDay => isLastDayOfMonth ? nextMonth : withDay(day + 1);
}

int _clipMonth(int month) => month.clamp(1, 12);

int _clipDay(int year, int month, int day) {
  if (day < 1) return 1;

  var lastMonthDay = _monthDays(year, month).last;
  if (day > lastMonthDay) {
    return lastMonthDay;
  }

  return day;
}

DateTimeWeekDay _getFirstDayOfWeek() {
  var currentLocale = getCurrentLocale();
  return getWeekFirstDay(currentLocale);
}

List<Pair<int>> _dayHours(int minuteInterval) {
  var list = <Pair<int>>[];

  for (var h = 0; h < 24; ++h) {
    for (var m = 0; m < 60; m += minuteInterval) {
      list.add(Pair<int>(h, m));
    }
  }

  return list;
}

List<int> _monthDays(int year, int month) {
  var list = <int>[];

  var cursor = DateTime(year, month);

  while (cursor.month == month) {
    list.add(cursor.day);
    cursor = cursor.add(Duration(days: 1));
  }

  return list;
}

List<List<DateTime>> _monthDaysPerWeek(
    int year, int month, DateTimeWeekDay firstDayOfWeek) {
  var datePrevMonth =
      (month == 1 ? DateTime(year - 1, 12) : DateTime(year, month - 1))
          .withLastDayOfMonth;
  var dateNextMonth =
      (month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1));
  var date = DateTime(year, month);

  var days = _monthDays(year, month);

  var list = <List<DateTime>>[];

  var weekDays = _weekDays(firstDayOfWeek);

  DateTime? day = date.withDay(days.removeAt(0));

  while (days.isNotEmpty) {
    var daysBeforeMonth = <DateTime>[];
    var week = <DateTime>[];

    for (var weekDay in weekDays) {
      if (day == null) {
        week.add(dateNextMonth);
        dateNextMonth = dateNextMonth.nextDay;
      } else if (day.weekday == weekDay) {
        if (daysBeforeMonth.isNotEmpty) {
          week.addAll(daysBeforeMonth.reversed);
          daysBeforeMonth.clear();
        }
        week.add(day);
        day = days.isNotEmpty ? date.withDay(days.removeAt(0)) : null;
      } else {
        daysBeforeMonth.add(datePrevMonth);
        datePrevMonth = datePrevMonth.previousDay;
      }
    }

    list.add(week);
  }

  while (list.length < 6) {
    var week = <DateTime>[];
    while (week.length < 7) {
      week.add(dateNextMonth);
      dateNextMonth = dateNextMonth.nextDay;
    }
    list.add(week);
  }

  return list;
}

List<int> _weekDays(DateTimeWeekDay firstDayOfWeek) {
  var weekDays = List<int>.generate(7, (i) => i + 1);

  if (firstDayOfWeek.index != 0) {
    var init = weekDays.sublist(firstDayOfWeek.index);
    var end = weekDays.sublist(0, firstDayOfWeek.index);
    weekDays = <int>[...init, ...end];
  }

  return weekDays;
}
