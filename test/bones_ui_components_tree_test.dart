@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:bones_ui/src/bones_ui_components_tree.dart';
import 'package:test/test.dart';

/// Tests of [UIComponentsTree], the tree of components of a `UIRootComponent`
/// (keyed by DOM nodes, hashed by JS identity with `dart2wasm`).
void main() {
  setUpAll(() async {
    await initializeTestUIRoot(_Root.new);
  });

  late HTMLDivElement root;

  setUp(() {
    root = HTMLDivElement()..id = 'tree-root';
    document.body!.appendChild(root);
    addTearDown(() => root.remove());
  });

  test('put / get / length', () {
    final tree = UIComponentsTree(root);
    final c1 = _Comp('c1');
    final c2 = _Comp('c2');
    root.appendChild(c1.content!);
    root.appendChild(c2.content!);

    tree.put(c1.content!, c1);
    tree.put(c2.content!, c2);

    expect(tree.length, equals(2));
    expect(tree.get(c1.content!), same(c1));
    expect(tree.get(c2.content!), same(c2));
    expect(tree.get(HTMLDivElement()), isNull);

    // Overwrite:
    tree.put(c1.content!, c2);
    expect(tree.length, equals(2));
    expect(tree.get(c1.content!), same(c2));
  });

  test('many keys (hashing by identity)', () {
    final tree = UIComponentsTree(root);
    final comps = [for (var i = 0; i < 1000; ++i) _Comp('c$i')];
    for (final c in comps) {
      root.appendChild(c.content!);
      tree.put(c.content!, c);
    }

    expect(tree.length, equals(1000));
    for (final c in comps) {
      expect(tree.get(c.content!), same(c));
    }

    // A node re-read from the DOM (possibly a distinct Dart wrapper):
    final reRead = root.children.item(500)!;
    expect(tree.get(reRead), same(comps[500]));
  });

  test('getParentValue / getParentKey / getSubValues', () {
    final tree = UIComponentsTree(root);

    final outer = _Comp('outer');
    final inner1 = _Comp('inner1');
    final inner2 = _Comp('inner2');
    final deep = _Comp('deep');

    final wrapper = HTMLDivElement();
    root.appendChild(outer.content!);
    outer.content!.appendChild(wrapper);
    wrapper.appendChild(inner1.content!);
    outer.content!.appendChild(inner2.content!);
    inner1.content!.appendChild(deep.content!);

    for (final c in [outer, inner1, inner2, deep]) {
      tree.put(c.content!, c);
    }

    final leaf = HTMLSpanElement();
    deep.content!.appendChild(leaf);

    expect(tree.getParentValue(leaf), same(deep));
    expect(tree.getParentValue(deep.content), same(inner1));
    expect(tree.getParentValue(inner1.content), same(outer));
    expect(tree.getParentValue(wrapper), same(outer));
    expect(tree.getParentKey(outer.content), same(root));
    expect(tree.getParentValue(outer.content), isNull);
    expect(tree.getParentKey(root), isNull);
    expect(tree.getParentKey(HTMLDivElement()), isNull);

    // Depth-first, not descending into found values:
    expect(tree.getSubValues(root), equals([outer]));
    expect(tree.getSubValues(outer.content), equals([inner1, inner2]));
    expect(tree.getSubValues(inner1.content), equals([deep]));
    expect(tree.getSubValues(null), isEmpty);
  });

  test('isInTree', () {
    final tree = UIComponentsTree(root);
    final c = _Comp('c');
    expect(tree.isInTree(c.content), isFalse);
    root.appendChild(c.content!);
    expect(tree.isInTree(c.content), isTrue);
    expect(tree.isInTree(root), isTrue);
    expect(tree.isInTree(null), isFalse);
  });

  test('purge / purged entries / revalidation', () {
    final purgedCalls = <Map<Node, UIComponent>>[];

    final tree = UIComponentsTree(root, onPurgedEntries: purgedCalls.add);
    final c1 = _Comp('c1');
    final c2 = _Comp('c2');
    root.appendChild(c1.content!);
    root.appendChild(c2.content!);
    tree.put(c1.content!, c1);
    tree.put(c2.content!, c2);

    tree.purge();
    expect(purgedCalls, isEmpty);
    expect(tree.length, equals(2));

    c2.content!.remove();
    tree.purge();

    expect(purgedCalls.length, equals(1));
    expect(purgedCalls.single.values, equals([c2]));
    expect(tree.length, equals(1));
    expect(tree.purgedLength, equals(1));

    // Purged: only resolvable including the purged entries:
    expect(tree.get(c2.content!), isNull);
    expect(tree.getAlsoFromPurgedEntries(c2.content!), same(c2));
    expect(tree.getFromPurgedEntries(c2.content!), same(c2));

    final child = HTMLSpanElement();
    c2.content!.appendChild(child);
    expect(tree.getParentValue(child), isNull);
    expect(tree.getParentValue(child, includePurgedEntries: true), same(c2));

    // Back in the tree: revalidated by the next purge:
    root.appendChild(c2.content!);
    tree.purge();
    expect(tree.get(c2.content!), same(c2));
    expect(tree.purgedLength, equals(0));
    expect(purgedCalls.length, equals(1));

    // Put removes a purged entry:
    c1.content!.remove();
    tree.purge();
    expect(tree.purgedLength, equals(1));
    tree.put(c1.content!, c1);
    expect(tree.purgedLength, equals(0));

    // Dispose purged entries:
    c1.content!.remove();
    tree.purge();
    expect(tree.getAlsoFromPurgedEntries(c1.content!), same(c1));
    tree.disposePurgedEntries();
    expect(tree.getAlsoFromPurgedEntries(c1.content!), isNull);
  });

  test('purgedEntriesTimeout', () async {
    final tree = UIComponentsTree(
      root,
      purgedEntriesTimeout: Duration(milliseconds: 10),
    );
    final c = _Comp('c');
    tree.put(c.content!, c);

    tree.purge();
    expect(tree.getAlsoFromPurgedEntries(c.content!), same(c));

    await Future.delayed(Duration(milliseconds: 50));

    // Expired (by the timer scheduled by `purge`, or by the next `purge`,
    // without depending on the timer precision):
    tree.purge();
    expect(tree.purgedLength, equals(0));
    expect(tree.getAlsoFromPurgedEntries(c.content!), isNull);
  });

  test('validator', () {
    final tree = UIComponentsTree(
      root,
      validator: (key, value) => value.id == 'keep' ? true : null,
    );
    final keep = _Comp('keep');
    final drop = _Comp('drop');
    tree.put(keep.content!, keep);
    tree.put(drop.content!, drop);

    // Neither is in the tree, but `keep` is valid by the validator:
    expect(tree.isValidEntry(keep.content!, keep), isTrue);
    expect(tree.isValidEntry(drop.content!, drop), isFalse);

    tree.purge();
    expect(tree.get(keep.content!), same(keep));
    expect(tree.get(drop.content!), isNull);

    expect(tree.validEntries.map((e) => e.value), equals([keep]));
    expect(tree.anyValidValue((c) => c.id == 'keep'), isTrue);
    expect(tree.anyValidValue((c) => c.id == 'drop'), isFalse);
  });
}

class _Root extends UIRoot {
  _Root(super.rootContainer);

  @override
  UIComponent? renderContent() => null;
}

class _Comp extends UIComponent {
  _Comp(String id) : super(null, id: id);

  @override
  dynamic render() => 'comp $id';
}
