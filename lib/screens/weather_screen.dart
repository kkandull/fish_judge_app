// 날씨 화면

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/weather_service.dart';
import '../widgets/weather_alert_banner.dart';

const Color _kPrimary = Color(0xFF1976D2);
const Color _kNavy = Color(0xFF1A1A2E);
const Color _kBg = Color(0xFFF5F7FA);
const Color _kSub = Color(0xFF6B7684);
const Color _kBorder = Color(0xFFE8EAED);

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherData? _weather;
  bool _loading = true;
  bool _refreshing = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    if (forceRefresh) setState(() => _refreshing = true);
    try {
      final data = await WeatherService.instance.fetch(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _weather = data;
          _loading = false;
          _refreshing = false;
          // isCached = true면 캐시 데이터 → 오프라인 배너 표시
          _isOffline = data.isCached;
        });
      }
    } catch (e) {
      // 캐시도 없는 완전 오프라인
      if (mounted) setState(() {
        _loading = false;
        _refreshing = false;
        _isOffline = true;
      });
    }
  }

  String _formatTime(DateTime dt) {
    final amPm = dt.hour < 12 ? '오전' : '오후';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$amPm $hour:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatUpdated(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${_formatTime(dt)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kNavy),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('현재 바다 상황',
              style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold, fontSize: 17)),
            if (_weather != null)
              Text('업데이트: ${_formatUpdated(_weather!.updatedAt)}',
                style: const TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
                : const Icon(Icons.refresh, color: _kPrimary),
            onPressed: _refreshing ? null : () {
              HapticFeedback.lightImpact();
              _loadWeather(forceRefresh: true);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isOffline && _weather == null
              ? Column(children: [
                  _buildOfflineBanner(), // 캐시도 없는 완전 오프라인
                  Expanded(child: _buildError()),
                ])
          : _weather == null
              ? _buildError()
              : Column(
                  children: [
                    // 오프라인 배너 상단 고정 
                    if (_isOffline) _buildOfflineBanner(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _loadWeather(forceRefresh: true),
                        color: _kPrimary,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_weather!.alerts.isNotEmpty)
                              WeatherAlertBanner(alerts: _weather!.alerts),
                            _buildFishingScoreCard(_weather!.fishingScore),
                            const SizedBox(height: 16),
                            _buildTideCard(_weather!.tide),
                            const SizedBox(height: 16),
                            _buildSunMoonCard(_weather!.sunMoon),
                            const SizedBox(height: 16),
                            _buildOceanGrid(_weather!),
                            const SizedBox(height: 16),
                            _buildWeatherGrid(_weather!),
                            const SizedBox(height: 16),
                            if (_weather!.fishingScore.score < 50)
                              _buildSafetyWarning(_weather!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFishingScoreCard(FishingScore score) {
    final color = Color(int.parse(score.colorHex));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(_getScoreIcon(score.score), color: Colors.white, size: 24)),
          const SizedBox(width: 12),
          const Text('오늘의 낚시 적합도',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${score.score}',
            style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1.0)),
          const Text(' / 100',
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
            child: Text(score.grade,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: score.reasons.take(5).map((reason) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 4, height: 4,
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                Expanded(child: Text(reason,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500))),
              ]),
            )).toList()),
        ),
      ]),
    );
  }

  IconData _getScoreIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.thumb_up;
    if (score >= 40) return Icons.info_outline;
    return Icons.warning_amber_rounded;
  }

  Widget _buildTideCard(TideInfo tide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.waves, color: _kPrimary, size: 20),
          const SizedBox(width: 8),
          const Text('오늘의 물때',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kNavy)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(tide.mulTtae,
              style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const SizedBox(height: 14),
        if (tide.nextEvent != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: tide.nextEvent!.isHighTide
                    ? [_kPrimary.withOpacity(0.15), _kPrimary.withOpacity(0.05)]
                    : [Colors.orange.withOpacity(0.15), Colors.orange.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: tide.nextEvent!.isHighTide ? _kPrimary : Colors.orange,
                  shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(
                  tide.nextEvent!.isHighTide ? Icons.waves : Icons.beach_access,
                  color: Colors.white, size: 24)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('다음 ${tide.nextEvent!.label}',
                  style: const TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_formatTime(tide.nextEvent!.time),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kNavy)),
                Text('조위 ${tide.nextEvent!.levelCm.toStringAsFixed(0)}cm',
                  style: const TextStyle(fontSize: 11, color: _kSub)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tide.nextEvent!.isHighTide ? _kPrimary : Colors.orange,
                  borderRadius: BorderRadius.circular(20)),
                child: Text(_untilLabel(tide.nextEvent!.time),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        const Divider(color: _kBorder),
        const SizedBox(height: 8),
        ...tide.events.map((e) {
          final isPast = e.time.isBefore(DateTime.now());
          final eventColor = e.isHighTide ? _kPrimary : Colors.orange;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isPast ? Colors.grey.shade200 : eventColor.withOpacity(0.15),
                  shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(e.isHighTide ? Icons.waves : Icons.beach_access,
                  size: 14, color: isPast ? Colors.grey : eventColor)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPast ? Colors.grey[200] : eventColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(e.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey : eventColor))),
              const SizedBox(width: 12),
              Text(_formatTime(e.time),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: isPast ? Colors.grey : _kNavy)),
              const Spacer(),
              Text('${e.levelCm.toStringAsFixed(0)}cm',
                style: TextStyle(fontSize: 12, color: isPast ? Colors.grey : _kSub,
                  fontWeight: FontWeight.w600)),
            ]),
          );
        }),
      ]),
    );
  }

  String _untilLabel(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return '지남';
    if (diff.inHours == 0) return '${diff.inMinutes}분 후';
    if (diff.inHours < 24) return '${diff.inHours}시간 후';
    return '내일';
  }

  Widget _buildSunMoonCard(SunMoonInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Expanded(child: _sunMoonItem(Icons.wb_sunny, '일출', _formatTime(info.sunrise), Colors.orange)),
        Container(width: 1, height: 50, color: _kBorder),
        Expanded(child: _sunMoonItem(Icons.wb_twilight, '일몰', _formatTime(info.sunset), Colors.deepOrange)),
        Container(width: 1, height: 50, color: _kBorder),
        Expanded(child: _sunMoonItem(Icons.brightness_2, '월령', info.moonName, Colors.indigo)),
      ]),
    );
  }

  Widget _sunMoonItem(IconData icon, String label, String value, Color color) {
    return Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        textAlign: TextAlign.center),
    ]);
  }

  Widget _buildOceanGrid(WeatherData data) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(children: [
          const Text('실시간 해양 데이터',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kNavy)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.07),
              borderRadius: BorderRadius.circular(6)),
            child: const Text('국립해양조사원',
              style: TextStyle(fontSize: 9, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600))),
        ]),
      ),
      Row(children: [
        Expanded(child: _statCard(icon: Icons.thermostat, label: '수온',
          value: '${data.waterTempC.toStringAsFixed(1)}°C', color: Colors.cyan,
          sub: _waterTempComment(data.waterTempC))),
        const SizedBox(width: 8),
        Expanded(child: _statCard(icon: Icons.waves, label: '파고',
          value: '${data.waveHeightM.toStringAsFixed(1)}m', color: Colors.blue,
          sub: _waveComment(data.waveHeightM))),
      ]),
    ]);
  }

  String _waterTempComment(double t) {
    if (t < 10) return '저수온'; if (t < 14) return '쌀쌀';
    if (t < 22) return '적정'; if (t < 26) return '따뜻'; return '고수온';
  }

  String _waveComment(double w) {
    if (w < 0.5) return '잔잔'; if (w < 1.0) return '양호';
    if (w < 1.5) return '주의'; return '위험';
  }

  Widget _buildWeatherGrid(WeatherData data) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(children: [
          const Text('기상 정보',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kNavy)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.07),
              borderRadius: BorderRadius.circular(6)),
            child: const Text('기상청',
              style: TextStyle(fontSize: 9, color: Color(0xFF1565C0), fontWeight: FontWeight.w600))),
        ]),
      ),
      Row(children: [
        Expanded(child: _statCard(icon: Icons.thermostat, label: '기온',
          value: '${data.airTempC.toStringAsFixed(1)}°C', color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(icon: Icons.air, label: '풍속',
          value: '${data.windSpeedMs.toStringAsFixed(1)}m/s', color: Colors.teal,
          sub: data.windDirection)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _statCard(icon: Icons.umbrella, label: '강수확률',
          value: '${data.rainProbability}%',
          color: data.rainProbability >= 40 ? Colors.indigo : Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(icon: _skyIcon(data.skyCondition), label: '하늘',
          value: data.skyCondition, color: Colors.lightBlue)),
      ]),
    ]);
  }

  IconData _skyIcon(String sky) {
    if (sky.contains('맑')) return Icons.wb_sunny;
    if (sky.contains('구름')) return Icons.cloud_outlined;
    if (sky.contains('흐')) return Icons.cloud;
    if (sky.contains('비')) return Icons.umbrella;
    if (sky.contains('눈')) return Icons.ac_unit;
    return Icons.cloud_outlined;
  }

  Widget _statCard({
    required IconData icon, required String label,
    required String value, required Color color, String? sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18)),
          const Spacer(),
        ]),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: _kSub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ]),
    );
  }

  Widget _buildDummyDataNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text('현재 일부 데이터는 예시 값입니다. 베타 출시 후 실제 API 연동 예정.',
          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.4))),
      ]),
    );
  }

  Widget _buildSafetyWarning(WeatherData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 22),
          const SizedBox(width: 10),
          Text('안전 안내',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
        ]),
        const SizedBox(height: 10),
        Text(
          data.windSpeedMs >= 7
              ? '강한 바람으로 인해 갯바위·방파제 낚시가 위험합니다.\n선상 출조는 자제해주세요.'
              : data.waveHeightM >= 1.5
                  ? '높은 파고로 인해 안전 사고 위험이 있습니다.\n갯바위 출조 자제, 안전 장비 필수.'
                  : '오늘은 낚시 조건이 좋지 않습니다.\n다음 출조를 권장합니다.',
          style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.phone, size: 14, color: Colors.red),
            SizedBox(width: 6),
            Text('해양 긴급: 122  /  소방: 119',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildOfflineBanner() {
    return Material(
      color: const Color(0xFFF97316), // 주황
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '오프라인 상태 — 마지막으로 저장된 데이터를 보여드려요',
                style: TextStyle(
                  fontSize: 12, color: Colors.white,
                  fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            GestureDetector(
              onTap: () => _loadWeather(forceRefresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8)),
                child: const Text('재시도',
                  style: TextStyle(
                    fontSize: 11, color: Colors.white,
                    fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          const Text('날씨 정보를 불러올 수 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
          const SizedBox(height: 8),
          const Text('인터넷 연결을 확인하고\n당겨서 새로고침 해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kSub, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadWeather(forceRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            label: const Text('다시 시도',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}