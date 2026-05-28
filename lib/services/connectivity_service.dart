// lib/services/connectivity_service.dart
//
// 오프라인 감지 통합 서비스.
//
// connectivity_plus 패키지 사용 → 실시간 네트워크 변화 감지.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline, unknown }

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _statusController = StreamController<NetworkStatus>.broadcast();
  
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  StreamSubscription? _subscription;
  bool _initialized = false;

  /// 초기화 — main.dart에서 호출
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 초기 상태 체크
      final initial = await _connectivity.checkConnectivity();
      _currentStatus = _convertToStatus(initial);
      _statusController.add(_currentStatus);

      // 실시간 감지
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final newStatus = _convertToStatus(results);
        if (newStatus != _currentStatus) {
          _currentStatus = newStatus;
          _statusController.add(newStatus);
          debugPrint('🌐 네트워크 상태 변경: $newStatus');
        }
      });
    } catch (e) {
      debugPrint('❌ ConnectivityService init 실패: $e');
    }
  }

  NetworkStatus _convertToStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) return NetworkStatus.offline;
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkStatus.online;
    }
    return NetworkStatus.offline;
  }

  /// 현재 상태
  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  /// 스트림 (실시간 변화 감지용)
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// 직접 체크 (필요할 때)
  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _currentStatus = _convertToStatus(results);
      return _currentStatus == NetworkStatus.online;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}