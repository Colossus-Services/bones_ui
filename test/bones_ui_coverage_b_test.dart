@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_ui/bones_ui_test.dart';
import 'package:swiss_knife/swiss_knife.dart' show DataURLBase64;
import 'package:test/test.dart';

/// Integration tests (real DOM) for the less covered paths of `capture.dart`,
/// `dialog_edit_image.dart` and `masonry.dart`.

class _Root extends UIRoot {
  _Root(super.rootContainer) : super(id: 'coverage-b-root');

  @override
  UIComponent? renderContent() => null;
}

/// A PNG of [w] x [h] pixels (red).
Uint8List _pngBytes(int w, int h) {
  var canvas = HTMLCanvasElement()
    ..width = w
    ..height = h;
  var ctx = canvas.context2D;
  ctx.fillStyle = 'red'.toJS;
  ctx.fillRect(0, 0, w, h);
  var dataURL = canvas.toDataUrl('image/png');
  return base64.decode(dataURL.split(',')[1]);
}

/// A PNG of [w] x [h] pixels: a 4px red border around a blue rectangle.
Uint8List _borderedPngBytes(int w, int h) {
  var canvas = HTMLCanvasElement()
    ..width = w
    ..height = h;
  var ctx = canvas.context2D;
  ctx.fillStyle = 'rgb(255,0,0)'.toJS;
  ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = 'rgb(0,0,255)'.toJS;
  ctx.fillRect(4, 4, w - 8, h - 8);
  var dataURL = canvas.toDataUrl('image/png');
  return base64.decode(dataURL.split(',')[1]);
}

File _pngFile(
  int w,
  int h, {
  String name = 'photo.png',
  String? type,
  bool bordered = false,
}) => File(
  <JSAny>[(bordered ? _borderedPngBytes(w, h) : _pngBytes(w, h)).toJS].toJS,
  name,
  FilePropertyBag(type: type ?? 'image/png'),
);

Future<List<int>> _pixelOf(String dataURL, int x, int y) async {
  var img = await _loadImage(dataURL);
  var canvas = HTMLCanvasElement()
    ..width = img.naturalWidth
    ..height = img.naturalHeight;
  var ctx = canvas.context2D;
  ctx.drawImage(img, 0, 0);
  return ctx.getImageData(x, y, 1, 1).data.toDart.toList();
}

File _textFile(String name, String content, [String type = 'text/plain']) =>
    File(<JSAny>[content.toJS].toJS, name, FilePropertyBag(type: type));

/// Selects [file] in the [capture] input and waits for the capture.
Future<void> _selectFile(UICapture capture, File file) async {
  var input = capture.getInputCapture() as HTMLInputElement;
  var dataTransfer = DataTransfer();
  dataTransfer.items.add(file);
  input.files = dataTransfer.files;

  var captured = capture.onCapture.first;
  input.dispatchEvent(Event('change'));
  await captured.timeout(Duration(seconds: 10));
}

Future<HTMLImageElement> _loadImage(String src) async {
  var img = HTMLImageElement();
  var loaded = img.onLoad.first;
  img.src = src;
  await loaded;
  return img;
}

MouseEvent _mouse(String type, Element target, num x, num y) {
  var r = target.getBoundingClientRect();
  return MouseEvent(
    type,
    MouseEventInit(
      clientX: (r.left + x).round(),
      clientY: (r.top + y).round(),
      bubbles: true,
      cancelable: true,
    ),
  );
}

TouchEvent _touch(String type, Element target, List<List<num>> points) {
  var r = target.getBoundingClientRect();
  var touches = <Touch>[
    for (var i = 0; i < points.length; ++i)
      Touch(
        TouchInit(
          identifier: i + 1,
          target: target,
          clientX: r.left + points[i][0],
          clientY: r.top + points[i][1],
        ),
      ),
  ];
  return TouchEvent(
    type,
    TouchEventInit(touches: touches.toJS, bubbles: true, cancelable: true),
  );
}

Future<UIDialogEditImage> _showEditImageDialog(int w, int h) async {
  var image = await _loadImage(
    'data:image/png;base64,${base64.encode(_borderedPngBytes(w, h))}',
  );
  var dialog = UIDialogEditImage(image);
  dialog.show();
  await testUISleep(ms: 300);
  return dialog;
}

