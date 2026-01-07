import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/stock_depletion_models.dart';
import 'pickup_part.dart';

class MonitorPartPage extends StatefulWidget {
  const MonitorPartPage({super.key});

  @override
  State<MonitorPartPage> createState() => _MonitorPartPageState();
}

class _MonitorPartPageState extends State<MonitorPartPage> {
  bool _loading = false;
  String? _err;
  List<StockDepletionItem> _rows = [];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load(); // 최초 로드

    // 30초마다 자동 갱신
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _load(silent: true); // 자동 갱신은 로딩 스피너로 화면을 흔들지 않도록
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
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
      // silent 모드: 기존 리스트는 유지
      _loading = true;
    }

    final res = await MobisWebApi.getStockDepletionInfo();
    if (!mounted) return;

    setState(() {
      _loading = false;

      if (res.resultCode == '00') {
        _rows = res.items;
        _err = null;
      } else {
        // 자동 갱신 실패 시: 기존 rows는 유지
        _err = res.resultMessage.isNotEmpty
            ? res.resultMessage
            : 'Failed to load.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFirstLoading = _loading && _rows.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor Part')),
      body: showFirstLoading
          ? const Center(child: CircularProgressIndicator())
          : _err != null && _rows.isEmpty
          ? Center(child: Text(_err!))
          : RefreshIndicator(
        onRefresh: () => _load(silent: false),
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1),
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupPartPage(
                      selectedPartNo: r.partNo,
                      selectedPcCode: r.pcCode,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
