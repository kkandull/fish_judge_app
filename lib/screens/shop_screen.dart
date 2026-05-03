import 'package:flutter/material.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
      title: const Text('장비 추천', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: Center(child: Text("장비 추천 화면입니다")),
  );
  }
}