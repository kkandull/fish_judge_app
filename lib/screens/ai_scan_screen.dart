import 'package:flutter/material.dart';

class AiScanScreen extends StatelessWidget {
  const AiScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 80, color: Colors.blue),
          const SizedBox(height: 20),
          const Text('AI 어종 판독 화면', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // 나중에 여기에 버튼 촬영 판독 로직이 들어갑니다.
            },
            child: const Text('판독하기 (1회 스캔)'),
          )
        ],
      ),
    );
  }
}