import 'dart:convert' as data_convert;
import 'dart:html';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:dom_tools/dom_tools.dart';
import 'package:swiss_knife/swiss_knife.dart';

import '../bones_ui_base.dart';
import '../bones_ui_log.dart';
import 'button.dart';

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
}

abstract class UICapture extends UIButtonBase implements UIField<String> {
  final CaptureType captureType;

  @override
  final String fieldName;

  UICapture(Element? container, this.captureType,
      {String? fieldName,
      this.captureAspectRatio,
      this.captureMaxWidth,
      this.captureMaxHeight,
      this.captureDataFormat = CaptureDataFormat.arrayBuffer,
      Object? selectedFileData,
      String? navigate,
      Map<String, String>? navigateParameters,
      ParametersProvider? navigateParametersProvider,
      dynamic classes,
      dynamic classes2,
      dynamic style,
      dynamic componentClass})
      : fieldName = fieldName ?? 'capture',
        super(container,
            classes: classes,
            classes2: classes2,
            style: style,
            componentClass: ['ui-capture', componentClass],
            navigate: navigate,
            navigateParameters: navigateParameters,
            navigateParametersProvider: navigateParametersProvider) {
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

    var fieldCapture = getInputCapture() as FileUploadInputElement;
    fieldCapture.onChange.listen((e) => _callOnCapture(fieldCapture, e));
  }

  final EventStream<UICapture> onCapture = EventStream();

  void _callOnCapture(FileUploadInputElement input, Event event) async {
    await _readFile(input);
    onCaptureFile(input, event);
    onCapture.add(this);
  }

  void onCaptureFile(FileUploadInputElement input, Event event) {
    var file = getInputFile();

    if (file != null) {
      UIConsole.log('onCapture> $input > $event > ${event.type} > $file');
      UIConsole.log(
          'file> ${file.name} ; ${file.type} ; ${file.lastModified} ; ${file.relativePath}');
    }
  }

