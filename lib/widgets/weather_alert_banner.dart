// lib/widgets/weather_alert_banner.dart
//
// 기상특보 배너.
// 풍랑주의보/태풍경보 등이 발효 중일 때 화면 상단에 표시.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/weather_alert_service.dart';

class WeatherAlertBanner extends StatelessWidget {
  final List<WeatherAlert> alerts;
  final VoidCallback? onTap;
  
  const WeatherAlertBanner({
    super.key,
    required this.alerts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeAlerts = alerts.where((a) => a.isCurrentlyActive).toList();
    if (activeAlerts.isEmpty) return const SizedBox.shrink();

    // 가장 심각한 특보를 대표로 표시
    activeAlerts.sort((a, b) {
      final aScore = a.type.fishingPenalty * a.level.multiplier;
      final bScore = b.type.fishingPenalty * b.level.multiplier;
      return bScore.compareTo(aScore);
    });
    final main = activeAlerts.first;
    
    final color = _getColor(main);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          _showDetailDialog(context, activeAlerts);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.85)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_getIcon(main.type), color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          main.level.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (activeAlerts.length > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${activeAlerts.length - 1}건',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    main.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getActionAdvice(main),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  Color _getColor(WeatherAlert alert) {
    // 위험도에 따라 색상
    if (alert.type == AlertType.typhoon || alert.type == AlertType.tsunami) {
      return Colors.red.shade700;
    }
    if (alert.level == AlertLevel.warning || alert.level == AlertLevel.emergency) {
      return Colors.red.shade600;
    }
    if (alert.type == AlertType.wind || alert.type == AlertType.wave) {
      return Colors.orange.shade700;
    }
    return Colors.amber.shade700;
  }

  IconData _getIcon(AlertType type) {
    switch (type) {
      case AlertType.typhoon: return Icons.cyclone;
      case AlertType.tsunami: return Icons.tsunami;
      case AlertType.storm: return Icons.thunderstorm;
      case AlertType.wind: return Icons.air;
      case AlertType.wave: return Icons.waves;
      case AlertType.rain: return Icons.umbrella;
      case AlertType.cold: return Icons.ac_unit;
      case AlertType.heat: return Icons.wb_sunny;
      case AlertType.dryness: return Icons.local_fire_department;
      case AlertType.unknown: return Icons.warning_amber_rounded;
    }
  }

  String _getActionAdvice(WeatherAlert alert) {
    switch (alert.type) {
      case AlertType.typhoon:
        return '출조 절대 금지 - 즉시 귀가';
      case AlertType.tsunami:
        return '해안 즉시 대피';
      case AlertType.storm:
        return '해안 접근 금지';
      case AlertType.wind:
        return '갯바위·선상 낚시 자제';
      case AlertType.wave:
        return '갯바위 출조 위험';
      case AlertType.rain:
        return '안전 장비 필수';
      case AlertType.cold:
        return '저체온증 주의';
      case AlertType.heat:
        return '온열질환 주의, 충분한 수분';
      default:
        return '안전에 유의';
    }
  }

  void _showDetailDialog(BuildContext context, List<WeatherAlert> alerts) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '발효 중 기상특보',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildAlertItem(alerts[i]),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '해양 긴급: 122  /  소방: 119',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertItem(WeatherAlert alert) {
    final color = _getColor(alert);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIcon(alert.type), color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                alert.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _getActionAdvice(alert),
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '발표: ${_formatDate(alert.issuedAt)}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}