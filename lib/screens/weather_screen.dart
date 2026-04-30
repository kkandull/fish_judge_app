import 'package:flutter/material.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('실시간 날씨 및 수온 화면\n(기상청 API 연동 예정)', 
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20)),
    );
  }
}