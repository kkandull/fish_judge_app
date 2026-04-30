import 'dart:io';
import 'dart:math'; // Softmax 계산을 위한 수학 라이브러리 추가
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AiService {
  late Interpreter interpreter;
  List<String>? labels;

  // 1. 모델 및 라벨 로드
  Future<void> loadModel() async {
    // TFLite 모델 불러오기
    interpreter = await Interpreter.fromAsset('assets/fish_model_float16.tflite');
    
    // 라벨(어종 이름) 불러오기
    final labelData = await rootBundle.loadString('assets/labels.txt');
    labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
    print("모델 및 라벨 로드 완료: $labels");
  }

  // Logit 값을 0~1 사이의 확률로 변환해 주는 함수 (Softmax)
  List<double> _applySoftmax(List<double> logits) {
    double maxLogit = logits.reduce(max); // 오버플로우 방지
    List<double> expValues = logits.map((e) => exp(e - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((e) => e / sumExp).toList();
  }

  // 2. 이미지 전처리 및 추론
  Future<Map<String, dynamic>> predict(File imageFile) async {
    // 이미지 디코딩 및 리사이징 (224x224)
    //final rawImage = img.decodeImage(imageFile.readAsBytesSync())!;
    //final resizedImage = img.copyResize(rawImage, width: 224, height: 224);
    final rawImage = img.decodeImage(imageFile.readAsBytesSync())!;
    int size = min(rawImage.width, rawImage.height);
    int x = (rawImage.width - size) ~/ 2;
    int y = (rawImage.height - size) ~/ 2;
    // 3. 가운데 부분만 정사각형으로 잘라내기 (찌그러짐 방지!)
    img.Image croppedImage = img.copyCrop(rawImage, x: x, y: y, width: size, height: size);
    
    // 4. 잘라낸 정사각형 이미지를 모델 크기(224x224)로 깔끔하게 리사이징
    final resizedImage = img.copyResize(croppedImage, width: 224, height: 224);
    // 모델 입력 형태에 맞게 변환 [1, 224, 224, 3] 및 정규화 (0~1)
    var input = List.generate(1, (i) =>
        List.generate(224, (j) =>
            List.generate(224, (k) =>
                [
                  (resizedImage.getPixel(k, j).r / 255.0),
                  (resizedImage.getPixel(k, j).g / 255.0),
                  (resizedImage.getPixel(k, j).b / 255.0),
                ]
            )
        )
    );

    // 출력 결과를 담을 리스트 (라벨 개수만큼 공간 확보)
    var output = List.generate(1, (i) => List.filled(labels!.length, 0.0));

    // 모델 추론 실행
    interpreter.run(input, output);

    // 1. 모델에서 나온 원시 결과값(Logit) 가져오기
    List<double> logits = (output[0] as List).cast<double>();
    
    // 2. Softmax를 적용하여 0~1 사이의 진짜 '확률'로 변환
    List<double> probabilities = _applySoftmax(logits);

    // 3. 가장 높은 확률과 그 인덱스(순서) 찾기
    double maxProb = probabilities.reduce(max);
    int maxIndex = probabilities.indexOf(maxProb);

    return {
      'label': labels![maxIndex], // 라벨에서 해당 어종 이름 찾기
      'confidence': maxProb,      // 0~1 사이의 확률값
    };
  }
}