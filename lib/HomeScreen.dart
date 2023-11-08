import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'LoaderState.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:image/image.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  final List<ModelObjectDetection> _objectModel = List.empty(growable: true);

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

  List<String> modelNames = ["model1.torchscript", "model1.torchscript", "best.torchscript", "model3.torchscript"]; //model들의 이름. 내용물 변경 필요 // 11-08 ksh revised. 0th dummy add. mode와 idx 일치 목적
  List<String> labelNames = ["labels.txt", "labels.txt", "labels2.txt", "labels3.txt"]; //똑같이, 내용물 변경 필요.(asset/model asset/labels) // 11-08 ksh revised. 0th dummy add. mode와 idx 일치 목적

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

  File? myCrop(File inputImageFile, int left, int top, int width, int height, int crop_idx) {
    final bytes = inputImageFile.readAsBytesSync();
    final originalImage = decodeImage(bytes);

    if (originalImage == null) {
      // 이미지를 디코딩할 수 없음
      return null;
    }

    // 원본 이미지의 절반을 유지하고 왼쪽 절반을 자릅니다.
    final croppedImage = copyCrop(originalImage, x: left, y: top, width: width, height: height);

    if (croppedImage == null) {
      // 이미지를 자를 수 없음
      return null;
    }

    // 자른 이미지를 파일로 저장합니다.
    final outputImageFile = File('${inputImageFile.path}_${crop_idx}');
    print(outputImageFile);
    outputImageFile.writeAsBytes(encodeJpg(croppedImage));

    return outputImageFile;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadModel(0,80); // ksh 11-08 add. dummy model (mode와 idx 일치시키기 위함)
    loadModel(1,80); // mode 1
    loadModel(2,1); // mode 2
    loadModel(3,80); // mode 3. maybe not used
    loadCamera();

    //ksh revised 10-26. TTS
    tts.setSpeechRate(0.3);
    tts.setLanguage("ko-KR");

     //zx is ..
  }

  Future loadModel(idx,count) async {
    String pathObjectDetectionModel = "assets/models/${modelNames[idx]}";
    try {
      _objectModel.add(await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, count, 640, 640,
          labelPath: "assets/labels/${labelNames[idx]}"));
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

    if(mode != 3) {
      double minimumScore;
      double IOUThershold;
      if(mode == 1){
        minimumScore = 0.3;
        IOUThershold = 0.3;
      }
      else {
        minimumScore = 0.5;
        IOUThershold = 0.3;
      }
      objDetect = await _objectModel[mode].getImagePrediction(
          await File(image!.path).readAsBytes(),
          minimumScore: minimumScore,
          IOUThershold: IOUThershold);


      //ksh revised 10-26. TTS
      String tts_message = "";
      List<ResultObjectDetection> results = [];

      int crop_idx = 0;
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
        if(mode == 1){
          //tts_message += "${labelList[mode][element!.classIndex]}. ";
          tts_message += "${element!.className!}\n";
        };

        if(mode == 2){
          final bytes = _curCamera.readAsBytesSync();
          final originalImage = decodeImage(bytes);
          int? w = originalImage?.width;
          int? h = originalImage?.height;
          /*
          File? croppedImage = myCrop(_curCamera, (w! * element!.rect.left).toInt(), (h! * element!.rect.top).toInt(), (w! * element!.rect.width).toInt(), (h! * element!.rect.height).toInt(),crop_idx);
          if (croppedImage != null){
            tts_message += myOCR(croppedImage) as String;
          }*/
          crop_idx += 1;
          // croppedImage를 OCR하여 OCR message에 add 필요
        }


        results.add(element!);
      }
      tts_message = myOCR(_curCamera).toString();
      tts.speak(tts_message);
      //ksh revised 10-26. TTS
      if(!detecting){
        tts.speak(tts_message);
      }

      setState(() {
      });
      return results;
    }
    //mode 3. test용, 구현 필요
    else{
      final ImagePicker _picker = ImagePicker();
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);

    }

  }
  //Detect mode에서 동작하는 runObjectDetection. mode는 전역 변수이기 때문에 문제 x.
  Future runObjectDetectionDetect(x,y) async {
    //ksh revised 10-26. set Object Detection Output List
    // Load the file using rootBundle
    final String labelsData = await rootBundle.loadString('assets/labels/${labelNames[0]}');
    // Split the content into lines and store them in labelList
    final labelList = labelsData.split('\n').map((line) => line.trim()).toList();
    // Remove any empty lines from the list
    labelList.removeWhere((label) => label.isEmpty);

    //pick an image
    //final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    final XFile image = await controller!.takePicture();
    _curCamera =File(image!.path);
    //final XFile? image = await _picker.pickImage(
    //    source: ImageSource.gallery, maxWidth: 200, maxHeight: 200);
    objDetect = await _objectModel[mode].getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.01,
        IOUThershold: 0.01);

    //ksh revised 10-26. TTS
    String tts_message = '';

    List<ResultObjectDetection> results = [];
    double minDistance = 2;
    var obj  = '';
    for (var element in objDetect) {
      //ksh revised 10-26. TTS

      tts_message += "${labelList[element!.classIndex]}. ";
      print("$x $y");
      print(element.rect.left);
      results.add(element);
      var xDistance = min(((element.rect.left)-x).abs(),((element.rect.right)-x).abs());
      var yDistance = min(((element.rect.bottom)-y).abs(),((element.rect.top)-y).abs());
      if(element.rect.right>x && element.rect.left<x) xDistance = 0;
      if(element.rect.top>y && element.rect.bottom<y) yDistance = 0;
      print(xDistance);
      print("Is the Xdistance");
      var distance = xDistance*xDistance+yDistance*yDistance;
      if (distance < minDistance){
        obj = "${labelList[element!.classIndex]}. ";
        minDistance = distance;
      }
    }

    //ksh revised 10-26. TTS
    if(detecting) tts.speak(obj);
    //ksh revised 10-26. I don't know why use this.
    //scheduleTimeout(5 * 1000);

    setState(() {
    });
    return results;
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

  Future<String?> myOCR(File? croppedImage) async {
    if (croppedImage == null) return null;
    final inputImage = InputImage.fromFile(croppedImage);
    final textRecognizer = GoogleMlKit.vision.textRecognizer(script: TextRecognitionScript.korean);
    RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String ttsMessage = "";

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        ttsMessage += "${line.text}\n";
      }
    }
    return ttsMessage;
  }

}