import 'dart:async';
import 'dart:convert' as data_convert;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:web_utils/web_utils.dart' hide MimeType;

import '../bones_ui_base.dart';
import '../bones_ui_utils.dart';
import '../bones_ui_log.dart';
import 'button.dart';
import 'dialog_edit_image.dart';

/// The capture type of an [UICapture].
enum CaptureType {
  photo,
  photoSelfie,
  photoFile,
  video,
  videoSelfie,
  videoFile,
  audioRecord,
  audioFile,
  json,
  file;

  /// Returns `true` if captures a photo.
  bool get isPhoto =>
      this == CaptureType.photo ||
      this == CaptureType.photoSelfie ||
      this == CaptureType.photoFile;

  /// Returns `true` if captures a video.
  bool get isVideo =>
      this == CaptureType.video ||
      this == CaptureType.videoSelfie ||
      this == CaptureType.videoFile;

  /// Returns `true` if captures an audio.
  bool get isAudio =>
      this == CaptureType.audioRecord || this == CaptureType.audioFile;
}

/// The internal representation of the captured data.
/// It's recommended to use the target format for your case,
/// to avoid data duplication and data conversion.
enum CaptureDataFormat {
  /// The data is stored as a content [String].
  string,

  /// The data is stored as an [Uint8List] array buffer.
  arrayBuffer,

  /// The data is stored as a Base64 [String].
  base64,

  /// The data is stored as a [DataURLBase64].
  dataUrlBase64,

  /// The data is stored as a URL [String] (including `DataURL`).
  url,

  /// The data is stored as a URL [String] or [Blob] URL.
  urlOrBlobUrl,
}

typedef CapturePhotoEditor = FutureOr<HTMLImageElement?> Function(
    HTMLImageElement image);

/// Base class for capture components.
/// See [UIButtonCapture] and [UIButtonCapturePhoto].
abstract class UICapture extends UIButtonBase implements UIField<String> {
  final CaptureType captureType;

  @override
  final String fieldName;

  final bool editCapture;

  final CapturePhotoEditor? photoEditor;

  UICapture(super.container, this.captureType,
      {String? fieldName,
      this.captureAspectRatio,
      this.captureMaxWidth,
      this.captureMaxHeight,
      this.captureDataFormat = CaptureDataFormat.arrayBuffer,
      this.editCapture = false,
      this.photoEditor,
      Object? selectedFileData,
      super.navigate,
      super.navigateParameters,
      super.navigateParametersProvider,
      super.classes,
      super.classes2,
      super.style,
      dynamic componentClass})
      : fieldName = fieldName ?? 'capture',
        super(componentClass: ['ui-capture', componentClass]) {
    this.selectedFileData = selectedFileData;
  }

  Set<String>? _acceptFilesExtensions;

  Set<String>? get acceptFilesExtensions =>
      isEmptyObject(_acceptFilesExtensions)
          ? null
          : Set.from(_acceptFilesExtensions!);

  void addAcceptFileExtension(String extension) {
    extension = _normalizeExtension(extension);
    if (extension.isEmpty) return;
    _acceptFilesExtensions ??= {};
    _acceptFilesExtensions!.add(extension);
  }

  bool removeAcceptFileExtension(String extension) {
    if (isEmptyObject(_acceptFilesExtensions)) return false;
    extension = _normalizeExtension(extension);
    if (extension.isEmpty) return false;
    return _acceptFilesExtensions!.remove(extension);
  }

  bool containsAcceptFileExtension(String extension) {
    if (isEmptyObject(_acceptFilesExtensions)) return false;
    extension = _normalizeExtension(extension);
    return _acceptFilesExtensions!.contains(extension);
  }

  void clearAcceptFilesExtensions() {
    if (isEmptyObject(_acceptFilesExtensions)) return;
    _acceptFilesExtensions!.clear();
  }

  String _normalizeExtension(String? extension) {
    if (extension == null) return '';
    extension = extension.trim();
    if (extension.isEmpty) return '';
    return extension.toLowerCase().replaceAll(RegExp(r'\W'), '');
  }

