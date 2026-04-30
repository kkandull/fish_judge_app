import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_services.dart'; // AI 서비스 불러오기

class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> {
  File? _selectedImage; // 찍은 사진을 저장할 변수
  String _resultText = "버튼을 눌러 물고기 사진을 찍어주세요."; // 화면에 띄울 결과 글자
  bool _isLoading = false; // 로딩 상태

  final AiService _aiService = AiService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initAi(); // 화면이 켜질 때 AI 모델 로딩
  }

  // AI 두뇌 준비
  Future<void> _initAi() async {
    await _aiService.loadModel();
  }

  // 1. 카메라 켜서 사진 찍기
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _isLoading = true;
        _resultText = "AI가 어종을 분석 중입니다... 🐟";
      });
      
      // 사진을 찍었으면 바로 AI에게 넘기기
      _analyzeFish(); 
    }
  }

  // 2. AI 판독 실행
  Future<void> _analyzeFish() async {
    if (_selectedImage == null) return;

    try {
      final result = await _aiService.predict(_selectedImage!);
      
      setState(() {
        _isLoading = false;
        double confidence = result['confidence'] as double;
        
        // 🔥 임계값 설정: 60% (0.6) 미만이면 판독 불가 처리
        if (confidence < 0.60) {
          _resultText = "인식 실패: 알 수 없는 어종입니다.\n(확률이 너무 낮습니다: ${(confidence * 100).toStringAsFixed(1)}%)\n물고기가 잘 보이게 다시 찍어주세요.";
        } else {
          // 60% 이상일 때만 결과 보여주기
          _resultText = "판독 결과: ${result['label']}\n(확률: ${(confidence * 100).toStringAsFixed(1)}%)";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultText = "판독 중 오류가 발생했습니다.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 어종 판독'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3. 사진을 찍었으면 화면에 보여주기, 아니면 카메라 아이콘 보여주기
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 300, fit: BoxFit.cover)
                : const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
            
            const SizedBox(height: 30),
            
            // 4. 결과 글씨 보여주기
            Text(
              _resultText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 40),
            
            // 5. 판독 시작 버튼
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _takePhoto,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('카메라 켜기 / 다시 찍기', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}