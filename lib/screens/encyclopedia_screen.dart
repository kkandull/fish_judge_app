import 'package:flutter/material.dart';

class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
      title: const Text('나만의 낚시 도감', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: Center(child: Text("낚시 도감")),
  );
  }
}