  @override
  String renderHidden() {
    String? capture;
    String? accept;

    switch (captureType) {
      case CaptureType.photo:
        {
          accept = 'image/*';
          capture = 'environment';
          break;
        }
      case CaptureType.photoSelfie:
        {
          accept = 'image/*';
          capture = 'user';
          break;
        }
      case CaptureType.photoFile:
        {
          accept = 'image/*';
          break;
        }
      case CaptureType.video:
        {
          accept = 'video/*';
          capture = 'environment';
          break;
        }
      case CaptureType.videoSelfie:
        {
          accept = 'video/*';
          capture = 'user';
          break;
        }
      case CaptureType.videoFile:
        {
          accept = 'video/*';
          break;
        }
      case CaptureType.audioRecord:
        {
          accept = 'audio/*';
          capture = 'environment';
          break;
        }
      case CaptureType.audioFile:
        {
          accept = 'audio/*';
          break;
        }
      case CaptureType.json:
        {
          accept = 'application/json';
          break;
        }
      default:
        break;
    }

    if (isNotEmptyObject(_acceptFilesExtensions)) {
      accept = accept == null ? '' : '$accept,';
      accept += _acceptFilesExtensions!.map((e) => '.$e').join(',');
    }

    var input = '<input field="$fieldName" type="file"';

    input += accept != null ? " accept='$accept'" : '';
    input += capture != null ? " capture='$capture'" : '';

    input += ' hidden>';

    UIConsole.log(input);

    return input;
  }

  @override
  void posRender() {
    super.posRender();

    var fieldCapture = getInputCapture() as HTMLInputElement;
    fieldCapture.onChange.listen((e) => _callOnCapture(fieldCapture, e));
  }

  final EventStream<UICapture> onCapture = EventStream();

  void _callOnCapture(HTMLInputElement input, Event event) async {
    await yeld();

    await _readFile(input);

    await yeld();

    onCaptureFile(input, event);
    onCapture.add(this);
  }

  void onCaptureFile(HTMLInputElement input, Event event) {
    var file = getInputFile();

    if (file != null) {
      UIConsole.log('onCapture> $input > $event > ${event.type} > $file');
      UIConsole.log(
          'file> ${file.name} ; ${file.type} ; ${file.lastModified} ; ${file.webkitRelativePath}');
    }
  }

  @override
  String? getFieldValue() {
    return selectedFileDataAsURLOrDataURLBase64;
  }

  @override
  void setFieldValue(String? value) {
    if (value == null) {
      _selectedFileData = null;
    } else {
      _selectedFileData = _CapturedData.from(captureDataFormat, value);
    }
  }

  final EventStream<UICapture> onCaptureData = EventStream();

  File? _selectedFile;

  File? get selectedFile => _selectedFile;

  bool get hasSelectedFile => _selectedFile != null;

  _CapturedData? _selectedFileData;

  bool get hasSelectedFileData => _selectedFileData != null;

  Object? get selectedFileData => _selectedFileData?.data;

  /// Sets the file [data].
  /// Accepted formats:
  /// - [Uint8List].
  /// - Data URL [String].
  /// - Base64 [String].
  set selectedFileData(Object? data) {
    _selectedFileData =
        data == null ? null : _CapturedData.from(captureDataFormat, data);
  }

  Uint8List? get selectedFileDataAsArrayBuffer =>
      _selectedFileData?.dataAsArrayBuffer(dataEncoding: _dataEncoding);

  data_convert.Encoding? _dataEncoding;

  data_convert.Encoding? get dataEncoding => _dataEncoding;

  set dataEncoding(data_convert.Encoding? value) {
    _dataEncoding = value ?? data_convert.latin1;
  }

  void setDataEncodingToLatin1() {
    _dataEncoding = data_convert.latin1;
  }

  void setDataEncodingToUTF8() {
    _dataEncoding = data_convert.utf8;
  }

  String? get selectedFileDataAsString =>
      _selectedFileData?.dataAsString(dataEncoding: _dataEncoding);

  String? get selectedFileDataAsBase64 =>
      _selectedFileData?.dataAsBase64(dataEncoding: _dataEncoding);

  String? get selectedFileDataAsDataURLBase64 {
    var selectedFileData = _selectedFileData;
    if (selectedFileData == null) return null;

    if (selectedFileData.dataFormat == CaptureDataFormat.url) {
      return selectedFileData.dataAsURL();
    } else {
      return selectedFileData
          .dataAsDataUrlBase64(dataEncoding: _dataEncoding)
          .asDataURLString();
    }
  }

