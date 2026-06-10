// 기상특보 조회 서비스

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// 모델

class WeatherAlert {
  final AlertType type;
  final AlertLevel level;
  final String title;
  final String areaName;
  final DateTime issuedAt;
  final DateTime? effectiveAt;
  final String content;

  WeatherAlert({
    required this.type,
    required this.level,
    required this.title,
    required this.areaName,
    required this.issuedAt,
    this.effectiveAt,
    required this.content,
  });

  bool get isCurrentlyActive {
    if (effectiveAt == null) return true;
    return DateTime.now().isAfter(effectiveAt!);
  }
}

enum AlertType { wind, typhoon, rain, storm, cold, heat, dryness, wave, tsunami, unknown }
enum AlertLevel { preliminary, advisory, warning, emergency }

extension AlertTypeExt on AlertType {
  String get label {
    switch (this) {
      case AlertType.wind:    return '풍랑';
      case AlertType.typhoon: return '태풍';
      case AlertType.rain:    return '호우';
      case AlertType.storm:   return '폭풍해일';
      case AlertType.cold:    return '한파';
      case AlertType.heat:    return '폭염';
      case AlertType.dryness: return '건조';
      case AlertType.wave:    return '파랑';
      case AlertType.tsunami: return '지진해일';
      case AlertType.unknown: return '특보';
    }
  }
  int get fishingPenalty {
    switch (this) {
      case AlertType.typhoon:  return 100;
      case AlertType.tsunami:  return 100;
      case AlertType.storm:    return 80;
      case AlertType.wind:     return 50;
      case AlertType.wave:     return 50;
      case AlertType.rain:     return 30;
      case AlertType.cold:     return 20;
      case AlertType.heat:     return 15;
      case AlertType.dryness:  return 5;
      case AlertType.unknown:  return 10;
    }
  }
}

extension AlertLevelExt on AlertLevel {
  String get label {
    switch (this) {
      case AlertLevel.preliminary: return '예비';
      case AlertLevel.advisory:    return '주의보';
      case AlertLevel.warning:     return '경보';
      case AlertLevel.emergency:   return '긴급';
    }
  }
  double get multiplier {
    switch (this) {
      case AlertLevel.preliminary: return 0.5;
      case AlertLevel.advisory:    return 1.0;
      case AlertLevel.warning:     return 1.5;
      case AlertLevel.emergency:   return 2.0;
    }
  }
}

// 서비스

class WeatherAlertService {
  static final WeatherAlertService instance = WeatherAlertService._();
  WeatherAlertService._();

  // 지역별 캐시
  final Map<String, List<WeatherAlert>> _cache = {};
  final Map<String, DateTime> _cachedAt = {};

  /// 활성 특보 가져오기
  ///
  /// [apiKey]   — 공공데이터포털 키
  /// [stnId]    — 지역 코드 
  /// [forceRefresh] — 캐시 무시
  Future<List<WeatherAlert>> fetchActiveAlerts({
    required String apiKey,
    String stnId = '26',      // 기본 부산
    bool forceRefresh = false,
  }) async {
    final cacheKey = stnId.isEmpty ? 'all' : stnId;

    if (!forceRefresh &&
        _cache[cacheKey] != null &&
        _cachedAt[cacheKey] != null &&
        DateTime.now().difference(_cachedAt[cacheKey]!).inMinutes < 10) {
      return _cache[cacheKey]!;
    }

    if (apiKey.isEmpty) {
      debugPrint('⚠️ 기상특보 API 키 없음');
      return [];
    }

    try {
      final now = DateTime.now();
      final from = _fmt(now.subtract(const Duration(days: 1)));
      final to   = _fmt(now);

      final params = {
        'serviceKey': apiKey,
        'numOfRows': '50',
        'pageNo': '1',
        'dataType': 'JSON',
        'fromTmFc': from,
        'toTmFc': to,
      };
      // stnId가 있을 때만 추가 (빈 문자열이면 전국 조회)
      if (stnId.isNotEmpty) params['stnId'] = stnId;

      final url = Uri.https(
        'apis.data.go.kr',
        '/1360000/WthrWrnInfoService/getWthrWrnList',
        params,
      );

      debugPrint('기상특보 호출: $url');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('특보 HTTP ${res.statusCode}');

      final j = jsonDecode(res.body);
      final items = j['response']?['body']?['items']?['item'];
      if (items == null) {
        _cache[cacheKey] = [];
        _cachedAt[cacheKey] = DateTime.now();
        return [];
      }

      final list = items is List ? items : [items];
      final alerts = list
          .map<WeatherAlert?>(_parse)
          .whereType<WeatherAlert>()
          .toList();

      _cache[cacheKey] = alerts;
      _cachedAt[cacheKey] = DateTime.now();
      return alerts;
    } catch (e) {
      debugPrint('기상특보 실패: $e');
      return _cache[cacheKey] ?? [];
    }
  }

  WeatherAlert? _parse(dynamic item) {
    try {
      final title   = (item['title'] ?? '').toString();
      final tmFc    = (item['tmFc']  ?? '').toString();
      final tmEf    = (item['tmEf']  ?? '').toString();
      final content = (item['t1']    ?? title).toString();
      return WeatherAlert(
        type:        _type(title + content),
        level:       _level(title),
        title:       title,
        areaName:    (item['areaName'] ?? '').toString(),
        issuedAt:    _parseDate(tmFc) ?? DateTime.now(),
        effectiveAt: _parseDate(tmEf),
        content:     content,
      );
    } catch (_) {
      return null;
    }
  }

  AlertType _type(String t) {
    if (t.contains('태풍'))   return AlertType.typhoon;
    if (t.contains('지진해일')) return AlertType.tsunami;
    if (t.contains('폭풍해일')) return AlertType.storm;
    if (t.contains('풍랑'))   return AlertType.wind;
    if (t.contains('파랑'))   return AlertType.wave;
    if (t.contains('호우'))   return AlertType.rain;
    if (t.contains('한파'))   return AlertType.cold;
    if (t.contains('폭염'))   return AlertType.heat;
    if (t.contains('건조'))   return AlertType.dryness;
    return AlertType.unknown;
  }

  AlertLevel _level(String t) {
    if (t.contains('긴급')) return AlertLevel.emergency;
    if (t.contains('경보')) return AlertLevel.warning;
    if (t.contains('주의보')) return AlertLevel.advisory;
    return AlertLevel.advisory;
  }

  DateTime? _parseDate(String s) {
    if (s.length < 12) return null;
    try {
      return DateTime(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(8, 10)),
        int.parse(s.substring(10, 12)),
      );
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}'
      '${d.hour.toString().padLeft(2,'0')}${d.minute.toString().padLeft(2,'0')}';

  void clearCache() {
    _cache.clear();
    _cachedAt.clear();
  }
}