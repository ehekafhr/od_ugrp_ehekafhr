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
import 'package:flutter_zxing/flutter_zxing.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  List? _prediction;
  File _curCamera = File('assets/images/basic_image.png');
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  //ksh revised 10-26. I don't know why use
  //bool firststate = false;
  //bool message = true;
  //ksh revised 10-26. TTS
  final FlutterTts tts = FlutterTts();
  double _x=0;
  double _y=0;
  double x = 0;
  double y = 0;
  bool detecting = false;

  //ddr revised 10-25. what should mode do?

  List<String> modelNames = ["yolov5s.torchscript", "model2.torchscript", "model3.torchscript"];
  List<String> labelNames = ["labels.txt", "labels2.txt", "labels3.txt"];

  int mode = 1;
  void leftSlide(){
    if(mode<3) {
      mode +=1;
    } else {
      mode = 1;
    }
    if(mode==3){
    }
    HapticFeedback.lightImpact();

    //ksh revised 10-26. TTS
    String mode_kr = '';
    if(mode == 1) mode_kr = "일";
    if(mode == 2) mode_kr = "이";
    if(mode == 3) mode_kr = "삼으";
    String tts_message = '모드 ' + mode_kr + '로 변경되었습니다.';
    tts.speak(tts_message);

    sleep(Duration(milliseconds:500));
  }
  void rightSlide(){
    if(mode==3){
    }
    if(mode>1){
      mode-=1;
    } else {
      mode = 3;
    }
    HapticFeedback.lightImpact();
    //ksh revised 10-26. TTS
    String mode_kr = '';
    if(mode == 1) mode_kr = "일";
    if(mode == 2) mode_kr = "이";
    if(mode == 3) mode_kr = "삼으";
    String tts_message = '모드 ' + mode_kr + '로 변경되었습니다.';
    tts.speak(tts_message);

    sleep(Duration(milliseconds:500));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadModel();
    loadCamera();

    //ksh revised 10-26. TTS
    tts.setSpeechRate(0.3);
    tts.setLanguage("ko-KR");

     //zx is ..
  }

  Future loadModel() async {
    String pathObjectDetectionModel = "assets/models/${modelNames[0]}";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/${labelNames[0]}");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
    await Future.delayed(const Duration(milliseconds:100));
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
    //ksh revised 10-26. I don't know why need.
    /*setState(() {
      firststate = false;
      message = false;
    });*/

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
    if(mode !=3) {
      objDetect = await _objectModel.getImagePrediction(
          await File(image!.path).readAsBytes(),
          minimumScore: 0.01,
          IOUThershold: 0.01);

      //ksh revised 10-26. TTS
      String tts_message = '';

      List<ResultObjectDetection> results = [];

      for (var element in objDetect) {
        //ksh revised 10-26. TTS
        tts_message += "${labelList[element!.classIndex]}. ";
        results.add(element);

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
      }
      //ksh revised 10-26. TTS
      if(!detecting){
        tts.speak(tts_message);
      }
      //ksh revised 10-26. I don't know why use this.
      //scheduleTimeout(5 * 1000);

      setState(() {
      });
      return results;
    }
    //mode 3.
    else{
      final ImagePicker _picker = ImagePicker();
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);

    }

  }
  Future runObjectDetectionDetect(x,y) async {
    //ksh revised 10-26. I don't know why need.
    /*setState(() {
      firststate = false;
      message = false;
    });*/

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
    objDetect = await _objectModel.getImagePrediction(
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
      appBar: AppBar(title: const Text("OBJECT DETECTOR APP")),
      backgroundColor: Colors.red,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _x += details.delta.dx;
                _y += details.delta.dy;
              });
              if(!detecting) {
                if (_x > 300) {
                  rightSlide();
                  _x = 0;
                }
                else if (_x < -300) {
                  leftSlide();
                  _x = 0;
                }
              }
            },
            onTapDown: (TapDownDetails tapDetails) {
              var x = tapDetails.globalPosition.dx/MediaQuery.of(context).size.width;
              var y = tapDetails.globalPosition.dy/MediaQuery.of(context).size.height;
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
              if(!detecting){
                detecting = true;
                HapticFeedback.lightImpact();
                tts.speak("디텍트 모드.");
              }else{
                HapticFeedback.lightImpact();
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