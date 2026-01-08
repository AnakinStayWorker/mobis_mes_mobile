import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/stock_depletion_models.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';
import 'pickup_part.dart';

class MonitorPartPage extends StatefulWidget {
  const MonitorPartPage({super.key});

  @override
  State<MonitorPartPage> createState() => _MonitorPartPageState();
}

class _MonitorPartPageState extends State<MonitorPartPage>
    with WidgetsBindingObserver {
  bool _loading = false;
  String? _err;
  List<StockDepletionItem> _rows = [];

  Timer? _timer;

  // 타이머를 재시작할 때 중복 방지용
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _load(silent: false); // 최초 로드
    _startTimer(); // 30초 주기 갱신 시작
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  // Modified by Scott Kim. 01/08/2026. 앱이 background로 가면 stop, foreground(resumed)로 오면 start
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Monitor가 화면에 떠있는 상태라도 앱 자체가 백그라운드면 호출을 멈춘다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      // 다시 돌아왔을 때만 재시작
      if (mounted) {
        _startTimer();
        // 복귀 직후 1회 즉시 갱신
        _load(silent: true);
      }
    }
  }

  void _startTimer() {
    if (_timerRunning) return;
    _timerRunning = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _load(silent: true);
    });
  }

  void _stopTimer() {
    _timerRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  Color _minutesColor(double? m) {
    if (m == null) return Colors.blue;
    if (m <= 20) return Colors.red;
    if (m <= 60) return Colors.orange;
    if (m <= 120) return Colors.purple;
    return Colors.blue;
  }

  Future<void> _load({bool silent = false}) async {
    // 중복 호출 방지
    if (_loading) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _err = null;
      });
    } else {
      _loading = true; // silent는 UI 흔들지 않음
    }

    try {
      final res = await MobisWebApi.getStockDepletionInfo();
      if (!mounted) return;

      // 401이면 즉시 세션 만료 처리
      if (await AuthSession.handle401IfNeeded(context, res.resultCode)) {
        // 세션 만료 처리 시 더 이상 갱신 돌릴 필요 없음
        _stopTimer();
        return;
      }

      setState(() {
        if (res.resultCode == '00') {
          _rows = res.items;
          _err = null;
        } else {
          // 자동 갱신 실패 시: 기존 rows는 유지, 에러만 기록
          _err = res.resultMessage.isNotEmpty
              ? res.resultMessage
              : 'Failed to load.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = 'Network/Parsing error: $e';
      });
    } finally {
      _loading = false;
      if (mounted && !silent) {
        setState(() {}); // 최초 스피너 내려주기
      }
    }
  }

  // Modified by Scott Kim. 01/08/2026. Monitor가 보이지 않을 때 타이머를 멈춘다.
  // Pickup으로 이동할 때 stop, 돌아오면 start
  Future<void> _goPickup(StockDepletionItem r) async {
    _stopTimer();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupPartPage(
          selectedPartNo: r.partNo,
          selectedPcCode: r.pcCode,
        ),
      ),
    );

    if (!mounted) return;

    // Modified by Scott Kim. 01/08/2026. 돌아오면 다시 타이머를 시작 시키고 즉시 한 번 갱신
    _startTimer();
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final showFirstLoading = _loading && _rows.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor Part')),
      body: showFirstLoading
          ? const Center(child: CircularProgressIndicator())
          : (_err != null && _rows.isEmpty)
          ? Center(child: Text(_err!))
          : RefreshIndicator(
        onRefresh: () => _load(silent: false),
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final r = _rows[i];
            final m = r.minutesToZero;

            return ListTile(
              title: Text('${r.partNo}  |  ${r.pcCode}'),
              subtitle: Text('Stock: ${r.stockQty}'),
              trailing: Text(
                m == null ? '-' : '${m.toStringAsFixed(1)} min',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _minutesColor(m),
                ),
              ),
              onTap: () => _goPickup(r),
            );
          },
        ),
      ),
    );
  }
}
