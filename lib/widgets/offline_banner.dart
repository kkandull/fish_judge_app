// lib/widgets/offline_banner.dart
//
// 오프라인 상태 배너 위젯.
// 어떤 화면에서든 wrap해서 사용.

import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// 화면 상단에 표시되는 오프라인 배너
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      initialData: ConnectivityService.instance.currentStatus,
      stream: ConnectivityService.instance.statusStream,
      builder: (context, snap) {
        final isOffline = snap.data == NetworkStatus.offline;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: isOffline ? 36 : 0,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade700,
                Colors.deepOrange.shade700,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: ClipRect(
            child: isOffline
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        '오프라인 상태입니다',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '·',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '인터넷 연결을 확인해주세요',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// 오프라인 풀스크린 카드 (콘텐츠 영역에 사용)
class OfflineFullCard extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? customMessage;
  
  const OfflineFullCard({super.key, this.onRetry, this.customMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.wifi_off,
                size: 50,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '인터넷에 연결되어 있지 않아요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              customMessage ?? 'Wi-Fi 또는 모바일 데이터를 켜고\n다시 시도해주세요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7684),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}