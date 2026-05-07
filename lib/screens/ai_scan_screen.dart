import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/ai_services.dart';
import '../services/regulation_service.dart';
import 'measurement_screen.dart';
import 'encyclopedia_screen.dart'; 

class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isAnalyzing = false;

  final AiService _aiService = AiService();
  final RegulationService _regulationService = RegulationService();

  @override
  void initState() {
    super.initState();
    _initAllServices();
  }

  Future<void> _initAllServices() async {
    await _aiService.loadModel(); // MobileNetV3 로드
    await _regulationService.loadRegulations();
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) { print("카메라 에러: $e"); }
  }

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }

  // 📅 금어기 판단 로직
  bool _checkIfProhibited(String? range) {
    if (range == null || range.contains("없음")) return false;
    try {
      final now = DateTime.now();
      final currentMd = now.month * 100 + now.day;
      final dates = range.split('~');
      int pm(String t) {
        final p = t.trim().split(RegExp(r'월|일')).where((s) => s.isNotEmpty).toList();
        return int.parse(p[0]) * 100 + int.parse(p[1]);
      }
      final s = pm(dates[0]); final e = pm(dates[1]);
      return s <= e ? (currentMd >= s && currentMd <= e) : (currentMd >= s || currentMd <= e);
    } catch (e) { return false; }
  }

  // 📸 사진 촬영 및 분석
  Future<void> _takeAndAnalyzePhoto() async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    try {
      final photo = await _cameraController!.takePicture();
      final result = await _aiService.predict(File(photo.path));
      _showResultBottomSheet(result, File(photo.path));
    } finally { setState(() => _isAnalyzing = false); }
  }

  // 🎨 3장 그림 스타일 튜토리얼 팝업
  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: const BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              width: double.infinity,
              child: const Text("📏 스마트 계측 가이드", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildIllustrationStep("1", "👟 신발을 옆에 두기", "물고기 옆에 신발을 나란히 놓으세요.", Colors.orange.shade100, Icons.do_not_step),
                  const Divider(height: 30),
                  _buildIllustrationStep("2", "📸 한 번에 촬영하기", "물고기와 신발이 다 보이게 찍으세요.", Colors.blue.shade100, Icons.camera_alt),
                  const Divider(height: 30),
                  _buildIllustrationStep("3", "📏 선 긋고 측정 끝!", "결과창에서 선만 그으면 cm가 나옵니다.", Colors.green.shade100, Icons.edit_note),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("이해했어요!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustrationStep(String num, String title, String desc, Color bgColor, IconData icon) {
    return Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.black54),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        )
      ],
    );
  }

  // ✨ 결과 바텀 시트 (도감 연동 버튼 추가됨!)
  void _showResultBottomSheet(Map<String, dynamic> result, File file) {
    double confidence = result['confidence']; 
    String label = result['label'];
    bool isSuccess = label != '알 수 없음' && confidence >= 0.6;
    var reg = _regulationService.getRegulationInfo(label);
    bool isPro = _checkIfProhibited(reg?["금어기"]);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sc) => Container(
        padding: const EdgeInsets.fromLTRB(24, 15, 24, 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(file, height: 100, width: 100, fit: BoxFit.cover)),
            const SizedBox(height: 15),
            Text(isSuccess ? "🐟 $label" : "🚨 어종 인식 실패", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSuccess ? Colors.black87 : Colors.redAccent)),
            const SizedBox(height: 20),
            
            // ✨ [여기를 추가해 주세요!] 인식 실패 시 나타나는 안내 문구
            if (!isSuccess)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, 
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.shade100)
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("💡 다시 한 번 찍어주세요!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    SizedBox(height: 8),
                    Text("• 물고기가 파란색 가이드라인 중앙에 오도록 맞춰주세요.\n• 너무 멀거나 어두우면 AI가 헷갈려 할 수 있어요.\n• 물고기의 측면(옆면)이 잘 보이게 찍어주세요.", 
                      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)
                    ),
                  ],
                ),
              ),
            if (isSuccess && reg != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPro ? Colors.red.shade50 : Colors.blue.shade50, 
                  borderRadius: BorderRadius.circular(15), 
                  border: Border.all(color: isPro ? Colors.red.shade100 : Colors.blue.shade100)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(isPro ? Icons.warning : Icons.info, color: isPro ? Colors.red : Colors.blue),
                      const SizedBox(width: 8),
                      Text(isPro ? "금어기 (방생 필수)" : "보호 규정 안내", style: TextStyle(fontWeight: FontWeight.bold, color: isPro ? Colors.red : Colors.blue)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MeasurementScreen(imageFile: file, label: label)));
                        }, 
                        icon: const Icon(Icons.straighten, size: 14, color: Colors.blueAccent),
                        label: const Text("신발로 크기 측정", style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.blue.shade200))),
                      ),
                    ]),
                    const Divider(height: 20),
                    Text("• 금어기: ${reg["금어기"]}"),
                    Text("• 금지체장: ${reg["금지체장"]}"),
                    if (reg["비고"] != null && reg["비고"].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("${reg["비고"]}", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),

            // ✨ [새로 추가된 기능] 인식 성공 시 '내 도감에 저장' 버튼 표시
            if (isSuccess)
              SizedBox(
                width: double.infinity, 
                height: 50, 
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sc); // 바텀시트 먼저 닫기
                    // 🚀 도감 화면으로 사진과 이름 넘겨주기!
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => EncyclopediaScreen(
                          capturedImage: file, 
                          targetFish: label
                        )
                      )
                    );
                  }, 
                  icon: const Icon(Icons.book, color: Colors.white),
                  label: const Text("내 도감에 저장 및 확인", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // 친환경적인 느낌의 색상
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  )
                )
              ),
            
            if (isSuccess) const SizedBox(height: 10),

            // 기존 닫기 버튼 (디자인을 회색으로 낮춰서 도감 버튼이 돋보이게 함)
            SizedBox(
              width: double.infinity, 
              height: 50, 
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sc), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200, 
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                child: const Text("닫기", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))
              )
            ),
            
            TextButton(
              onPressed: () {
                Navigator.pop(sc);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오답 신고가 접수되었습니다. 더 나은 결과를 보답하도록 노력하겠습니다.'), behavior: SnackBarBehavior.floating));
              }, 
              child: const Text("결과가 틀렸나요? (오답 신고)", style: TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.underline))
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),
          Positioned.fill(child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut), child: Stack(children: [Container(color: Colors.transparent), Align(alignment: Alignment.center, child: Container(width: 280, height: 280, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30))))]))),
          Align(alignment: Alignment.center, child: Container(width: 280, height: 280, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF007AFF), width: 3), borderRadius: BorderRadius.circular(30)))),
          
          Positioned(top: 60, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)), child: const Text("가이드라인 안에 물고기를 맞추세요", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))))),

          Positioned(
            top: 55, right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _showTutorialDialog,
                  child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.help_outline, color: Colors.white, size: 28)),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                  child: const Text("길이 재는 법", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Positioned(bottom: 100, left: 0, right: 0, child: Center(child: _isAnalyzing ? const CircularProgressIndicator() : GestureDetector(onTap: _takeAndAnalyzePhoto, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.white.withOpacity(0.2)), child: Center(child: Container(width: 55, height: 55, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))))))),
        ],
      ),
    );
  }
}