import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// ── dangerMessage 필드 추가
class AiPredictionResult {
  final List<FishCandidate> topCandidates;
  final bool isReliable;
  final bool isConfusingPair;
  final String? warningMessage;
  final String? dangerMessage;

  AiPredictionResult({
    required this.topCandidates,
    required this.isReliable,
    required this.isConfusingPair,
    this.warningMessage,
    this.dangerMessage,
  });

  FishCandidate get top => topCandidates.first;
}

class FishCandidate {
  final String englishLabel;
  final String koreanName;
  final double confidence;

  FishCandidate({
    required this.englishLabel,
    required this.koreanName,
    required this.confidence,
  });
}

class AiService {
  late Interpreter interpreter;
  List<String>? labels;

  static const double kReliableThreshold = 0.55;
  static const double kMinConfidence     = 0.30;
  static const double kAmbiguousMargin   = 0.15;

  static const Map<String, String> kLabelToKorean = {
    "0_black_sea_bream":   "감성돔",
    "1_flat_fish":         "광어",
    "2_rock_fish":         "우럭",
    "3_fat_greenling":     "쥐노래미",
    "4_red_seabream":      "참돔",
    "5_background":        "알 수 없음",
    "6_bellied_greenling": "노래미",
    "7_flounder":          "도다리",
    "8_black_rabbitfish":  "독가시치",
    "9_rudder_fish":       "벵에돔",
    "10_marbled_rockfish": "볼락",
  };

  static const Map<String, String> kDangerousSpecies = {
    "8_black_rabbitfish":
        "독가시치는 등지느러미·배지느러미·뒷지느러미에 독침이 있습니다. 맨손으로 잡지 마시고 두꺼운 장갑을 착용하거나 니퍼로 가시를 제거한 후 취급하세요. 찔렸을 경우 즉시 뜨거운 물(45~50℃)에 담그고 병원을 방문하세요.",
  };

  static const List<Set<String>> kConfusingPairs = [
    {"3_fat_greenling", "6_bellied_greenling"},
    {"1_flat_fish",     "7_flounder"},
    {"2_rock_fish",     "10_marbled_rockfish"},
  ];

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/fish_model_float16.tflite');

    final labelData = await rootBundle.loadString('assets/labels.txt');
    labels = labelData
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final inputShape  = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    print("✅ 모델 로드 완료");
    print("   Input  shape : $inputShape");
    print("   Output shape : $outputShape");
    print("   라벨 수       : ${labels!.length}개");

