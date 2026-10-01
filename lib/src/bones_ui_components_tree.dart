import 'dart:async';
import 'dart:collection';

import 'package:web_utils/web_utils.dart';

import 'bones_ui_component.dart';

/// The tree of [UIComponent]s of a [UIRootComponent], keyed by the
/// components' `content` [Node]s.
///
/// Replaces `dom_tools`' `DOMTreeReferenceMap` for the [UIRootComponent]s:
///
/// - Keys are hashed by JS identity. With `dart2wasm` every JS object has the
///   same Dart `hashCode` (`0`), turning a plain `Map` keyed by DOM nodes into
///   a linear scan (O(n) per registration and lookup).
///
/// - Purged entries (components no longer in the tree) are held only weakly:
///   they can still be found and revalidated (if placed back in the tree)
///   while referenced elsewhere, or until [purgedEntriesTimeout], but they no
///   longer keep discarded components (and their DOM) alive.
class UIComponentsTree {
  /// The root [Node] of the tree.
  final Node root;

  /// Decides if an entry is valid without checking [isInTree]: returns `true`
  /// or `false`, or `null` to validate it by [isInTree]. Invalid entries are
  /// purged by [purge].
  final bool? Function(Node key, UIComponent value)? validator;

  /// Called with the entries purged by [purge].
  final void Function(Map<Node, UIComponent> purgedEntries)? onPurgedEntries;

  /// How long a purged entry can be resolved or revalidated.
  final Duration purgedEntriesTimeout;

  UIComponentsTree(
    this.root, {
    this.validator,
    this.onPurgedEntries,
    this.purgedEntriesTimeout = const Duration(minutes: 1),
  });

  final Map<Node, UIComponent> _map = _newNodeMap<UIComponent>();

  Map<Node, _PurgedEntry>? _purged;

  /// The number of registered (not purged) entries.
  int get length => _map.length;

  /// The number of purged entries (possibly already collected).
  int get purgedLength => _purged?.length ?? 0;

  void put(Node key, UIComponent value) {
    _map[key] = value;
    _purged?.remove(key);
  }

  UIComponent? get(Node key) => _map[key];

  UIComponent? getAlsoFromPurgedEntries(Node key) =>
      _map[key] ?? getFromPurgedEntries(key);

  UIComponent? getFromPurgedEntries(Node key) {
    final purged = _purged;
    if (purged == null) return null;

    final entry = purged[key];
    if (entry == null) return null;

    final value = entry.ref.target;
    if (value == null) purged.remove(key);
    return value;
  }

  bool _containsPurgedKey(Node key) => getFromPurgedEntries(key) != null;

  bool isValidEntry(Node key, UIComponent value) =>
      validator?.call(key, value) ?? isInTree(key);

  bool isInTree(Node? key) {
    if (key == null) return false;
    // `root` and `key` can't be in the same tree if only one is connected:
    if (root.isConnected != key.isConnected) return false;
    return root.contains(key);
  }

  /// Returns the closest ancestor value of [child].
  UIComponent? getParentValue(
    Node? child, {
    bool includePurgedEntries = false,
  }) {
    final parent = getParentKey(
      child,
      includePurgedEntries: includePurgedEntries,
    );
    if (parent == null) return null;
    return includePurgedEntries
        ? getAlsoFromPurgedEntries(parent)
        : get(parent);
  }

  /// Returns the closest ancestor key of [child].
  Node? getParentKey(Node? child, {bool includePurgedEntries = false}) {
    if (child == null || child == root) return null;

    var cursor = child.parentNode;
    while (cursor != null) {
      if (_map.containsKey(cursor) ||
          (includePurgedEntries && _containsPurgedKey(cursor))) {
        return cursor;
      }
      cursor = cursor.parentNode;
    }

    if (root.isConnected == child.isConnected && root.contains(child)) {
      return root;
    }

    return null;
  }

  /// Returns the values under [key] (excluding [key]), in depth-first order,
  /// not descending into the nodes of found values.
  List<UIComponent> getSubValues(
    Node? key, {
    bool includePurgedEntries = false,
  }) {
    final subValues = <UIComponent>[];
    if (key == null) return subValues;

    final stack = Queue<Node>();
    _pushChildrenReversed(key, stack);

    while (stack.isNotEmpty) {
      final current = stack.removeLast();

      final value = includePurgedEntries
          ? getAlsoFromPurgedEntries(current)
          : get(current);
      if (value != null) {
        subValues.add(value);
        continue;
      }

      _pushChildrenReversed(current, stack);
    }

    return subValues;
  }

