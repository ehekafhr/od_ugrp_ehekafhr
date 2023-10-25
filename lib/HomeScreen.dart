import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  File? _imageFile;
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  List? _prediction;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];

  //ddr revised 10-25. what should mode do?
  int mode = 1;
  void rightSlide(){
    if(mode<3) {
      mode +=1;
    } else {
      mode = 1;
    }
    sleep(Duration(milliseconds:500));
  }
  void leftSlide(){
    if(mode>1){
      mode-=1;
    } else {
      mode = 3;
    }
    sleep(Duration(milliseconds:500));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadModel();
    loadCamera();
  }

  Future loadModel() async {
    String pathObjectDetectionModel = "assets/models/yolov5s.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
        //Remeber here 80 value represents number of classes for custom model it will be different don't forget to change this.
          pathObjectDetectionModel, 80, 640, 640,
          labelPath: "assets/labels/labels.txt");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  List<CameraDescription> ? cameras;
  CameraController? controller;
  loadCamera() async{
    cameras = await availableCameras();
    if(cameras != null) {
      controller = CameraController(cameras![0], ResolutionPreset.max);
      controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    }else{
      print("Error: No camera found");
    }
  }

  Future runObjectDetection() async {
    //pick an image

    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 200, maxHeight: 200);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.05,
        IOUThershold: 0.1);
    objDetect.forEach((element) {
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
    });
    setState(() {
      _image = File(image!.path);
    });
  }

  Future runObjectDetectionLong() async {
    //pick an image

    final XFile image = await controller!.takePicture();
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.05,
        IOUThershold: 0.1);
    objDetect.forEach((element) {
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
    });
    setState(() {
      _image = File(image!.path);
    });
  }
  double _x=0;
  double _y=0;

  bool detecting = false;

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
              if(_x>300){
                rightSlide();
                _x = 0;
              }
              else if(_x<-300){
                leftSlide();
                _x = 0;
              }
            },
            onTap: () {},
            onLongPress: () {
              runObjectDetectionLong();
            },
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: ElevatedButton(
                onPressed: () {runObjectDetection();},
                child: Text("$mode+"),
              ),
            ),
          ),
        ),
      ),

    );
  }

}