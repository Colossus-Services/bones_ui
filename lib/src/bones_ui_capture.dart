
import 'dart:html';

import 'bones_ui_base.dart';
import 'bones_ui_component.dart';

import 'package:swiss_knife/swiss_knife_browser.dart';

enum CaptureType {
  PHOTO,
  PHOTO_SELFIE,
  VIDEO,
  VIDEO_SELFIE,
  AUDIO
}

abstract class UICapture extends UIButton {

  final CaptureType captureType ;

  UICapture(Element container, this.captureType, {dynamic classes}) : super(container, classes: classes) ;

  @override
  String renderHiddens() {

    String capture ;
    String accept ;

    if ( captureType == CaptureType.PHOTO ) {
      accept = 'image/*' ;
      capture = 'environment';
    }
    else if ( captureType == CaptureType.PHOTO_SELFIE ) {
      accept = 'image/*' ;
      capture = 'user';
    }
    else if ( captureType == CaptureType.VIDEO ) {
      accept = 'video/*' ;
      capture = 'environment';
    }
    else if ( captureType == CaptureType.VIDEO_SELFIE ) {
      accept = 'video/*' ;
      capture = 'user';
    }
    else if ( captureType == CaptureType.AUDIO ) {
      accept = 'audio/*' ;
    }

    var input = '<input field="capture" type="file"' ;

    input += accept != null ? " accept='$accept'" : '' ;
    input += capture != null ? " capture='$capture'" : ' capture' ;

    input += ' hidden>' ;

    UIConsole.log(input);

    return input ;
  }

  @override
  void posRender() {
    FileUploadInputElement fieldCapture = getInputCapture();
    fieldCapture.onChange.listen( (e) => onCapture(fieldCapture, e) ) ;
  }

  void onCapture(FileUploadInputElement input, Event event) {
    var file = getInputFile() ;

    if ( file != null ) {
      UIConsole.log('onCapture> $input > $event > ${ event.type } > $file') ;
      UIConsole.log('file> ${ file.name } ; ${ file.type } ; ${ file.lastModified } ; ${ file.relativePath }') ;
    }
  }

  @override
  void onClickEvent(event, List params) {
    FileUploadInputElement input = getInputCapture();
    input.value = null;
    input.click();
  }

  Element getInputCapture() => getFieldElement('capture');

  File getInputFile() {
    FileUploadInputElement input = getInputCapture();
    return input != null && input.files.isNotEmpty ? input.files[0] : null ;
  }

  bool isFileImage() {
    var file = getInputFile();
    return file != null && file.type.contains('image') ;
  }

  bool isFileVideo() {
    var file = getInputFile();
    return file != null && file.type.contains('video') ;
  }

  bool isFileAudio() {
    var file = getInputFile();
    return file != null && file.type.contains('audio') ;
  }

  ImageFileReader getImageFileReader() {
    var file = getInputFile();
    if ( file == null || !isFileImage() ) return null ;
    return ImageFileReader(file) ;
  }

  VideoFileReader getVideoFileReader() {
    var file = getInputFile();
    if ( file == null || !isFileVideo() ) return null ;
    return VideoFileReader(file) ;
  }

  AudioFileReader getAudioFileReader() {
    var file = getInputFile();
    if ( file == null || !isFileAudio() ) return null ;
    return AudioFileReader(file) ;
  }

}

class URLFileReader {
  final File _file ;

  URLFileReader(this._file) {
    var fileReader = FileReader();

    fileReader.onLoad.listen((e) {
      var dataURL = fileReader.result ;

      try {
        onLoad(dataURL, _file.type);
      } catch (e) {
        UIConsole.error('Error calling onLoad', e) ;
      }

      try {
        onLoadData.add(dataURL);
      } catch (e) {
        UIConsole.error('Error calling onLoadData controler', e) ;
      }
    });

    fileReader.readAsDataUrl(_file);
  }

  final EventStream<String> onLoadData = EventStream() ;

  void onLoad(String dataURL, String type) {

  }

}

class ImageFileReader extends URLFileReader {

  ImageFileReader(File file) : super(file) ;

  @override
  void onLoad(String dataURL, String type) {
    var img = ImageElement(src: dataURL) ;
    onLoadImage.add(img) ;
  }

  final EventStream<ImageElement> onLoadImage = EventStream() ;

}

class VideoFileReader extends URLFileReader {

  VideoFileReader(File file) : super(file) ;

  @override
  void onLoad(String dataURL, String type) {
    var video = VideoElement() ;
    video.controls = true ;

    var sourceElement = SourceElement();
    sourceElement.src = dataURL ;
    sourceElement.type = type ;

    video.children.add(sourceElement);

    onLoadVideo.add(video) ;
  }

  final EventStream<VideoElement> onLoadVideo = EventStream() ;

}

class AudioFileReader extends URLFileReader {

  AudioFileReader(File file) : super(file) ;

  @override
  void onLoad(String dataURL, String type) {
    var audio = AudioElement() ;
    audio.controls = true ;

    var sourceElement = SourceElement();
    sourceElement.src = dataURL ;
    sourceElement.type = type ;

    audio.children.add(sourceElement);

    onLoadAudio.add(audio) ;
  }

  final EventStream<AudioElement> onLoadAudio = EventStream() ;

}