  static void _pushChildrenReversed(Node node, Queue<Node> stack) {
    final children = node.childNodes;
    for (var i = children.length - 1; i >= 0; --i) {
      stack.add(children.item(i)!);
    }
  }

  List<MapEntry<Node, UIComponent>> get validEntries =>
      _map.entries.where((e) => isValidEntry(e.key, e.value)).toList();

  /// Returns `true` if any valid entry matches [test] (checked before the
  /// entry validity, that is more expensive).
  bool anyValidValue(bool Function(UIComponent value) test) =>
      _map.entries.any((e) => test(e.value) && isValidEntry(e.key, e.value));

  /// Moves the invalid entries to the purged entries (weakly referenced),
  /// and revalidates the purged entries back in the tree.
  void purge() {
    _revalidatePurgedEntries();
    _checkPurgedEntriesTimeout();

    final invalidKeys = _map.entries
        .where((e) => !isValidEntry(e.key, e.value))
        .map((e) => e.key)
        .toList();

    if (invalidKeys.isEmpty) return;

    final purged = _purged ??= _newNodeMap<_PurgedEntry>();
    final now = DateTime.now().millisecondsSinceEpoch;
    final onPurgedEntries = this.onPurgedEntries;
    final purgedEntries = <Node, UIComponent>{};

    for (var k in invalidKeys) {
      final value = _map.remove(k);
      if (value == null) continue;
      purged[k] = _PurgedEntry(WeakReference(value), now);
      if (onPurgedEntries != null) {
        purgedEntries[k] = value;
      }
    }

    if (purgedEntriesTimeout.inMilliseconds > 0) {
      Future.delayed(purgedEntriesTimeout, _checkPurgedEntriesTimeout);
    }

    if (onPurgedEntries != null && purgedEntries.isNotEmpty) {
      onPurgedEntries(purgedEntries);
    }
  }

  void _revalidatePurgedEntries() {
    final purged = _purged;
    if (purged == null || purged.isEmpty) return;

    purged.removeWhere((k, entry) {
      final value = entry.ref.target;
      if (value == null) return true;

      if (isValidEntry(k, value)) {
        _map[k] = value;
        return true;
      }

      return false;
    });
  }

  void _checkPurgedEntriesTimeout() {
    final purged = _purged;
    if (purged == null || purged.isEmpty) return;

    final timeoutMs = purgedEntriesTimeout.inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;

    purged.removeWhere(
      (k, entry) =>
          entry.ref.target == null || (now - entry.timeMs) >= timeoutMs,
    );
  }

  /// Removes all the purged entries.
  void disposePurgedEntries() {
    _purged = null;
  }

  @override
  String toString() =>
      'UIComponentsTree{length: $length, purgedLength: $purgedLength}';
}

class _PurgedEntry {
  final WeakReference<UIComponent> ref;
  final int timeMs;

  _PurgedEntry(this.ref, this.timeMs);
}

const bool _isWasm = bool.fromEnvironment('dart.tool.dart2wasm');

/// A [Map] keyed by DOM [Node]s. With `dart2wasm` the keys are hashed by JS
/// identity (see [UIComponentsTree]). With `dart2js` the default identity hash
/// of JS objects is already effective.
Map<Node, V> _newNodeMap<V>() => _isWasm
    ? LinkedHashMap<Node, V>(equals: _nodeEquals, hashCode: _nodeIdentityHash)
    : <Node, V>{};

bool _nodeEquals(Node a, Node b) => a == b;

@JS('WeakMap')
extension type _JSWeakMap._(JSObject _) implements JSObject {
  external _JSWeakMap();

  external JSAny? get(JSObject key);

  external void set(JSObject key, JSAny? value);
}

final _JSWeakMap _nodesIDs = _JSWeakMap();

int _nodesIDsCount = 0;

/// A stable identity hash for [node] (kept in a JS `WeakMap`).
int _nodeIdentityHash(Node node) {
  final id = _nodesIDs.get(node);
  if (id != null) return (id as JSNumber).toDartInt;

  final newID = ++_nodesIDsCount;
  _nodesIDs.set(node, newID.toJS);
  return newID;
}
