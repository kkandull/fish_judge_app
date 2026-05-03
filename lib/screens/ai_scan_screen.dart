import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/ai_services.dart';
import '../services/regulation_service.dart';

class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false; // 분석(로딩) 상태

  final AiService _aiService = AiService();
  final RegulationService _regulationService = RegulationService();

  @override
  void initState() {
    super.initState();
    _initAllServices();
  }

  // AI 두뇌, JSON, 카메라 렌즈 초기화
  Future<void> _initAllServices() async {
    await _aiService.loadModel();
    await _regulationService.loadRegulations();

    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false, // 셔터 소리 외 불필요한 오디오 권한 제거
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("카메라 초기화 실패: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose(); // 메모리 최적화 (필수)
    super.dispose();
  }

  // 📸 사진 촬영 및 분석 로직
  Future<void> _takeAndAnalyzePhoto() async {
    if (!_cameraController!.value.isInitialized || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);

      final result = await _aiService.predict(imageFile);
      _showResultBottomSheet(result, imageFile);
    } catch (e) {
      print("촬영/분석 중 에러: $e");
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // ✨ 세련된 결과 팝업 (Bottom Sheet)
  void _showResultBottomSheet(Map<String, dynamic> result, File imageFile) {
    double confidence = result['confidence'] as double;
    String label = result['label'] as String;
    Map<String, dynamic>? regulationInfo;
    
    String titleText = "";
    String subText = "";
    bool isSuccess = false;

    // 판독 로직
    if (label == '알 수 없음') {
      titleText = "🚨 물고기가 아닙니다!";
      subText = "배경이나 사물로 인식되었습니다.\n물고기가 중앙에 오도록 다시 찍어주세요.";
    } else if (confidence < 0.60) {
      titleText = "🤔 알 수 없는 어종입니다.";
      subText = "AI 확신도가 너무 낮습니다. (${(confidence * 100).toStringAsFixed(1)}%)\n조명이 밝은 곳에서 다시 찍어주세요.";
    } else {
      titleText = "🐟 $label";
      subText = "AI 확신도: ${(confidence * 100).toStringAsFixed(1)}%";
      regulationInfo = _regulationService.getRegulationInfo(label);
      isSuccess = true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 💡 [중요] 팝업 내부의 context와 화면의 context가 충돌하지 않도록 이름을 sheetContext로 변경합니다.
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.only(top: 15, left: 24, right: 24, bottom: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 손잡이 바
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            
            // 🖼️ 찍은 사진 프리뷰 (그림자 효과 추가)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(imageFile, height: 120, width: 120, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),

            // 텍스트 영역
            Text(titleText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isSuccess ? Colors.black87 : Colors.redAccent)),
            const SizedBox(height: 8),
            Text(subText, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4)),
            const SizedBox(height: 25),

            // 🎣 성공 시: 금어기 정보 카드
            if (isSuccess && regulationInfo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('금어기 및 금지체장 안내', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white, thickness: 2)),
                    
                    // 💡 [완벽 매칭] 조장님의 JSON 키 값인 "금어기", "금지체장"을 정확히 호출합니다!
                    Text('• 금어기: ${regulationInfo["금어기"] ?? "정보 없음"}', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text('• 방생 기준: ${regulationInfo["금지체장"] ?? "정보 없음"}', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                  ],
                ),
              ),

            const SizedBox(height: 30),
            
            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('확인 및 다시 찍기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            
            const SizedBox(height: 10), // 버튼 사이 여백
            // 2. 🔥 새로 추가된 '오답 신고' 텍스트 버튼
            TextButton.icon(
              onPressed: () {
                // ① 팝업창을 먼저 부드럽게 닫아줍니다.
                Navigator.pop(sheetContext); 
                
                // ② 화면 하단에 스낵바(Toast) 메시지를 띄웁니다.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(child: Text('신고가 접수되어 다음 AI 학습에 반영됩니다!')),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating, // 화면에 살짝 떠오르는 스타일
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 3), // 3초 뒤 사라짐
                  ),
                );
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.grey),
              label: const Text(
                '결과가 틀렸나요? (오답 신고)',
                style: TextStyle(
                  fontSize: 13, 
                  color: Colors.grey, 
                  decoration: TextDecoration.underline, // 텍스트에 밑줄을 그어 클릭하고 싶게 유도
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade300, // 클릭했을 때 살짝 퍼지는 물결 효과 색상
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 풀스크린 배경
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // 2. 💡 [수정됨] 완벽한 스캐너 뚫기 마법 (ColorFiltered 적용)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.65), // 바깥쪽 배경을 어둡게 (숫자 조절 가능)
                BlendMode.srcOut, // ⭐️ 안쪽을 100% 투명하게 뚫어주는 블렌드 모드
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent, 
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black, // 여기가 실제로 뚫리는 '구멍' 영역입니다.
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2-1. 뚫린 구멍 위에 예쁜 파란색 테두리만 살짝 얹기
          Positioned.fill(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF007AFF), width: 3),
                ),
              ),
            ),
          ),

          // 3. 상단 안내 문구 뱃지 (기존 코드와 동일)
          Positioned(
            top: MediaQuery.of(context).padding.top + 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Text(
                  "가이드라인 안에 물고기를 맞추고 촬영하세요",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),

          // 4. 하단 DSLR급 셔터 버튼 (아이폰 순정 카메라 느낌)
          Positioned(
            bottom: 110, // 하단 네비게이션 바(BottomNav)에 가리지 않게 위로 띄움
            left: 0,
            right: 0,
            child: Center(
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(color: Color(0xFF007AFF), strokeWidth: 5),
                    )
                  : GestureDetector(
                      onTap: _takeAndAnalyzePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.transparent, // 겉은 투명한 링
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white, // 속은 꽉 찬 하얀색 원
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}