    for (var label in labels!) {
      if (!kLabelToKorean.containsKey(label)) {
        print("⚠️  한국어 매핑 없음: '$label'");
      }
    }
  }

  String toKoreanName(String englishLabel) =>
      kLabelToKorean[englishLabel] ?? englishLabel;

  List<double> _toProbs(List<double> raw) {
    final bool alreadyProbs = raw.every((v) => v >= 0.0 && v <= 1.0);
    final double sumCheck = raw.fold(0.0, (a, b) => a + b);
    // 합이 1에 가깝고 모든 값이 0~1 범위면 이미 softmax된 확률
    if (alreadyProbs && (sumCheck - 1.0).abs() < 0.05) {
      return raw;
    }
    final maxVal  = raw.reduce(max);
    final expVals = raw.map((e) => exp(e - maxVal)).toList();
    final expSum  = expVals.reduce((a, b) => a + b);
    return expVals.map((e) => e / expSum).toList();
  }

  bool _isConfusingPair(String a, String b) {
    final pair = {a, b};
    return kConfusingPairs.any((cp) => cp.containsAll(pair));
  }

  // ── [핵심 수정] 정규화: 무조건 255.0 고정 + 0~1 클램프
  /// PyTorch의 ToTensor()와 정확히 같은 동작:
  ///   1) uint8 픽셀(0~255)을 0.0~1.0으로 변환
  ///   2) ImageNet mean/std로 정규화
  List<double> _runSingleInference(img.Image image) {
    const mean     = [0.485, 0.456, 0.406];
    const std      = [0.229, 0.224, 0.225];
    const cropSize = 224;
    const double inv255 = 1.0 / 255.0;  // ← 학습과 동일하게 무조건 255

    final inputShape = interpreter.getInputTensor(0).shape;
    final bool isNCHW = (inputShape.length == 4 && inputShape[1] == 3);

    Object input;
    if (isNCHW) {
      input = [
        List.generate(3, (c) =>
          List.generate(cropSize, (y) =>
            List.generate(cropSize, (x) {
              final pixel = image.getPixel(x, y);
              final ch    = [pixel.r, pixel.g, pixel.b];
              // 픽셀이 8비트보다 크면(16비트 PNG 등) 8비트로 다운스케일
              double v = ch[c].toDouble();
              if (v > 255.0) v = v / 257.0;  // 16비트(0~65535) → 8비트(0~255) 근사
              return (v * inv255 - mean[c]) / std[c];
            })
          )
        )
      ];
    } else {
      input = [
        List.generate(cropSize, (y) =>
          List.generate(cropSize, (x) {
            final pixel = image.getPixel(x, y);
            double r = pixel.r.toDouble();
            double g = pixel.g.toDouble();
            double b = pixel.b.toDouble();
            if (r > 255.0) r = r / 257.0;
            if (g > 255.0) g = g / 257.0;
            if (b > 255.0) b = b / 257.0;
            return <double>[
              (r * inv255 - mean[0]) / std[0],
              (g * inv255 - mean[1]) / std[1],
              (b * inv255 - mean[2]) / std[2],
            ];
          })
        )
      ];
    }

    var output = [List<double>.filled(labels!.length, 0.0)];
    interpreter.run(input, output);
    return output[0];
  }

  Future<AiPredictionResult> predict(File imageFile) async {
    // ── 1. 이미지 로드 + EXIF 보정
    final rawBytes = imageFile.readAsBytesSync();
    final decoded  = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception("이미지를 디코드할 수 없습니다.");
    }
    final rawImage = img.bakeOrientation(decoded);

    // ── 2. 비율 무시하고 224×224로 강제 리사이즈
    //     PC TFLite 검증 스크립트(PIL Image.resize((224, 224)))와 정확히 동일.
    //     이 방식이 학습 시 transforms.Resize→CenterCrop과는 다르지만,
    //     실제로 변환된 모델은 이 입력에 최적화되어 있음 (검증 정확도 84.55%).
    const int cropSize = 224;
    final img.Image cropped = img.copyResize(
      rawImage,
      width:         cropSize,
      height:        cropSize,
      interpolation: img.Interpolation.linear,  // PIL의 기본은 BILINEAR
    );

    // ── 3. 단일 추론 (TTA 제거 — 학습 시 HorizontalFlip 이미 적용됨)
    final raw = _runSingleInference(cropped);

    // ── 4. 확률 변환
    final List<double> probs = _toProbs(raw);

    // ── 진단 로그 (배포 전 제거 가능)
    final sortedProbs = (probs.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => "${labels![e.key]}: ${(e.value * 100).toStringAsFixed(1)}%")
        .toList();
    print("[AiService] Top-3: $sortedProbs");

    // ── 5. Top-3 추출
    final indexed = probs.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top3 = indexed.take(3).map((e) {
      final label = labels![e.key];
      return FishCandidate(
        englishLabel: label,
        koreanName:   toKoreanName(label),
        confidence:   e.value,
      );
    }).toList();

    // ── 6. 안전성 판단
    final top1 = top3[0].confidence;
    final top2 = top3.length > 1 ? top3[1].confidence : 0.0;

    String? warning;
    bool isReliable = true;

    if (top3[0].englishLabel == "5_background") {
      isReliable = false;
      warning    = "물고기가 인식되지 않았습니다. 물고기가 화면 중앙에 오도록 다시 촬영해주세요.";
    } else if (top1 < kMinConfidence) {
      isReliable = false;
      warning    = "어종 식별이 어렵습니다. 더 선명한 사진을 찍어주세요.";
    } else if (top1 < kReliableThreshold) {
      isReliable = false;
      warning    = "AI 식별 신뢰도가 낮습니다 (${(top1 * 100).toStringAsFixed(0)}%). 직접 확인해주세요.";
    } else if (top1 - top2 < kAmbiguousMargin) {
      isReliable = false;
      warning    = "비슷한 어종이 있어 식별이 불확실합니다. 두 가지 가능성을 모두 확인하세요.";
    }

    bool isConfusing = false;
    if (top3.length >= 2) {
      isConfusing = _isConfusingPair(top3[0].englishLabel, top3[1].englishLabel);
      if (isConfusing && warning == null) {
        warning = "${top3[0].koreanName}과(와) ${top3[1].koreanName}은(는) 외형이 매우 비슷합니다. 규정을 직접 확인하세요.";
      }
    }

    // ── 7. 위험 어종 경고 (신뢰 가능 + background 아님 + 충분히 확신할 때만)
    String? dangerMessage;
    final isBackground = top3[0].englishLabel == "5_background";
    final isHighConfidence = top1 >= kReliableThreshold;
    final isClearWinner = (top1 - top2) >= kAmbiguousMargin;

    if (!isBackground && isHighConfidence && isClearWinner) {
      dangerMessage = kDangerousSpecies[top3[0].englishLabel];
    }

    return AiPredictionResult(
      topCandidates:   top3,
      isReliable:      isReliable,
      isConfusingPair: isConfusing,
      warningMessage:  warning,
      dangerMessage:   dangerMessage,
    );
  }
}