  String? get selectedFileDataAsURLOrDataURLBase64 {
    var selectedFileData = _selectedFileData;
    if (selectedFileData == null) return null;

    if (selectedFileData.dataFormat == CaptureDataFormat.url ||
        selectedFileData.dataFormat == CaptureDataFormat.dataUrlBase64) {
      return selectedFileData.dataAsURLOrDataURL();
    } else {
      return selectedFileData
          .dataAsDataUrlBase64(dataEncoding: _dataEncoding)
          .asDataURLString();
    }
  }

  /// The maximum width of the captured photo.
  /// See [captureType].
  int? captureMaxWidth;

  /// The maximum height of the captured photo.
  /// See [captureType].
  int? captureMaxHeight;

  /// The aspect ratio of a captured image. It's the ratio of its width to its height.
  /// For example:
  /// - `16/9 = 1,7777` (standard widescreen)
  /// - `1/1 = 1.0` (square)
  /// - `4/3 = 1.3333` (traditional TV)
  /// - `6/13 = 0.4615` (modern smartphones)
  double? captureAspectRatio;

  CaptureDataFormat captureDataFormat = CaptureDataFormat.arrayBuffer;

  /// If `true` will remove the Exif data from the captured data.
  /// Default true since not all popular browsers can't handle Exif yet.
  /// This is useful to avoid issues with device orientation and image rotation.
  bool removeExifFromImage = true;

  Future<void> _readFile(HTMLInputElement input) async {
    var files = input.files;
    if (files == null || files.isEmpty) return;

    var file = files.item(0);
    if (file == null) return;

    _selectedFile = file;

    await yeld();

    var data = await _readFileInput(input);

    if (data == null) {
      throw StateError("Can't capture data as format: $captureDataFormat");
    }

    await yeld();

    var mimeType = getFileMimeType(file);

    var capturedData = _CapturedData.from(captureDataFormat, data,
        mimeType: mimeType?.toString());

    await yeld();

    capturedData = await _filterCapturedData(capturedData);

    _selectedFileData = capturedData;

    onCaptureData.add(this);
    onChange.add(this);
  }

  Future<_CapturedData> _filterCapturedData(_CapturedData capturedData) async {
    if (captureMaxWidth == null &&
        captureMaxHeight == null &&
        captureAspectRatio == null &&
        !editCapture) {
      return capturedData;
    }

    if (captureType.isPhoto) {
      var fileURL = capturedData.dataAsURLOrDataURL();

      var imageElement = HTMLImageElement()..src = fileURL;

      if (imageElement.complete) {
        return _filterCapturedPhoto(capturedData, imageElement);
      } else {
        return imageElement.onLoad.first
            .then((value) => _filterCapturedPhoto(capturedData, imageElement));
      }
    }

    return capturedData;
  }

  /// [MimeType] to use when scaling a captured photo. Usually
  /// 'image/png', 'image/jpeg' or 'image/webp'.
  /// Default: 'image/jpeg'
  /// See [captureMaxWidth] and [captureMaxHeight].
  String? photoScaleMimeType;

  /// Image quality to use when scaling a captured photo.
  /// Used when [photoScaleMimeType] is 'image/jpeg' or 'image/webp'.
  /// Default: 0.98
  /// See [captureMaxWidth] and [captureMaxHeight].
  double photoScaleQuality = 0.98;

