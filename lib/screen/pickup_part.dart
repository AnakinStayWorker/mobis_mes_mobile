import 'package:flutter/material.dart';
import 'place_part.dart';
import 'package:flutter/services.dart';

class PickedBox {
  final String partNo;
  final int qty;
  final String serial;

  PickedBox({required this.partNo, required this.qty, required this.serial});

  String key() => '$partNo|$serial';
}

class PickupPartPage extends StatefulWidget {
  final String selectedPartNo;
  const PickupPartPage({super.key, required this.selectedPartNo});

  @override
  State<PickupPartPage> createState() => _PickupPartPageState();
}

class _PickupPartPageState extends State<PickupPartPage> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  final List<PickedBox> _boxes = [];

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
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
  // 예: P68464838ABV48671Q56S960240436
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
    final digits = qToken.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  // -----------------------------
  // Enter 기반 처리
  // -----------------------------
  Future<void> _onSubmitted(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;

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

    // P/Q/V/S 모두 필수
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

    final part = stripPrefix1(p).toUpperCase();
    final qty = parseQtyFromQ(q);
    final serial = stripPrefix1(s);

    if (qty <= 0) {
      await _popup('Scan Error', 'Invalid Qty from label: $q');
      _refocusScanBoxField();
      return;
    }

    // 선택한 PART_NO와 일치해야 함
    if (part != widget.selectedPartNo.toUpperCase()) {
      await _popup(
        'Invalid Part',
        'Scanned Part# ($part) does not match selected PART_NO (${widget.selectedPartNo}).',
      );
      _refocusScanBoxField();
      return;
    }

    final box = PickedBox(partNo: part, qty: qty, serial: serial);

    // 중복 방지 (Part#, Serial# 기준)
    final exists = _boxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (exists) {
      await _popup('Duplicate', 'This box is already scanned.\nPart#: ${box.partNo}\nSerial#: ${box.serial}');
      _refocusScanBoxField();
      return;
    }

    setState(() => _boxes.add(box));
    await _scanSuccessFeedback(); // 성공 피드백

    _refocusScanBoxField();
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
    final canProceed = _boxes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Part')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected PART_NO: ${widget.selectedPartNo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Scan Box Label',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _onSubmitted(value),
            ),

            const SizedBox(height: 12),
            Text(
              'Scanned Boxes: (Box Count: ${_boxes.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _boxes.length,
                itemBuilder: (_, i) {
                  final b = _boxes[i];
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
                onPressed: canProceed
                    ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlacePartPage(
                        selectedPartNo: widget.selectedPartNo,
                        pickedBoxes: _boxes,
                      ),
                    ),
                  );
                }
                    : null,
                child: const Text('Proceed to Place Part'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
