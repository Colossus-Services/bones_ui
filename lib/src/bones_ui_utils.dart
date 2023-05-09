import 'dart:html';

import 'package:dom_builder/dom_builder.dart';
import 'package:collection/collection.dart';

/// Returns a [StackTrace] ensuring that no error will be thrown.
StackTrace stackTraceSafe() {
  try {
    var s = StackTrace.current;
    return s;
  } catch (e) {
    print('Error getting current StackTrace');
    print(e);
    return StackTrace.empty;
  }
}

/// Returns `true` if [value] is empty.
bool isEmptyValue(Object? value) {
  if (value == null) return true;

  if (value is Iterable) {
    return value.isEmpty;
  } else if (value is Map) {
    return value.isEmpty;
  } else {
    var s = value.toString();
    return s.isEmpty;
  }
}

/// Returns `true` if [s] contains an `{{intl:...}}` message.
bool containsIntlMessage(String s) {
  return s.contains('{{intl:') && s.contains('}}');
}

/// Resolves [o] to a text.
String? resolveToText(Object? o) {
  if (o == null) return null;

  if (o is String) {
    return o;
  } else if (o is Iterable) {
    var l = o.whereNotNull().map(resolveToText).whereNotNull().toList();
    return l.isEmpty ? null : l.join();
  } else if (o is Element) {
    return o.text;
  } else if (o is DOMElement) {
    return o.text;
  } else {
    return o.toString();
  }
}
