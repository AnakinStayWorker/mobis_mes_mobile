import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';

import 'monitor_part.dart';
import 'pickup_part.dart';

class PlacePartPage extends StatefulWidget {
  final String selectedPartNo;
  final String selectedPcCode;
  final List<PickedBox> pickedBoxes;

  const PlacePartPage({
    super.key,
    required this.selectedPartNo,
    required this.selectedPcCode,
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

  // Location QR를 사람이 보기 좋게 해석한 값 (PART|PC)
  String? _locationParsedDisplay; // ex) 04877659AE | FF010_PC01

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
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
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

  // Location 바코드(P+10 + L+10) 파싱
  // 예: P04877659AELFF010_PC01  (QR 뒤에 쓰레기/개행이 있어도 앞 22자만 사용)
  Map<String, String>? _parsePartPcBarcode(String raw) {
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

  // -----------------------------
  // Location (Enter 기반)
  // -----------------------------
  Future<void> _onLocationSubmitted(String v) async {
    final raw = v.trim();
    if (raw.isEmpty) return;

    // Location 스캔 시점에 세션 확인
    // final ok = await AuthSession.ensureAliveOrLogin(context);
    // if (!ok) return;

    final parsed = _parsePartPcBarcode(raw);
    if (parsed == null) {
      await _popup(
        'Scan Error',
        'Invalid location barcode.\n'
            'Expected: P{10-digit PART_NO}L{10-digit PC_CODE}\n'
            'Example: P04877659AELFF010_PC01\n'
            'Received: $raw',
      );
      _locCtrl.clear();
      _locationParsedDisplay = null;
      _locFocus.requestFocus();
      return;
    }

    final core = parsed['core']!;
    final scannedPart = parsed['partNo']!.toUpperCase();
    final scannedPcCode = parsed['pcCode']!.toUpperCase();

    final expectedPart = widget.selectedPartNo.toUpperCase();
    final expectedPcCode = widget.selectedPcCode.toUpperCase();

    _locCtrl.text = core;

    setState(() {
      _locationParsedDisplay = '$scannedPart | $scannedPcCode';
    });

    if (scannedPart != expectedPart || scannedPcCode != expectedPcCode) {
      await _popup(
        'Wrong Location',
        'Scanned Location does not match selected.\n'
            'Scanned: $scannedPart | $scannedPcCode\n'
            'Selected: $expectedPart | $expectedPcCode',
      );
      _locCtrl.clear();
      setState(() => _locationParsedDisplay = null);
      _locFocus.requestFocus();
      return;
    }

    setState(() {
      _locationOk = true;
      _loadingStock = true;
    });

    try {
      final res = await MobisWebApi.getPartStock(
        widget.selectedPartNo,
        widget.selectedPcCode,
      );
      if (!mounted) return;

      // 401이면 세션 만료 처리 (팝업+로그인 이동)
      if (await AuthSession.handle401IfNeeded(context, res.resultCode)) {
        return;
      }

      if (res.resultCode != '00' || res.data == null) {
        setState(() {
          _loadingStock = false;
          _locationOk = false;
        });
        await _popup('Error',
            'GetPartStock failed. (${res.resultCode}) ${res.resultMessage}');
        _locFocus.requestFocus();
        return;
      }

      final apiQty = res.data!.stockQty; // 음수도 그대로 받음

      setState(() {
        _apiCurrentQty = apiQty;
        _currentQty = apiQty;
        _modified = false;
        _loadingStock = false;

        _scannedQty = 0;
        _scannedBoxes.clear();
        _placedRawScans.clear();
      });

      _currentQtyCtrl.text = _currentQty.toString();
      _scanCtrl.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scanFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStock = false;
        _locationOk = false;
      });
      await _popup('Error', 'Network/Parsing error: $e');
      _locFocus.requestFocus();
    }
  }

  void _onCurrentQtyChanged(String v) {
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
      await _popup(
        'Scan Error',
        'Invalid label scan.\nExpected: P..., Q..., V..., S...\nReceived: $text',
      );
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
      raw: text,
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
      await _popup(
        'Invalid Part',
        'Scanned box Part# ($part) does not match (${widget.selectedPartNo}).',
      );
      return;
    }

    final box = PickedBox(partNo: part, qty: qty, serial: serial, raw: raw);

    final picked = widget.pickedBoxes
        .any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (!picked) {
      await _popup(
        'Not Picked',
        'This box was not scanned in Pickup step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}',
      );
      return;
    }

    final dup = _scannedBoxes
        .any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (dup) {
      await _popup(
        'Duplicate',
        'Already scanned in this step.\nPart#: ${box.partNo}\nSerial#: ${box.serial}',
      );
      return;
    }

    setState(() {
      _scannedBoxes.add(box);
      _scannedQty += box.qty;
      _placedRawScans.add(raw);
    });

    await _scanSuccessFeedback();
  }

