import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Footer extends StatefulWidget {
  const Footer({super.key});

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  final String _currentYear = DateTime.now().year.toString();
  static const _storage = FlutterSecureStorage();

  String _deviceId = '';
  String _deviceNick = '';

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _loadDeviceInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _packageInfo = info);
  }

  Future<void> _loadDeviceInfo() async {
    // 1) storage 우선
    final storedId = await _storage.read(key: 'DeviceId');
    final storedNick = await _storage.read(key: 'DeviceNickName');

    // 2) 없으면 AndroidId fallback
    String id = storedId ?? '';
    if (id.isEmpty) {
      const androidIdPlugin = AndroidId();
      id = await androidIdPlugin.getId() ?? 'Unknown';
    }

    if (!mounted) return;
    setState(() {
      _deviceId = id;
      _deviceNick = (storedNick ?? '').trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickText = _deviceNick.isEmpty ? '-' : _deviceNick;

    return Container(
      color: Colors.white.withOpacity(0.9),
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Version: ${_packageInfo.version}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo, fontSize: 12),
                ),
                const SizedBox(width: 10.0),
                Text(
                  '© $_currentYear MOBIS All rights reserved.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Text(
                  'Device: $_deviceId',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo, fontSize: 12),
                ),
                const SizedBox(width: 10.0),
                Text(
                  'Nick: $nickText',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo, fontSize: 12),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
