// lib/services/location_service.dart
//
// 전국 관측소 및 기상청 격자 데이터.
// 사용자 위치 기반 자동 선택 + 수동 선택 지원.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지역 정보 - 기상청 격자 + 해양조사원 관측소 통합
class RegionInfo {
  final String id;          // 'busan', 'incheon' 등
  final String name;        // '부산'
  final String fullName;    // '부산광역시'
  final double lat;
  final double lng;
  
  // 기상청 격자
  final int nx;
  final int ny;
  
  // 해양조사원 관측소
  final String khoaCode;
  
  // 해무관측소
  final String? fogCode;
  
  // 해수유동(HF-RADAR)
  final String? hfRadarCode;
  
  // 기상특보 지역코드
  final String alertStnId;

  const RegionInfo({
    required this.id,
    required this.name,
    required this.fullName,
    required this.lat,
    required this.lng,
    required this.nx,
    required this.ny,
    required this.khoaCode,
    this.fogCode,
    this.hfRadarCode,
    required this.alertStnId,
  });
}

/// 전국 주요 해안 지역
const List<RegionInfo> kAllRegions = [
  RegionInfo(
    id: 'busan', name: '부산', fullName: '부산광역시',
    lat: 35.18, lng: 129.07,
    nx: 98, ny: 76,
    khoaCode: 'DT_0001', fogCode: 'BPT', hfRadarCode: 'HF_0011',
    alertStnId: '26',
  ),
  RegionInfo(
    id: 'incheon', name: '인천', fullName: '인천광역시',
    lat: 37.45, lng: 126.70,
    nx: 55, ny: 124,
    khoaCode: 'DT_0002', fogCode: 'IPT',
    alertStnId: '28',
  ),
  RegionInfo(
    id: 'ulsan', name: '울산', fullName: '울산광역시',
    lat: 35.54, lng: 129.31,
    nx: 102, ny: 84,
    khoaCode: 'DT_0024', fogCode: 'UPT',
    alertStnId: '31',
  ),
  RegionInfo(
    id: 'pohang', name: '포항', fullName: '경상북도 포항시',
    lat: 36.03, lng: 129.36,
    nx: 102, ny: 94,
    khoaCode: 'DT_0007',
    alertStnId: '37',
  ),
  RegionInfo(
    id: 'mokpo', name: '목포', fullName: '전라남도 목포시',
    lat: 34.79, lng: 126.39,
    nx: 50, ny: 67,
    khoaCode: 'DT_0004', fogCode: 'MPT',
    alertStnId: '46',
  ),
  RegionInfo(
    id: 'yeosu', name: '여수', fullName: '전라남도 여수시',
    lat: 34.76, lng: 127.66,
    nx: 73, ny: 66,
    khoaCode: 'DT_0005',
    alertStnId: '46',
  ),
  RegionInfo(
    id: 'jeju', name: '제주', fullName: '제주특별자치도',
    lat: 33.51, lng: 126.52,
    nx: 53, ny: 38,
    khoaCode: 'DT_0010', fogCode: 'JPT',
    alertStnId: '50',
  ),
  RegionInfo(
    id: 'sokcho', name: '속초', fullName: '강원도 속초시',
    lat: 38.21, lng: 128.59,
    nx: 87, ny: 141,
    khoaCode: 'DT_0021',
    alertStnId: '42',
  ),
  RegionInfo(
    id: 'gangneung', name: '강릉', fullName: '강원도 강릉시',
    lat: 37.75, lng: 128.88,
    nx: 92, ny: 131,
    khoaCode: 'DT_0022',
    alertStnId: '42',
  ),
  RegionInfo(
    id: 'gunsan', name: '군산', fullName: '전라북도 군산시',
    lat: 35.97, lng: 126.71,
    nx: 56, ny: 92,
    khoaCode: 'DT_0003',
    alertStnId: '45',
  ),
  RegionInfo(
    id: 'tongyeong', name: '통영', fullName: '경상남도 통영시',
    lat: 34.85, lng: 128.43,
    nx: 87, ny: 68,
    khoaCode: 'DT_0006',
    alertStnId: '38',
  ),
  RegionInfo(
    id: 'wando', name: '완도', fullName: '전라남도 완도군',
    lat: 34.31, lng: 126.75,
    nx: 57, ny: 56,
    khoaCode: 'DT_0008',
    alertStnId: '46',
  ),
];

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  RegionInfo? _selectedRegion;
  Position? _userPosition;

  static const String _prefsKey = 'selected_region_id';

  /// 초기화 - SharedPreferences에서 마지막 선택 로드
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);
    if (savedId != null) {
      _selectedRegion = kAllRegions.firstWhere(
        (r) => r.id == savedId,
        orElse: () => kAllRegions[0],
      );
    }
  }

  /// 현재 선택된 지역 (위치 기반 or 수동 선택)
  RegionInfo get currentRegion => _selectedRegion ?? kAllRegions[0];
  
  /// 위치 기반 가장 가까운 지역 자동 선택
  Future<RegionInfo> detectNearestRegion() async {
    try {
      // 위치 권한
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('위치 권한 거부');
          return currentRegion;
        }
      }
      
      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5));
      
      final nearest = _findNearest(_userPosition!.latitude, _userPosition!.longitude);
      
      // 자동 감지 결과를 저장하지 않음 (수동 선택만 저장)
      if (_selectedRegion == null) {
        _selectedRegion = nearest;
      }
      return nearest;
    } catch (e) {
      debugPrint('위치 감지 실패: $e');
      return currentRegion;
    }
  }

  RegionInfo _findNearest(double lat, double lng) {
    RegionInfo nearest = kAllRegions[0];
    double minDist = double.infinity;
    for (final r in kAllRegions) {
      final d = _haversine(lat, lng, r.lat, r.lng);
      if (d < minDist) {
        minDist = d;
        nearest = r;
      }
    }
    return nearest;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const earthR = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthR * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  /// 수동 지역 변경 (저장됨)
  Future<void> setRegion(RegionInfo region) async {
    _selectedRegion = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, region.id);
  }
}