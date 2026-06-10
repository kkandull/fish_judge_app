// 이미지를 Base64로 인코딩.
// Firestore에 저장하기 위해 Storage 없이 직접 문서 안에 이미지를 넣음.
// 사용처: 게시글 사진, 조과 기록 사진

import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;

class ImageEncoder {
  // 본 이미지 설정
  static const int _fullMaxDim = 800;
  static const int _fullQuality = 75;
  
  // 썸네일 설정
  static const int _thumbMaxDim = 240;
  static const int _thumbQuality = 70;
  
  /// 게시글 작성 화면(post_compose_screen) 호환용 메소드
  static Future<({String thumbBase64, String fullBase64})> encodeForPost(File file) async {
    final result = await encodeImage(file);
    return (
      thumbBase64: result['thumbnail']!,
      fullBase64: result['full']!,
    );
  }

  /// 반환:
  ///   {
  ///     'full': 'iVBORw0KGgo...',   // 본 이미지 Base64
  ///     'thumbnail': 'iVBORw...',   // 썸네일 Base64
  ///   }
  static Future<Map<String, String>> encodeImage(File file) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('이미지를 읽을 수 없어요');
    }
    
    // EXIF 회전 정보 적용 (세로로 찍은 사진이 가로로 표시되는 문제 방지)
    final oriented = img.bakeOrientation(original);
    
    // 본 이미지 (긴 변 기준 800px)
    final full = _resize(oriented, _fullMaxDim);
    final fullJpeg = img.encodeJpg(full, quality: _fullQuality);
    final fullBase64 = base64Encode(fullJpeg);
    
    // 썸네일 (긴 변 기준 240px)
    final thumb = _resize(oriented, _thumbMaxDim);
    final thumbJpeg = img.encodeJpg(thumb, quality: _thumbQuality);
    final thumbBase64 = base64Encode(thumbJpeg);
    
    // 크기 확인 (Firestore 1MB 한도)
    final totalKB = (fullBase64.length + thumbBase64.length) ~/ 1024;
    if (totalKB > 900) {
      throw Exception('이미지가 너무 커요 (${totalKB}KB)');
    }
    
    return {
      'full': fullBase64,
      'thumbnail': thumbBase64,
    };
  }
  
  /// 긴 변 기준으로 리사이즈 (종횡비 유지)
  static img.Image _resize(img.Image src, int maxDim) {
    final w = src.width;
    final h = src.height;
    
    if (w <= maxDim && h <= maxDim) return src;
    
    if (w > h) {
      return img.copyResize(src, width: maxDim, interpolation: img.Interpolation.linear);
    } else {
      return img.copyResize(src, height: maxDim, interpolation: img.Interpolation.linear);
    }
  }
  
  /// Base64 문자열의 대략적인 KB 크기
  static int sizeInKB(String? base64Str) {
    if (base64Str == null) return 0;
    return base64Str.length ~/ 1024;
  }
}