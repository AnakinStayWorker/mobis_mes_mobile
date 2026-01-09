import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/main_menu.dart';
import 'package:mobis_mes_mobile/screen/inventory_check.dart';
import 'package:mobis_mes_mobile/screen/monitor_part.dart';
import 'package:mobis_mes_mobile/screen/logout.dart';

enum AppPage { home, monitorPart, inventoryCheck }

class AppDrawer extends StatelessWidget {
  final AppPage current;
  const AppDrawer({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadUserAndDevice(),
      builder: (context, snapshot) {
        final userId = snapshot.data?['id'] ?? '';
        final userName = snapshot.data?['name'] ?? '';
        final deviceId = snapshot.data?['deviceId'] ?? '';
        final deviceNick = snapshot.data?['deviceNick'] ?? '';

        final nickText = deviceNick.isEmpty ? '-' : deviceNick;
        final idText = deviceId.isEmpty ? '-' : deviceId;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: BACKGROUND_COLOR),
                accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(userId, style: const TextStyle(fontWeight: FontWeight.bold)),
                currentAccountPicture: const CircleAvatar(),
              ),

              // Device info card
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.devices, size: 18, color: Colors.indigo),
                          SizedBox(width: 6),
                          Text(
                            'Device',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _kvRow('Nickname', nickText),
                      const SizedBox(height: 6),
                      _kvRow('Device Id', idText),
                    ],
                  ),
                ),
              ),

              // Home
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Main Menu'),
                enabled: current != AppPage.home,
                onTap: current == AppPage.home
                    ? () => Navigator.pop(context)
                    : () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainMenuView()),
                        (route) => false,
                  );
                },
              ),

              // Monitor Part
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Monitor Part'),
                enabled: current != AppPage.monitorPart,
                onTap: current == AppPage.monitorPart
                    ? () => Navigator.pop(context)
                    : () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MonitorPartPage()),
                  );
                },
              ),

              // Inventory Check
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Inventory Check'),
                enabled: current != AppPage.inventoryCheck,
                onTap: current == AppPage.inventoryCheck
                    ? () => Navigator.pop(context)
                    : () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryCheckPage()),
                  );
                },
              ),

              const Divider(),

              // Sign out
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LogOutPage()));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _kvRow(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>> _loadUserAndDevice() async {
    const storage = FlutterSecureStorage();
    final id = await storage.read(key: 'UserId') ?? '';
    final name = await storage.read(key: 'UserName') ?? '';
    final deviceId = await storage.read(key: 'DeviceId') ?? '';
    final deviceNick = await storage.read(key: 'DeviceNickName') ?? '';
    return {'id': id, 'name': name, 'deviceId': deviceId, 'deviceNick': deviceNick};
  }
}
