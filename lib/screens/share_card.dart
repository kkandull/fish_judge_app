import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 공유 카드 유틸

class ShareCardUtil {
  /// 공유 카드를 렌더링 → PNG 저장 → 시스템 공유 시트 호출
  static Future<void> shareRecord(
    BuildContext context, {
    required String fishName,
    required CatchRecordForShare record,
  }) async {
    // 오버레이에 카드를 invisible하게 렌더링
    final repaintKey = GlobalKey();

    // 카드를 Overlay에 삽입
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999, // 화면 밖
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: _ShareCard(fishName: fishName, record: record),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // 한 프레임 대기 (렌더링 완료)
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final boundary = repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0); // 고해상도
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 임시 파일로 저장
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      entry.remove();

      // 공유
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: "$fishName 조황 공유 🎣",
      );
    } catch (e) {
      entry.remove();
      debugPrint("공유 카드 생성 오류: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("공유에 실패했습니다.")),
        );
      }
    }
  }
}

// 공유용 데이터 모델


class CatchRecordForShare {
  final String imagePath;
  final DateTime catchTime;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final double? lengthCm;
  final double? weightG;
  final String? memo;

  const CatchRecordForShare({
    required this.imagePath,
    required this.catchTime,
    this.locationName,
    this.latitude,
    this.longitude,
    this.lengthCm,
    this.weightG,
    this.memo,
  });
}

// 공유 카드 위젯 


class _ShareCard extends StatelessWidget {
  final String fishName;
  final CatchRecordForShare record;

  const _ShareCard({required this.fishName, required this.record});

  String _formatDate(DateTime dt) {
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return "${dt.year} ${months[dt.month]} ${dt.day.toString().padLeft(2, '0')}  $amPm $h:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _weightLabel(double g) =>
      g >= 1000 ? '${(g / 1000).toStringAsFixed(2)} kg' : '${g.toStringAsFixed(0)} g';

  String get _locationLabel {
    if (record.locationName != null) return record.locationName!;
    if (record.latitude != null && record.longitude != null) {
      return '${record.latitude!.toStringAsFixed(3)}°N  ${record.longitude!.toStringAsFixed(3)}°E';
    }
    return '위치 미기록';
  }

  @override
  Widget build(BuildContext context) {
    const double cardW = 390.0;
    const Color deepBlue = Color(0xFF0D2137);
    const Color accentTeal = Color(0xFF00C6A2);
    const Color softGold = Color(0xFFE8C96B);

    return SizedBox(
      width: cardW,
      child: Container(
        decoration: const BoxDecoration(
          color: deepBlue,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 바 
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D2137), Color(0xFF163652)],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 낚시 아이콘
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentTeal.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentTeal, width: 1.5),
                    ),
                    child: const Center(
                      child: Text("🎣", style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fishName,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(record.catchTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.55),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 앱 브랜드
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "CATCH",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentTeal,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        "LOG",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: accentTeal,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 메인 사진 
            Stack(
              children: [
                Image.file(
                  File(record.imagePath),
                  width: cardW,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: cardW,
                    height: 280,
                    color: const Color(0xFF1C3A56),
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white38, size: 56),
                    ),
                  ),
                ),
                // 하단 그라디언트 페이드
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          deepBlue.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ),
                // 위치 레이블 (사진 위)
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 13,
                          color: accentTeal.withOpacity(0.9)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 스탯 행
            if (record.lengthCm != null || record.weightG != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF163652),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentTeal.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (record.lengthCm != null) ...[
                      Expanded(
                        child: _StatCell(
                          emoji: "📏",
                          label: "길이",
                          value:
                              "${record.lengthCm!.toStringAsFixed(1)} cm",
                          accent: accentTeal,
                        ),
                      ),
                    ],
                    if (record.lengthCm != null && record.weightG != null)
                      Container(
                          width: 1,
                          height: 36,
                          color: Colors.white.withOpacity(0.1)),
                    if (record.weightG != null) ...[
                      Expanded(
                        child: _StatCell(
                          emoji: "⚖️",
                          label: "무게",
                          value: _weightLabel(record.weightG!),
                          accent: softGold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // 메모 
            if (record.memo != null && record.memo!.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF163652),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: softGold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("✏️", style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.memo!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.75),
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 하단 푸터
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 해시태그
                  Flexible(
                    child: Text(
                      "#낚시 #조황 #$fishName #낚시기록",
                      style: TextStyle(
                        fontSize: 11,
                        color: accentTeal.withOpacity(0.7),
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 물결 장식
                  Text(
                    "～～～",
                    style: TextStyle(
                      fontSize: 14,
                      color: accentTeal.withOpacity(0.4),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 스탯 셀 위젯

class _StatCell extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color accent;

  const _StatCell({
    required this.emoji,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: accent.withOpacity(0.7),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}