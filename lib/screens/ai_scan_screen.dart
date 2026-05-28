import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_services.dart';
import '../services/regulation_service.dart';
import 'measurement_screen.dart';
import 'encyclopedia_screen.dart';
import 'post_compose_screen.dart'; // ✅ Day 6 추가

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
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initAllServices();
  }

  Future<void> _initAllServices() async {
    await _aiService.loadModel();
    await _regulationService.loadRegulations();
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      print("카메라 에러: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
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
                  showFishInfo ? "🐟 ${top.koreanName}" : "🚨 어종 인식 실패",
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
                      backgroundColor: const Color(0xFF1976D2),
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
                onPressed: () {
                  Navigator.pop(sc);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('오답 신고가 접수되었습니다. 더 나은 결과로 보답하겠습니다.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
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
          Text("💡 다시 촬영해 주세요",
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
                      color: idx == 0 ? const Color(0xFF1976D2) : Colors.grey.shade300,
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
                        color: idx == 0 ? const Color(0xFF1976D2) : Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
              child: Stack(children: [
                Container(color: Colors.transparent),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF007AFF), width: 3),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("가이드라인 안에 물고기를 맞추세요",
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Positioned(
            top: 55,
            right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _showTutorialDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.help_outline, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("길이 재는 법",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _isAnalyzing
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickFromGalleryAndAnalyze,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.25),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: _takeAndAnalyzePhoto,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Container(
                              width: 55,
                              height: 55,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40 + 50),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}