  @override
  String? getFieldValue() {
    return selectedFileDataAsDataURLBase64;
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

  Future<void> _readFile(FileUploadInputElement input) async {
    if (input.files!.isNotEmpty) {
      var file = input.files!.first;

      _selectedFile = file;

      var data = await _readFileInput(input);

      if (data == null) {
        throw StateError("Can't capture data as format: $captureDataFormat");
      }

      var capturedData = _CapturedData.from(captureDataFormat, data);

      capturedData = await _filterCapturedData(capturedData);

      _selectedFileData = capturedData;

      onCaptureData.add(this);
      onChange.add(this);
    }
  }

  Future<_CapturedData> _filterCapturedData(_CapturedData capturedData) async {
    if (captureMaxWidth == null &&
        captureMaxHeight == null &&
        captureAspectRatio == null) {
      return capturedData;
    }

    if (captureType.isPhoto) {
      var fileURL = capturedData.dataAsURL();

      var imageElement = ImageElement()..src = fileURL;

      if (imageElement.complete ?? false) {
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

  Future<_CapturedData> _filterCapturedPhoto(
      _CapturedData capturedData, ImageElement image) async {
    var imgW = image.naturalWidth;
    var imgH = image.naturalHeight;

    var aspectRatio = captureAspectRatio;

    var maxW = captureMaxWidth ?? imgW;
    var maxH = captureMaxHeight ?? imgH;

    if (imgW <= maxW &&
        imgH <= maxH &&
        (aspectRatio == null || (imgW / imgH) == aspectRatio)) {
      return capturedData;
    }

    var wLimit = imgW > maxW ? maxW : imgW;
    var hLimit = imgH > maxH ? maxH : imgH;

    var rW = wLimit / imgW;
    var rH = hLimit / imgH;
    var r = math.min(rW, rH);

    var w2 = (imgW * r).toInt();
    var h2 = (imgH * r).toInt();

    var canvasW = w2;
    var canvasH = h2;

    if (aspectRatio != null) {
      var canvasH2 = canvasH;
      var canvasW2 = (canvasH2 * aspectRatio).toInt();

      if (canvasW2 > w2) {
        canvasH2 = (canvasW * (1 / aspectRatio)).toInt();
        canvasW2 = (canvasH2 * aspectRatio).toInt();
      }

      assert(canvasW2 <= w2);
      assert(canvasH2 <= h2);

      canvasW = canvasW2;
      canvasH = canvasH2;
    }

    var canvas = CanvasElement(width: canvasW, height: canvasH);

    var ctx = canvas.context2D;

    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    ctx.clearRect(0, 0, w2, h2);
    ctx.drawImageScaled(image, 0, 0, w2, h2);

    var photoScaleMimeType = this.photoScaleMimeType;

    if (photoScaleMimeType == null || photoScaleMimeType.isEmpty) {
      var m = capturedData.mimeType;
      if (m != null && m.type == 'image') {
        photoScaleMimeType = m.toString();
      }
    }

    photoScaleMimeType ??= "image/jpeg";

    var canvasDataURL = canvas.toDataUrl(photoScaleMimeType, photoScaleQuality);
    var capturedData2 = _CapturedData.fromURL(canvasDataURL);

    capturedData2 = capturedData2.withDataFormat(capturedData.dataFormat);
    return capturedData2;
  }

  Future<Object?> _readFileInput(FileUploadInputElement input) async {
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
    }
  }

  @override
  void onClickEvent(event, List? params) {
    var input = getInputCapture() as FileUploadInputElement;
    input.value = null;
    input.click();
  }

  Element? getInputCapture() => getFieldElement(fieldName);

  File? getInputFile() {
    var input = getInputCapture() as FileUploadInputElement?;
    return input != null && input.files!.isNotEmpty ? input.files![0] : null;
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

  _CapturedData._(this.dataFormat, this.data);

  factory _CapturedData.fromArrayBuffer(List<int> data) {
    var bs = data is Uint8List ? data : Uint8List.fromList(data);
    return _CapturedData._(CaptureDataFormat.arrayBuffer, bs);
  }

  factory _CapturedData.fromBase64(String base64) {
    return _CapturedData._(CaptureDataFormat.base64, base64.trim());
  }

  factory _CapturedData.fromDataUrlBase64(DataURLBase64 dataUrlBase64) {
    return _CapturedData._(CaptureDataFormat.dataUrlBase64, dataUrlBase64);
  }

  factory _CapturedData.fromString(String string) {
    return _CapturedData._(CaptureDataFormat.string, string);
  }

  factory _CapturedData.fromURL(String url) {
    return _CapturedData._(CaptureDataFormat.url, url);
  }

  factory _CapturedData.from(CaptureDataFormat dataFormat, Object data,
      {data_convert.Encoding? dataEncoding}) {
    switch (dataFormat) {
      case CaptureDataFormat.arrayBuffer:
        {
          if (data is List<int>) {
            return _CapturedData.fromArrayBuffer(data);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromArrayBuffer(data.payloadArrayBuffer);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromArrayBuffer(dataUrl.payloadArrayBuffer);
            } else {
              var bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromArrayBuffer(bs);
              }

              dataEncoding ??= data_convert.utf8;

              return _CapturedData.fromArrayBuffer(dataEncoding.encode(s));
            }
          }
        }
      case CaptureDataFormat.dataUrlBase64:
        {
          if (data is List<int>) {
            return _CapturedData.fromDataUrlBase64(
                DataURLBase64(data_convert.base64.encode(data)));
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
                return _CapturedData.fromDataUrlBase64(DataURLBase64(s));
              }

              dataEncoding ??= data_convert.utf8;

              bs = dataEncoding.encode(s);
              return _CapturedData.fromDataUrlBase64(
                  DataURLBase64(data_convert.base64.encode(bs), 'text/plain'));
            }
          }
        }
      case CaptureDataFormat.base64:
        {
          if (data is List<int>) {
            return _CapturedData.fromBase64(data_convert.base64.encode(data));
          } else if (data is DataURLBase64) {
            return _CapturedData.fromBase64(data.payload);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromBase64(dataUrl.payloadBase64);
            } else {
              List<int>? bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromBase64(s);
              }

              dataEncoding ??= data_convert.utf8;

              bs = dataEncoding.encode(s);
              return _CapturedData.fromBase64(data_convert.base64.encode(bs));
            }
          }
        }
      case CaptureDataFormat.string:
        {
          if (data is List<int>) {
            var s = _decodeAsString(data, dataEncoding);
            return _CapturedData.fromString(s);
          } else if (data is DataURLBase64) {
            return _CapturedData.fromString(data.payload);
          } else {
            var s = data.toString();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromString(dataUrl.payload);
            } else {
              List<int>? bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromString(
                    _decodeAsString(bs, dataEncoding));
              }

              return _CapturedData.fromString(s);
            }
          }
        }
      case CaptureDataFormat.url:
        {
          if (data is List<int>) {
            return _CapturedData.fromURL(
                DataURLBase64(data_convert.base64.encode(data))
                    .asDataURLString());
          } else if (data is DataURLBase64) {
            return _CapturedData.fromURL(data.asDataURLString());
          } else {
            var s = data.toString().trim();
            var dataUrl = DataURLBase64.parse(s);

            if (dataUrl != null) {
              return _CapturedData.fromURL(dataUrl.asDataURLString());
            } else {
              List<int>? bs = _decodeBase64(s);
              if (bs != null) {
                return _CapturedData.fromURL(
                    DataURLBase64(s).asDataURLString());
              }

              return _CapturedData.fromURL(s);
            }
          }
        }
      default:
        throw StateError("Unknown format: $dataFormat");
    }
  }

  Uint8List dataAsArrayBuffer({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.arrayBuffer) {
      return data as Uint8List;
    } else {
      return _CapturedData.from(CaptureDataFormat.arrayBuffer, data,
              dataEncoding: dataEncoding)
          .data as Uint8List;
    }
  }

  String dataAsBase64({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.base64) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.base64, data,
              dataEncoding: dataEncoding)
          .data as String;
    }
  }

  DataURLBase64 dataAsDataUrlBase64({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.dataUrlBase64) {
      return data as DataURLBase64;
    } else {
      return _CapturedData.from(CaptureDataFormat.dataUrlBase64, data,
              dataEncoding: dataEncoding)
          .data as DataURLBase64;
    }
  }

  String dataAsString({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.string) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.string, data,
              dataEncoding: dataEncoding)
          .data as String;
    }
  }

  String dataAsURL({data_convert.Encoding? dataEncoding}) {
    if (dataFormat == CaptureDataFormat.url) {
      return data as String;
    } else {
      return _CapturedData.from(CaptureDataFormat.url, data,
              dataEncoding: dataEncoding)
          .data as String;
    }
  }

  MimeType? get mimeType {
    DataURLBase64? dataUrl;

    if (dataFormat == CaptureDataFormat.dataUrlBase64) {
      dataUrl = dataAsDataUrlBase64();
    } else if (dataFormat == CaptureDataFormat.url &&
        dataAsURL().startsWith('data:')) {
      dataUrl = dataAsDataUrlBase64();
    } else {
      try {
        dataUrl = dataAsDataUrlBase64();
      } catch (_) {}
    }

    if (dataUrl != null) {
      return dataUrl.mimeType;
    }

    return null;
  }

  _CapturedData withDataFormat(CaptureDataFormat targetDataFormat) {
    if (dataFormat != targetDataFormat) {
      return _CapturedData.from(targetDataFormat, data);
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
      var dataURL = fileReader.result as String;
      _notifyOnLoad(dataURL);
    });

    fileReader.readAsDataUrl(_file);
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
  ImageFileReader(File file) : super(file);

  @override
  void onLoad(String? dataURL, String type) {
    var img = ImageElement(src: dataURL);
    onLoadImage.add(img);
  }

  final EventStream<ImageElement> onLoadImage = EventStream();
}

