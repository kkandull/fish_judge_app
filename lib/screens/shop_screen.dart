import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';



class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // 변수 초기값을 5000으로 설정하여 실행 즉시 5000P가 보이게 합니다.
  int _ecoPoint = 5000;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  // 저장된 포인트를 불러오는 함수
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 저장된 값이 있으면 그걸 쓰고, 없으면 5000을 유지합니다.
      _ecoPoint = prefs.getInt('eco_point') ?? 5000;
    });
  }

  void _goToDetail(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(item: item)),
    );
    // 상세 페이지에서 돌아왔을 때 (구매 후) 포인트를 새로고침합니다.
    _loadPoints(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 정보 & 피싱 샵', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildWallet(),      // 포인트 지갑
            _buildAdBanner(),    // 광고 배너
            _buildSearchBar(),   // 검색창
            _buildList(),        // 물품 리스트
          ],
        ),
      ),
    );
  }

  // 상단 지갑 UI
  Widget _buildWallet() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3F51B5), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("나의 포인트", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text("$_ecoPoint P", 
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            children: [
              _walletBtn("충전"),
              const SizedBox(height: 8),
              _walletBtn("쿠폰함"),
            ],
          )
        ],
      ),
    );
  }

  Widget _walletBtn(String label) => Container(
    width: 80, padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    alignment: Alignment.center,
    child: Text(label, 
      style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold, fontSize: 12)),
  );

  // 광고 배너 UI
  Widget _buildAdBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity, height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5), 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.orange.shade200)
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20), 
            child: Icon(Icons.campaign, size: 35, color: Colors.orange)
          ),
          const Expanded(
            child: Text("해운대 낚시마트 특별 이벤트\n20% 추가 적립 기회!", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
          ),
          const Icon(Icons.chevron_right, color: Colors.orange),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  // 검색창 UI
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: "용품, 매점 검색", 
                  border: InputBorder.none, 
                  contentPadding: EdgeInsets.symmetric(horizontal: 10)
                )
              )
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_return, color: Color(0xFF3F51B5)), 
              onPressed: () {}
            ),
          ],
        ),
      ),
    );
  }

  // 리스트 UI
  Widget _buildList() {
    final items = [
      {"name": "해운대 고급 바늘 세트", "price": 500, "loc": "중동", "type": "택배배송", "fee": "3,000원", "desc": "장인이 만든 고강도 바늘 세트입니다."},
      {"name": "광안리 선상 낚시권", "price": 5000, "loc": "민락동", "type": "직거래", "fee": "없음", "desc": "3시간 선상 체험 패키지입니다."},
      {"name": "고탄성 카본 낚싯대 대여", "price": 1200, "loc": "송정", "type": "직거래", "fee": "없음", "desc": "가벼운 무게의 최신형 카본대입니다."},
      {"name": "에코 가맹점 할인권", "price": 300, "loc": "다대포", "type": "쿠폰", "fee": "무료", "desc": "제휴 가맹점에서 즉시 사용 가능합니다."},
      {"name": "감성돔 특수 집어제", "price": 800, "loc": "영도구", "type": "택배배송", "fee": "3,000원", "desc": "조과가 검증된 특제 집어제입니다."},
      {"name": "야간 케미라이트 10입", "price": 200, "loc": "중구", "type": "택배배송", "fee": "2,500원", "desc": "밤낚시 시인성이 뛰어난 필수템."},
      {"name": "고성능 릴 세척 서비스", "price": 1500, "loc": "동래구", "type": "방문접수", "fee": "없음", "desc": "염분 제거 및 릴 케어 서비스."},
      {"name": "휴대용 에어펌프", "price": 2000, "loc": "기장군", "type": "택배배송", "fee": "3,000원", "desc": "물고기 신선도 유지를 위한 펌프."},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (c, i) {
        final item = items[i];
        return InkWell(
          onTap: () => _goToDetail(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 22.0),
            child: Row(
              children: [
                Container(
                  width: 100, height: 100, 
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), 
                  alignment: Alignment.center, 
                  child: const Icon(Icons.image, color: Colors.grey)
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] as String, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text("${item['loc']} · 포인트 교환", 
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text("${item['price']} P", 
                        style: const TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold, fontSize: 19)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 상세 페이지 클래스
class DetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const DetailScreen({super.key, required this.item});

  Future<void> _buy(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('eco_point') ?? 5000;
    int price = item['price'];

    if (current >= price) {
      await prefs.setInt('eco_point', current - price);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("교환이 완료되었습니다!")));
        Navigator.pop(context);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("포인트가 부족합니다.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('상세 정보', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.white, 
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity, height: 300, 
                    color: Colors.grey[100], 
                    child: const Icon(Icons.image, size: 100, color: Colors.grey)
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("${item['price']} P", 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
                        const Divider(height: 40),
                        _infoRow(Icons.local_shipping, "배송 정보", item['type']),
                        _infoRow(Icons.money, "배송비", item['fee']),
                        _infoRow(Icons.location_on, "거래 지역", item['loc']),
                        const Divider(height: 40),
                        const Text("상품 설명", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Text(item['desc'], style: const TextStyle(fontSize: 16, height: 1.6)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 하단 구매 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
            decoration: const BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
            ),
            child: ElevatedButton(
              onPressed: () => _buy(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("포인트로 구매하기", 
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
