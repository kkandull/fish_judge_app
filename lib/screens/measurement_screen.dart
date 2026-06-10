import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/regulation_service.dart';

class MeasurementScreen extends StatefulWidget {
  final File imageFile;
  final String? label; 
  
  const MeasurementScreen({super.key, required this.imageFile, this.label});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  int _step = 1;
  Offset? _shoeStart; Offset? _shoeEnd;
  double _shoeSizeMm = 270.0;
  Offset? _fishStart; Offset? _fishEnd;
  double _finalResultCm = 0.0;
  
  final RegulationService _regulationService = RegulationService();
  bool _isRegLoaded = false; // 규정 데이터 로드 완료 여부

  @override
  void initState() {
    super.initState();
    _initRegData(); // 화면 시작 시 규정 데이터 로드
  }

  // 규정 서비스 초기화 로직 추가
  Future<void> _initRegData() async {
    await _regulationService.loadRegulations();
    if (mounted) {
      setState(() {
        _isRegLoaded = true;
      });
    }
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      if (_step == 1) { _shoeStart = d.localPosition; _shoeEnd = d.localPosition; }
      else if (_step == 2) { _fishStart = d.localPosition; _fishEnd = d.localPosition; }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      if (_step == 1) _shoeEnd = d.localPosition;
      else if (_step == 2) _fishEnd = d.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_step == 1 && _shoeStart != null) _askShoeSize();
    else if (_step == 2 && _fishStart != null) _calculateResult();
  }

  void _askShoeSize() {
    TextEditingController c = TextEditingController(text: "270");
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("👟 신발 사이즈 입력"),
      content: TextField(
        controller: c, 
        keyboardType: TextInputType.number, 
        decoration: const InputDecoration(suffixText: "mm", hintText: "기본 270")
      ),
      actions: [TextButton(onPressed: () {
        setState(() { _shoeSizeMm = double.tryParse(c.text) ?? 270.0; _step = 2; });
        Navigator.pop(ctx);
      }, child: const Text("확인"))],
    ));
  }

  void _calculateResult() {
    if (_shoeStart == null || _shoeEnd == null || _fishStart == null || _fishEnd == null) return;
    
    double sDist = sqrt(pow(_shoeEnd!.dx - _shoeStart!.dx, 2) + pow(_shoeEnd!.dy - _shoeStart!.dy, 2));
    double fDist = sqrt(pow(_fishEnd!.dx - _fishStart!.dx, 2) + pow(_fishEnd!.dy - _fishStart!.dy, 2));
    
    setState(() { 
      _finalResultCm = ((fDist / sDist) * _shoeSizeMm) / 10; 
      _step = 3; 
    });
  }

  @override
  Widget build(BuildContext context) {
    // 데이터 로딩 중일 때와 완료되었을 때의 처리
    final reg = (widget.label != null && _isRegLoaded) 
        ? _regulationService.getRegulationInfo(widget.label!) 
        : null;
    final limit = reg?["금지체장"] ?? "데이터 불러오는 중...";
    final note = reg?["비고"] ?? "";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("스마트 체장 측정", style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.blue.shade900,
            child: Text(
                _step == 1 ? "1단계: 신발의 양 끝을 그어주세요" : 
                _step == 2 ? "2단계: 물고기의 길이를 그어주세요" : "계측이 완료되었습니다",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: _step < 3 ? _onPanStart : null,
              onPanUpdate: _step < 3 ? _onPanUpdate : null,
              onPanEnd: _step < 3 ? _onPanEnd : null,
              child: Stack(fit: StackFit.expand, children: [
                Image.file(widget.imageFile, fit: BoxFit.contain),
                CustomPaint(painter: LinePainter(_shoeStart, _shoeEnd, _fishStart, _fishEnd)),
              ]),
            ),
          ),
          if (_step == 3)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: const BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))
              ),
              child: Column(
                children: [
                  const Text("계측 결과", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text("${_finalResultCm.toStringAsFixed(1)} cm", 
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                  const SizedBox(height: 15),
                  

                  // 규정 정보 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Text("${widget.label} 보호 규정", 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text("금지체장 기준: $limit", 
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                        
                        // 비고란이 있을 때만 화면에 표시
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6), 
                            child: Text(
                              note, 
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),


                  
                  const SizedBox(height: 15),
                  const Text("※ 실제 단속 시에는 줄자 측정이 우선됩니다.", 
                      style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52, 
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: const Text("확인 완료", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  )
                ],
              ),
            )
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final Offset? sS, sE, fS, fE;
  LinePainter(this.sS, this.sE, this.fS, this.fE);
  @override
  void paint(Canvas canvas, Size size) {
    final shoePaint = Paint()..color = Colors.greenAccent..strokeWidth = 4..strokeCap = StrokeCap.round;
    final fishPaint = Paint()..color = Colors.redAccent..strokeWidth = 4..strokeCap = StrokeCap.round;
    
    if (sS != null && sE != null) canvas.drawLine(sS!, sE!, shoePaint);
    if (fS != null && fE != null) canvas.drawLine(fS!, fE!, fishPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}