  Future<void> _updateStock() async {
    if (_updating) return;

    // 업데이트 직전에 세션을 한 번 더 확인
    final ok = await AuthSession.ensureAliveOrLogin(context);
    if (!ok) return;

    if (_currentQty < 0) {
      await _popup(
        'Invalid Qty',
        'Current Stock Qty cannot be negative when updating.\n'
            'Please correct it to 0 or higher.',
      );
      return;
    }

    final editQty = _currentQty - _apiCurrentQty;
    final totalQty = _currentQty + _scannedQty;

    if (totalQty < 0) {
      await _popup(
        'Invalid Total',
        'Total Qty cannot be negative.\n'
            'Current: $_currentQty, Scanned: $_scannedQty',
      );
      return;
    }

    final barcodePayload = jsonEncode({
      'locationPartNo': widget.selectedPartNo,
      'pcCode': widget.selectedPcCode,
      'pickedRawScans': widget.pickedBoxes.map((b) => b.raw).toList(),
      'placedRawScans': _placedRawScans,
    });

    setState(() => _updating = true);

    try {
      final r = await MobisWebApi.updateStock(
        partNo: widget.selectedPartNo,
        pcCode: widget.selectedPcCode,
        currentQty: _currentQty,
        editQty: editQty,
        scannedQty: _scannedQty,
        totalQty: totalQty,
        requestBarcodeJson: barcodePayload,
      );

      if (!mounted) return;

      // 401이면 세션 만료 처리
      if (await AuthSession.handle401IfNeeded(context, r.resultCode)) {
        return;
      }

      if (r.resultCode == '00') {
        await _popup('Success', 'Stock updated successfully.');
        if (!mounted) return;

        // 작업 플로우 스택 정리: MainMenu(첫 화면)까지 복귀
        Navigator.of(context).popUntil((route) => route.isFirst);

        // Monitor를 다시 push → back은 항상 MainMenu로
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MonitorPartPage()),
        );
      } else {
        await _popup('Failed', 'ResultCode: ${r.resultCode}\n${r.resultMessage}');
        if (_locationOk) _refocusScanBoxField();
      }
    } catch (e) {
      if (!mounted) return;
      await _popup('Error', 'Network/Parsing error: $e');
      if (_locationOk) _refocusScanBoxField();
    } finally {
      if (mounted) setState(() => _updating = false);
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
    final scannedAll =
        _scannedBoxes.length == widget.pickedBoxes.length && widget.pickedBoxes.isNotEmpty;
    final canUpdate = _locationOk && scannedAll && !_loadingStock && !_updating;

    return Scaffold(
      appBar: AppBar(title: const Text('Place Part')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: ${widget.selectedPartNo} | ${widget.selectedPcCode}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _locCtrl,
              focusNode: _locFocus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Scan Location Barcode (P{PartNo}L{PcCode})',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _onLocationSubmitted,
            ),

            if (_locationParsedDisplay != null) ...[
              const SizedBox(height: 6),
              Text(
                'Parsed: $_locationParsedDisplay',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

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
                    decoration: const InputDecoration(
                      labelText: 'Scanned Qty',
                      border: OutlineInputBorder(),
                    ),
                    child: Text('$_scannedQty'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Total Qty',
                      border: OutlineInputBorder(),
                    ),
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
                child: _updating
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Update Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
