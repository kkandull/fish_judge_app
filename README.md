# NowFishing — AI 기반 낚시 어종 판독 앱

> 사진 한 장으로 어종을 즉시 판독하고, 금어기·날씨·포인트 정보를 통합 제공하는 스마트 낚시 플랫폼

---

## 개요

국내 낚시 인구는 약 1,012만 명(해양수산부, 2024)에 달하지만, 현장에서 잡은 어종을 즉시 식별하거나 금어기 정보를 실시간으로 확인할 수 있는 도구가 부족한 실정이다. NowFishing은 이 문제를 On-device AI 기술로 해결하는 졸업 프로젝트 결과물이다.

기존 낚시 앱(어신, 데일리피싱, 피싱노트 등)이 날씨·물때 정보에 특화된 반면, NowFishing은 **AI 어종 판독**을 핵심 기능으로 하여 조과 기록, 포인트 지도, 커뮤니티까지 하나의 앱에서 제공한다.

---

## 주요 기능

### AI 어종 판독
- MobileNetV3 기반 On-device TFLite 모델로 사진 한 장에서 어종 즉시 분류
- 부산·경남 연안 주요 어종 11종 지원 (감성돔, 광어, 우럭, 참돔 등)
- 판독 후 수산자원관리법 기준 금어기·금지체장 자동 안내
- 독가시치 등 위험 어종 경고 기능
- 모니터·인쇄물 재촬영 환경에서도 안정적으로 동작하도록 화면/인쇄 강건 증강 학습 적용

### 실시간 날씨 및 물때
- 공공데이터포털 기상청 API 연동 (수온, 파고, 풍속)
- 국립해양조사원 물때 정보 연동
- 풍속·파고·수온·날씨 조건 기반 낚시 적합도 점수 산출
- 기상특보 FCM 푸시 알림

### 낚시 포인트 지도
- 전국 47개 낚시 포인트 등록 (갯바위, 방파제, 선착장)
- OpenStreetMap 기반 지도 (flutter_map)
- GPS 자동 지역 선택 및 수동 위치 검색 (geocoding)

### 조과 기록 및 도감
- 어종별 조과 기록 자동 저장 (위치, 날씨, 크기, 사진)
- Gemini API를 활용한 조과 패턴 분석
- 금어기 자동 필터링으로 현재 월 기준 잡을 수 있는 어종 표시

### 커뮤니티
- 게시글, 댓글, 좋아요, 신고 기능
- 조과 사진 공유 (PNG 카드 렌더링)
- Firebase Firestore 실시간 연동

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| Frontend | Flutter 3.x (Dart) |
| AI/ML | TensorFlow Lite, MobileNetV3, PyTorch (학습) |
| Backend | Firebase (Auth, Firestore, Remote Config, FCM) |
| AI API | Google Gemini 2.0 Flash Lite |
| 지도 | OpenStreetMap (flutter_map) |
| 공공 API | 기상청, 국립해양조사원 |
| 배포 | ONE store (정식 출시), Google Play (심사 중) |

---

## AI 모델 성능

| 지표 | 결과 |
|------|------|
| 전체 정확도 (Test Acc) | 95.00% |
| Top-3 정확도 | 100.00% |
| Macro F1 | 95.02% |
| 모델 크기 | 16.28 MB (FP32 TFLite) |
| CPU 추론 속도 | 19.8ms |

**학습 환경**
- 아키텍처: MobileNetV3-Large (ImageNet 사전학습 → Fine-tuning)
- 학습 데이터: 총 2,266장 (train 1,926 / val 340 / test 220)
- 증강 기법: RandAugment, MixUp(40%), CutMix(20%), Focal Loss, EMA, 화면/인쇄 강건 증강
- 학습 환경: NVIDIA RTX 5070 Ti, CUDA 12.x, PyTorch 2.x

---

## 프로젝트 구조

```
lib/
├── main.dart                   # 앱 진입점, 네비게이션
├── models/                     # 데이터 모델
│   └── unified_catch_record.dart
├── screens/                    # 화면
│   ├── home_screen.dart        # 홈 (날씨, 물때, 적합도)
│   ├── ai_scan_screen.dart     # AI 판독
│   ├── encyclopedia_screen.dart # 도감
│   ├── map_screen.dart         # 포인트 지도
│   ├── community_screen.dart   # 커뮤니티
│   └── settings_screen.dart    # 설정
├── services/                   # 비즈니스 로직
│   ├── ai_services.dart        # TFLite 추론
│   ├── weather_service.dart    # 날씨/물때 API
│   ├── gemini_service.dart     # Gemini API
│   ├── catch_record_repository.dart
│   └── regulation_service.dart # 금어기 규정
└── widgets/                    # 공통 위젯
    └── unified_catch_form.dart # 조과 입력 폼
```

---

## 실행 방법

### 요구사항
- Flutter 3.x 이상
- Android SDK (minSdk 26, targetSdk 34)
- Firebase 프로젝트 설정 (`google-services.json`)

### 설치 및 실행

```bash
git clone https://github.com/[ 저장소 주소 ]
cd nowfishing
flutter pub get
flutter run
```

### 릴리즈 빌드

```bash
flutter build appbundle --release
```

---

## 배포 현황

| 스토어 | 상태 | 패키지 |
|--------|------|--------|
| ONE store | 정식 출시 | com.nowfishing.app |
| Google Play | 심사 진행 중 | com.nowfishing.app |

- ONE store 다운로드: [https://m.onestore.co.kr/v2/ko-kr/app/0001006359]
- 개인정보처리방침: [https://kkandull.github.io/nowfishing/privacy.html]

---

## 팀 구성

| 이름 | 역할 |
|------|------|
| [천준영] | [ 역할 ] |
| [표재국] | [ 역할 ] |
| [강태한] | [ 역할 ] |
| [김승연] | [ 역할 ] |

---

## 한계점 및 향후 계획

**한계점**
- 초기 버전은 부산·경남 연안 주요 어종 11종에 집중한 지역 특화 설계로, 전국 서비스 확장 전 핵심 어종의 판독 품질을 우선 확보하는 전략적 선택
- 날씨 적합도 점수는 규칙 기반으로 산출하여 실제 조과 데이터와의 상관관계 검증이 미흡
- Firebase 익명 인증 채택으로 앱 재설치 시 조과 기록 유실

**향후 계획**
- v1.1: 어종 50종 이상으로 확대 (국립수산과학원 DB 활용)
- v1.2: 실제 조과 데이터 기반 낚시 적합도 ML 모델 전환
- v2.0: iOS 출시, 다크 모드, 조과 데이터 지도 시각화 (Heatmap)

---

## 라이선스