class VideoFileReader extends URLFileReader {
  VideoFileReader(File file) : super(file);

  @override
  void onLoad(String? dataURL, String type) {
    var video = VideoElement();
    video.controls = true;

    var sourceElement = SourceElement();
    sourceElement.src = dataURL!;
    sourceElement.type = type;

    video.children.add(sourceElement);

    onLoadVideo.add(video);
  }

  final EventStream<VideoElement> onLoadVideo = EventStream();
}

class AudioFileReader extends URLFileReader {
  AudioFileReader(File file) : super(file);

  @override
  void onLoad(String? dataURL, String type) {
    var audio = AudioElement();
    audio.controls = true;

    var sourceElement = SourceElement();
    sourceElement.src = dataURL!;
    sourceElement.type = type;

    audio.children.add(sourceElement);

    onLoadAudio.add(audio);
  }

  final EventStream<AudioElement> onLoadAudio = EventStream();
}

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
  void onCaptureFile(FileUploadInputElement input, Event event) {
    if (showSelectedImageInButton) {
      showSelectedImage();
    }
  }

  final List<Element> _selectedImageElements = [];

  void showSelectedImage() {
    var dataURL = selectedFileDataAsDataURLBase64;
    if (dataURL == null) return;

    var content = this.content!;

    for (var e in _selectedImageElements) {
      content.children.remove(e);
    }

    if (onlyShowSelectedImageInButton) {
      content.children.removeWhere((e) => !e.hidden);
    }

    var img = ImageElement(src: dataURL)
      ..classes.add('ui-capture-img')
      ..style.margin = '2px 4px'
      ..style.maxHeight = '100%';

    if (selectedImageMaxWidth > 0) {
      img.style.maxWidth = '${selectedImageMaxWidth}px';
    }

    if (selectedImageMaxHeight > 0) {
      img.style.maxHeight = '${selectedImageMaxHeight}px';
    }

    if (isNotEmptyObject(selectedImageClasses)) {
      img.classes.addAll(selectedImageClasses!);
    }

    if (isNotEmptyString(selectedImageStyle, trim: true)) {
      img.style.cssText = '${img.style.cssText ?? ''}; $selectedImageStyle';
    }

    _selectedImageElements.clear();
    if (!onlyShowSelectedImageInButton) {
      _selectedImageElements.add(BRElement());
    }
    _selectedImageElements.add(img);

    img.onClick.listen((e) => fireClickEvent(e));

    content.children.addAll(_selectedImageElements);
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = null;
  }
}

class UIButtonCapture extends UICapture {
  final String text;

  final String? fontSize;

  UIButtonCapture(Element parent, this.text, CaptureType captureType,
      {String? fieldName,
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
  void onCaptureFile(FileUploadInputElement input, Event event) {
    if (showSelectedFileInButton) {
      showSelectedFile();
    }
  }

  void showSelectedFile() {
    var dataURL = selectedFileDataAsDataURLBase64;
    if (dataURL == null) return;

    content!.children.removeWhere((e) => (e is SpanElement || e is BRElement));

    var fileName = selectedFile != null ? selectedFile!.name : null;

    if (fileName != null && fileName.isNotEmpty) {
      content!.children.add(BRElement());
      content!.children.add(SpanElement()..text = fileName);
    }
  }

  void setWideButton() {
    content!.style.width = '80%';
  }

  void setNormalButton() {
    content!.style.width = null;
  }
}