HTMLElement _buttonWithText(UIDialog dialog, String text) =>
    dialog.content!
            .querySelectorAll('button')
            .toElements()
            .firstWhere((b) => b.textContent!.trim() == text)
        as HTMLElement;

void main() {
  late final _Root uiRoot;

  setUpAll(() async {
    uiRoot = await initializeTestUIRoot((rootContainer) {
      return _Root(rootContainer);
    });
    await uiRoot.callRenderAndWait();
  });

  tearDown(() {
    UIDialog.removeAllDialogs();
  });

  /// A container attached to the root, removed after the test.
  HTMLDivElement newHolder() {
    var holder = HTMLDivElement();
    uiRoot.content!.append(holder);
    addTearDown(() => holder.remove());
    return holder;
  }

  group('UICapture', () {
    test('a click opens the (reset) file input', () async {
      var capture = UIButtonCapture(newHolder(), 'Pick', CaptureType.file);
      await capture.callRenderAndWait();

      var input = capture.getInputCapture() as HTMLInputElement;
      expect(input.type, equals('file'));
      expect(input.hasAttribute('hidden'), isTrue);

      var inputClicks = 0;
      input.addEventListener(
        'click',
        ((Event e) {
          inputClicks++;
          // Don't open a file chooser:
          e.preventDefault();
        }).toJS,
      );

      capture.content!.click();
      await testUISleep(ms: 20);

      expect(inputClicks, equals(1));
      expect(input.value, isEmpty);
    });

    test('reads a file as string, URL and Blob URL', () async {
      var capture = UIButtonCapture(newHolder(), 'Read', CaptureType.file);
      await capture.callRenderAndWait();

      capture.captureDataFormat = CaptureDataFormat.string;
      await _selectFile(capture, _textFile('a.txt', 'hello'));
      expect(capture.selectedFileData, equals('hello'));
      expect(capture.selectedFileDataAsString, equals('hello'));

      // A data URL read in the `url` format is kept as a `DataURLBase64`
      // (not a `String`, as `CaptureDataFormat.url` documents):
      capture.captureDataFormat = CaptureDataFormat.url;
      await _selectFile(capture, _textFile('b.txt', 'world'));
      expect(capture.selectedFileData, isA<DataURLBase64>());
      var url = capture.selectedFileData.toString();
      expect(url, startsWith('data:text/plain'));
      expect(capture.selectedFileDataAsString, equals('world'));
      expect(capture.getFieldValue(), equals(url));

      capture.captureDataFormat = CaptureDataFormat.urlOrBlobUrl;
      await _selectFile(capture, _textFile('c.txt', 'blob!'));
      expect(capture.selectedFileData as String, startsWith('blob:'));
      expect(capture.selectedFile!.name, equals('c.txt'));

      // Shown in the button (only the last file name):
      var spans = capture.content!.querySelectorAll('span').toElements();
      expect(spans.map((e) => e.textContent), equals(['c.txt']));
    });

    test('a max width on a non-photo capture keeps the data', () async {
      var capture = UIButtonCapture(newHolder(), 'File', CaptureType.file)
        ..captureMaxWidth = 1;
      await capture.callRenderAndWait();

      await _selectFile(capture, _textFile('d.txt', 'not an image'));
      expect(capture.selectedFileDataAsString, equals('not an image'));
    });

    test('initial data is shown on render (without a file name)', () async {
      var capture = UIButtonCapture(null, 'Init', CaptureType.file);
      capture.setFieldValue(base64.encode(utf8.encode('init')));
      expect(capture.hasSelectedFileData, isTrue);

      newHolder().append(capture.content!);
      await capture.callRenderAndWait();

      expect(capture.content!.textContent, contains('Init'));
      expect(capture.content!.querySelector('span'), isNull);
      expect(capture.selectedFileDataAsString, equals('init'));
    });

    test('crops to a wide aspect ratio', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.dataUrlBase64,
        captureAspectRatio: 4,
      );
      await capture.callRenderAndWait();

      await _selectFile(capture, _pngFile(20, 10));

      var img = await _loadImage(capture.selectedFileDataAsDataURLBase64!);
      expect(img.naturalWidth, equals(20));
      expect(img.naturalHeight, equals(5));
    });

    test('scales a photo in URL format', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.url,
        captureMaxHeight: 4,
      );
      await capture.callRenderAndWait();

      await _selectFile(capture, _pngFile(16, 8));

      var url = capture.selectedFileData.toString();
      expect(url, startsWith('data:image/png'), reason: 'The file MIME type');

      var img = await _loadImage(url);
      expect(img.naturalWidth, equals(8));
      expect(img.naturalHeight, equals(4));
    });

    test('scales a photo without a MIME type to JPEG', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.dataUrlBase64,
        captureMaxWidth: 5,
      );
      await capture.callRenderAndWait();

      await _selectFile(capture, _pngFile(10, 10, name: 'photo', type: ''));

      var url = capture.selectedFileDataAsDataURLBase64!;
      expect(url, startsWith('data:image/jpeg'));

      var img = await _loadImage(url);
      expect(img.naturalWidth, equals(5));
      expect(img.naturalHeight, equals(5));
    });

    test('edits a photo with the UIDialogEditImage', () async {
      var capture = UIButtonCapturePhoto(
        newHolder(),
        captureType: CaptureType.photoFile,
        captureDataFormat: CaptureDataFormat.dataUrlBase64,
        editCapture: true,
      );
      await capture.callRenderAndWait();

      var input = capture.getInputCapture() as HTMLInputElement;
      var dataTransfer = DataTransfer();
      dataTransfer.items.add(_pngFile(20, 20, bordered: true));
      input.files = dataTransfer.files;

      var captured = capture.onCapture.first;
      input.dispatchEvent(Event('change'));

      UIDialogEditImage? dialog;
      for (var i = 0; i < 100 && dialog == null; ++i) {
        await testUISleep(ms: 20);
        dialog = UIDialog.getAllDialogs()
            .whereType<UIDialogEditImage>()
            .where((d) => d.isShowing)
            .firstOrNull;
      }
      expect(dialog, isNotNull);

      await testUISleep(ms: 200);

      // Zoom in (the corners are now inside the blue rectangle):
      var plus = _buttonWithText(dialog!, '+');
      for (var i = 0; i < 60; ++i) {
        plus.click();
      }
      await testUISleep(ms: 50);

      _buttonWithText(dialog, 'OK').click();

      await captured.timeout(Duration(seconds: 10));
      expect(dialog.isShowing, isFalse);

      // Regression: without a max dimension or aspect ratio, the edited
      // image was discarded (the original data was kept).
      var url = capture.selectedFileDataAsDataURLBase64!;
      expect(url, startsWith('data:image/png'), reason: 'The file MIME type');
      var img = await _loadImage(url);
      expect(img.naturalWidth, equals(20));
      expect(img.naturalHeight, equals(20));

      var corner = await _pixelOf(url, 0, 0);
      expect(corner[2], greaterThan(200), reason: 'Zoomed (blue): $corner');
      expect(corner[0], lessThan(60), reason: 'Zoomed (blue): $corner');
    });

    test('data conversions', () {
      UIButtonCapturePhoto capture(CaptureDataFormat format) =>
          UIButtonCapturePhoto(null, captureDataFormat: format);

      var dataURL = DataURLBase64(base64.encode(utf8.encode('xyz')), 'a/b');

      var asDataURL = capture(CaptureDataFormat.dataUrlBase64)
        ..selectedFileData = dataURL;
      expect(asDataURL.selectedFileData, same(dataURL));
      expect(asDataURL.selectedFileDataAsString, equals('xyz'));

      var asURL = capture(CaptureDataFormat.url)..selectedFileData = dataURL;
      expect(asURL.selectedFileDataAsDataURLBase64, startsWith('data:a/b;'));

      var asBlob = capture(CaptureDataFormat.urlOrBlobUrl)
        ..selectedFileData = dataURL;
      expect(asBlob.selectedFileData as String, startsWith('blob:'));

      // An explicit encoding decodes the bytes:
      var latin = capture(CaptureDataFormat.arrayBuffer)
        ..setDataEncodingToLatin1()
        ..selectedFileData = Uint8List.fromList([0x63, 0xE9]);
      expect(latin.dataEncoding, equals(latin1));
      expect(latin.selectedFileDataAsString, equals('cé'));
    });
  });

  group('UIDialogEditImage', () {
    test('drag (with the grid) and translation limits', () async {
      var dialog = await _showEditImageDialog(20, 20);
      var canvas = dialog.content!.querySelector('canvas') as HTMLCanvasElement;

      // Without a mouse down, a move does nothing:
      var initial = dialog.editedImageDataURL;
      canvas.dispatchEvent(_mouse('mousemove', canvas, 15, 15));
      await testUISleep(ms: 20);
      expect(dialog.editedImageDataURL, equals(initial));

      var plus = _buttonWithText(dialog, '+');
      for (var i = 0; i < 50; ++i) {
        plus.click();
      }
      await testUISleep(ms: 50);
      var zoomed = dialog.editedImageDataURL;

      // A drag far right/down is limited to the zoomed margin:
      canvas.dispatchEvent(_mouse('mousedown', canvas, 10, 10));
      canvas.dispatchEvent(_mouse('mousemove', canvas, 500, 500));
      await testUISleep(ms: 20);
      var farRight = dialog.editedImageDataURL;
      canvas.dispatchEvent(_mouse('mousemove', canvas, 900, 900));
      await testUISleep(ms: 20);
      expect(dialog.editedImageDataURL, equals(farRight), reason: 'Limited');
      canvas.dispatchEvent(_mouse('mouseup', canvas, 900, 900));
      await testUISleep(ms: 20);
      expect(farRight, isNot(equals(zoomed)));

      // And far left/up:
      canvas.dispatchEvent(_mouse('mousedown', canvas, 10, 10));
      canvas.dispatchEvent(_mouse('mousemove', canvas, -500, -500));
      await testUISleep(ms: 20);
      var farLeft = dialog.editedImageDataURL;
      canvas.dispatchEvent(_mouse('mousemove', canvas, -900, -900));
      await testUISleep(ms: 20);
      expect(dialog.editedImageDataURL, equals(farLeft), reason: 'Limited');
      canvas.dispatchEvent(_mouse('mouseleave', canvas, -900, -900));
      await testUISleep(ms: 20);
      expect(farLeft, isNot(equals(farRight)));

      // Zooming with a translation scales it:
      var minus = _buttonWithText(dialog, '-');
      minus.click();
      await testUISleep(ms: 20);
      expect(dialog.editedImageDataURL, isNot(equals(farLeft)));
    });

    test('touch drag and pinch zoom', () async {
      var dialog = await _showEditImageDialog(20, 20);
      var canvas = dialog.content!.querySelector('canvas') as HTMLCanvasElement;

      var initial = dialog.editedImageDataURL;

      // Pinch out (zoom in):
      canvas.dispatchEvent(
        _touch('touchstart', canvas, [
          [8, 10],
          [12, 10],
        ]),
      );
      // 1.5x (a larger zoom shows only the blue center):
      canvas.dispatchEvent(
        _touch('touchmove', canvas, [
          [7, 10],
          [13, 10],
        ]),
      );
      // A single touch while scaling is ignored:
      canvas.dispatchEvent(
        _touch('touchmove', canvas, [
          [0, 0],
        ]),
      );
      canvas.dispatchEvent(_touch('touchend', canvas, []));
      await testUISleep(ms: 20);

      var pinched = dialog.editedImageDataURL;
      expect(pinched, isNot(equals(initial)));

      // A one finger drag:
      canvas.dispatchEvent(
        _touch('touchstart', canvas, [
          [10, 10],
        ]),
      );
      canvas.dispatchEvent(
        _touch('touchmove', canvas, [
          [14, 13],
        ]),
      );
      canvas.dispatchEvent(_touch('touchend', canvas, []));
      await testUISleep(ms: 20);

      expect(dialog.editedImageDataURL, isNot(equals(pinched)));

      // No touches on the canvas:
      canvas.dispatchEvent(_touch('touchstart', canvas, []));
      await testUISleep(ms: 20);
    });

    test('restores the canvas dimension when it changes', () async {
      var dialog = await _showEditImageDialog(20, 20);
      var canvas = dialog.content!.querySelector('canvas') as HTMLCanvasElement;
      expect(canvas.width, equals(20));

      canvas.width = 7;

      for (var i = 0; i < 50 && canvas.width != 20; ++i) {
        await testUISleep(ms: 20);
      }

      expect(canvas.width, equals(20));
      expect(canvas.height, equals(20));
    });
  });

  group('UIMasonry', () {
    HTMLDivElement box(int w, int h, String text) => HTMLDivElement()
      ..style.width = '${w}px'
      ..style.height = '${h}px'
      ..textContent = text;

    Future<UIMasonry> renderMasonry(
      List<List<int>> sizes, {
      int width = 300,
    }) async {
      var holder = newHolder()
        ..style.width = '${width}px'
        ..style.height = '400px';

      var masonry = UIMasonry(
        holder,
        [
          for (var i = 0; i < sizes.length; ++i)
            MasonryItem.fromElement(box(sizes[i][0], sizes[i][1], 'm$i;')),
        ],
        masonryWidthSize: 50,
        masonryHeightSize: 50,
        itemsMargin: 0,
      );
      await masonry.callRenderAndWait();
      return masonry;
    }

    /// Every item is rendered exactly once.
    void expectAllItems(UIMasonry masonry, int length) {
      var content = masonry.content!;
      expect(
        content.querySelectorAll('.ui-masonry-block').length,
        greaterThanOrEqualTo(length),
      );
      var text = content.textContent!;
      for (var i = 0; i < length; ++i) {
        expect(
          RegExp('m$i;').allMatches(text).length,
          equals(1),
          reason: 'm$i in: $text',
        );
      }
    }

    test('groups small items beside a big one', () async {
      var sizes = [
        [100, 100],
        [50, 50],
        [50, 50],
        [50, 50],
        [50, 50],
        [100, 50],
        [50, 100],
        [150, 100],
        [50, 50],
      ];
      var masonry = await renderMasonry(sizes);
      expectAllItems(masonry, sizes.length);
    });

    test('groups mixed sizes', () async {
      var sizes = [
        [150, 150],
        [100, 50],
        [50, 100],
        [100, 100],
        [50, 50],
        [100, 50],
        [50, 150],
        [50, 50],
        [100, 150],
        [50, 50],
        [150, 50],
      ];
      var masonry = await renderMasonry(sizes, width: 400);
      expectAllItems(masonry, sizes.length);
    });

    test('groups items with gaps', () async {
      var sizes = [
        [200, 150],
        [100, 100],
        [50, 50],
        [150, 50],
        [50, 100],
        [100, 50],
        [50, 50],
      ];
      var masonry = await renderMasonry(sizes, width: 350);
      expectAllItems(masonry, sizes.length);
    });

    test('refreshes when an item dimension changes', () async {
      var first = box(100, 100, 'm0;');
      var items = [
        MasonryItem.fromElement(first),
        MasonryItem.fromElement(box(50, 50, 'm1;')),
        MasonryItem.fromElement(box(50, 50, 'm2;')),
        MasonryItem.fromElement(box(50, 50, 'm3;')),
      ];

      var holder = newHolder()
        ..style.width = '300px'
        ..style.height = '300px';
      var masonry = UIMasonry(
        holder,
        items,
        masonryWidthSize: 50,
        masonryHeightSize: 50,
        itemsMargin: 0,
      );
      await masonry.callRenderAndWait();

      // Changed before the `posRender` dimension check:
      first.style.width = '150px';

      for (var i = 0; i < 50 && items[0].width != 150; ++i) {
        await testUISleep(ms: 20);
      }
      await testUISleep(ms: 50);

      expect(items[0].width, equals(150));
      expectAllItems(masonry, items.length);
    });

    test('the masonry size of not dividing dimensions', () {
      var masonry = UIMasonry(newHolder(), [
        MasonryItem.fromElement(box(13, 13, 'a')),
        MasonryItem.fromElement(box(17, 17, 'b')),
      ]);

      // No size from 13 to 10 divides both: the lowest remainder ratio
      // (10: 3/10 for both) is used.
      expect(masonry.computeMasonryWidthSize(0), equals(10));
      expect(masonry.computeMasonryHeightSize(0), equals(10));
    });
  });
}
