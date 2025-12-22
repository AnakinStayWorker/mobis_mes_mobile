import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_id/android_id.dart';

class Footer extends StatefulWidget {
  const Footer({super.key});

  @override
  State<Footer> createState() => _Footer();
}

class _Footer extends State<Footer> {
  final String _currentYear = DateTime.now().year.toString();
  String _deviceID = "";

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
    _getDeviceID();
  }

  Future<void> _getDeviceID() async {
    const androidIdPlugin = AndroidId();
    _deviceID = await androidIdPlugin.getId() ?? 'Unknown';

    setState(() {
      _deviceID = _deviceID;
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.9),
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child:Column(
          children: [
            Row(
              children: [
                Text(
                  'Version: ${_packageInfo.version}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10.0),
                Text(
                  '© $_currentYear MOBIS All rights reserved.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Text(
                  'Device Id:$_deviceID',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}