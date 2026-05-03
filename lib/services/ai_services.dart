import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AiService {
  late Interpreter interpreter;
  List<String>? labels;

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/fish_model_float16.tflite');
    final labelData = await rootBundle.loadString('assets/labels.txt');
    
    // 🔥 핵심 수정: .map((s) => s.trim()) 을 추가하여 보이지 않는 공백과 줄바꿈 문자를 완벽하게 날려버립니다!
    labels = labelData.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    print("✅ 모델 로드 완료! Input Shape: ${interpreter.getInputTensor(0).shape}");
    print("✅ 라벨 목록(공백 제거됨): $labels"); // 디버깅용 출력
  }

  List<double> _applySoftmax(List<double> logits) {
    double maxLogit = logits.reduce(max);
    List<double> expValues = logits.map((e) => exp(e - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((e) => e / sumExp).toList();
  }

  Future<Map<String, dynamic>> predict(File imageFile) async {
    try {
      final rawImage = img.decodeImage(imageFile.readAsBytesSync())!;
      int size = min(rawImage.width, rawImage.height);
      int x = (rawImage.width - size) ~/ 2;
      int y = (rawImage.height - size) ~/ 2;
      
      img.Image croppedImage = img.copyCrop(rawImage, x: x, y: y, width: size, height: size);
      final resizedImage = img.copyResize(croppedImage, width: 224, height: 224);
      
      final mean = [0.485, 0.456, 0.406];
      final std = [0.229, 0.224, 0.225];

      var inputShape = interpreter.getInputTensor(0).shape;
      Object input;

      // 🔥 피드백 1: 모든 배열에 제네릭(<double>)을 강제 주입하여 TFLite 충돌 완벽 방지
      if (inputShape.length == 4 && inputShape[1] == 3) {
        // NCHW 포맷 (파이토치 원본 형태)
        input = [
          List<List<List<double>>>.generate(3, (c) => 
            List<List<double>>.generate(224, (y) => 
              List<double>.generate(224, (x) {
                final pixel = resizedImage.getPixel(x, y);
                double pixelValue = 0.0;
                if (c == 0) pixelValue = pixel.r / 255.0;
                if (c == 1) pixelValue = pixel.g / 255.0;
                if (c == 2) pixelValue = pixel.b / 255.0;
                return (pixelValue - mean[c]) / std[c];
              })
            )
          )
        ];
      } else {
        // NHWC 포맷 (텐서플로 라이트 최적화 형태)
        input = [
          List<List<List<double>>>.generate(224, (y) => 
            List<List<double>>.generate(224, (x) {
              final pixel = resizedImage.getPixel(x, y);
              return <double>[
                (pixel.r / 255.0 - mean[0]) / std[0],
                (pixel.g / 255.0 - mean[1]) / std[1],
                (pixel.b / 255.0 - mean[2]) / std[2],
              ];
            })
          )
        ];
      }

      // 🔥 피드백 2: 출력 배열 역시 강타입(Strong Type)으로 초기화
      var output = [List<double>.filled(labels!.length, 0.0)];
      
      // 모델 추론 실행
      interpreter.run(input, output);

      // 🔥 피드백 3: 불필요한 cast() 제거
      List<double> logits = output[0];
      List<double> probabilities = _applySoftmax(logits);

      double maxProb = probabilities.reduce(max);
      int maxIndex = probabilities.indexOf(maxProb);

      return {
        'label': labels![maxIndex], 
        'confidence': maxProb,      
      };
    } catch (e) {
      // 이제 에러가 나더라도 터미널에 정확한 이유가 찍힙니다.
      print("🚨 AI 분석 중 치명적 오류 발생: $e");
      rethrow; 
    }
  }
}