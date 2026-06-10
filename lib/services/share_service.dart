import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/unified_catch_record.dart';

class ShareService {
  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> share(String text) async {
    await Share.share(text);
  }

  // 조과 카드 이미지로 렌더링 후 단일 PNG로 공유
  static Future<void> shareRecordAsCard(
    BuildContext context, {
    required UnifiedCatchRecord record,
    required String fallbackText,
  }) async {
    final repaintKey = GlobalKey();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: _ShareCardWidget(record: record),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      final boundary = repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/nowfishing_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      entry.remove();

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${record.fishName} 조과 공유 🎣',
      );
    } catch (e) {
      entry.remove();
      debugPrint('카드 공유 실패: $e');
      // 실패 시 텍스트만 공유
      await Share.share(fallbackText);
    }
  }
}

// 공유용 카드 위젯 

class _ShareCardWidget extends StatelessWidget {
  final UnifiedCatchRecord record;
  const _ShareCardWidget({required this.record});

  String get _weightLabel {
    if (record.weightG == null) return '';
    return record.weightG! >= 1000
        ? '${(record.weightG! / 1000).toStringAsFixed(2)} kg'
        : '${record.weightG!.toStringAsFixed(0)} g';
  }

  String get _dateLabel {
    final dt = record.catchTime;
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '${dt.year} ${months[dt.month]} ${dt.day.toString().padLeft(2, '0')}  $ap $h:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get _locationLabel {
    if (record.spotName != null && record.spotName!.isNotEmpty) {
      return record.spotName!;
    }
    if (record.locationName != null && record.locationName!.isNotEmpty) {
      return record.locationName!;
    }
    if (record.hasLocation) {
      return '${record.latitude!.toStringAsFixed(3)}°N  ${record.longitude!.toStringAsFixed(3)}°E';
    }
    return '위치 미기록';
  }

  @override
  Widget build(BuildContext context) {
    const double cardW = 390.0;
    const Color deepBlue   = Color(0xFF0D2137);
    const Color accentTeal = Color(0xFF00C6A2);
    const Color softGold   = Color(0xFFE8C96B);
    const Color cardBg     = Color(0xFF163652);

    return SizedBox(
      width: cardW,
      child: Container(
        color: deepBlue,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              color: const Color(0xFF163652),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: accentTeal.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentTeal, width: 1.5),
                    ),
                    child: const Center(
                      child: Text('🎣', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fishName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.55),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('NOW', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: accentTeal, letterSpacing: 2.5)),
                      Text('FISHING', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: accentTeal, letterSpacing: 2.5)),
                    ],
                  ),
                ],
              ),
            ),

            // 메인 사진 or 이모지 배경
            Stack(
              children: [
                // 사진
                record.hasPhoto
                    ? Image.file(
                        File(record.imagePath!),
                        width: cardW,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emojiBlock(record.emoji, cardW),
                      )
                    : _emojiBlock(record.emoji, cardW),

                // 하단 페이드
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, deepBlue.withOpacity(0.9)],
                      ),
                    ),
                  ),
                ),

                // 위치
                Positioned(
                  bottom: 12, left: 16, right: 16,
                  child: Row(children: [
                    Icon(Icons.location_on, size: 13,
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
                  ]),
                ),
              ],
            ),

            // 스탯 행 
            if (record.lengthCm != null || record.weightG != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentTeal.withOpacity(0.25)),
                ),
                child: Row(children: [
                  if (record.lengthCm != null) ...[
                    Expanded(child: _StatCell(
                      emoji: '📏', label: '길이',
                      value: '${record.lengthCm!.toStringAsFixed(1)} cm',
                      accent: accentTeal,
                    )),
                  ],
                  if (record.lengthCm != null && record.weightG != null)
                    Container(
                      width: 1, height: 36,
                      color: Colors.white.withOpacity(0.1)),
                  if (record.weightG != null) ...[
                    Expanded(child: _StatCell(
                      emoji: '⚖️', label: '무게',
                      value: _weightLabel,
                      accent: softGold,
                    )),
                  ],
                ]),
              ),

            // 조과 정보 텍스트 박스 
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentTeal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('🐟', '어종', record.fishName, accentTeal),
                  const SizedBox(height: 6),
                  _infoRow('📅', '날짜', record.dateStr, accentTeal),
                  if (_locationLabel != '위치 미기록') ...[
                    const SizedBox(height: 6),
                    _infoRow('📍', '포인트', _locationLabel, accentTeal),
                  ],
                  if (record.count > 0) ...[
                    const SizedBox(height: 6),
                    _infoRow('🎣', '마릿수', '${record.count}마리', accentTeal),
                  ],
                  if (record.weather.isNotEmpty && record.weather != '정보 없음') ...[
                    const SizedBox(height: 6),
                    _infoRow('🌤', '날씨', record.weather, accentTeal),
                  ],
                ],
              ),
            ),

            // 메모 
            if (record.memo.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: softGold.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✏️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.memo,
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

            // 푸터 
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '#낚시 #조황 #${record.fishName} #낚시기록 #나우피싱',
                      style: TextStyle(
                        fontSize: 11,
                        color: accentTeal.withOpacity(0.7),
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('～～～',
                    style: TextStyle(
                      fontSize: 14,
                      color: accentTeal.withOpacity(0.4),
                      letterSpacing: 2,
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiBlock(String emoji, double width) {
    return Container(
      width: width,
      height: 280,
      color: const Color(0xFF163652),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 80)),
      ),
    );
  }

  Widget _infoRow(String emoji, String label, String value, Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Text('$label  ',
          style: TextStyle(
            fontSize: 12,
            color: accent.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          )),
        Expanded(
          child: Text(value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            )),
        ),
      ],
    );
  }
}

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
        Text(label,
          style: TextStyle(
            fontSize: 9,
            color: accent.withOpacity(0.7),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          )),
        const SizedBox(height: 2),
        Text(value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          )),
      ],
    );
  }
}