  // This is only called after load [image].
  Future<_CapturedData> _filterCapturedPhoto(
      _CapturedData capturedData, HTMLImageElement image) async {
    if (editCapture) {
      await yeld();

      var photoEditor = this.photoEditor;
      if (photoEditor != null) {
        var imageEdited = await photoEditor(image);
        if (imageEdited != null) {
          image = imageEdited;
        }
      } else {
        var dialogEdit = UIDialogEditImage(image);
        await yeld();
        var edited = await dialogEdit.showAndWait();
        if (edited) {
          image = dialogEdit.editedImage ?? image;
        }
      }
    }

    if (!(image.complete)) {
      await image.onLoad.first;
    }

    var imgW = image.naturalWidth;
    var imgH = image.naturalHeight;

    CanvasImageSource imgSrc = image;

    var aspectRatio = captureAspectRatio;

    if (aspectRatio != null) {
      var imgH2 = imgH;
      var imgW2 = (imgH2 * aspectRatio).toInt();

      if (imgW2 > imgW) {
        imgH2 = (imgW * (1 / aspectRatio)).toInt();
        imgW2 = (imgH2 * aspectRatio).toInt();
      }

      assert(imgW2 <= imgW);
      assert(imgH2 <= imgH);

      if (imgW2 != imgW || imgH2 != imgH) {
        var canvas = HTMLCanvasElement()
          ..width = imgW2
          ..height = imgH2;

        var ctx = canvas.context2D;
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        ctx.clearRect(0, 0, imgW2, imgH2);

        var x = (imgW2 - imgW) ~/ 2;
        var y = (imgH2 - imgH) ~/ 2;
        ctx.drawImage(
          image,
          x.toDouble(),
          y.toDouble(),
          imgW.toDouble(),
          imgH.toDouble(),
        );

        imgW = imgW2;
        imgH = imgH2;
        imgSrc = canvas;
      }
    }

    var maxW = captureMaxWidth ?? imgW;
    var maxH = captureMaxHeight ?? imgH;

    if (imgW <= maxW && imgH <= maxH && imgSrc == image) {
      return capturedData;
    }

    var wLimit = imgW > maxW ? maxW : imgW;
    var hLimit = imgH > maxH ? maxH : imgH;

    var rW = wLimit / imgW;
    var rH = hLimit / imgH;
    var r = math.min(rW, rH);

    var canvasW = (imgW * r).toInt();
    var canvasH = (imgH * r).toInt();

    var canvas = HTMLCanvasElement()
      ..width = canvasW
      ..height = canvasH;

    var ctx = canvas.context2D;

    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    ctx.clearRect(0, 0, canvasW, canvasH);
    ctx.drawImage(
      imgSrc,
      0,
      0,
      canvasW.toDouble(),
      canvasH.toDouble(),
    );

    var photoScaleMimeType = this.photoScaleMimeType;

    if (photoScaleMimeType == null || photoScaleMimeType.isEmpty) {
      var m = capturedData.mimeType;
      if (m != null && m.type == 'image') {
        photoScaleMimeType = m.toString();
      }
    }

    photoScaleMimeType ??= "image/jpeg";

    var canvasDataURL = canvas.toDataUrl(photoScaleMimeType, photoScaleQuality);
    var capturedData2 =
        _CapturedData.fromURL(canvasDataURL, photoScaleMimeType);

    capturedData2 = capturedData2.withDataFormat(capturedData.dataFormat);
    return capturedData2;
  }

  Future<Object?> _readFileInput(HTMLInputElement input) async {
    switch (captureDataFormat) {
      case CaptureDataFormat.arrayBuffer:
        return await readFileInputElementAsArrayBuffer(
            input, removeExifFromImage);

      case CaptureDataFormat.string:
        return await readFileInputElementAsString(input, removeExifFromImage);

      case CaptureDataFormat.base64:
        return await readFileInputElementAsBase64(input, removeExifFromImage);

      case CaptureDataFormat.dataUrlBase64:
        return await readFileInputElementAsDataURLBase64(
            input, removeExifFromImage);

      case CaptureDataFormat.url:
        return await readFileInputElementAsDataURLBase64(
            input, removeExifFromImage);

      case CaptureDataFormat.urlOrBlobUrl:
        return await readFileInputElementAsBlobUrl(input, removeExifFromImage);
    }
  }

  @override
  void onClickEvent(event, List? params) {
    var input = getInputCapture() as HTMLInputElement;
    input.value = '';
    input.click();
  }

  Element? getInputCapture() => getFieldElementNonTyped(fieldName);

  File? getInputFile() {
    var input = getInputCapture() as HTMLInputElement?;
    if (input == null) return null;
    var files = input.files!;
    return files.isNotEmpty ? files.item(0) : null;
  }

  bool isFileImage() {
    var file = getInputFile();
    return file != null && file.type.contains('image');
  }

  bool isFileVideo() {
    var file = getInputFile();
    return file != null && file.type.contains('video');
  }

  bool isFileAudio() {
    var file = getInputFile();
    return file != null && file.type.contains('audio');
  }

  ImageFileReader? getImageFileReader() {
    var file = getInputFile();
    if (file == null || !isFileImage()) return null;
    return ImageFileReader(file);
  }

