import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/stock_depletion_models.dart';

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
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  String _stripPrefixP(String raw) {
    final s = raw.trim();
    if (s.length >= 2 && (s[0] == 'P' || s[0] == 'p')) return s.substring(1);
    return s;
  }

  Future<void> _search(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return;

    // P 유무 상관없이 처리, 입력창에는 P 제거된 값 표시
    final partNo = _stripPrefixP(raw).toUpperCase();
    _partCtrl.text = partNo;

    setState(() {
      _loading = true;
      _err = null;
      _info = null;
    });

    try {
      final res = await MobisWebApi.getPartStock(partNo);
      if (!mounted) return;

      if (res.resultCode != '00' || res.data == null) {
        setState(() {
          _loading = false;
          _err = '(${res.resultCode}) ${res.resultMessage.isNotEmpty ? res.resultMessage : 'Failed to load.'}';
        });
        await _popup('Failed', _err!);
        _partFocus.requestFocus();
        return;
      }

      setState(() {
        _loading = false;
        _info = res.data;
      });

      // 성공 피드백
      try {
        SystemSound.play(SystemSoundType.click);
        await HapticFeedback.lightImpact();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = 'Network/Parsing error: $e';
      });
      await _popup('Error', _err!);
      _partFocus.requestFocus();
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
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search Bar
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _partCtrl,
                        focusNode: _partFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'Enter PART_NO',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                        onSubmitted: _search,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => _search(_partCtrl.text),
                        icon: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_err != null)
              Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),

            if (info == null && !_loading)
              Expanded(
                child: Center(
                  child: Text(
                    'Enter PART_NO and press Search.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ),

            if (info != null)
              Expanded(
                child: ListView(
                  children: [
                    // Summary
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

                    // Location/Work
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Line / Work', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

                    // Sequence / Times
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sequence / Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
