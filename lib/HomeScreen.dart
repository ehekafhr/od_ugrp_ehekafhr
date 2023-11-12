import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'LoaderState.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:image/image.dart' as img;
import 'package:google_ml_kit/google_ml_kit.dart';
//import 'package:google_ml_kit_for_korean/google_ml_kit_for_korean.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:gallery_saver/gallery_saver.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  //final List<ModelObjectDetection> _objectModel = List.empty(growable: true);
  late ModelObjectDetection _objectModel1;
  late ModelObjectDetection _objectModel2;
  late ModelObjectDetection _objectModel3;

  File _curCamera = File('assets/images/basic_image.png');
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = List.empty(growable : true);

  final FlutterTts tts = FlutterTts();
  double _x=0;
  double _y=0;
  double x = 0;
  double y = 0;
  bool detecting = false;

  //ddr revised 10-25. what should mode do?

  List<String> modelNames = ["model1.torchscript", "best.torchscript", "model3.torchscript"]; //model들의 이름. 내용물 변경 필요 // 11-08 ksh revised. 0th dummy add. mode와 idx 일치 목적
  List<String> labelNames = ["labels.txt", "labels2.txt", "labels3.txt"]; //똑같이, 내용물 변경 필요.(asset/model asset/labels) // 11-08 ksh revised. 0th dummy add. mode와 idx 일치 목적

  int mode = 1; //기본 모드. mode 1 2 3 있음.

  //왼쪽으로 밀기
  void leftSlide(){
    if(mode<3) {
      mode +=1;
    } else {
      mode = 1;
    }
    if(mode==3){
    }
    Haptics.vibrate(HapticsType.heavy);

    //ksh revised 10-26. TTS
    String mode_kr = '';
    if(mode == 1) mode_kr = "일";
    if(mode == 2) mode_kr = "이";
    if(mode == 3) mode_kr = "삼으";
    String tts_message = '모드 ' + mode_kr + '로 변경되었습니다.';
    tts.speak(tts_message);

  }
  //오른쪽으로 밀기. haptic은 왠지 모르겠는데 안됨..
  void rightSlide(){
    if(mode==3){
    }
    if(mode>1){
      mode-=1;
    } else {
      mode = 3;
    }
    Haptics.vibrate(HapticsType.heavy);
    //ksh revised 10-26. TTS
    String mode_kr = '';
    if(mode == 1) mode_kr = "일";
    if(mode == 2) mode_kr = "이";
    if(mode == 3) mode_kr = "삼으";
    String tts_message = '모드 ' + mode_kr + '로 변경되었습니다.';
    tts.speak(tts_message);

  }

  File? myCrop(File inputImageFile, double left, double top, double width, double height, int crop_idx) {
    print('$left, $top, $width, $height');
    final bytes = inputImageFile.readAsBytesSync();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      // 이미지를 디코딩할 수 없음
      return null;
    }

    // 원본 이미지의 절반을 유지하고 왼쪽 절반을 자릅니다.
    //{score: 0.8971056, className: pricetag, class: 0, rect: {left: 0.38418707, top: 0.79063356, width: 0.11710417, height: 0.09816212, right: 0.5012912, bottom: 0.8887957}}
    //final croppedImage = img.copyResize(img.copyCrop(originalImage, x: left, y: top, width: width, height: height), width: 600, height: 800);
    int? w = originalImage?.width;
    int? h = originalImage?.height;
    print('$w $h');
    //print('x: ${w! - ((w!*top).toInt())}, y: ${(h! * left).toInt()}, width: ${(w! * height).toInt()}, height: ${(h!*width).toInt()}');
    //final croppedImage = img.copyCrop(originalImage, x: (w - (w!*top).toInt()), y: (h!*left).toInt(), width: (w!*height).toInt(), height: (h!*width).toInt());
    final croppedImage = img.copyCrop(originalImage, x: (w!*left).toInt(), y: (h!*(1-top)).toInt(), width: (w!*width).toInt(), height: (h!*height).toInt());

    if (croppedImage == null) {
      // 이미지를 자를 수 없음
      return null;
    }


    // 자른 이미지를 파일로 저장합니다.
    final outputImageFile = File('${inputImageFile.path.split('.jpg').join('')}_${crop_idx}.jpg');
    print(outputImageFile);
    outputImageFile.writeAsBytes(img.encodeJpg(croppedImage));

    GallerySaver.saveImage(outputImageFile.path);
    return outputImageFile;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadModel(); // mode 1
    //loadModel(2,1); // mode 2
    //loadModel(3,80); // mode 3. maybe not used
    loadCamera();

    //ksh revised 10-26. TTS
    tts.setSpeechRate(0.3);
    tts.setLanguage("ko-KR");

     //zx is ..
  }

  Future loadModel() async {
    try {
      String pathObjectDetectionModel = "assets/models/${modelNames[0]}";
      _objectModel1 = await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/${labelNames[0]}");

      pathObjectDetectionModel = "assets/models/${modelNames[1]}";
      _objectModel2 = await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, 1, 640, 640,
          labelPath: "assets/labels/${labelNames[1]}");

      pathObjectDetectionModel = "assets/models/${modelNames[2]}";
      _objectModel3 = await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/${labelNames[2]}");

    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  //ddr revised 10-25. Camera 10-29. 승주 code 참조해서 변환함.
  CameraController? controller;

  Future loadCamera() async{
    List<CameraDescription> cameras = await availableCameras();
    if(cameras != null) {
      try{
        controller= CameraController(cameras[0], ResolutionPreset.high);
        await controller!.initialize();
      } catch (e) {
        print(e);
        print("Is the error");
      }
    }
    else{
      print("Failed");
    }

    await Future.delayed(const Duration(milliseconds:100));
  }

  Future runObjectDetection(mode) async {
    //pick an image
    //final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    final XFile image = await controller!.takePicture();
    _curCamera =File(image!.path);

    if(mode == 1) {
      objDetect = await _objectModel1.getImagePrediction(
          await _curCamera.readAsBytes(),
          minimumScore: 0.3,
          IOUThershold: 0.3);
      String tts_message = "";

      for (var element in objDetect) {
        //그냥 변수들 확인용. print된 것들은 run에서 확인 가능.
        print({
          "score": element?.score,
          "className": element?.className,
          "class": element?.classIndex,
          "rect": {
            "left": element?.rect.left,
            "top": element?.rect.top,
            "width": element?.rect.width,
            "height": element?.rect.height,
            "right": element?.rect.right,
            "bottom": element?.rect.bottom,
          },
        });

        //ksh revised 10-26. TTS
        tts_message += "${element!.className!}\n";
      }
      print(tts_message);
      if(!detecting) tts.speak(tts_message);
    }
    else if(mode == 2) {
      objDetect = await _objectModel2.getImagePrediction(
          await _curCamera.readAsBytes(),
          minimumScore: 0.2,
          IOUThershold: 0.2);
      String tts_message = "";
      int crop_idx = 0;

      for (var element in objDetect) {
        print({
          "score": element?.score,
          "className": element?.className,
          "class": element?.classIndex,
          "rect": {
            "left": element?.rect.left,
            "top": element?.rect.top,
            "width": element?.rect.width,
            "height": element?.rect.height,
            "right": element?.rect.right,
            "bottom": element?.rect.bottom,
          },
        });

        //final bytes = _curCamera.readAsBytesSync();
        //final originalImage = img.decodeImage(bytes);

        // transpose
        var h = element!.rect.width;
        var w = element.rect.height;
        var t = 1 - element.rect.right;
        var b = 1 - element.rect.left;
        var l = 1 - element.rect.bottom;
        var r = 1 - element.rect.top;

        //File? croppedImage = myCrop(_curCamera, (w! * element!.rect.left).toInt(), (h! * element!.rect.top).toInt(), (w! * element!.rect.width).toInt(), (h! * element!.rect.height).toInt(), crop_idx);
        File? croppedImage = myCrop(_curCamera, l, b, w, h, crop_idx);

        crop_idx += 1;
        if (croppedImage != null){
          final inputImage = InputImage.fromFile(croppedImage);
          final textRecognizer = GoogleMlKit.vision.textRecognizer(script: TextRecognitionScript.korean);
          RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          await textRecognizer.close();

          for (TextBlock block in recognizedText.blocks) {
            for (TextLine line in block.lines) {
              tts_message += "${line.text}\n";
            }
          }
        }
      }
      print(tts_message);
      if(!detecting) tts.speak(tts_message);
    }
    //mode 3. test용, 구현 필요
    else{
      final ImagePicker _picker = ImagePicker();
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    }
  }
  //Detect mode에서 동작하는 runObjectDetection. mode는 전역 변수이기 때문에 문제 x.
  Future runObjectDetectionDetect(x,y) async {
    //ksh revised 11-09. Don't used
    //ksh revised 10-26. set Object Detection Output List
    // Load the file using rootBundle
    //final String labelsData = await rootBundle.loadString('assets/labels/${labelNames[0]}');
    // Split the content into lines and store them in labelList
    //final labelList = labelsData.split('\n').map((line) => line.trim()).toList();
    // Remove any empty lines from the list
    //labelList.removeWhere((label) => label.isEmpty);

    //pick an image
    //final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    final XFile image = await controller!.takePicture();
    _curCamera =File(image!.path);

    //final XFile? image = await _picker.pickImage(
    //    source: ImageSource.gallery, maxWidth: 200, maxHeight: 200);

    //ksh revised 11-09. Split code mode by mode
    if(mode == 1) {
      objDetect = await _objectModel1.getImagePrediction(
          await File(image!.path).readAsBytes(),
          minimumScore: 0.3,
          IOUThershold: 0.3);

      double minDistance = 2;
      var tts_message  = "";
      for (var element in objDetect) {
        //ksh revised 10-26. TTS
        //tts_message += "${element!.className}\n";
        print("$x $y");
        print(element!.rect.left);
        //results.add(element);
        var xDistance = min(((element!.rect.left)!-x).abs(),((element!.rect.right)-x).abs());
        var yDistance = min(((element!.rect.bottom)-y).abs(),((element!.rect.top)-y).abs());
        if(element!.rect.right>x && element!.rect.left<x) xDistance = 0;
        if(element!.rect.top>y && element!.rect.bottom<y) yDistance = 0;
        print(xDistance);
        print("Is the Xdistance");
        var distance = xDistance*xDistance+yDistance*yDistance;
        if (distance < minDistance){
          tts_message = "${element!.className}\n";
          minDistance = distance;
        }
      }

      //ksh revised 10-26. TTS
      if(detecting) tts.speak(tts_message);
    }
    else if(mode == 2) {
      objDetect = await _objectModel2.getImagePrediction(
          await _curCamera.readAsBytes(),
          minimumScore: 0.2,
          IOUThershold: 0.2);
      String tts_message = "";
      int crop_idx = 0;
      double minDistance = 0.02;

      for (var element in objDetect) {
        print({
          "score": element?.score,
          "className": element?.className,
          "class": element?.classIndex,
          "rect": {
            "left": element?.rect.left,
            "top": element?.rect.top,
            "width": element?.rect.width,
            "height": element?.rect.height,
            "right": element?.rect.right,
            "bottom": element?.rect.bottom,
          },
        });

        // transpose
        var h = element!.rect.width;
        var w = element.rect.height;
        var t = 1 - element.rect.right;
        var b = 1 - element.rect.left;
        var l = 1 - element.rect.bottom;
        var r = 1 - element.rect.top;

        var xDistance = min((l-x).abs(),(r-x).abs());
        var yDistance = min((b-y).abs(),(t-y).abs());
        if(r>x && l<x) xDistance = 0;
        if(t>y && b<y) yDistance = 0;
        print(xDistance);
        print("Is the Xdistance");
        var distance = xDistance*xDistance+yDistance*yDistance;
        if (distance < minDistance) {

          //final bytes = _curCamera.readAsBytesSync();
          //final originalImage = img.decodeImage(bytes);

          //File? croppedImage = myCrop(_curCamera, (w! * element!.rect.left).toInt(), (h! * element!.rect.top).toInt(), (w! * element!.rect.width).toInt(), (h! * element!.rect.height).toInt(), crop_idx);
          File? croppedImage = myCrop(_curCamera, l, b, w, h, crop_idx);

          crop_idx += 1;
          if (croppedImage != null){
            final inputImage = InputImage.fromFile(croppedImage);
            final textRecognizer = GoogleMlKit.vision.textRecognizer(script: TextRecognitionScript.korean);
            RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
            await textRecognizer.close();

            for (TextBlock block in recognizedText.blocks) {
              for (TextLine line in block.lines) {
                tts_message += "${line.text}\n";
              }
            }
          }
        }
      }
      print(tts_message);
      if(detecting) tts.speak(tts_message);
    }

    //mode 3. test용, 구현 필요
    else{
      final ImagePicker _picker = ImagePicker();
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ORVH")),
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          //슬라이드
          child: GestureDetector(

            onPanUpdate: (details) {
              setState(() {
                _x += details.delta.dx;
                _y += details.delta.dy;
              });
            },
            onPanEnd: (details) {
              if(!detecting){
                if(_x>300){
                  rightSlide();
                  _x = 0;
                }
                if(_x<-300){
                  leftSlide();
                  _x = 0;
                }
              }
            },
            //짧터치
            onTapDown: (TapDownDetails tapDetails) {
              var x = tapDetails.globalPosition.dx/MediaQuery.of(context).size.width;
              var y = tapDetails.globalPosition.dy/MediaQuery.of(context).size.height;
              Haptics.vibrate(HapticsType.heavy);
              if(mode == 3){
                 runObjectDetection(mode);
              }
              else{
                if(detecting){
                  runObjectDetectionDetect(x,(1-y));
                }
                else{
                  runObjectDetection(mode);
                }
              }
            },
            onLongPress: () {
              Haptics.vibrate(HapticsType.heavy);
              if(!detecting){
                detecting = true;
                tts.speak("디텍트 모드.");
              }else{
                detecting = false;
                tts.speak("일반 모드");
              }
            },
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  },
                child: FutureBuilder<void>(
                  builder: (context, snapshot){
                    //카메라 뷰 보여주기. 편의를 위함.
                    return CameraPreview(controller!);
                  }
                ),
              ),
            ),
          ),
        ),
      ),

    );
  }
}