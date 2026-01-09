import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/stock_depletion_models.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';
import 'package:mobis_mes_mobile/component/app_drawer.dart';

class InventoryCheckPage extends StatefulWidget {
  const InventoryCheckPage({super.key});

  @override
  State<InventoryCheckPage> createState() => _InventoryCheckPageState();
}

class _InventoryCheckPageState extends State<InventoryCheckPage> {
  final _partCtrl = TextEditingController();
  final _partFocus = FocusNode();

  bool _loading = false;
  String? _err;
  CurrentStockInfo? _info;

  String? _lastCoreBarcode;
  String? _lastParsedDisplay;

  @override
  void dispose() {
    _partCtrl.dispose();
    _partFocus.dispose();
    super.dispose();
  }

  Future<void> _popup(String title, String msg) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
  }

  void _refocusAndClearInput() {
    _partCtrl.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _partFocus.requestFocus();
    });
  }

  Map<String, String>? _parsePartPcCodeBarcode(String raw) {
    if (raw.isEmpty) return null;
    final s = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (s.length < 22) return null;

    final core = s.substring(0, 22);
    if (core[0] != 'P') return null;
    if (core[11] != 'L') return null;

    final partNo = core.substring(1, 11);
    final pcCode = core.substring(12, 22);

    return {
      'core': core,
      'partNo': partNo,
      'pcCode': pcCode,
    };
  }

  Future<void> _search(String input) async {
    if (_loading) return;

    final raw = input.trim();
    if (raw.isEmpty) return;

    final parsed = _parsePartPcCodeBarcode(raw);
    if (parsed == null) {
      setState(() {
        _err =
        'Invalid barcode. Expected: P{10-digit PART_NO}L{10-digit PC_CODE}\n'
            'Example: P04877659AELFF010_PC01\n'
            'Received: $raw';
        _info = null;
        _lastCoreBarcode = null;
        _lastParsedDisplay = null;
      });
      await _popup('Scan Error', _err!);
      _refocusAndClearInput();
      return;
    }

    final core = parsed['core']!;
    final partNo = parsed['partNo']!.toUpperCase();
    final pcCode = parsed['pcCode']!.toUpperCase();

    // UI 먼저 업데이트
    setState(() {
      _loading = true;
      _err = null;
      _info = null;
      _lastCoreBarcode = core;
      _lastParsedDisplay = '$partNo | $pcCode';
    });

    _refocusAndClearInput();

    // API 호출 직전에 세션 확인(Refresh 포함)
    final ok = await AuthSession.ensureAliveOrLogin(context);
    if (!ok) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await MobisWebApi.getPartStock(partNo, pcCode);
      if (!mounted) return;

      // 401이면 세션 만료 처리
      if (await AuthSession.handle401IfNeeded(context, res.resultCode)) {
        setState(() => _loading = false);
        return;
      }

      if (res.resultCode != '00' || res.data == null) {
        setState(() {
          _loading = false;
          _err = '(${res.resultCode}) '
              '${res.resultMessage.isNotEmpty ? res.resultMessage : 'Failed to load.'}';
          _info = null;
        });
        await _popup('Failed', _err!);
        _refocusAndClearInput();
        return;
      }

      setState(() {
        _loading = false;
        _info = res.data;
      });

      try {
        SystemSound.play(SystemSoundType.click);
        await HapticFeedback.lightImpact();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = 'Network/Parsing error: $e';
        _info = null;
      });
      await _popup('Error', _err!);
      _refocusAndClearInput();
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _s(dynamic v) => (v == null) ? '-' : v.toString();

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Check')),
      drawer: const AppDrawer(current: AppPage.inventoryCheck),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _partCtrl,
                  focusNode: _partFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Scan Barcode (P{PART_NO}L{PC_CODE})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    suffixIcon: _loading
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : null,
                  ),
                  onSubmitted: _search,
                ),
              ),
            ),

            if (_lastCoreBarcode != null || _lastParsedDisplay != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Scanned Barcode:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_lastCoreBarcode != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _lastCoreBarcode!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
            ],

            const SizedBox(height: 12),

            if (_err != null)
              Text(
                _err!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),

            if (info == null && !_loading)
              Expanded(
                child: Center(
                  child: Text(
                    'Scan barcode (P{PART_NO}L{PC_CODE}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ),

            if (info != null)
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Summary',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _kv('PART_NO', _s(info.partNo)),
                            _kv('PARTNM_CODE', _s(info.partnmCode)),
                            _kv('PART_NAME', _s(info.partName)),
                            _kv('STOCK_QTY', _s(info.stockQty)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Line / Work',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _kv('LINE_CODE', _s(info.lineCode)),
                            _kv('PC_CODE', _s(info.pcCode)),
                            _kv('STATION_CODE', _s(info.stationCode)),
                            _kv('WORK_CODE', _s(info.workCode)),
                            _kv('WORK_TYPE', _s(info.workType)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sequence / Time',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _kv('SEQ_IDX', _s(info.seqIdx)),
                            _kv('DEDUCTION_TIME', _s(info.subtractionTime)),
                            _kv('ADDITION_TIME', _s(info.additionTime)),
                            _kv('USE_FLAG', _s(info.useFlag)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
