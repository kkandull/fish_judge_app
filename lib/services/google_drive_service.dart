// 오답 신고 사진 + 내용을 Google Apps Script → Google Drive로 전송

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbwnNKdfySRnyaL_RU1lulbdsAfVbwnDnKB8tkGHc88R7z-TZB6jY63cweRgFGL3JLyxNw/exec';

  /// 오답 신고 사진과 정보를 구글 드라이브로 전송
  static Future<bool> uploadWrongAnswer({
    required File imageFile,
    required String predictedLabel,
    required String userComment,
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final fileName =
          'WRONG_${predictedLabel}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fileName': fileName,
          'contentType': 'image/jpeg',
          'base64Data': base64Image,
          'comment': userComment,
          'predicted': predictedLabel,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 302) {
        print('✅ 오답 신고 드라이브 업로드 성공');
        return true;
      } else {
        print('❌ 업로드 실패 (${response.statusCode})');
        return false;
      }
    } catch (e) {
      print('❌ 업로드 예외: $e');
      return false;
    }
  }
}