  VideoFileReader? getVideoFileReader() {
    var file = getInputFile();
    if (file == null || !isFileVideo()) return null;
    return VideoFileReader(file);
  }

  AudioFileReader? getAudioFileReader() {
    var file = getInputFile();
    if (file == null || !isFileAudio()) return null;
    return AudioFileReader(file);
  }
}

/// The captured data with interchangeable formats.
/// See [CaptureDataFormat].
class _CapturedData {
  final CaptureDataFormat dataFormat;

  final Object data;

  String? _mimeTypeStr;

  _CapturedData._(this.dataFormat, this.data, this._mimeTypeStr);

  factory _CapturedData.fromArrayBuffer(List<int> data, String? mimeType) {
    var bs = data is Uint8List ? data : Uint8List.fromList(data);
    return _CapturedData._(CaptureDataFormat.arrayBuffer, bs, mimeType);
  }

  factory _CapturedData.fromBase64(String base64, String? mimeType) {
    return _CapturedData._(CaptureDataFormat.base64, base64.trim(), mimeType);
  }

  factory _CapturedData.fromDataUrlBase64(DataURLBase64 dataUrlBase64) {
    return _CapturedData._(CaptureDataFormat.dataUrlBase64, dataUrlBase64,
        dataUrlBase64.mimeTypeAsString);
  }

  factory _CapturedData.fromString(String string, String? mimeType) {
    return _CapturedData._(CaptureDataFormat.string, string, mimeType);
  }

  factory _CapturedData.fromURL(String url, String? mimeType) {
    return _CapturedData._(CaptureDataFormat.url, url, mimeType);
  }

