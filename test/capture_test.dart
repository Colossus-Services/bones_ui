@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_ui/bones_ui_test.dart';
import 'package:test/test.dart';

void main() {
  group('UICapture conversions', () {
    late final _CaptureRoot uiRoot;

    setUpAll(() async {
      uiRoot = await initializeTestUIRoot((rootContainer) {
        return _CaptureRoot(rootContainer);
      });
      await uiRoot.callRenderAndWait();
    });

    // "hi" -> bytes [104, 105] -> base64 "aGk="
    final bytes = Uint8List.fromList([104, 105]);
    const base64Str = 'aGk=';

    UIButtonCapturePhoto newCapture(CaptureDataFormat format) {
      var capture = UIButtonCapturePhoto(
        uiRoot.content,
        text: 'Capture',
        captureDataFormat: format,
      );
      return capture;
    }

    test('arrayBuffer format round-trips', () {
      var capture = newCapture(CaptureDataFormat.arrayBuffer);
      capture.selectedFileData = bytes;

      expect(capture.hasSelectedFileData, isTrue);
      expect(capture.selectedFileDataAsArrayBuffer, equals(bytes));
      expect(capture.selectedFileDataAsBase64, equals(base64Str));
      expect(capture.selectedFileDataAsString, equals('hi'));
    });

    test('base64 format round-trips', () {
      var capture = newCapture(CaptureDataFormat.base64);
      capture.selectedFileData = base64Str;

      expect(capture.hasSelectedFileData, isTrue);
      expect(capture.selectedFileDataAsBase64, equals(base64Str));
      expect(capture.selectedFileDataAsArrayBuffer, equals(bytes));
    });

    test('null clears the data', () {
      var capture = newCapture(CaptureDataFormat.arrayBuffer);
      capture.selectedFileData = bytes;
      expect(capture.hasSelectedFileData, isTrue);

      capture.setFieldValue(null);
      expect(capture.hasSelectedFileData, isFalse);
      expect(capture.getFieldValue(), isNull);
    });

    test('dataUrlBase64 format exposes a data URL', () {
      var capture = newCapture(CaptureDataFormat.dataUrlBase64);
      capture.selectedFileData = 'data:text/plain;base64,$base64Str';

      var url = capture.selectedFileDataAsURLOrDataURLBase64;
      expect(url, startsWith('data:'));
      expect(url, contains(base64Str));
      expect(capture.selectedFileDataAsString, equals('hi'));
    });

    test('fieldValue round-trips via setFieldValue/getFieldValue', () {
      var capture = newCapture(CaptureDataFormat.base64);
      capture.setFieldValue(base64Str);
      expect(capture.getFieldValue(), isNotNull);
      expect(capture.selectedFileDataAsArrayBuffer, equals(bytes));
    });

    test('latin1 encoding applied to string<->bytes', () {
      var capture = newCapture(CaptureDataFormat.string);
      capture.setDataEncodingToLatin1();
      // 0xE9 is 'é' in latin1 (invalid as standalone UTF-8).
      capture.selectedFileData = Uint8List.fromList([0xE9]);
      expect(capture.dataEncoding, equals(latin1));
      expect(capture.selectedFileDataAsString, equals('é'));
    });
  });
}

class _CaptureRoot extends UIRoot {
  _CaptureRoot(super.rootContainer) : super(id: 'CaptureRoot');

  @override
  UIComponent? renderContent() => null;
}
