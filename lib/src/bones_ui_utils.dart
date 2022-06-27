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

bool containsIntlMessage(String s) {
  return s.contains('{{intl:') && s.contains('}}');
}