  factory _CapturedData.from(CaptureDataFormat dataFormat, Object data,
      {String? mimeType, data_convert.Encoding? dataEncoding}) {
    switch (dataFormat) {
      case CaptureDataFormat.arrayBuffer:
        {
          if (data is List<int>) {
            return _CapturedData.fromArrayBuffer(data, mimeType);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromArrayBuffer(
                data.payloadArrayBuffer, mimeType);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromArrayBuffer(
                  dataUrl.payloadArrayBuffer, dataUrl.mimeTypeAsString);
            } else {
              var bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromArrayBuffer(bs, mimeType);
              }

              dataEncoding ??= data_convert.utf8;

              return _CapturedData.fromArrayBuffer(
                  dataEncoding.encode(s), mimeType);
            }
          }
        }
      case CaptureDataFormat.dataUrlBase64:
        {
          if (data is List<int>) {
            var dataURLBase64 =
                DataURLBase64(data_convert.base64.encode(data), mimeType);
            return _CapturedData.fromDataUrlBase64(dataURLBase64);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromDataUrlBase64(data);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromDataUrlBase64(dataUrl);
            } else {
              List<int>? bs = _decodeBase64(s);
              if (bs != null) {
                var dataURLBase64 = DataURLBase64(s, mimeType);
                return _CapturedData.fromDataUrlBase64(dataURLBase64);
              }

              dataEncoding ??= data_convert.utf8;
              bs = dataEncoding.encode(s);

              var dataURLBase64 = DataURLBase64(
                  data_convert.base64.encode(bs), mimeType ?? 'text/plain');
              return _CapturedData.fromDataUrlBase64(dataURLBase64);
            }
          }
        }
      case CaptureDataFormat.base64:
        {
          if (data is List<int>) {
            return _CapturedData.fromBase64(
                data_convert.base64.encode(data), mimeType);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromBase64(
                data.payload, data.mimeTypeAsString);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromBase64(dataUrl.payloadBase64, mimeType);
            } else {
              List<int>? bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromBase64(s, mimeType);
              }

              dataEncoding ??= data_convert.utf8;

              bs = dataEncoding.encode(s);
              return _CapturedData.fromBase64(
                  data_convert.base64.encode(bs), mimeType);
            }
          }
        }
      case CaptureDataFormat.string:
        {
          if (data is List<int>) {
            var s = _decodeAsString(data, dataEncoding);
            return _CapturedData.fromString(s, mimeType);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromString(data.payload, mimeType);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromString(dataUrl.payload, mimeType);
            } else {
              var bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromString(
                    _decodeAsString(bs, dataEncoding), mimeType);
              }
              return _CapturedData.fromString(s, mimeType);
            }
          }
        }
      case CaptureDataFormat.url:
        {
          if (data is List<int>) {
            var dataUrl = DataURLBase64.from(
                data, mimeType ?? MimeType.applicationOctetStream);
            return _CapturedData.fromDataUrlBase64(dataUrl);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromDataUrlBase64(data);
          } else {
            var s = data.toString().trim();

            // Identify URL and avoid extra parsing:
            if (s.startsWith("http://") ||
                s.startsWith("https://") ||
                s.startsWith("blob:http")) {
              return _CapturedData.fromURL(s, mimeType);
            }

            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromDataUrlBase64(dataUrl);
            } else {
              var bs = _decodeBase64(s);
              if (bs != null) {
                var dataUrl = DataURLBase64(s, mimeType);
                return _CapturedData.fromDataUrlBase64(dataUrl);
              }

              return _CapturedData.fromURL(s, mimeType);
            }
          }
        }
      case CaptureDataFormat.urlOrBlobUrl:
        {
          if (data is List<int>) {
            var bs = data is Uint8List ? data : Uint8List.fromList(data);
            var url =
                createBlobURL(bs, mimeType ?? MimeType.applicationOctetStream);
            return _CapturedData.fromURL(url, mimeType);
          } else if (data is DataURLBase64) {
            var url =
                createBlobURL(data.payloadArrayBuffer, data.mimeTypeAsString);
            return _CapturedData.fromURL(url, data.mimeTypeAsString);
          } else {
            var s = data.toString().trim();

            // Identify URL and avoid extra parsing:
            if (s.startsWith("http://") ||
                s.startsWith("https://") ||
                s.startsWith("blob:http")) {
              return _CapturedData.fromURL(s, mimeType);
            }

            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              var url = createBlobURL(
                  dataUrl.payloadArrayBuffer, dataUrl.mimeTypeAsString);
              return _CapturedData.fromURL(url, mimeType);
            } else {
              var bs = _decodeBase64(s);
              if (bs != null) {
                var url = createBlobURL(
                    bs, mimeType ?? MimeType.applicationOctetStream);
                return _CapturedData.fromURL(url, mimeType);
              }

              return _CapturedData.fromURL(s, mimeType);
            }
          }
        }
    }
  }

  Uint8List dataAsArrayBuffer({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.arrayBuffer) {
      return data as Uint8List;
    } else {
      return _CapturedData.from(CaptureDataFormat.arrayBuffer, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as Uint8List;
    }
  }

  String dataAsBase64({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.base64) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.base64, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as String;
    }
  }

  DataURLBase64 dataAsDataUrlBase64({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.dataUrlBase64) {
      return data as DataURLBase64;
    } else {
      return _CapturedData.from(CaptureDataFormat.dataUrlBase64, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as DataURLBase64;
    }
  }

  String dataAsString({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.string) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.string, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as String;
    }
  }

  String dataAsURL({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.url) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.url, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as String;
    }
  }

  String dataAsURLOrDataURL({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.url) {
      return data as String;
    } else if (dataFormat == CaptureDataFormat.dataUrlBase64) {
      return (data as DataURLBase64).toString();
    } else {
      return _CapturedData.from(CaptureDataFormat.url, data,
              mimeType: _mimeTypeStr, dataEncoding: dataEncoding)
          .data as String;
    }
  }

  MimeType? get mimeType {
    var mimeTypeStr = _mimeTypeStr;
    if (mimeTypeStr != null && mimeTypeStr.isNotEmpty) {
      return MimeType.parse(mimeTypeStr);
    }

    if (dataFormat == CaptureDataFormat.dataUrlBase64) {
      var dataUrl = data as DataURLBase64;
      var mimeType = dataUrl.mimeType;
      _mimeTypeStr = mimeType?.toString();
      return mimeType;
    } else if (dataFormat == CaptureDataFormat.url) {
      var dataUrl = dataAsURL();
      if (dataUrl.startsWith('data:')) {
        var mimeType = DataURLBase64.parseMimeType(dataUrl);
        _mimeTypeStr = mimeType?.toString();
        return mimeType;
      } else {
        return null;
      }
    }

    try {
      var dataUrl = dataAsDataUrlBase64();
      var mimeType = dataUrl.mimeType;
      _mimeTypeStr = mimeType?.toString();
      return mimeType;
    } catch (_) {}

    return null;
  }

  _CapturedData withDataFormat(CaptureDataFormat targetDataFormat) {
    if (dataFormat != targetDataFormat) {
      return _CapturedData.from(targetDataFormat, data, mimeType: _mimeTypeStr);
    } else {
      return this;
    }
  }
}

