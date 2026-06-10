// TFLite 기반 낚시 적합도 ML 점수 예측 서비스


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FishingScoreMLService {
  FishingScoreMLService._();
  static final instance = FishingScoreMLService._();

  Interpreter? _interpreter;
  List<double>? _normMin;
  List<double>? _normMax;
  bool _initialized = false;

  // 초기화 
  Future<void> init() async {
    try {
      // TFLite 모델 로드
      _interpreter = await Interpreter.fromAsset(
        'assets/models/fishing_score_model.tflite');

      // 정규화 파라미터 로드
      final jsonStr = await rootBundle.loadString(
        'assets/fishing_norm_params.json');
      final params = json.decode(jsonStr) as Map<String, dynamic>;
      _normMin = List<double>.from(params['min']);
      _normMax = List<double>.from(params['max']);

      _initialized = true;
      debugPrint('✅ FishingScoreMLService 초기화 완료');
    } catch (e) {
      debugPrint('FishingScoreMLService 초기화 실패 (기존 규칙 점수 사용): $e');
    }
  }

  bool get isAvailable => _initialized && _interpreter != null;

  // ML 점수 예측
  Future<int?> predict({
    required double waterTempC,
    required double windSpeedMs,
    required double waveHeightM,
    required int mulTtae,
    required int month,
    required int hour,
  }) async {
    if (!isAvailable) return null;

    try {
      // 입력 특징 벡터
      final rawInput = [
        waterTempC,
        windSpeedMs,
        waveHeightM,
        mulTtae.toDouble(),
        month.toDouble(),
        hour.toDouble(),
      ];

      // 정규화 (Min-Max Scaling)
      final normalized = List<double>.generate(6, (i) {
        final range = _normMax![i] - _normMin![i];
        if (range < 1e-8) return 0.0;
        return (rawInput[i] - _normMin![i]) / range;
      });

      // 추론
      final input = [normalized.map((v) => v.toDouble()).toList()];
      final output = List.filled(1, [0.0]);
      _interpreter!.run(input, output);

      final rawScore = output[0][0];
      final score = rawScore.clamp(0.0, 100.0).round();

      debugPrint('ML 점수: $rawScore → $score');
      return score;
    } catch (e) {
      debugPrint('ML 예측 실패: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}