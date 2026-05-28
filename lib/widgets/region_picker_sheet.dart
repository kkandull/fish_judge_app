// lib/widgets/region_picker_sheet.dart
// 지역 선택 바텀시트

import 'package:flutter/material.dart';
import '../services/weather_service.dart';

const Color _kBlue = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kSub  = Color(0xFF6B7684);

class RegionPickerSheet extends StatelessWidget {
  final FishingRegion selected;
  final void Function(FishingRegion) onSelect;

  const RegionPickerSheet({super.key, required this.selected, required this.onSelect});

  static Future<FishingRegion?> show(BuildContext context, FishingRegion current) {
    return showModalBottomSheet<FishingRegion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegionPickerSheet(
        selected: current,
        onSelect: (r) => Navigator.pop(context, r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 도/시 별로 그룹
    final groups = <String, List<FishingRegion>>{};
    for (final r in kFishingRegions) {
      groups.putIfAbsent(r.province, () => []).add(r);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            width: 40, height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Icon(Icons.location_on, color: _kBlue, size: 20),
              SizedBox(width: 8),
              Text('낚시 지역 선택', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.all(16),
              children: groups.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(entry.key,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kSub)),
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: entry.value.map((r) {
                      final isSel = r.id == selected.id;
                      return GestureDetector(
                        onTap: () => onSelect(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSel ? _kBlue : Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? _kBlue : const Color(0xFFE8EAED),
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isSel) ...[
                              const Icon(Icons.check, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                            ],
                            Text(r.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? Colors.white : _kNavy,
                              )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              )).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}