Uint8List? _decodeBase64(String s) {
  try {
    return data_convert.base64.decode(s);
  } catch (_) {
    return null;
  }
}

String _decodeAsString(List<int> bs, data_convert.Encoding? dataEncoding) {
  if (dataEncoding != null) {
    return dataEncoding.decode(bs);
  }

  try {
    return data_convert.utf8.decode(bs);
  } catch (_) {
    return data_convert.latin1.decode(bs);
  }
}

class URLFileReader {
  final File _file;

  URLFileReader(this._file) {
    var fileReader = FileReader();

    fileReader.onError.listen((event) {
      _notifyOnLoad(null);
    });

    fileReader.onLoad.listen((e) {
      var dataURL = fileReader.result.dartify()?.toString();
      _notifyOnLoad(dataURL);
    });

    fileReader.onLoadEnd.listen((event) {
      final error = fileReader.error;

      if (error != null) {
        _notifyOnLoad(null);
      } else {
        var dataURL = fileReader.result.dartify()?.toString();
        _notifyOnLoad(dataURL);
      }
    });

    fileReader.readAsDataURL(_file);
  }

  void _notifyOnLoad(String? dataURL) {
    try {
      onLoad(dataURL, _file.type);
    } catch (e) {
      UIConsole.error('Error calling onLoad', e);
    }

    try {
      onLoadData.add(dataURL);
    } catch (e) {
      UIConsole.error('Error calling onLoadData controller', e);
    }
  }

  final EventStream<String?> onLoadData = EventStream();

  void onLoad(String? dataURL, String type) {}
}

class ImageFileReader extends URLFileReader {
  ImageFileReader(super.file);

  @override
  void onLoad(String? dataURL, String type) {
    var img = HTMLImageElement();

    if (dataURL != null && dataURL.isNotEmpty) {
      img.src = dataURL;
    }

    onLoadImage.add(img);
  }

  final EventStream<HTMLImageElement> onLoadImage = EventStream();
}

class VideoFileReader extends URLFileReader {
  VideoFileReader(super.file);

  @override
  void onLoad(String? dataURL, String type) {
    var video = HTMLVideoElement();
    video.controls = true;

    var sourceElement = HTMLSourceElement();
    sourceElement.src = dataURL!;
    sourceElement.type = type;

    video.appendChild(sourceElement);

    onLoadVideo.add(video);
  }

  final EventStream<HTMLVideoElement> onLoadVideo = EventStream();
}

class AudioFileReader extends URLFileReader {
  AudioFileReader(super.file);

  @override
  void onLoad(String? dataURL, String type) {
    var audio = HTMLAudioElement();
    audio.controls = true;

    var sourceElement = HTMLSourceElement();
    sourceElement.src = dataURL!;
    sourceElement.type = type;

    audio.appendChild(sourceElement);

    onLoadAudio.add(audio);
  }

  final EventStream<HTMLAudioElement> onLoadAudio = EventStream();
}

/// A Button that captures a photo.
/// See [UICapture].
class UIButtonCapturePhoto extends UICapture {
  final String? text;
  final dynamic buttonContent;

  final String? fontSize;

  UIButtonCapturePhoto(Element? parent,
      {this.text,
      CaptureType captureType = CaptureType.photo,
      this.buttonContent,
      super.fieldName,
      super.captureAspectRatio,
      super.captureMaxWidth,
      super.captureMaxHeight,
      super.captureDataFormat,
      super.editCapture,
      super.photoEditor,
      super.selectedFileData,
      super.navigate,
      super.navigateParameters,
      super.navigateParametersProvider,
      super.classes,
      super.classes2,
      dynamic componentClass,
      super.style,
      bool small = false,
      this.fontSize})
      : super(parent, captureType, componentClass: [
          small ? 'ui-button-small' : 'ui-button',
          componentClass
        ]);

  @override
  void configure() {
    content!.style.verticalAlign = 'middle';
  }

