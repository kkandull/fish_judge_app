import '../models/unified_catch_record.dart';

class PostGeneratorService {
  static String generate(UnifiedCatchRecord record) {
    final fish = record.fishName;
    final location = record.displayLocation;
    final date = record.dateStr;
    final weather = record.weather;
    final length =
        record.lengthCm != null ? '${record.lengthCm!.toStringAsFixed(1)}cm' : null;
    final weight =
        record.weightG != null ? '${record.weightG!.toStringAsFixed(0)}g' : null;

    final sizeText = [
      if (length != null) length,
      if (weight != null) weight,
    ].join(' / ');

    final memo =
        record.memo.trim().isNotEmpty ? '\n\n메모:\n${record.memo}' : '';

    return '''
🎣 $date 조과 기록

오늘은 $location 에서 낚시 다녀왔습니다.

${record.count}마리의 $fish 를 잡았고,
날씨는 "$weather" 였습니다.

${sizeText.isNotEmpty ? '사이즈는 $sizeText 정도 나왔네요.\n' : ''}손맛 정말 좋았습니다 :)

$memo

#낚시 #$fish #조과 #바다낚시
''';
  }
}