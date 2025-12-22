// lib/screen/inventory_check.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobis_mes_mobile/component/app_drawer.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';
import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/footer.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/inventory_models.dart';
import 'package:mobis_mes_mobile/screen/login.dart';

class InventoryCheckPage extends StatefulWidget {
  const InventoryCheckPage({super.key});

  @override
  State<InventoryCheckPage> createState() => _InventoryCheckPageState();
}

class _InventoryCheckPageState extends State<InventoryCheckPage> {
  final _node = FocusNode();
  final _focusId = FocusNode();
  final _ctrlId = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  String? _lastError;
  bool _sessionDialogOpen = false;

  List<InventoryItem> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    _focusId.dispose();
    _ctrlId.dispose();
    super.dispose();
  }

  Future<void> _handleSessionExpired() async {
    if (_sessionDialogOpen) return;
    _sessionDialogOpen = true;
    try {
      await AuthSession.clearLocalTokens();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          title: const Text('Session expired'),
          content: const Text('Please sign in again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Login()),
            (route) => false,
      );
    } finally {
      _sessionDialogOpen = false;
    }
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _lastError = null;
    });

    final res = await MobisWebApi.getInventoryAll();
    if (!mounted) return;

    if (res.resultCode == '401') {
      setState(() {
        _loading = false;
        _rows = [];
        _lastError = null;
      });
      await _handleSessionExpired();
      return;
    }

    setState(() {
      _loading = false;
      if (res.resultCode == '00') {
        _rows = res.items;
      } else {
        _rows = [];
        _lastError =
        res.resultMessage.isNotEmpty ? res.resultMessage : 'Failed to get inventory.';
      }
    });
  }

  Future<void> _fetchById(String id) async {
    setState(() {
      _loading = true;
      _lastError = null;
    });

    final res = await MobisWebApi.getInventoryQty(id);
    if (!mounted) return;

    if (res.resultCode == '401') {
      setState(() {
        _loading = false;
        _rows = [];
        _lastError = null;
      });
      await _handleSessionExpired();
      return;
    }

    setState(() {
      _loading = false;
      if (res.resultCode == '00' && res.item != null) {
        _rows = [res.item!];
      } else {
        _rows = [];
        _lastError =
        res.resultMessage.isNotEmpty ? res.resultMessage : 'Inventory not found.';
      }
    });
  }

  void _onSearch() {
    final id = _ctrlId.text.trim();
    if (id.isEmpty) {
      _fetchAll();
    } else {
      _fetchById(id);
    }
  }

  DataTable _buildTable() {
    return DataTable(
      columns: const [
        DataColumn(
          label: Text('ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DataColumn(
          label:
          Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DataColumn(
          label:
          Text('UseFlag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DataColumn(
          label: Text('Last Updated',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DataColumn(
          label:
          Text('Remark', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        DataColumn(
          label:
          Text('Other', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
      rows: _rows
          .map(
            (e) => DataRow(
          cells: [
            DataCell(Text(e.id)),
            DataCell(Text(e.quantity.toString())),
            DataCell(Text(e.useFlag)),
            DataCell(
              Text(
                e.lastUptDate == null
                    ? ''
                    : e.lastUptDate!.toLocal().toString().split('.').first,
              ),
            ),
            DataCell(Text(e.remark ?? '')),
            DataCell(Text(e.otherInfo ?? '')),
          ],
        ),
      )
          .toList(),
    );
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = KeyboardListener(
      focusNode: _node,
      onKeyEvent: (value) {
        if (value is KeyDownEvent && value.logicalKey == LogicalKeyboardKey.enter) {
          _onSearch();
          _focusId.requestFocus();
        }
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      focusNode: _focusId,
                      controller: _ctrlId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Type inventory ID (optional)',
                        labelText: 'Inventory ID',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 50,
                    width: 140,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: SEARCH_BUTTON_BACK_COLOR,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: _loading ? null : _onSearch,
                      child: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                          : const Text('Search',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_lastError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_lastError!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildTable(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Inventory Check'),
        backgroundColor: BACKGROUND_COLOR,
        titleTextStyle:
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 24),
      ),
      drawer: const AppDrawer(current: AppPage.inventoryCheck),
      bottomNavigationBar: const BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Center(child: Footer()),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        backgroundColor: ACTION_BUTTON_BACK_COLOR,
        onPressed: () => Navigator.pop(context),
        tooltip: 'Back',
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}
