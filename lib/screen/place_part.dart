import 'package:flutter/material.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'monitor_part.dart';
import 'pickup_part.dart';
import 'package:flutter/services.dart';

class PlacePartPage extends StatefulWidget {
  final String selectedPartNo;
  final List<PickedBox> pickedBoxes;

  const PlacePartPage({
    super.key,
    required this.selectedPartNo,
    required this.pickedBoxes,
  });

  @override
  State<PlacePartPage> createState() => _PlacePartPageState();
}

class _PlacePartPageState extends State<PlacePartPage> {
  final _locCtrl = TextEditingController();
  final _locFocus = FocusNode();

  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  final _currentQtyCtrl = TextEditingController();

  bool _locationOk = false;

  int _apiCurrentQty = 0;
  int _currentQty = 0;
  bool _modified = false;

  int _scannedQty = 0;
  final List<PickedBox> _scannedBoxes = [];
  final List<String> _buffer = [];

  bool _loadingStock = false;
  bool _updating = false;

  @override
  void dispose() {
    _locCtrl.dispose();
    _locFocus.dispose();

    _scanCtrl.dispose();
    _scanFocus.dispose();

    _currentQtyCtrl.dispose();
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

  String stripPrefix1(String raw) {
    final s = raw.trim();
    if (s.length >= 2 && RegExp(r'^[A-Za-z]').hasMatch(s[0])) {
      return s.substring(1);
    }
    return s;
  }

  // 붙어있는 문자열을 P/Q/V/S 토큰 단위로 split
  // 예: P04877658AEQ50V22904S000851437
  List<String> splitPQVS(String s) {
    final t = s.trim();
    if (t.isEmpty) return [];

    final idx = <int>[];
    for (int i = 0; i < t.length; i++) {
      final ch = t[i].toUpperCase();
      if (ch == 'P' || ch == 'Q' || ch == 'V' || ch == 'S') {
        idx.add(i);
      }
    }
    if (idx.isEmpty) return [];

    final out = <String>[];
    for (int k = 0; k < idx.length; k++) {
      final start = idx[k];
      final end = (k + 1 < idx.length) ? idx[k + 1] : t.length;
      out.add(t.substring(start, end));
    }
    return out;
  }

  int parseQtyFromQ(String qToken) {
    // qToken 예: "Q100"
    final digits = qToken.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  // -----------------------------
  // Location PART_NO (Enter 기반)
  // -----------------------------
  Future<void> _onLocationSubmitted(String v) async {
    final raw = v.trim();
    if (raw.isEmpty) return;

    // P 유무 상관없이 허용, 입력칸에는 prefix 제거값 표시
    final scanned = stripPrefix1(raw).toUpperCase();
    final expected = widget.selectedPartNo.toUpperCase();

    _locCtrl.text = scanned;

    if (scanned != expected) {
      await _popup('Wrong Location', 'Location PART_NO ($scanned) does not match selected part ($expected).');
      _locCtrl.clear();
      _locFocus.requestFocus();
      return;
    }

    setState(() {
      _locationOk = true;
      _loadingStock = true;
    });

    final res = await MobisWebApi.getPartStock(widget.selectedPartNo);

    if (!mounted) return;

    if (res.resultCode != '00' || res.data == null) {
      setState(() {
        _loadingStock = false;
        _locationOk = false;
      });
      await _popup('Error', 'GetPartStock failed. (${res.resultCode}) ${res.resultMessage}');
      _locFocus.requestFocus();
      return;
    }

    final apiQty = res.data!.stockQty;

    setState(() {
      _apiCurrentQty = apiQty;
      _currentQty = apiQty;
      _modified = false;
      _loadingStock = false;

      // 로케이션 재스캔 시 초기화
      _scannedQty = 0;
      _scannedBoxes.clear();
      _buffer.clear();
    });

    _currentQtyCtrl.text = _currentQty.toString();
    _scanCtrl.clear();

    // Scan Picked Box Labels 로 자동 포커스 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scanFocus.requestFocus();
    });
  }

  void _onCurrentQtyChanged(String v) {
    final n = int.tryParse(v) ?? 0;
    final val = n < 0 ? 0 : n;

    setState(() {
      _currentQty = val;
      _modified = (_currentQty != _apiCurrentQty);
    });
  }

  // ------------------------------------------
  // Picked Box Label (Enter 기반, P/Q/V/S 모두 필수)
  // ------------------------------------------
  Future<void> _onBoxSubmitted(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;

    // 토큰 분리
    final tokens = splitPQVS(text);
    if (tokens.isEmpty) {
      await _popup(
        'Scan Error',
        'Invalid label scan.\nExpected: P..., Q..., V..., S...\nReceived: $text',
      );
      _refocusScanBoxField();
      return;
    }

    // 이번 스캔은 "한 박스 라벨"이므로, 이번 입력에서 바로 P/Q/V/S를 모두 확보해야 함.
    String? p, q, vv, s;

    for (final t in tokens) {
      if (t.isEmpty) continue;
      final head = t[0].toUpperCase();
      if (head == 'P') p ??= t;
      else if (head == 'Q') q ??= t;
      else if (head == 'V') vv ??= t;
      else if (head == 'S') s ??= t;
    }

    // P/Q/V/S 모두 없으면 에러 + 처리 중단
    if (p == null || q == null || vv == null || s == null) {
      await _popup(
        'Scan Error',
        'Invalid label. Missing required barcode(s).\n'
            'Required: P / Q / V / S\n'
            'Received tokens: ${tokens.join(" ")}',
      );
      _refocusScanBoxField();
      return;
    }

    // 여기서 한 박스 처리로 바로 넘긴다 (buffer 누적 방식 필요 없음)
    await _handleOneLabelPqvs(p: p, q: q, v: vv, s: s);

    _refocusScanBoxField();
  }

