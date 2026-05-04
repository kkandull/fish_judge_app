import 'dart:io';
import 'package:flutter/material.dart';
// TODO 1: pubspec.yaml에 url_launcher: ^6.2.6, shared_preferences: ^2.2.3 추가 후 주석을 해제하세요.
// import 'package:url_launcher/url_launcher.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// 🎯 [강태한 담당] 나만의 낚시 도감 + 장비 추천 통합 화면
// 
// 💡 [기획 의도 및 개발 가이드]
// 1. 나만의 도감 (로컬 DB 연동): AI 카메라에서 넘어온 사진(capturedImage)과 어종(targetFish)을 
//    shared_preferences에 저장하세요. 앱을 재실행해도 내가 잡은 고기 사진이 도감에 유지되어야 합니다.
// 2. 데이터 리팩토링: 하드코딩하지 말고, 부산 5대 어종(감성돔, 벵에돔 등) 데이터를 
//    List<Map>으로 구성해 ListView.builder로 효율적으로 화면을 그리세요.
// 3. 수익화 연동: 각 어종 카드 하단에 [쿠팡 추천 장비 구매] 버튼을 배치해 url_launcher로 연결하세요.

class EncyclopediaScreen extends StatefulWidget {
  final File? capturedImage; // AI 스캔 화면에서 방금 찍은 사진
  final String? targetFish;  // AI가 인식한 물고기 이름

  const EncyclopediaScreen({super.key, this.capturedImage, this.targetFish});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  // TODO 2: 어종 데이터 리스트(List<Map>)와 로컬 DB에서 불러온 수집 상태 데이터를 선언하세요.

  @override
  void initState() {
    super.initState();
    _loadEncyclopediaData();
  }

  Future<void> _loadEncyclopediaData() async {
    // TODO 3: SharedPreferences를 사용해 기존에 저장된 사진 경로들을 불러오고, 
    // 새로 넘어온 widget.capturedImage가 있다면 DB에 새로 저장하는 로직을 짜주세요.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('내 도감 및 장비 추천', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      // TODO 4: ListView.builder를 사용하여 어종 리스트를 만드세요.
      // 수집된 어종은 '내가 찍은 사진'을, 미수집 어종은 '기본 일러스트'를 보여줘야 합니다.
      body: const Center(child: Text("ListView.builder를 구현해 주세요!")),
    );
  }
}