  @override
  dynamic renderButton() {
    if (disabled) {
      content!.style.opacity = '0.7';
    } else {
      content!.style.opacity = '';
    }

    if (isNotEmptyString(text)) {
      if (fontSize != null) {
        return "<span style='font-size: $fontSize'>$text</span>";
      } else {
        return text;
      }
    } else if (buttonContent != null) {
      return buttonContent;
    } else {
      return 'Photo';
    }
  }

  @override
  void posRender() {
    super.posRender();

    if (hasSelectedFileData) {
      showSelectedImage();
    }
  }

  int selectedImageMaxWidth = 100;

  int selectedImageMaxHeight = 100;

  bool onlyShowSelectedImageInButton = false;

  bool showSelectedImageInButton = true;

  List<String>? selectedImageClasses;
  String? selectedImageStyle;

  @override
  void onCaptureFile(HTMLInputElement input, Event event) {
    if (showSelectedImageInButton) {
      showSelectedImage();
    }
  }

  final List<Element> _selectedImageElements = [];

  void showSelectedImage() {
    var dataURL = selectedFileDataAsURLOrDataURLBase64;
    if (dataURL == null) return;

    var content = this.content!;

    content.removeNodes(_selectedImageElements);

    if (onlyShowSelectedImageInButton) {
      content.removeNodeWhere((e) => !(e.asElementChecked?.hidden ?? false));
    }

    var img = HTMLImageElement()
      ..src = dataURL
      ..classList.add('ui-capture-img')
      ..style.margin = '2px 4px'
      ..style.maxHeight = '100%';

    if (selectedImageMaxWidth > 0) {
      img.style.maxWidth = '${selectedImageMaxWidth}px';
    }

    if (selectedImageMaxHeight > 0) {
      img.style.maxHeight = '${selectedImageMaxHeight}px';
    }

    if (isNotEmptyObject(selectedImageClasses)) {
      img.classList.addAll(selectedImageClasses!);
    }

    if (isNotEmptyString(selectedImageStyle, trim: true)) {
      img.style.cssText = '${img.style.cssText}; $selectedImageStyle';
    }

    _selectedImageElements.clear();
    if (!onlyShowSelectedImageInButton) {
      _selectedImageElements.add(HTMLBRElement());
    }
    _selectedImageElements.add(img);

    img.onClick.listen((e) => fireClickEvent(e));

    content.appendNodes(_selectedImageElements);
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = '';
  }
}

/// A generic capture button.
/// See [UICapture].
class UIButtonCapture extends UICapture {
  final String text;

  final String? fontSize;

  UIButtonCapture(Element? parent, this.text, CaptureType captureType,
      {super.editCapture,
      super.photoEditor,
      String? fieldName,
      String? navigate,
      Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic componentClass,
      dynamic style,
      bool small = false,
      this.fontSize})
      : super(parent, captureType,
            fieldName: fieldName,
            navigate: navigate,
            navigateParameters: navigateParameters,
            navigateParametersProvider: navigateParametersProvider,
            classes: classes,
            classes2: classes2,
            style: style,
            componentClass: [
              small ? 'ui-button-small' : 'ui-button',
              componentClass
            ]);

  @override
  void configure() {
    content!.style.verticalAlign = 'middle';
  }

  @override
  String renderButton() {
    if (disabled) {
      content!.style.opacity = '0.7';
    } else {
      content!.style.opacity = '';
    }

    if (fontSize != null) {
      return "<span style='font-size: $fontSize'>$text</span>";
    } else {
      return text;
    }
  }

  @override
  void posRender() {
    super.posRender();

    if (hasSelectedFileData) {
      showSelectedFile();
    }
  }

  bool showSelectedFileInButton = true;

  @override
  void onCaptureFile(HTMLInputElement input, Event event) {
    if (showSelectedFileInButton) {
      showSelectedFile();
    }
  }

  void showSelectedFile() {
    var dataURL = selectedFileDataAsURLOrDataURLBase64;
    if (dataURL == null) return;

    final content = this.content;

    content!.removeNodeWhere(
        (e) => (e.isA<HTMLSpanElement>() || e.isA<HTMLBRElement>()));

    var fileName = selectedFile?.name;

    if (fileName != null && fileName.isNotEmpty) {
      content.appendChild(HTMLBRElement());
      content.appendChild(HTMLSpanElement()..text = fileName);
    }
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = '';
  }
}
