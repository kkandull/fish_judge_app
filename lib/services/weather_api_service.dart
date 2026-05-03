import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherApiService {
  // 나중에 발급받은 실제 기상청 API 키를 여기에 넣습니다.
  final String apiKey = 'YOUR_API_KEY';

  Future<Map<String, dynamic>> fetchWeatherData() async {
    // [테스트 1] 조장님 지시: 데이터를 불러오는 시간을 흉내 내기 위해 2초 대기 (빙글빙글 확인용)
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 실제 API 통신 코드는 나중에 이 주석을 풀고 사용합니다.
      // final response = await http.get(Uri.parse('기상청_API_URL'));
      // if (response.statusCode == 200) { return jsonDecode(response.body); }

      // 현재는 화면 UI 테스트를 위한 가짜(Mock) 데이터를 반환합니다.
      return {
        'temperature': '24.5',
        'waterTemp': null, // [테스트 2] 조장님 지시: 데이터가 안 왔을 때 튕기는지 보기 위해 일부러 null 삽입
        'waveHeight': '1.5',
      };
    } catch (e) {
      return {}; // 에러 발생 시 빈 데이터 반환
    }
  }
}