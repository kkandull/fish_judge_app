// FCM (Firebase Cloud Messaging) + 로컬 알림 통합.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// 백그라운드 메시지 핸들러 (반드시 최상위 함수)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase가 이미 초기화된 상태에서 호출됨
  debugPrint('🔔 백그라운드 메시지: ${message.messageId}');
  // 시스템이 자동으로 알림 표시
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  bool _initialized = false;

  /// 초기화 — main.dart에서 호출
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. 백그라운드 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. 권한 요청 (iOS / 안드로이드 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('🔔 알림 권한: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ 사용자가 알림 권한 거부');
        return;
      }

      // 3. 로컬 알림 초기화 (포그라운드 알림 표시용)
      await _initLocalNotifications();

      // 4. FCM 토큰 가져와 Firestore 저장
      await saveTokenToFirestore();

      // 5. 토큰 갱신 리스너
      _fcm.onTokenRefresh.listen((token) {
        saveTokenToFirestore(token: token);
      });

      // 6. 포그라운드 메시지 리스너 (앱 켜져 있을 때)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. 알림 탭으로 앱 열렸을 때 (백그라운드 상태)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // 8. 종료 상태에서 알림 탭으로 앱 열렸을 때
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpened(initialMessage);
      }

      debugPrint('✅ 푸시 알림 초기화 완료');
    } catch (e) {
      debugPrint('❌ 푸시 알림 초기화 실패: $e');
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initLocalNotifications() async {

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // FCM에서 권한을 이미 요청하므로 iOS 로컬 알림 초기화 시 중복 요청 방지
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, 
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    
    await _localNotif.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🔔 로컬 알림 탭: ${response.payload}');
      
      },
    );

    // 안드로이드 알림 채널 생성
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      '나우피싱 알림',
      description: '댓글, 좋아요 등 중요한 알림',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// FCM 토큰을 Firestore에 저장 
  Future<void> saveTokenToFirestore({String? token}) async {
    try {
      final uid = AuthService.instance.uid;
      if (uid == null) {
        debugPrint('⚠️ UID 없음, 토큰 저장 건너뜀');
        return;
      }

      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null) {
        debugPrint('⚠️ FCM 토큰 가져오기 실패');
        return;
      }

      await _db.collection('users').doc(uid).set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM 토큰 저장: ${fcmToken.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ 토큰 저장 실패: $e');
    }
  }

  /// 포그라운드 메시지 처리 (앱 켜져 있을 때 알림 표시)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 포그라운드 메시지: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localNotif.show(
      id: message.hashCode.abs(),
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          '나우피싱 알림',
          channelDescription: '댓글, 좋아요 등 중요한 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher', 
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['postId']?.toString(), 
    );
  }

  /// 알림 탭으로 앱 열렸을 때
  void _handleMessageOpened(RemoteMessage message) {
    debugPrint('🔔 알림 탭으로 앱 열림: ${message.data}');
  }

  /// 사용자 로그아웃 시 토큰 삭제
  Future<void> clearToken() async {
    try {
      final uid = AuthService.instance.uid;
      if (uid == null) return;

      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });

      await _fcm.deleteToken();
      debugPrint('✅ FCM 토큰 삭제 완료');
    } catch (e) {
      debugPrint('❌ 토큰 삭제 실패: $e');
    }
  }
}