  // ------------------------------------------
  // 박스 1개 처리 (P/Q/V/S 모두 사용해서 검증)
  // ------------------------------------------
  Future<void> _handleOneLabelPqvs({
    required String p,
    required String q,
    required String v,
    required String s,
  }) async {
    final part = stripPrefix1(p).toUpperCase();
    final qty = parseQtyFromQ(q);
    final serial = stripPrefix1(s);

    if (qty <= 0) {
      await _popup('Scan Error', 'Invalid Qty from label: $q');
      return;
    }

    if (part != widget.selectedPartNo.toUpperCase()) {
      await _popup('Invalid Part', 'Scanned box Part# ($part) does not match (${widget.selectedPartNo}).');
      _refocusScanBoxField();
      return;
    }

    final box = PickedBox(partNo: part, qty: qty, serial: serial);

    // Pickup 단계에서 스캔된 박스인지 확인
    final picked = widget.pickedBoxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (!picked) {
      await _popup('Not Picked', 'This box was not scanned in Pickup step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}');
      _refocusScanBoxField();
      return;
    }

    // Place 단계 중복 방지
    final dup = _scannedBoxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (dup) {
      await _popup('Duplicate', 'Already scanned in this step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}');
      _refocusScanBoxField();
      return;
    }

    setState(() {
      _scannedBoxes.add(box);
      _scannedQty += box.qty;
    });

    await _scanSuccessFeedback(); // 성공 피드백

    // 아직 스캔할 박스가 남아있으면 즉시 다음 스캔 준비
    final remaining = widget.pickedBoxes.length - _scannedBoxes.length;
    if (remaining > 0) {
      _refocusScanBoxField();
    }
  }

  // -----------------------------
  // Update Stock
  // -----------------------------
  Future<void> _updateStock() async {
    if (_updating) return;

    final editQty = _currentQty - _apiCurrentQty;
    final totalQty = _currentQty + _scannedQty;

    setState(() {
      _updating = true;
    });

    final r = await MobisWebApi.updateStock(
      partNo: widget.selectedPartNo,
      currentQty: _currentQty,
      editQty: editQty,
      scannedQty: _scannedQty,
      totalQty: totalQty,
    );

    if (!mounted) return;

    setState(() {
      _updating = false;
    });

    if (r.resultCode == '00') {
      await _popup('Success', 'Stock updated successfully.');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MonitorPartPage()),
            (route) => false,
      );
    } else {
      await _popup('Failed', 'ResultCode: ${r.resultCode}\n${r.resultMessage}');
    }
  }

  Future<void> _scanSuccessFeedback() async {
    try {
      SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _refocusScanBoxField() {
    _scanCtrl.clear();

    // 포커스 튐 방지용으로 한번 정리
    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scanFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalQty = _currentQty + _scannedQty;
    final scannedAll = _scannedBoxes.length == widget.pickedBoxes.length && widget.pickedBoxes.isNotEmpty;
    final canUpdate = _locationOk && scannedAll && !_loadingStock && !_updating;

    return Scaffold(
      appBar: AppBar(title: const Text('Place Part')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected PART_NO: ${widget.selectedPartNo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _locCtrl,
              focusNode: _locFocus,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Scan Location PART_NO',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _onLocationSubmitted(value),
            ),

            const SizedBox(height: 10),
            if (_loadingStock) const LinearProgressIndicator(),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: _locationOk && !_loadingStock,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Current Stock Qty',
                      suffixText: _modified ? 'Modified' : null,
                      border: const OutlineInputBorder(),
                    ),
                    controller: _currentQtyCtrl,
                    onChanged: _onCurrentQtyChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Scanned Qty', border: OutlineInputBorder()),
                    child: Text('$_scannedQty'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Total Qty', border: OutlineInputBorder()),
                    child: Text('$totalQty'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              enabled: _locationOk && !_loadingStock,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Scan Picked Box Labels',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _onBoxSubmitted(value),
            ),

            const SizedBox(height: 10),
            Text(
              'Scanned Boxes: (${_scannedBoxes.length} of ${widget.pickedBoxes.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _scannedBoxes.length,
                itemBuilder: (_, i) {
                  final b = _scannedBoxes[i];
                  return ListTile(
                    dense: true,
                    title: Text('Part#: ${b.partNo} | Qty: ${b.qty} | Serial#: ${b.serial}'),
                  );
                },
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canUpdate ? _updateStock : null,
                child: _updating ? const Text('Updating...') : const Text('Update Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
