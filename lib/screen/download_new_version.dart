import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/footer.dart';
import 'package:mobis_mes_mobile/model/version_check_info.dart';

class DownloadNewVersion extends StatefulWidget {
  final VersionCheckInfoResponse versionChkResponse;
  final String currentVer;

  const DownloadNewVersion({
    super.key,
    required this.versionChkResponse,
    required this.currentVer,
  });

  @override
  State<DownloadNewVersion> createState() => _DownloadNewVersionState();
}

class _DownloadNewVersionState extends State<DownloadNewVersion> {
  final _storage = const FlutterSecureStorage();

  String _deviceId = '';
  bool _opening = false; // 버튼 로딩 표시용

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await _storage.read(key: 'DeviceId') ?? '';
    if (!mounted) return;
    setState(() => _deviceId = id);
  }

  Future<void> _openApkUrl(String url) async {
    try {
      final trimmed = url.trim();
      if (trimmed.isEmpty) {
        await _showError('Invalid download URL.');
        return;
      }

      final uri = Uri.tryParse(trimmed);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        await _showError('Unsupported URL scheme.');
        return;
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await _showError('Could not launch the download URL.');
      }
    } catch (_) {
      await _showError('Failed to open the download URL.');
    }
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vi = widget.versionChkResponse.versionInfo!;
    final latest = vi.lastAppVer.isNotEmpty
        ? vi.lastAppVer
        : '${vi.majorVer}.${vi.minorVer}.${vi.patchVer}';
    final isUpdateAvailable = (vi.verChkRet.trim().toUpperCase() == 'Y');
    final canDownload = isUpdateAvailable && vi.installUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Version Check'),
        backgroundColor: BACKGROUND_COLOR,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 24,
        ),
        automaticallyImplyLeading: true,
      ),
      bottomNavigationBar: const BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Center(child: Footer()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('Current Version: ${widget.currentVer}'),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('Latest Version: $latest'),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                vi.retMsg,
                style: TextStyle(
                  color: isUpdateAvailable ? Colors.blue : Colors.black54,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: (!canDownload || _opening)
                      ? null
                      : () async {
                    setState(() => _opening = true);
                    await _openApkUrl(vi.installUrl);
                    if (!mounted) return;
                    setState(() => _opening = false);
                  },
                  child: _opening
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                      : const Text('Get the Latest Version'),
                ),
              ),
            ),

            const SizedBox(height: 40),

            if (_deviceId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Device Id: $_deviceId',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
