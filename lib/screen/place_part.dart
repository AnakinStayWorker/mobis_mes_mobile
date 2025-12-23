import 'dart:convert';
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

  // 원본 스캔 로그(Place 단계)
  final List<String> _placedRawScans = [];

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

  List<String> splitPQVS(String s) {
    final t = s.trim();
    if (t.isEmpty) return [];

    final idx = <int>[];
    for (int i = 0; i < t.length; i++) {
      final ch = t[i].toUpperCase();
      if (ch == 'P' || ch == 'Q' || ch == 'V' || ch == 'S') idx.add(i);
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
    final digits = qToken.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  // -----------------------------
  // Location PART_NO (Enter 기반)
  // -----------------------------
  Future<void> _onLocationSubmitted(String v) async {
    final raw = v.trim();
    if (raw.isEmpty) return;

    // 입력창에는 prefix 제거값 표시
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

    final apiQty = res.data!.stockQty; // 음수도 그대로 받음

    setState(() {
      _apiCurrentQty = apiQty;
      _currentQty = apiQty;
      _modified = false;
      _loadingStock = false;

      // 로케이션 재스캔 시 초기화
      _scannedQty = 0;
      _scannedBoxes.clear();
      _placedRawScans.clear();
    });

    _currentQtyCtrl.text = _currentQty.toString(); // 음수 그대로 표시
    _scanCtrl.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scanFocus.requestFocus();
    });
  }

  void _onCurrentQtyChanged(String v) {
    // 사용자가 수정한 값은 “그대로” 반영하되,
    //    Update 시 서버/DB 규칙에 맡긴다 (여기서 0으로 강제 클램프 하지 않음)
    final n = int.tryParse(v);
    if (n == null) return;

    setState(() {
      _currentQty = n;
      _modified = (_currentQty != _apiCurrentQty);
    });
  }

  // ------------------------------------------
  // Picked Box Label (Enter 기반, P/Q/V/S 모두 필수)
  // ------------------------------------------
  Future<void> _onBoxSubmitted(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;

    _scanCtrl.clear();

    final tokens = splitPQVS(text);
    if (tokens.isEmpty) {
      await _popup('Scan Error', 'Invalid label scan.\nExpected: P..., Q..., V..., S...\nReceived: $text');
      _refocusScanBoxField();
      return;
    }

    String? p, q, vv, s;
    for (final t in tokens) {
      if (t.isEmpty) continue;
      final head = t[0].toUpperCase();
      if (head == 'P') p ??= t;
      else if (head == 'Q') q ??= t;
      else if (head == 'V') vv ??= t;
      else if (head == 'S') s ??= t;
    }

    // P/Q/V/S 모두 필수: 2~3개만 읽힌 경우 반드시 에러
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

    await _handleOneLabelPqvs(
      p: p,
      q: q,
      v: vv,
      s: s,
      raw: text, // 원본 저장용
    );

    _refocusScanBoxField();
  }

  Future<void> _handleOneLabelPqvs({
    required String p,
    required String q,
    required String v,
    required String s,
    required String raw,
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
      return;
    }

    final box = PickedBox(partNo: part, qty: qty, serial: serial, raw: raw);

    // Pickup 단계에서 스캔된 박스인지 확인
    final picked = widget.pickedBoxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (!picked) {
      await _popup('Not Picked', 'This box was not scanned in Pickup step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}');
      return;
    }

    // Place 단계 중복 방지
    final dup = _scannedBoxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (dup) {
      await _popup('Duplicate', 'Already scanned in this step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}');
      return;
    }

    setState(() {
      _scannedBoxes.add(box);
      _scannedQty += box.qty;
      _placedRawScans.add(raw); // 원본 스캔 저장
    });

    await _scanSuccessFeedback();

    // 아직 스캔할 박스 남아있으면 바로 다음 스캔 준비
    final remaining = widget.pickedBoxes.length - _scannedBoxes.length;
    if (remaining > 0) _refocusScanBoxField();
  }

  Future<void> _updateStock() async {
    if (_updating) return;

    // Update 시점에 Current Stock 음수 금지
    if (_currentQty < 0) {
      await _popup(
        'Invalid Qty',
        'Current Stock Qty cannot be negative when updating.\n'
            'Please correct it to 0 or higher.',
      );
      // 다시 Current Stock 편집칸으로 포커스
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
      });
      return;
    }

    final editQty = _currentQty - _apiCurrentQty;
    final totalQty = _currentQty + _scannedQty;

    // Total도 안전하게
    if (totalQty < 0) {
      await _popup(
        'Invalid Total',
        'Total Qty cannot be negative.\n'
            'Current: $_currentQty, Scanned: $_scannedQty',
      );
      return;
    }

    // 로그로 남길 barcode payload
    final barcodePayload = jsonEncode({
      'locationPartNo': _locCtrl.text,
      'pickedRawScans': widget.pickedBoxes.map((b) => b.raw).toList(),
      'placedRawScans': _placedRawScans,
    });

    setState(() => _updating = true);

    final r = await MobisWebApi.updateStock(
      partNo: widget.selectedPartNo,
      currentQty: _currentQty,
      editQty: editQty,
      scannedQty: _scannedQty,
      totalQty: totalQty,
      requestBarcodeJson: barcodePayload,
    );

    if (!mounted) return;

    setState(() => _updating = false);

    if (r.resultCode == '00') {
      await _popup('Success', 'Stock updated successfully.');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MonitorPartPage()),
            (route) => false,
      );
    } else {
      await _popup('Failed', 'ResultCode: ${r.resultCode}\n${r.resultMessage}');
      // 실패해도 다시 스캔 가능 상태로
      if (_locationOk) _refocusScanBoxField();
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
            Text('Selected PART_NO: ${widget.selectedPartNo}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            TextField(
              controller: _locCtrl,
              focusNode: _locFocus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Scan Location PART_NO',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _onLocationSubmitted,
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
              onSubmitted: _onBoxSubmitted,
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
