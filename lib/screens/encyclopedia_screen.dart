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

  // 어종별 데이터
  final List<Map<String, String>> fishData = [
    {
      "name": "감성돔",
    },
    {
      "name": "광어",
    },
    {
      "name": "우럭",
    },
    {
      "name": "쥐노래미",
    },
    {
      "name": "참돔",
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

  // 💡 [추가됨] 파일명(밀리초 타임스탬프)에서 날짜와 시간을 예쁘게 추출하는 함수
  String _getFormattedDateFromPath(String path) {
    try {
      String fileName = p.basename(path); // 예: 1683928371923_image.jpg
      String timeStr = fileName.split('_')[0]; // 언더바 앞의 밀리초만 추출
      int millis = int.parse(timeStr);
      DateTime date = DateTime.fromMillisecondsSinceEpoch(millis);
      
      String amPm = date.hour < 12 ? '오전' : '오후';
      int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      
      return "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} $amPm $hour:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "날짜 정보 없음"; // 오류 발생 시 기본값 (예전 방식의 파일명일 경우)
    }
  }

  // 💡 [추가됨] 도감 상세 보기 팝업 함수
  void _showFishDetailPopup(BuildContext context, String fishName, String imagePath, String catchDate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Text(
                  fishName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1976D2)),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file( // File 이미지 렌더링
                    File(imagePath), 
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 280,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.black54, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "포획 일시: $catchDate",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B3A55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(context).pop(), 
                    child: const Text('닫기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            "어종별 수집 현황",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 2. 어종별 리스트 섹션
          ...fishData.map((fish) {
            final String name = fish['name'] ?? 'Unknown';
            final List<String> imagePathList = collectionMap[name] ?? [];
            final bool isCollected = imagePathList.isNotEmpty;

            // 모든 물고기 카드는 동일한 여백(bottom: 16)으로 생성합니다.
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
                          // 사진 터치 시 팝업 띄우기
                          return GestureDetector(
                            onTap: () {
                              String dateStr = _getFormattedDateFromPath(path);
                              _showFishDetailPopup(context, name, path, dateStr);
                            },
                            child: Padding(
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
                  ),
                ],
              ),
            );
          }), // 👈 map 함수 종료

          // 💡 [핵심 추가] 리스트 맨 마지막(참돔 아래)에 빈 공간을 추가하여 스크롤을 더 내릴 수 있게 만듭니다.
          const SizedBox(height: 120), // 이 숫자를 조절하여 스크롤 여유 공간을 맞추세요!

        ],
      ),
    );
  }
}