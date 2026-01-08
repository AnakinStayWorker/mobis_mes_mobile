import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'place_part.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';

class PickedBox {
  final String partNo;
  final int qty;
  final String serial;
  final String raw; // 원본 스캔

  PickedBox({
    required this.partNo,
    required this.qty,
    required this.serial,
    required this.raw,
  });

  String key() => '$partNo|$serial';
}

class PickupPartPage extends StatefulWidget {
  final String selectedPartNo;
  final String selectedPcCode;

  const PickupPartPage({
    super.key,
    required this.selectedPartNo,
    required this.selectedPcCode,
  });

  @override
  State<PickupPartPage> createState() => _PickupPartPageState();
}

class _PickupPartPageState extends State<PickupPartPage> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  final List<PickedBox> _boxes = [];

  bool _navigating = false; // 중복 클릭 방지

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
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
  }

  String stripPrefix1(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.length >= 2 && RegExp(r'^[A-Za-z]').hasMatch(s[0])) {
      return s.substring(1);
    }
    return s;
  }

  // 예: P68464838ABV48671Q56S960240436 (붙어서 들어오는 케이스)
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

  Future<void> _onSubmitted(String v) async {
    final text = v.trim();
    if (text.isEmpty) return;

    _scanCtrl.clear();

    final tokens = splitPQVS(text);
    if (tokens.isEmpty) {
      await _popup(
        'Scan Error',
        'Invalid label scan.\nExpected: P..., Q..., V..., S...\nReceived: $text',
      );
      _refocus();
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
      _refocus();
      return;
    }

    final part = stripPrefix1(p).toUpperCase();
    final qty = parseQtyFromQ(q);
    final serial = stripPrefix1(s);

    if (qty <= 0) {
      await _popup('Scan Error', 'Invalid Qty from label: $q');
      _refocus();
      return;
    }

    if (part != widget.selectedPartNo.toUpperCase()) {
      await _popup(
        'Invalid Part',
        'Scanned Part# ($part) does not match selected PART_NO (${widget.selectedPartNo}).',
      );
      _refocus();
      return;
    }

    final box = PickedBox(partNo: part, qty: qty, serial: serial, raw: text);

    final exists = _boxes.any((b) => b.partNo == box.partNo && b.serial == box.serial);
    if (exists) {
      await _popup(
        'Duplicate',
        'This box is already scanned.\nPart#: ${box.partNo}\nSerial#: ${box.serial}',
      );
      _refocus();
      return;
    }

    setState(() => _boxes.add(box));
    await _scanSuccessFeedback();
    _refocus();
  }

  Future<void> _scanSuccessFeedback() async {
    try {
      SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _refocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scanFocus.requestFocus();
    });
  }

  Future<void> _proceed() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    try {
      // 토큰/세션 확인
      // 만료라면 AuthSession이 팝업 + 로그인 이동 처리하고 false 리턴
      final ok = await AuthSession.ensureAliveOrLogin(context);
      if (!ok) return;

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlacePartPage(
            selectedPartNo: widget.selectedPartNo,
            selectedPcCode: widget.selectedPcCode,
            pickedBoxes: _boxes,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _boxes.isNotEmpty && !_navigating;

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Part')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: ${widget.selectedPartNo}  |  ${widget.selectedPcCode}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _scanCtrl,
              focusNode: _scanFocus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Scan Box Label',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _onSubmitted,
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
                onPressed: canProceed ? _proceed : null,
                child: _navigating
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Proceed to Place Part'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
