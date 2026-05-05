import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncyclopediaScreen extends StatefulWidget {
  final File? capturedImage;
  final String? targetFish;

  const EncyclopediaScreen({super.key, this.capturedImage, this.targetFish});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  // 공용 장비 데이터
  final List<Map<String, String>> commonGear = [
    {
      "name": "낚시대+릴",
      "url": "https://www.coupang.com/np/search?q=JAHCHO 캠핑 바다낚시 입문자용 다용도 미니 낚시대 세트"
    },
    {
      "name": "두레박",
      "url": "https://www.coupang.com/np/search?q=낚시+잇츠온 EVA 접이식 두레박"
    },
    {
      "name": "가위, 집개",
      "url": "https://www.coupang.com/np/search?q=다용도 스테인리스 낚시 가위 겸용 집게 컨트롤 플라이어"
    },
  ];

  // 어종별 데이터 (rodUrl 제거 및 제공해주신 데이터 반영)
  final List<Map<String, String>> fishData = [
    {
      "name": "감성돔",
      "tackleUrl": "https://www.coupang.com/np/search?q=바다+찌낚시+채비세트"
    },
    {
      "name": "넙치",
      "tackleUrl": "https://www.coupang.com/np/search?q=광어+프리리그+채비"
    },
    {
      "name": "우럭",
      "tackleUrl": "https://www.coupang.com/np/search?q=지그헤드+웜+세트"
    },
    {
      "name": "쥐노래미",
      "tackleUrl": "https://www.coupang.com/np/search?q=지그헤드+웜+세트"
    },
    {
      "name": "참돔",
      "tackleUrl": "https://www.coupang.com/np/search?q=쇼어+타이라바"
    },
  ];

  Map<String, List<String>> collectionMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();

    for (var fish in fishData) {
      String name = fish['name']!;
      List<String>? savedList = prefs.getStringList(name);
      collectionMap[name] = savedList ?? [];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (widget.targetFish != null && widget.capturedImage != null) {
      if (fishData.any((fish) => fish['name'] == widget.targetFish)) {
        await _saveImagePermanently(
          widget.targetFish!,
          widget.capturedImage!,
          prefs,
        );
      }
    }
  }

  Future<void> _saveImagePermanently(
      String fishName,
      File tempFile,
      SharedPreferences prefs,
      ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fishDir = Directory('${directory.path}/$fishName');
      if (!await fishDir.exists()) {
        await fishDir.create(recursive: true);
      }

      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${p.basename(tempFile.path)}";
      final permanentFile = await tempFile.copy('${fishDir.path}/$fileName');

      List<String> currentList = prefs.getStringList(fishName) ?? [];
      if (!currentList.contains(permanentFile.path)) {
        currentList.add(permanentFile.path);
        await prefs.setStringList(fishName, currentList);

        if (mounted) {
          setState(() {
            collectionMap[fishName] = currentList;
          });
        }
      }
    } catch (e) {
      debugPrint("파일 저장 중 오류 발생: $e");
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '내 도감 및 장비 추천',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 공용 장비 섹션
          const Text(
            "필수 공용 장비",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: commonGear.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    onPressed: () => _launchURL(commonGear[index]['url']),
                    child: Text(
                      commonGear[index]['name']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            "어종별 수집 현황 및 추천 채비",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 2. 어종별 리스트 섹션
          ...fishData.map((fish) {
            final String name = fish['name'] ?? 'Unknown';
            final List<String> imagePathList = collectionMap[name] ?? [];
            final bool isCollected = imagePathList.isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (isCollected)
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imagePathList.length,
                        itemBuilder: (context, imgIndex) {
                          final path = imagePathList[imgIndex];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(path),
                                width: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 220,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Text(
                          "미수집 어종",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(isCollected ? "수집 완료 (${imagePathList.length})" : "미수집"),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _launchURL(fish['tackleUrl']),
                      icon: const Icon(Icons.shopping_cart, size: 16),
                      label: const Text("채비 구매"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}