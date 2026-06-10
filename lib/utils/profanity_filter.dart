// 단순 키워드 매칭 욕설 필터.
// 게시글/댓글 작성 시 호출.


class ProfanityFilter {
  // 기본 욕설/혐오 표현 (필요시 추가)
  static const _bannedWords = [
    // 욕설
    '시발', '씨발', '병신', '개새끼', '좆', '존나', '꺼져', '닥쳐',
    'ㅅㅂ', 'ㅆㅂ', 'ㅄ', 'ㅂㅅ', 'ㅈㄴ', 'ㄲㅈ',
    // 혐오 표현
    '한남', '한녀', '맘충', '급식충',
    // 광고
    '카톡', '톡주세요', '돈벌이', '재택부업',
  ];

  /// 욕설/금지어 포함 여부
  static bool contains(String text) {
    final normalized = _normalize(text);
    return _bannedWords.any((w) => normalized.contains(w));
  }

  /// 텍스트 정규화 (공백, 특수문자 제거 후 소문자)
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\.\,\!\?\@\#\$\%\^\&\*\(\)\-\_\+\=\[\]\{\}]'), '');
  }

  /// 첫 번째 발견된 금지어 반환 (사용자에게 알려줄 때)
  static String? firstBannedWord(String text) {
    final normalized = _normalize(text);
    for (final w in _bannedWords) {
      if (normalized.contains(w)) return w;
    }
    return null;
  }

  /// 금지어를 * 로 치환 (게시 후 보여줄 때 사용)
  static String mask(String text) {
    var result = text;
    for (final w in _bannedWords) {
      result = result.replaceAll(w, '*' * w.length);
    }
    return result;
  }

  /// 게시글/댓글 검사 — 통과 시 null, 실패 시 에러 메시지
  static String? validate(String text) {
    if (text.trim().isEmpty) {
      return '내용을 입력해주세요';
    }
    if (contains(text)) {
      return '부적절한 표현이 포함되어 있어요';
    }
    return null;
  }
}
