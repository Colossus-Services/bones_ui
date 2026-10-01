@TestOn('browser')
library;

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

/// Tests of the automatic purge of the [UIRoot] after rendering.
void main() {
  late _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot(_Root.new);
    await uiRoot.callRenderAndWait();
  });

  for (final sliceTime in [Duration.zero, UIComponent.purgeSliceTime]) {
    test('purges removed components (purgeSliceTime: $sliceTime)', () async {
      final prevSliceTime = UIComponent.purgeSliceTime;
      UIComponent.purgeSliceTime = sliceTime;
      addTearDown(() => UIComponent.purgeSliceTime = prevSliceTime);

      final list = _List(uiRoot.content, 50);
      addTearDown(list.delete);
      await list.callRenderAndWait();

      final kept = list.items.first;
      final removed = list.items.last;
      expect(uiRoot.getUIComponentByContent(removed.content), same(removed));

      removed.content!.remove();

      // Render again (the purge runs after the rendering finishes):
      kept.refresh();
      await Future.delayed(Duration(milliseconds: 1500));

      expect(uiRoot.getUIComponentByContent(removed.content), isNull);
      expect(uiRoot.getUIComponentByContent(kept.content), same(kept));
    });
  }
}

class _Root extends UIRoot {
  _Root(super.rootContainer);

  @override
  UIComponent? renderContent() => null;
}

class _List extends UIComponent {
  final int size;

  late final List<_Item> items = [for (var i = 0; i < size; ++i) _Item(i)];

  _List(super.parent, this.size);

  @override
  dynamic render() => items;
}

class _Item extends UIComponent {
  final int index;

  _Item(this.index) : super(null);

  @override
  dynamic render() => $span(content: 'item $index');
}
