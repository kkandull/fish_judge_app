import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_services.dart';
import '../services/gemini_service.dart';
import '../services/google_drive_service.dart';
import '../services/weather_service.dart';
import '../services/regulation_service.dart';
import 'measurement_screen.dart';
import 'encyclopedia_screen.dart';
import 'post_compose_screen.dart'; // ✅ Day 6 추가

class AiScanScreen extends StatefulWidget {
  final bool isActive; // ⭐ 탭 활성화 여부
  const AiScanScreen({super.key, this.isActive = false});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false; // 카메라 권한 거부 상태
  bool _isAnalyzing = false;
  bool _isFlashOn = false;       // 현재 플래시 상태
  bool _autoFlashEnabled = true; // 자동 플래시 켜기 설정

  final AiService _aiService = AiService();
  final RegulationService _regulationService = RegulationService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAllServices();
  }

  Future<void> _initAllServices() async {
    await _aiService.loadModel();
    await _regulationService.loadRegulations();
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      // 기본 플래시 OFF로 시작
      await _cameraController!.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _isCameraInitialized = true);
      // ⭐ 자동 감지는 탭 진입 시 didChangeDependencies에서 실행
    } catch (e) {
      debugPrint('카메라 에러: $e');
      // 권한 거부 감지 (CameraException 또는 권한 관련 에러)
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('permission') ||
          errStr.contains('denied') ||
          errStr.contains('access') ||
          errStr.contains('cameraexception')) {
        if (mounted) setState(() => _isCameraPermissionDenied = true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 화면 떠날 때 플래시 반드시 끄기
    if (_isFlashOn) {
      _cameraController?.setFlashMode(FlashMode.off);
    }
    _cameraController?.dispose();
    super.dispose();
  }

  // ── 앱 생명주기: 백그라운드 가면 플래시 끄기 ──────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isFlashOn) {
        _cameraController?.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      }
    }
  }

  // 📅 금어기 판단 로직
  bool _checkIfProhibited(String? range) {
    if (range == null ||
        range.contains("없음") ||
        range.contains("확인 필요") ||
        range.contains("해당 없음")) {
      return false;
    }
    try {
      final now = DateTime.now();
      final currentMd = now.month * 100 + now.day;
      final dates = range.split('~');
      int pm(String t) {
        final p = t.trim().split(RegExp(r'월|일')).where((s) => s.isNotEmpty).toList();
        return int.parse(p[0]) * 100 + int.parse(p[1]);
      }
      final s = pm(dates[0]);
      final e = pm(dates[1]);
      return s <= e ? (currentMd >= s && currentMd <= e) : (currentMd >= s || currentMd <= e);
    } catch (e) {
      return false;
    }
  }

  // ── 플래시 토글 ─────────────────────────────────
  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
    await _cameraController!.setFlashMode(newMode);
    setState(() => _isFlashOn = !_isFlashOn);
  }

  // ── 조도 자동 감지 → 어두우면 플래시 자동 ON ────────
  Future<void> _checkAndAutoFlash() async {
    if (!_autoFlashEnabled || _cameraController == null) return;
    if (_cameraController!.value.isStreamingImages) return;
    try {
      bool detected = false;
      _cameraController!.startImageStream((CameraImage image) async {
        if (detected) return;
        detected = true;
        // 즉시 스트림 중지
        try { await _cameraController?.stopImageStream(); } catch (_) {}

        // Y채널(밝기)만 샘플링 — 빠르고 정확
        final bytes = image.planes[0].bytes;
        int total = 0;
        final step = (bytes.length ~/ 200).clamp(1, 9999);
        int count = 0;
        for (int i = 0; i < bytes.length; i += step) {
          total += bytes[i];
          count++;
        }
        final avg = count > 0 ? total / count : 128.0;
        debugPrint('[Flash] 평균 밝기: ${avg.toStringAsFixed(1)}');

        if (avg < 80 && mounted) {
          await _cameraController?.setFlashMode(FlashMode.torch);
          if (mounted) setState(() => _isFlashOn = true);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.flash_on, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text('어두운 환경 감지 — 플래시를 자동으로 켰어요',
                  style: TextStyle(fontSize: 13)),
              ]),
              backgroundColor: const Color(0xFF212529),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[Flash] 조도 감지 실패 (무시): $e');
    }
  }

  // ── 카메라 촬영 + 가이드라인 영역 크롭
  Future<void> _takeAndAnalyzePhoto() async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    try {
      final photo = await _cameraController!.takePicture();
      final croppedFile = await _cropToGuideline(File(photo.path));
      final result = await _aiService.predict(croppedFile);
      if (mounted) _showResultBottomSheet(result, croppedFile);
    } catch (e) {
      print("촬영/분석 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('분석 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<File> _cropToGuideline(File originalPhoto) async {
    final bytes = await originalPhoto.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return originalPhoto;

    final oriented = img.bakeOrientation(decoded);

    final shortSide = min(oriented.width, oriented.height);
    final cropSize = (shortSide * 0.72).toInt();
    
    final cx = (oriented.width  - cropSize) ~/ 2;
    final cy = (oriented.height - cropSize) ~/ 2;

    final cropped = img.copyCrop(
      oriented,
      x: cx, y: cy,
      width: cropSize, height: cropSize,
    );

    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));

    return tmpFile;
  }

  // ── 갤러리에서 사진 선택 후 분석
  Future<void> _pickFromGalleryAndAnalyze() async {
    if (_isAnalyzing) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
      );
      if (picked == null) return;

      setState(() => _isAnalyzing = true);

      final result = await _aiService.predict(File(picked.path));
      if (mounted) _showResultBottomSheet(result, File(picked.path));
    } catch (e) {
      print("갤러리 분석 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 분석할 수 없습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ✅ Day 6 추가: 커뮤니티에 질문 올리기
  void _askCommunity(File image, String? guessedFishName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposeScreen(
          prefilledFishName: guessedFishName,
          prefilledImage: image,
        ),
      ),
    );
  }

  // 🎨 튜토리얼 팝업 (기존 그대로)
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
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              width: double.infinity,
              child: const Text("📏 스마트 계측 가이드",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildIllustrationStep("1", "👟 신발을 옆에 두기", "물고기 옆에 신발을 나란히 놓으세요.",
                      Colors.orange.shade100, Icons.do_not_step),
                  const Divider(height: 30),
                  _buildIllustrationStep("2", "📸 한 번에 촬영하기", "물고기와 신발이 다 보이게 찍으세요.",
                      Colors.blue.shade100, Icons.camera_alt),
                  const Divider(height: 30),
                  _buildIllustrationStep("3", "📏 선 긋고 측정 끝!", "결과창에서 선만 그으면 cm가 나옵니다.",
                      Colors.green.shade100, Icons.edit_note),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("이해했어요!",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          width: 50,
          height: 50,
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

  // ✨ 결과 바텀 시트 (Top-3 + 안전 경고 + 면책 + 커뮤니티 질문)
  // ── 오답 신고 다이얼로그 ───────────────────────────────────
  void _showWrongAnswerDialog(BuildContext sc, File file, String predicted) {
    final commentCtrl = TextEditingController();
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('오답 신고',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('AI가 "$predicted"로 판독했어요.\n실제 어종이 다르다면 신고해주세요!',
              style: const TextStyle(fontSize: 13, color: Color(0xFF868E96), height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '실제 어종이나 추가 설명을 적어주세요 (선택)',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF868E96)),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: uploading ? null : () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
                child: const Text('취소',
                  style: TextStyle(color: Color(0xFF868E96))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: uploading ? null : () async {
                  setDialogState(() => uploading = true);
                  final success = await GoogleDriveService.uploadWrongAnswer(
                    imageFile: file,
                    predictedLabel: predicted,
                    userComment: commentCtrl.text.isEmpty
                        ? '의견 없음' : commentCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (sc.mounted) Navigator.pop(sc); // 바텀시트도 닫기
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? '오답 신고가 접수됐어요. 더 나은 앱으로 보답할게요!'
                          : '신고 전송에 실패했어요. 잠시 후 다시 시도해주세요.'),
                      backgroundColor: success
                          ? const Color(0xFF1976D2) : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
                child: uploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Text('신고하기',
                        style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  void _showResultBottomSheet(AiPredictionResult result, File file) {
    final top = result.top;
    final isBackground = top.englishLabel == "5_background";
    final showFishInfo = result.isReliable && !isBackground;

    final reg = showFishInfo ? _regulationService.getRegulationInfo(top.koreanName) : null;
    final isPro = reg != null && _checkIfProhibited(reg["금어기"]);
    final isIncomplete = reg != null && _regulationService.isRegulationIncomplete(reg);

    // ✅ Day 6: 커뮤니티 질문 노출 조건
    // - 신뢰도 낮을 때 (50% 미만 또는 isReliable=false)
    // - background로 잘못 잡힌 게 아니어야 함
    final showAskCommunity = !isBackground && 
        (!result.isReliable || top.confidence < 0.6);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sc) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(file, height: 100, width: 100, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 15),

              // ─── 결과 헤더
              Center(
                child: Text(
                  showFishInfo ? "🐟 ${top.koreanName}" : "어종 인식 실패",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: showFishInfo ? Colors.black87 : Colors.redAccent,
                  ),
                ),
              ),
              if (showFishInfo)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "AI 신뢰도 ${(top.confidence * 100).toStringAsFixed(0)}%",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ─── 경고 메시지
              if (result.warningMessage != null) _buildWarningBox(result.warningMessage!),

              // ─── 위험 어종 경고
              if (result.dangerMessage != null) ...[
                const SizedBox(height: 10),
                _buildDangerBox(result.dangerMessage!),
              ],

              // ─── 인식 실패 시 촬영 가이드
              if (!showFishInfo) _buildRetryGuide(),

              // ─── Top-3 후보 표시
              if (showFishInfo) ...[
                const SizedBox(height: 12),
                _buildTopCandidates(result.topCandidates),
              ],

              // ─── 규정 정보 카드
              if (showFishInfo && reg != null) ...[
                const SizedBox(height: 12),
                _buildRegulationCard(reg, isPro, isIncomplete, top.koreanName, file),
              ],

              // ─── 규정 정보 없음
              if (showFishInfo && reg == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text("규정 정보 미등록",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        "'${top.koreanName}'의 규정 정보가 앱에 등록되어 있지 않습니다. 해양수산부 또는 지역 수협에 문의해주세요.",
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── ⭐ Gemini AI 낚시 조언
              if (showFishInfo) _GeminiTipsCard(
                fishName: top.koreanName,
              ),

              const SizedBox(height: 20),

              // ─── 도감 저장 버튼 (신뢰 가능한 경우만)
              if (showFishInfo)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sc);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EncyclopediaScreen(
                            capturedImage: file,
                            targetFish: top.koreanName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.book, color: Colors.white),
                    label: const Text("내 도감에 저장",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (showFishInfo) const SizedBox(height: 10),

              // ✅ Day 6 추가: 커뮤니티에 물어보기 (신뢰도 낮을 때)
              if (showAskCommunity)
                _buildAskCommunityCard(file, showFishInfo ? top.koreanName : null),

              if (showAskCommunity) const SizedBox(height: 10),

              // ─── 닫기 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("닫기",
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // ─── 면책 문구
              _buildDisclaimer(),

              TextButton(
                onPressed: () => _showWrongAnswerDialog(sc, file, top.koreanName),
                child: const Text(
                  "결과가 틀렸나요? (오답 신고)",
                  style: TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Day 6 신규: 커뮤니티 질문 카드
  Widget _buildAskCommunityCard(File file, String? guessedFish) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                "확실하지 않아요?",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "커뮤니티의 다른 낚시인에게 물어볼 수 있어요.\n사진은 자동으로 첨부됩니다.",
            style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7684)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // 바텀시트 닫기
                _askCommunity(file, guessedFish);
              },
              icon: const Icon(Icons.forum, color: Colors.white, size: 18),
              label: const Text("커뮤니티에 물어보기",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
  Widget _buildDangerBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dangerous, color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                "⚠️ 위험 어종 주의",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("※다시 촬영해 주세요",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          SizedBox(height: 8),
          Text(
            "• 물고기가 가이드라인 중앙에 오도록 맞춰주세요.\n• 물고기의 측면(옆면)이 잘 보이게 찍어주세요.\n• 너무 멀거나 어두우면 인식이 어려워요.\n• 등지느러미와 꼬리지느러미가 보이도록 찍으면 좋습니다.",
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCandidates(List<FishCandidate> candidates) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text("AI 식별 후보 (정확하지 않을 수 있어요)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          ...candidates.asMap().entries.map((entry) {
            final idx = entry.key;
            final c = entry.value;
            final pct = (c.confidence * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: idx == 0 ? Colors.teal : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text("${idx + 1}",
                          style: TextStyle(
                            color: idx == 0 ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.koreanName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                  Text("$pct%",
                      style: TextStyle(
                        fontSize: 13,
                        color: idx == 0 ? Colors.teal : Colors.grey.shade600,
                        fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  Widget _buildRegulationCard(
      Map<String, dynamic> reg, bool isPro, bool isIncomplete, String koreanName, File file) {
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final String title;
    final Color accentColor;

    if (isPro) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      icon = Icons.warning;
      title = "⚠️ 금어기 (방생 권장)";
      accentColor = Colors.red;
    } else if (isIncomplete) {
      bgColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      icon = Icons.info_outline;
      title = "정보 일부 누락";
      accentColor = Colors.amber.shade800;
    } else {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      icon = Icons.info;
      title = "보호 규정 안내";
      accentColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: accentColor, fontSize: 15)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MeasurementScreen(imageFile: file, label: koreanName),
                  ),
                );
              },
              icon: const Icon(Icons.straighten, size: 14, color: Colors.blueAccent),
              label: const Text("크기 측정",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
            ),
          ]),
          const Divider(height: 20),
          Text("• 금어기: ${reg["금어기"]}", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text("• 금지체장: ${reg["금지체장"]}", style: const TextStyle(fontSize: 14)),
          if (reg["비고"] != null && reg["비고"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("${reg["비고"]}",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                      height: 1.4)),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    final disclaimer = _regulationService.disclaimer;
    final version = _regulationService.version;
    final lastUpdated = _regulationService.lastUpdated;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text("법적 안내", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            disclaimer.isNotEmpty
                ? disclaimer
                : "본 정보는 참고용입니다. 최종 책임은 사용자에게 있습니다.",
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.5),
          ),
          if (version.isNotEmpty || lastUpdated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "규정 데이터 v$version (갱신: $lastUpdated)",
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  // ── 탭 전환 감지: isActive 파라미터 변화 감지 ───────────────
  @override
  void didUpdateWidget(AiScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 비활성 → 활성: 플래시 감지 실행
    if (widget.isActive && !oldWidget.isActive && _isCameraInitialized) {
      _cameraController?.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _isFlashOn = false);
      _autoFlashEnabled = true;
      _checkAndAutoFlash();
    }
    // 활성 → 비활성: 플래시 끄기
    if (!widget.isActive && oldWidget.isActive) {
      if (_isFlashOn) {
        _cameraController?.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _isFlashOn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 카메라 권한 거부 UI
    if (_isCameraPermissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: 20),
              const Text('카메라 권한이 필요해요',
                style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('AI 어종 판독을 위해\n카메라 접근 권한을 허용해주세요',
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  // 앱 설정 열기
                  // app_settings 패키지 없으면 그냥 재시도
                  setState(() => _isCameraPermissionDenied = false);
                  await _initAllServices();
                },
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // 설정 앱으로 이동 안내
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('설정 > 앱 > 나우피싱 > 권한 > 카메라 허용'),
                      behavior: SnackBarBehavior.floating));
                },
                child: const Text('설정에서 허용하는 방법',
                  style: TextStyle(color: Colors.white38, fontSize: 12))),
            ]),
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── 카메라 프리뷰 ──────────────────────────────
          Positioned.fill(child: CameraPreview(_cameraController!)),

          // ── 어두운 오버레이 (가이드라인 구멍) ────────────
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5), BlendMode.srcOut),
              child: Stack(children: [
                Container(color: Colors.transparent),
                Align(
                  alignment: const Alignment(0, -0.1),
                  child: Container(
                    width: 270, height: 270,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(28))),
                ),
              ]),
            ),
          ),

          // ── 가이드라인 테두리 ──────────────────────────
          Align(
            alignment: const Alignment(0, -0.1),
            child: Container(
              width: 270, height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF007AFF), width: 2.5),
                borderRadius: BorderRadius.circular(28)),
              child: Stack(children: [
                // 모서리 포인터 (카메라 앱 느낌)
                ..._buildCorners(),
              ]),
            ),
          ),

          // ── 상단 바 (안내 문구) ────────────────────────
          Positioned(
            top: safePadding.top + 16,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Text('물고기를 가이드라인 안에 맞추세요',
                  style: TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600, letterSpacing: 0.2)),
              ),
            ),
          ),

          // ── 우측 상단 버튼 그룹 ────────────────────────
          Positioned(
            top: safePadding.top + 14,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 플래시 버튼
                _IconBtn(
                  icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  label: _isFlashOn ? 'ON' : 'OFF',
                  active: _isFlashOn,
                  activeColor: const Color(0xFFFFC107),
                  onTap: _toggleFlash,
                ),
                const SizedBox(height: 12),
                // 길이 재는 법
                _IconBtn(
                  icon: Icons.straighten,
                  label: '길이',
                  onTap: _showTutorialDialog,
                ),
              ],
            ),
          ),

          // ── 가이드라인 아래 힌트 텍스트 ──────────────────
          Align(
            alignment: const Alignment(0, 0.28),
            child: Text(
              _isFlashOn ? '💡 플래시 켜짐' : '어두우면 우측 플래시 버튼을 눌러주세요',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500),
            ),
          ),

          // ── 하단 컨트롤 ───────────────────────────────
          Positioned(
            bottom: safePadding.bottom + 48,
            left: 0, right: 0,
            child: _isAnalyzing
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5)),
                    const SizedBox(height: 12),
                    Text('AI 판독 중...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ])
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 갤러리 버튼
                      _RoundBtn(
                        size: 52,
                        icon: Icons.photo_library_outlined,
                        iconSize: 24,
                        onTap: _pickFromGalleryAndAnalyze,
                        label: '갤러리',
                      ),
                      const SizedBox(width: 36),
                      // 촬영 버튼 (중앙 메인)
                      GestureDetector(
                        onTap: _takeAndAnalyzePhoto,
                        child: Container(
                          width: 76, height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white.withOpacity(0.15)),
                          child: Center(
                            child: Container(
                              width: 60, height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      // 빈 공간 (좌우 대칭)
                      const SizedBox(width: 52),
                    ],
                  ),
          ),

        ],
      ),
    );
  }

  // 가이드라인 모서리 포인터 4개
  List<Widget> _buildCorners() {
    const c = Color(0xFF007AFF);
    const len = 22.0;
    const thick = 3.0;
    return [
      // 좌상
      Positioned(top: 0, left: 0, child: _Corner(c, len, thick, true, true)),
      // 우상
      Positioned(top: 0, right: 0, child: _Corner(c, len, thick, true, false)),
      // 좌하
      Positioned(bottom: 0, left: 0, child: _Corner(c, len, thick, false, true)),
      // 우하
      Positioned(bottom: 0, right: 0, child: _Corner(c, len, thick, false, false)),
    ];
  }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 카메라 UI 공통 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 우측 아이콘 버튼 (플래시 / 길이재는법)
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? activeColor
                : Colors.black.withOpacity(0.45),
            border: Border.all(
              color: active ? activeColor : Colors.white.withOpacity(0.5),
              width: 1.5)),
          child: Icon(icon,
            color: active ? Colors.black87 : Colors.white,
            size: 22)),
        const SizedBox(height: 4),
        Text(label,
          style: TextStyle(
            color: active ? activeColor : Colors.white.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// 하단 원형 버튼 (갤러리)
class _RoundBtn extends StatelessWidget {
  final double size;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final String label;

  const _RoundBtn({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.45),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
          child: Icon(icon, color: Colors.white, size: iconSize)),
        const SizedBox(height: 5),
        Text(label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// 가이드라인 모서리 포인터
class _Corner extends StatelessWidget {
  final Color color;
  final double len;
  final double thick;
  final bool top;
  final bool left;

  const _Corner(this.color, this.len, this.thick, this.top, this.left);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: len, height: len,
      child: CustomPaint(painter: _CornerPainter(color, thick, top, left)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top;
  final bool left;

  _CornerPainter(this.color, this.thick, this.top, this.left);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ⭐ Gemini AI 낚시 조언 카드
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _GeminiTipsCard extends StatefulWidget {
  final String fishName;
  const _GeminiTipsCard({required this.fishName});

  @override
  State<_GeminiTipsCard> createState() => _GeminiTipsCardState();
}

class _GeminiTipsCardState extends State<_GeminiTipsCard> {
  List<String>? _tips;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    final weather = WeatherService.instance.cachedData;
    final tips = await GeminiService.instance.getFishingTipsAfterCapture(
      fishName: widget.fishName,
      waterTempC: weather?.waterTempC ?? 18.0,
      waveHeightM: weather?.waveHeightM ?? 0.5,
      month: DateTime.now().month,
    );
    if (mounted) {
      setState(() {
        _tips = tips;
        _loading = false;
        _failed = tips == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gemini 사용 불가 또는 실패 시 카드 숨김
    if (_failed && !_loading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1565C0).withOpacity(0.06),
                   const Color(0xFF42A5F5).withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('✨', style: TextStyle(fontSize: 10)),
              SizedBox(width: 3),
              Text('AI 낚시 코치',
                style: TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          Text('Gemini 1.5 Flash',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          Row(children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: const Color(0xFF1976D2).withOpacity(0.6))),
            const SizedBox(width: 10),
            Text('AI가 맞춤 조언을 생성 중이에요...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ])
        else if (_tips != null)
          Column(
            children: _tips!.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 11, color: Color(0xFF1976D2))),
                Expanded(child: Text(tip,
                  style: const TextStyle(
                    fontSize: 13, color: Color(0xFF212529), height: 1.45))),
              ]),
            )).toList(),
          ),
      ]),
    );
  }
}